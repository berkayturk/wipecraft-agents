#!/bin/bash
# Wipecraft Claude Code eklentisi, SessionEnd: oturum bir bağlı worktree'de bittiyse durumunu stderr'e tek satır yazar.
# Uygulamada "Tidy finished worktrees after agent sessions" açıksa, öğe kilitli de olsa, düşük öncelikli bir
# arka plan işi kısa bir gecikmeden sonra `clean <kimlik> --apply` çalıştırır; kilidi CLI'nın eylem anı denetimi
# karara bağlar (betik hiçbir şeyi aşmaz; reddedilirse çıkış 3 sessizce geçilir). Kanca temizliği BEKLEMEZ.
# Oturumu asla bozmaz: her yol 0 ile biter; errexit kullanılmaz. Ayrıştırıcı (`jq` ya da `python3`) yoksa hiçbir şey çalışmaz.
set -u

CLI=wipecraft
SOURCE=worktrees
SETTING=claudeAutoTidy
# Arka plan temizliğinin gecikmesi (sn); oturum sürecinin çıkması için süre tanır. Testler kısaltır.
DELAY=${SESSION_TIDY_DELAY:-10}

command -v "$CLI" >/dev/null 2>&1 || exit 0

# Arka plan kipi (bu betiğin kendi kendini `--tidy <kimlik>` ile çağırması): bekler, sonra temizler.
if [ "${1:-}" = --tidy ]; then
  id=${2:-}
  case $id in
    "$SOURCE".*) ;;
    *) exit 0 ;;
  esac
  [[ $DELAY =~ ^[0-9]+(\.[0-9]+)?$ ]] || DELAY=10
  /bin/sleep "$DELAY" 2>/dev/null
  "$CLI" clean "$id" --apply >/dev/null 2>&1 </dev/null
  exit 0
fi

if command -v jq >/dev/null 2>&1; then
  PARSER=jq
elif command -v python3 >/dev/null 2>&1; then
  PARSER=python3
else
  exit 0
fi

# Kanca girdisi stdin'de JSON; yalnız `cwd` okunur.
input=$(</dev/stdin) || exit 0
if [ "$PARSER" = jq ]; then
  cwd=$(printf '%s' "$input" | jq -r '.cwd | strings' 2>/dev/null)
