#!/usr/bin/env bash
# Builds the release and exercises real ZIP64 range-loading plus WAV export in Chromium.
set -euo pipefail
python3 tool/offline_archive_parts.py assemble --manifest source-android/app/src/main/assets/offline/ansagengenerator-offline-opus-data.parts.json

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

flutter build web --release --pwa-strategy=none
python3 tool/serve_web_with_ranges.py --directory build/web --port 8765 > /tmp/ansagengenerator-web-range.log 2>&1 &
server_pid=$!
cleanup() {
  kill "$server_pid" 2>/dev/null || true
  wait "$server_pid" 2>/dev/null || true
}
trap cleanup EXIT

for _ in {1..30}; do
  if curl --fail --silent http://127.0.0.1:8765/index.html >/dev/null; then
    break
  fi
  sleep 0.1
done

if [[ -z "${CHROME_EXECUTABLE:-}" ]]; then
  export CHROME_EXECUTABLE="$(command -v google-chrome || command -v chromium || command -v chromium-browser)"
fi
: "${CHROME_EXECUTABLE:?Chrome/Chromium is required for this browser test.}"

archive_url='http://127.0.0.1:8765/assets/source-android/app/src/main/assets/offline/ansagengenerator-offline-opus-data.zip'
flutter test --platform chrome \
  --dart-define="OFFLINE_ARCHIVE_URL=$archive_url" \
  test/web_offline_audio_library_browser_test.dart
