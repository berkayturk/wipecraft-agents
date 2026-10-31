#!/bin/bash
# Wipecraft Claude Code eklentisi, SessionStart: boşaltılabilir alan eşiği aşıyorsa tek satır yazar.
# Stdout oturumun bağlamına eklenir. Tarama dakikalar sürebilir; bu yüzden kanca taramayı BEKLEMEZ:
#   1) Önbellek dosyası varsa ve 24 saatten yeniyse satırı hemen yazar (satır zaten eşikten geçmiştir).
#   2) Ayrı, düşük öncelikli bir arka plan işi `status`u çalıştırıp sonucu önbelleğe atomik yazar; ilk oturum
#      sessizdir. Süren bir yenileme varsa ya da önbellek bir saatten gençse yenisi başlamaz.
# Oturumu asla bozmaz: her yol 0 ile biter; errexit kullanılmaz. CLI yalnız okur; yazılan tek yer önbellek dizinidir.
set -u

CLI=wipecraft
THRESHOLD=1GB
MAX_AGE_MINUTES=1440
# Önbellek bundan gençse yenileme başlamaz (resume, clear, compact ve fork da SessionStart tetikler).
REFRESH_AFTER_MINUTES=60
STALE_LOCK_MINUTES=10

command -v "$CLI" >/dev/null 2>&1 || exit 0

# Önbellek tabanı: mutlak XDG_CACHE_HOME; yoksa YALNIZ mutlak ve boş olmayan HOME altındaki Library/Caches.
# Göreli XDG yok sayılır (XDG belirtimi; yoksa dizin kullanıcının projesinde açılırdı). Hiçbiri kullanılamıyorsa hemen
# çıkılır: dizin açılmaz, yenileme ve CLI çağrısı olmaz (boş HOME "/Library/Caches" üretirdi).
cache_base=
case ${XDG_CACHE_HOME:-} in
  /) ;;
  /*) cache_base=$XDG_CACHE_HOME ;;
esac
if [ -z "$cache_base" ]; then
  case ${HOME:-} in
    /) exit 0 ;;
    /*) cache_base=$HOME/Library/Caches ;;
    *) exit 0 ;;
  esac
fi
cache_dir=$cache_base/$CLI
cache=$cache_dir/session-brief.txt
lock=$cache_dir/refresh.lock

# Arka plan kipi (bu betiğin kendi kendini `--refresh` ile çağırması): tarar, sonucu geçici dosyaya yazıp taşır.
if [ "${1:-}" = --refresh ]; then
  trap '/bin/rmdir "$lock" 2>/dev/null' EXIT
  # `--no-github`: ağ çağrısı yok. Hata çıktısı ve çıkış kodu yok sayılır; boş çıktı boş önbellek olur.
  line=$("$CLI" status --brief --no-github --min-reclaimable "$THRESHOLD" 2>/dev/null </dev/null)
  tmp=$cache.tmp.$$
  if printf '%s' "$line" >"$tmp" 2>/dev/null; then
    /bin/mv -f "$tmp" "$cache" 2>/dev/null || /bin/rm -f "$tmp" 2>/dev/null
  fi
  exit 0
fi

# 1) Taze önbellek varsa hemen yaz. 2) Önbellek bir saatten gençse yenileme de gerekmez.
if [ -s "$cache" ] && [ -n "$(/usr/bin/find "$cache" -maxdepth 0 -mmin "-$MAX_AGE_MINUTES" -print 2>/dev/null)" ]; then
  line=$(<"$cache")
  [ -z "$line" ] || printf '%s\n' "$line"
fi
if [ -e "$cache" ] && [ -n "$(/usr/bin/find "$cache" -maxdepth 0 -mmin "-$REFRESH_AFTER_MINUTES" -print 2>/dev/null)" ]; then
  exit 0
fi

# Yenileme: kilit dizini atomiktir. Çökmüş bir yenilemenin kilidi 10 dakika sonra düşer.
/bin/mkdir -p "$cache_dir" 2>/dev/null || exit 0
if [ -n "$(/usr/bin/find "$lock" -maxdepth 0 -mmin "+$STALE_LOCK_MINUTES" -print 2>/dev/null)" ]; then
  /bin/rmdir "$lock" 2>/dev/null
fi
/bin/mkdir "$lock" 2>/dev/null || exit 0

# Üç akış da yönlendirilir: kanca hemen döner, Claude Code devralınan borulara beklemez.
( /usr/bin/nohup /usr/bin/nice -n 19 /bin/bash "$0" --refresh </dev/null >/dev/null 2>&1 & ) 2>/dev/null
exit 0
