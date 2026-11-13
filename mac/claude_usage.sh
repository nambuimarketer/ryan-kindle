#!/bin/bash
# Gửi lên Apps Script 2 thứ để dashboard Kindle hiển thị: việc cần làm trong vault Obsidian, và mức dùng Claude (phiên 5 giờ + tuần).
# Chạy trên Mac (đã cài và đăng nhập Claude Code), launchd gọi 10 phút/lần.
# Lưu ý: endpoint này là endpoint nội bộ Claude Code dùng, chưa được Anthropic công bố — có thể đổi bất cứ lúc nào.

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$HOME/.npm-global/bin:/usr/bin:/bin"
DIR="$(cd "$(dirname "$0")" && pwd)"
LOG="$DIR/claude_usage.log"
URL_FILE="$HOME/.kindle-dashboard-url"   # chứa DATA_URL (link Web app + ?token=...), chmod 600
STAMP="$DIR/.last_refresh"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"; tail -n 500 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"; }

DATA_URL="$(cat "$URL_FILE" 2>/dev/null)"
[ -n "$DATA_URL" ] || { log "Thiếu file $URL_FILE"; exit 1; }

# ---- Việc cần làm trong vault Obsidian → gửi lên Apps Script (chạy trước, độc lập với phần Claude)
# Đường dẫn vault: ghi trong ~/.kindle-dashboard-vault, không có thì dùng mặc định bên dưới.
VAULT="$(cat "$HOME/.kindle-dashboard-vault" 2>/dev/null)"
[ -n "$VAULT" ] || VAULT="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Ryan-OS"
if [ -d "$VAULT" ]; then
  VJSON="$(python3 "$DIR/vault_tasks.py" "$VAULT" 2>>"$LOG")"
  if [ -n "$VJSON" ]; then
    VPOST="$(printf '%s' "$VJSON" | curl -s -L -m 30 -H 'Content-Type: application/json' --data-binary @- "$DATA_URL&kind=vault")"
    case "$VPOST" in
      *'"ok":true'*) log "VAULT OK $(printf '%s' "$VJSON" | grep -o '"total": *[0-9]*')" ;;
      *) log "Gửi việc vault lỗi: $(echo "$VPOST" | cut -c1-160)" ;;
    esac
  else
    log "Không đọc được việc trong vault (python3 có chưa? macOS đã cho quyền đọc iCloud Drive chưa?)"
  fi
else
  log "Không thấy vault ở: $VAULT"
fi

get_token() {
  local creds
  creds="$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)"
  [ -n "$creds" ] || creds="$(cat "$HOME/.claude/.credentials.json" 2>/dev/null)"
  [ -n "$creds" ] || return 1
  osascript -l JavaScript -e 'function run(a){return JSON.parse(a[0]).claudeAiOauth.accessToken}' "$creds" 2>/dev/null
}

fetch_usage() {
  curl -s -m 20 -w '\n%{http_code}' \
    -H "Authorization: Bearer $1" \
    -H "anthropic-beta: oauth-2025-04-20" \
    -H "Content-Type: application/json" \
    "https://api.anthropic.com/api/oauth/usage"
}

TOKEN="$(get_token)" || { log "Không đọc được token Claude Code (đã đăng nhập Claude Code chưa?)"; exit 1; }
RESP="$(fetch_usage "$TOKEN")"
CODE="${RESP##*$'\n'}"; BODY="${RESP%$'\n'*}"

# Token hết hạn → chạy Claude Code 1 lệnh rất ngắn để nó tự làm mới token (tối đa 1 lần/giờ)
if [ "$CODE" = "401" ]; then
  if [ ! -f "$STAMP" ] || [ $(( $(date +%s) - $(stat -f %m "$STAMP") )) -gt 3600 ]; then
    touch "$STAMP"
    log "Token hết hạn, làm mới bằng claude -p"
    claude -p "ok" --max-turns 1 >/dev/null 2>&1
    TOKEN="$(get_token)"
    RESP="$(fetch_usage "$TOKEN")"
    CODE="${RESP##*$'\n'}"; BODY="${RESP%$'\n'*}"
  fi
fi

if [ "$CODE" != "200" ]; then
  log "Lấy mức dùng thất bại (HTTP $CODE)"
  exit 1
fi

POST="$(curl -s -L -m 30 -H 'Content-Type: application/json' --data "$BODY" "$DATA_URL")"
case "$POST" in
  *'"ok":true'*) log "OK $(echo "$BODY" | tr -d '\n' | cut -c1-160)" ;;
  *) log "Gửi lên Apps Script lỗi: $(echo "$POST" | cut -c1-160)" ;;
esac
