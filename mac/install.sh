#!/bin/bash
# Cài job gửi việc trong vault + mức dùng Claude trên Mac: chạy 10 phút/lần bằng launchd.
# Cách dùng:  bash install.sh
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
# Chép script ra ~/kindle-dashboard-mac: macOS chặn job chạy ngầm đọc thư mục Downloads/Desktop/Documents
DIR="$HOME/kindle-dashboard-mac"
mkdir -p "$DIR"
cp "$SRC/claude_usage.sh" "$SRC/vault_tasks.py" "$DIR/"
chmod +x "$DIR/claude_usage.sh"
command -v python3 >/dev/null || echo "CẢNH BÁO: chưa có python3 (cần để đọc việc trong vault). Cài: brew install python"

if [ ! -s "$HOME/.kindle-dashboard-url" ]; then
  echo "Dán DATA_URL (link Web app Apps Script + ?token=...) rồi Enter:"
  read -r url
  printf '%s' "$url" > "$HOME/.kindle-dashboard-url"
  chmod 600 "$HOME/.kindle-dashboard-url"
fi

PLIST="$HOME/Library/LaunchAgents/com.kindledashboard.claude-usage.plist"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.kindledashboard.claude-usage</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$DIR/claude_usage.sh</string></array>
  <key>StartInterval</key><integer>600</integer>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
EOF
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
echo "Đã cài. Chạy thử ngay:"
bash "$DIR/claude_usage.sh" || true
tail -n 4 "$DIR/claude_usage.log"
echo
echo "Nếu macOS hỏi 'security muốn truy cập Keychain' → bấm Always Allow (Luôn cho phép)."
