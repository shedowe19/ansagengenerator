#!/usr/bin/env bash
# Package the already verified Android APK and web release for a GitHub Release.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

version="${1:-$(awk '/^version:/{print $2; exit}' pubspec.yaml)}"
out="${2:-$root/.release/$version}"
apk="build/app/outputs/flutter-apk/app-debug.apk"
web="build/web"

[[ -s "$apk" ]] || { echo "APK fehlt: $apk" >&2; exit 1; }
[[ -d "$web" && -f "$web/index.html" ]] || {
  echo "Web-Release fehlt: $web" >&2
  exit 1
}

mkdir -p "$out"
cp "$apk" "$out/Ansagengenerator-v${version}-debug.apk"
(
  cd "$web"
  zip -q -r "$out/Ansagengenerator-web-v${version}.zip" .
)
(
  cd "$out"
  sha256sum \
    "Ansagengenerator-v${version}-debug.apk" \
    "Ansagengenerator-web-v${version}.zip" > SHA256SUMS.txt
)
printf 'Release-Artefakte erstellt: %s\n' "$out"
