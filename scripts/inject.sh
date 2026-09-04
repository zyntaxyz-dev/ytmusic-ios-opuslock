#!/usr/bin/env bash
# inject.sh — inyecta OpusLock.dylib en la IPA desencriptada de YouTube Music
# y la deja lista para firmar/instalar por sideload (sin jailbreak).
#
# Uso:
#   ./scripts/inject.sh <input.ipa> <OpusLock.dylib> <output.ipa>
#
# Requisitos (macOS o Linux): unzip, zip, insert_dylib (o optool),
# ldid, y para firmar: zsign o codesign con "Apple Development".
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Uso: $0 <input.ipa> <OpusLock.dylib> <output.ipa>" >&2
  exit 2
fi

INPUT_IPA="$1"
DYLIB="$2"
OUTPUT_IPA="$3"

for f in "$INPUT_IPA" "$DYLIB"; do
  [[ -f "$f" ]] || { echo "No existe: $f" >&2; exit 1; }
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

unzip -q "$INPUT_IPA" -d "$WORK"
APP_DIR="$(find "$WORK/Payload" -maxdepth 1 -name '*.app' | head -n 1)"
[[ -n "${APP_DIR:-}" ]] || { echo "IPA sin Payload/*.app" >&2; exit 1; }
BIN="$APP_DIR/$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$APP_DIR/Info.plist" 2>/dev/null || echo YouTubeMusic)"
DYLIB_NAME="$(basename "$DYLIB")"

cp -f "$DYLIB" "$APP_DIR/$DYLIB_NAME"

# LC_LOAD_DYLIB -> @executable_path/OpusLock.dylib
if command -v insert_dylib >/dev/null 2>&1; then
  insert_dylib --in-place --all-yes "@executable_path/$DYLIB_NAME" "$BIN"
elif command -v optool >/dev/null 2>&1; then
  optool install -c load -p "@executable_path/$DYLIB_NAME" -t "$BIN"
else
  echo "Falta insert_dylib u optool" >&2
  exit 1
fi

# Refirmar dylib + binario con entitlements del repo (si ldid disponible).
ENT="entitlements.plist"
if command -v ldid >/dev/null 2>&1; then
  if [[ -f "$ENT" ]]; then
    ldid -S"$ENT" "$APP_DIR/$DYLIB_NAME"
  else
    ldid -S "$APP_DIR/$DYLIB_NAME"
  fi
fi

# Empaquetar. La firma final con identidad personal se hace fuera
# (zsign / codesign / AltStore / Sideloadly) — ver README.
rm -f "$OUTPUT_IPA"
(cd "$WORK" && zip -qr "$OLDPWD/$OUTPUT_IPA" Payload)

echo "OK: $OUTPUT_IPA (firma con tu certificado antes de instalar)"
