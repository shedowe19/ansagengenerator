#!/usr/bin/env bash
# Rebuild the compact embedded Ogg/Opus library from the verified v1.8 source.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
release_repo='shedowe19/ansagengenerator-android'
release_tag='v1.8-debug'
destination="$repo_root/app/src/main/assets/offline"
cache_root="${ANSAGEN_OPUS_BUILD_CACHE:-$repo_root/.opus-build-cache}"
source_dir="$cache_root/source-parts"
source_zip="$cache_root/ansagengenerator-offline-data.zip"
staging="$cache_root/opus-stage"
output="$cache_root/ansagengenerator-offline-opus-data.zip"
manifest="$cache_root/ansagengenerator-offline-opus-manifest.json"
workers="${ANSAGEN_OPUS_WORKERS:-12}"

expected_part_00='81460e953558dd20876dfb0de0f259384a0dc647631aa6aa8a3480518d434c39'
expected_part_01='bfba2a83a06868cd708b556997460b2fff1c07d63c6d70709e2b6144e1589025'
expected_source='2be282ad3b829268e8d69455e2ae82acfe35a82669c7f583a40740109ed0efc6'
expected_opus='80ada82a559fa5a40085cfd7c10aeae483991be68ec4ca0073150755489e4214'
expected_opus_size='467116673'

command -v gh >/dev/null || { echo 'GitHub CLI gh fehlt.' >&2; exit 1; }
command -v ffmpeg >/dev/null || { echo 'ffmpeg mit libopus fehlt.' >&2; exit 1; }
mkdir -p "$source_dir" "$destination"

# Download only into the build cache. The active APK assets never contain the
# original multi-GB WAV parts after a successful Opus build.
gh release download "$release_tag" --repo "$release_repo" \
  --pattern 'ansagengenerator-offline-data.zip.part-*' --dir "$source_dir" --clobber
mv -f "$source_dir/ansagengenerator-offline-data.zip.part-00" "$source_dir/ansagengenerator-offline-data-00.zip"
mv -f "$source_dir/ansagengenerator-offline-data.zip.part-01" "$source_dir/ansagengenerator-offline-data-01.zip"

printf '%s  %s\n' "$expected_part_00" "$source_dir/ansagengenerator-offline-data-00.zip" | sha256sum -c -
printf '%s  %s\n' "$expected_part_01" "$source_dir/ansagengenerator-offline-data-01.zip" | sha256sum -c -
cat "$source_dir/ansagengenerator-offline-data-00.zip" "$source_dir/ansagengenerator-offline-data-01.zip" > "$source_zip"
printf '%s  %s\n' "$expected_source" "$source_zip" | sha256sum -c -

python3 "$repo_root/scripts/build_opus_offline_library.py" \
  --source-zip "$source_zip" --staging "$staging" --output "$output" \
  --manifest "$manifest" --bitrate 32k --workers "$workers" --clean

actual_size=$(stat -c '%s' "$output")
test "$actual_size" = "$expected_opus_size"
printf '%s  %s\n' "$expected_opus" "$output" | sha256sum -c -
parts_manifest="$destination/ansagengenerator-offline-opus-data.parts.json"
python3 "$repo_root/../tool/offline_archive_parts.py" split \
  --input "$output" --manifest "$parts_manifest" \
  --archive-name ansagengenerator-offline-opus-data.zip
python3 "$repo_root/../tool/offline_archive_parts.py" assemble \
  --manifest "$parts_manifest"
printf '%s  %s\n' "$expected_opus" "$destination/ansagengenerator-offline-opus-data.zip" | sha256sum -c -
printf 'Prepared verified Git-native Ogg/Opus library parts in %s\n' "$destination"