else
  cwd=$(printf '%s' "$input" | python3 -I -c '
import json, sys
try:
    value = json.load(sys.stdin).get("cwd")
except Exception:
    value = None
if isinstance(value, str):
    print(value)
' 2>/dev/null)
fi
# Yalnız mutlak yol: göreli yolda yukarı yürüyüş hiç bitmezdi.
case $cwd in
  /*) ;;
  *) exit 0 ;;
esac
cwd=${cwd%/}
[ -n "$cwd" ] || exit 0

# Bağlı worktree'nin kökünde `.git` bir DOSYADIR (ana depoda dizin). Yukarı doğru ilk `.git` girdisine bakılır;
# dizin ise ana depodur ve taramaya gerek yoktur.
dir=$cwd
linked=0
while [ -n "$dir" ]; do
  if [ -f "$dir/.git" ]; then
    linked=1
    break
  fi
  [ -e "$dir/.git" ] && break
  parent=${dir%/*}
  [ "$parent" != "$dir" ] || break
  dir=$parent
done
[ "$linked" = 1 ] || exit 0

# Eşleşme hem verilen hem fiziksel yolla yapılır (sembolik bağlantı); APFS gibi büyük/küçük harf duyarsız.
physical=$(cd "$cwd" 2>/dev/null && pwd -P) || physical=

# `--no-github` verilmez: uygulamanın tercihi geçerlidir. Kısmi tarama (çıkış 2) de geçerli JSON üretir.
report=$("$CLI" scan --json --source "$SOURCE" 2>/dev/null </dev/null) || true
[ -n "$report" ] || exit 0

# Tek satır: kimlik, kilit, boyut, başlık, kilit nedeni (\x1f ile ayrılmış; boş alan kaybolmaz).
if [ "$PARSER" = jq ]; then
  row=$(printf '%s' "$report" | jq -r --arg cwd "$cwd" --arg phys "$physical" --arg source "$SOURCE" '
    ($cwd | ascii_downcase) as $c | ($phys | ascii_downcase) as $f
    | [.items[]?
        | select(.source == $source and ((.id // "") | endswith(".remove")))
        | ([(.paths // [])[] | strings | ascii_downcase | select(. != "") | . as $p
            | select($c == $p or ($c | startswith($p + "/")) or $f == $p or ($f | startswith($p + "/")))
            | length] | max) as $len
        | select($len != null)
        | {len: $len, row: ([(.id // ""), ((.locked // false) | tostring), ((.sizeBytes // 0) | tostring),
                             (.title // ""), (.lockReason // "")] | join("\u001f"))}]
    | sort_by(-.len) | (.[0].row // empty)' 2>/dev/null)
else
  row=$(printf '%s' "$report" | python3 -I -c '
import json, sys
cwd, phys = (value.lower() for value in sys.argv[1:3])
try:
    items = json.load(sys.stdin).get("items") or []
except Exception:
    items = []
best = None
for item in items:
    try:
        ident = str(item.get("id") or "")
        if str(item.get("source")) != sys.argv[3] or not ident.endswith(".remove"):
            continue
        paths = [p.lower() for p in (item.get("paths") or []) if isinstance(p, str) and p]
        lengths = [len(p) for p in paths
                   if cwd == p or cwd.startswith(p + "/") or phys == p or phys.startswith(p + "/")]
        if not lengths:
            continue
        fields = [ident, "true" if item.get("locked") else "false", str(item.get("sizeBytes") or 0),
                  str(item.get("title") or ""), str(item.get("lockReason") or "")]
        if best is None or max(lengths) > best[0]:
            best = (max(lengths), "\x1f".join(fields))
    except Exception:
        continue
if best:
    print(best[1])
' "$cwd" "$physical" "$SOURCE" 2>/dev/null)
fi
[ -n "$row" ] || exit 0

IFS=$'\x1f' read -r id locked size title reason <<<"$row"

# Terminale yazılacak metinden denetim karakterleri (ESC dahil) atılır.
title=${title//[[:cntrl:]]/}
reason=${reason//[[:cntrl:]]/}
[ -n "$title" ] || title=worktree
[[ $size =~ ^[0-9]+$ ]] || size=0

human_size() {
  local bytes=$1
  if [ "$bytes" -ge 1000000000 ]; then
    printf '%s.%s GB' "$((bytes / 1000000000))" "$(((bytes % 1000000000) / 100000000))"
  elif [ "$bytes" -ge 1000000 ]; then
    printf '%s MB' "$((bytes / 1000000))"
  else
    printf '%s KB' "$((bytes / 1000))"
  fi
}
amount=$(human_size "$size")

if [ "$locked" = true ]; then
  printf '%s: %s, %s, stays: %s\n' "$CLI" "$title" "$amount" "${reason:-locked}" >&2
else
  printf '%s: %s, %s, can be removed\n' "$CLI" "$title" "$amount" >&2
fi

# Kimlik her zaman "worktrees.<yol>.remove" biçimindedir; başka biçim (örn. "-" ile başlayan) hiçbir zaman verilmez.
case $id in
  "$SOURCE".*) ;;
  *) exit 0 ;;
esac

[ "$("$CLI" config get "$SETTING" 2>/dev/null </dev/null)" = true ] || exit 0

# Kilitli de olsa zamanlanır; üç akış da yönlendirilir, kanca hemen döner.
( /usr/bin/nohup /usr/bin/nice -n 19 /bin/bash "$0" --tidy "$id" </dev/null >/dev/null 2>&1 & ) 2>/dev/null
exit 0
