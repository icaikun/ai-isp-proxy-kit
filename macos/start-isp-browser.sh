#!/usr/bin/env bash
set -euo pipefail

PURE_ISP_PORT="${PURE_ISP_PORT:-17899}"
TARGET_TZ="${TARGET_TZ:-America/Los_Angeles}"
START_URL="${START_URL:-https://ping0.cc/env}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="$SCRIPT_DIR/chrome-ca-profile"
CHROME_BIN="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

if [ ! -x "$CHROME_BIN" ]; then
  echo "未找到 Google Chrome: $CHROME_BIN"
  exit 1
fi

if ! nc -z 127.0.0.1 "$PURE_ISP_PORT" >/dev/null 2>&1; then
  echo "专属纯净端口 127.0.0.1:$PURE_ISP_PORT 未监听，请确认 Clash Verge 已运行并启用 全局扩展覆写配置。"
  exit 1
fi

mkdir -p "$PROFILE_DIR/Default"
PREF_FILE="$PROFILE_DIR/Default/Preferences"

python3 - "$PREF_FILE" << 'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1])
data = {}
if p.exists():
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        data = {}
data["webrtc"] = {
    "ip_handling_policy": "disable_non_proxied_udp",
    "multiple_routes_enabled": False,
    "nonproxied_udp_enabled": False,
}
p.write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")
PY

echo "正在启动 macOS 纯净 Chrome（端口: $PURE_ISP_PORT, 时区: $TARGET_TZ）..."
TZ="$TARGET_TZ" "$CHROME_BIN" \
  --user-data-dir="$PROFILE_DIR" \
  --proxy-server="socks5://127.0.0.1:$PURE_ISP_PORT" \
  --enforce-webrtc-ip-permission-check \
  --force-webrtc-ip-handling-policy=disable_non_proxied_udp \
  --lang=en-US \
  --accept-lang=en-US,en \
  --no-first-run \
  --no-default-browser-check \
  "$START_URL" >/dev/null 2>&1 &
