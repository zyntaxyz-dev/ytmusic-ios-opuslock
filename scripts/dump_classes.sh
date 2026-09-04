#!/usr/bin/env bash
# dump_classes.sh — redescubre clases/selectores de calidad de audio en
# YouTubeMusic cuando la ofuscación cambia entre versiones.
# Corre en macOS (nunca en este host Windows) o en CI macOS.
#
# Uso:
#   ./scripts/dump_classes.sh <YouTubeMusic.app | binario> [out/]
set -euo pipefail

TARGET="${1:?Uso: $0 <YouTubeMusic.app|binario> [out/]}"
OUT="${2:-out/headers}"
mkdir -p "$OUT"

BIN="$TARGET"
if [[ -d "$TARGET" ]]; then
  EXE="$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$TARGET/Info.plist" 2>/dev/null || echo YouTubeMusic)"
  BIN="$TARGET/$EXE"
fi

echo "== strings: itag / adaptiveFormats / streamingData / audioQuality =="
strings -a "$BIN" | grep -Ei 'itag|adaptiveFormats|streamingData|audioQuality|googlevideo|always.?high' | sort -u | head -n 200 | tee "$OUT/quality_strings.txt"

if command -v class-dump >/dev/null 2>&1; then
  echo "== class-dump =="
  class-dump -H "$BIN" -o "$OUT" 2>/dev/null || true
  grep -RliE 'quality|adaptive|streamingdata|HAMPlayer|audioQuality' "$OUT" | head -n 50 | tee "$OUT/quality_classes.txt"
else
  echo "(sin class-dump; usa 'brew install class-dump' o lechium/classdumpios)"
fi

cat <<'EOF'
Siguiente paso (dispositivo + Frida, app en primer plano):
  frida-trace -U -m "*Quality*" -m "*Adaptive*" -m "*StreamingData*" -m "*AudioQuality*" YouTubeMusic
  frida-trace -U -j '*!*/*Player*/*' YouTubeMusic   # si lo anterior no da hits
Actualiza solo Tweak/OpusLockPolicy.m + lookups en Tweak/OpusLock.m; no reescribas el tweak.
EOF
