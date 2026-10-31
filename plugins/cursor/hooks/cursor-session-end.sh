#!/bin/bash
# Wipecraft Cursor eklentisi, sessionEnd: Cursor oturum olaylarında `cwd` vermez; klasör `CURSOR_PROJECT_DIR`'dan
# (yoksa `CLAUDE_PROJECT_DIR`) alınır ve `session-end.sh`'e Claude Code biçiminde (`{"cwd": …}`) verilir.
# Klasör yoksa hiçbir şey çalışmaz. Cursor bu olayın çıktısını göstermez; iş yalnız arka plan toparlamasıdır.
set -u

dir=${CURSOR_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-}}
case $dir in
  /*) ;;
  *) exit 0 ;;
esac

dir=${dir//\\/\\\\}
dir=${dir//\"/\\\"}
printf '{"cwd":"%s","hook_event_name":"SessionEnd"}' "$dir" | /bin/bash "${0%/*}/session-end.sh"
exit 0
