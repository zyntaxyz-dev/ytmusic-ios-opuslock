# OpusLock — máxima calidad de audio + pill de stream para YouTube Music iOS

Dylib inyectable (jailed/sideload, **sin jailbreak**) que fuerza el stream de mayor bitrate disponible y muestra una pill con codec, bitrate, itag y frecuencia de muestreo del audio en reproducción.

## Cómo funciona

1. **Calidad máxima**: reordena `streamingData.adaptiveFormats` en respuestas JSON del endpoint InnerTube `player` para que el mejor itag quede primero, y pide `Always High` en prefs (best-effort). Cadena: `774 > 141 > 251 > 140 > 250 > 249 > 139`. Si el itag forzado no existe para un track, se usa el siguiente disponible — el playback nunca falla por el tweak.
2. **Pill de stream**: observa `AVPlayer.currentItem` (API pública) y muestra `OPUS • 256k • itag774 • 48kHz` 6 s sobre el now-playing. Usa el bitrate medido del `accessLog` cuando existe.
3. **Corrección importante**: `251` es Opus **~128k**, no 256k. El máximo real es `774` (Opus ~256k) / `141` (AAC 256k), solo Premium + `Always High`. Cuentas gratuitas quedan en 128k aunque se fuerce.

## Estructura

```
Makefile  control  entitlements.plist
Tweak/OpusLock.{h,m}  Tweak/OpusLockPolicy.{h,m}  Tweak/OpusLockOverlay.{h,m}
scripts/inject.sh  scripts/dump_classes.sh  scripts/re/
.github/workflows/build.yml  README.md  docs/CHANGES.md  docs/TODO.md
```

## 1. Entorno local (Windows: solo triaje; el build es en CI macOS)

```powershell
# Triaje estático del binario (opcional, aislado)
python -m venv .venv-re
.\.venv-re\Scripts\Activate.ps1
pip install -r scripts/re/requirements-re.txt
python scripts/re/macho_triage.py "com.google.ios.youtubemusic-9.35-Decrypted\Payload\YouTubeMusic.app\YouTubeMusic" --out scripts/re/out
```

No commitees la carpeta `com.google.ios.youtubemusic-9.35-Decrypted/`, IPAs, `.dylib`, certs ni `.venv-re/`.

## 2. Compilar con GitHub Actions

1. Sube el repo a GitHub (sin la carpeta desencriptada).
2. Ve a **Actions → build → Run workflow** (también corre en push/PR a `main`).
3. Descarga el artifact **OpusLock-dylib** (`OpusLock.dylib`, arm64).

Localmente solo puedes pre-validar: `make -n package`, lint XML del plist y `shellcheck scripts/*.sh` si disponible. No intentes compilar el dylib iOS en Windows.

## 3. Inyectar, firmar e instalar

Necesitas: IPA **desencriptada** de YouTube Music (consíguela tú; no se distribuye aquí), `OpusLock.dylib` del CI, macOS o Linux para inyectar.

```bash
./scripts/inject.sh YouTubeMusic-decrypted.ipa OpusLock.dylib YouTubeMusic-opuslock-unsigned.ipa
# Firmar con tu certificado personal (una opción):
zsign -s "Apple Development: tu@email.com" -m embedded.mobileprovision YouTubeMusic-opuslock-unsigned.ipa -o YouTubeMusic-opuslock.ipa
```

Instala con **AltStore Classic** (`My Apps → +`), **Sideloadly** o **TrollStore** (donde aplique). Notas: certificado gratuito = re-firma cada 7 días, 3 apps activas, Developer Mode en iOS 18+ (`Ajustes → Privacidad y seguridad`).

## 4. Adaptar a nuevas versiones (ofuscación)

Las clases YT cambian por versión. Para redescubrir selectores (macOS):

```bash
./scripts/dump_classes.sh YouTubeMusic.app out/
frida-trace -U -m "*Quality*" -m "*Adaptive*" -m "*StreamingData*" YouTubeMusic
```

Actualiza solo `Tweak/OpusLockPolicy.m` y los lookups en `Tweak/OpusLock.m`. El tweak resuelve todo por `NSClassFromString` + `respondsToSelector` con fallback silencioso.

## 5. Problemas comunes

| Síntoma | Causa probable | Solución |
|---|---|---|
| `OpusLock.dylib` no carga / crash al abrir | `LC_LOAD_DYLIB` mal insertado o firma inválida | Verifica con `otool -L YouTubeMusic \| grep OpusLock`, `lipo -info OpusLock.dylib` (arm64), re-firma dylib + binario |
| Error de firma al instalar | Certificado/provisión no coinciden | Usa tu Apple ID personal en AltStore/Sideloadly, confía el perfil en `VPN y gestión de dispositivos` |
| Pill no aparece | Item HLS sin URL con itag aún | Espera al siguiente track; el overlay solo muestra itags reales, nunca inventa |
| Sigue en 128k | Cuenta gratuita o ajuste no en `Always High` | Activa `Perfil → Ajustes → Reproducción → Always High`; Free está capado por servidor |
| CI falla en `make package` | Theos/SDK | Revisa el log de `Setup Theos`; el SDK es `theos/sdks`, runner `macos-14` |

## Archivos vivos

- `docs/CHANGES.md`: cambios vitales aplicados (append-only).
- `docs/TODO.md`: pendientes/en proceso con criterio de cierre.
