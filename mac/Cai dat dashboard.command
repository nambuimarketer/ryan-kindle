#!/bin/bash
# Bấm đúp file này để cài phần chạy trên Mac của dashboard Kindle
# (gửi việc trong vault + mức dùng Claude lên Apps Script, 10 phút/lần).
# TRƯỚC KHI BẤM: copy DATA_URL (link Apps Script có ?token=...) vào clipboard.
DIR="$(cd "$(dirname "$0")" && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$HOME/.npm-global/bin:/usr/bin:/bin"
echo "=== Cài dashboard Kindle trên Mac ==="
echo

# 1. Claude Code
if command -v claude >/dev/null 2>&1; then
  echo "[1/3] Claude Code: có ($(claude --version 2>/dev/null | head -1))"
else
  echo "[1/3] Chưa có Claude Code. Phần % Claude sẽ chưa chạy, phần việc trong vault vẫn chạy."
  echo "      Cài sau bằng: curl -fsSL https://claude.ai/install.sh | bash   rồi gõ: claude   để đăng nhập."
fi

# 2. DATA_URL (lấy từ clipboard, không in ra màn hình)
if [ -s "$HOME/.kindle-dashboard-url" ]; then
  echo "[2/3] DATA_URL: đã lưu từ trước."
else
  CLIP="$(pbpaste | tr -d ' \n\r')"
  case "$CLIP" in
    https://script.google.com/*\?token=*)
      printf '%s' "$CLIP" > "$HOME/.kindle-dashboard-url"; chmod 600 "$HOME/.kindle-dashboard-url"
      echo "[2/3] DATA_URL: đã lưu từ clipboard." ;;
    *)
      echo "[2/3] Clipboard không chứa DATA_URL. Copy DATA_URL rồi bấm đúp lại file này."
      read -rp "Nhấn Enter để đóng."; exit 1 ;;
  esac
fi
unset CLIP

# 3. Cài job chạy ngầm + chạy thử
echo "[3/3] Cài job chạy ngầm (nếu macOS hỏi quyền Keychain hoặc iCloud Drive: nhập mật khẩu Mac, bấm Always Allow / Allow)"
echo
bash "$DIR/install.sh"
echo
echo "=== Gửi Claude 4 dòng log phía trên (không chứa thông tin bí mật) ==="
read -rp "Nhấn Enter để đóng."
