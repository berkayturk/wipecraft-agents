#!/bin/bash
# Wipecraft Cursor eklentisi, sessionStart: `session-start.sh`'in tek satırını Cursor'un beklediği JSON'a sarar
# (`additional_context`). Satır yoksa (ilk oturum, eşik altı, CLI yok) hiçbir şey yazmaz. Her yol 0 ile biter.
set -u

line=$(/bin/bash "${0%/*}/session-start.sh" </dev/null 2>/dev/null)
[ -n "$line" ] || exit 0

# JSON dizesi kaçışı: ters bölü, tırnak, sekme ve satır sonu.
line=${line//\\/\\\\}
line=${line//\"/\\\"}
line=${line//$'\t'/\\t}
line=${line//$'\n'/\\n}
printf '{"additional_context":"%s"}\n' "$line"
exit 0
