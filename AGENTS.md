# AGENTS.md — ytmusic-ios-opuslock

## What this is
- Greenfield Theos tweak project: force max audio quality + stream-info pill in YouTube Music iOS, jailed/sideloaded (no jailbreak). No source, Makefile, README, or CI exists yet.
- Only verified artifact in repo: decrypted reference app at `com.google.ios.youtubemusic-9.35-Decrypted/Payload/YouTubeMusic.app` — bundle `com.google.ios.youtubemusic`, v `9.35.2`, min iOS `16.0`, `arm64` only, built with SDK `iphoneos26.4`. Binary `YouTubeMusic` ~171 MB.

## Decided architecture (do not reverse without asking)
- Pure ObjC `LIBRARY` dylib with `__attribute__((constructor))` + ObjC runtime swizzling. No `TWEAK_NAME`, no CydiaSubstrate/MobileSubstrate dependency.
- CI builds **dylib only** (artifact download); no patched-IPA publishing.
- Overlay is a minimal non-interactive pill (`OPUS • 256k • itag774 • 48kHz`), auto-hide, main thread only.

## Domain facts (correct, do not re-derive wrong)
- `251` = Opus ~128k, NOT 256k. True max: `774` Opus ~256k / `141` AAC 256k (Premium + Always High only). Free accounts cap at 128k even if forced.
- Fallback chain: `774 > 141 > 251 > 140 > 250 > 249 > 139`. Parse `itag=` from `*.googlevideo.com` URLs; if forced itag missing, pick next available, never fail playback.
- YT classes are obfuscated and change per version. Never hardcode selectors as ground truth; resolve via `NSClassFromString` + `respondsToSelector` with silent fallback.

## Layout
- Target (create when implementing): `Makefile` (LIBRARY), `Tweak/OpusLock.{h,m}`, `Tweak/OpusLockPolicy.{h,m}`, `Tweak/OpusLockOverlay.{h,m}`, `entitlements.plist`, `scripts/inject.sh`, `scripts/dump_classes.sh`, `scripts/re/` (Python triage, see below), `.github/workflows/build.yml`, `README.md`, `docs/CHANGES.md`, `docs/TODO.md` (living trackers, table format — update both on every vital change, never rewrite history).
- Never edit, move, or commit under `com.google.ios.youtubemusic-9.35-Decrypted/`. Never commit IPA, `.dylib` binaries, certs, `.p12`, provisioning profiles, or `.venv-re/`.

## Build / verify
- Do not build iOS dylib on this Windows host. Real build is GitHub Actions `macos-14` + Theos (`Randomblock1/theos-action` or `beer-psi/setup-theos`, SDKs from `theos/sdks`) running `make clean package FINALPACKAGE=1`.
- Local checks only: `make -n package`, `plutil`/XML lint of plist, `shellcheck scripts/*.sh` if available. Reference pattern (not dependency): `dayanch96/YTMusicUltimate` + Azule/`insert_dylib` flow.

## Injection / sign (via `scripts/inject.sh`)
- Flow: `unzip` → copy dylib to `Payload/*.app/` → `insert_dylib --in-place` (fallback `optool install -c load`) → `ldid -S entitlements.plist` → `zsign`/`codesign -f -s "Apple Development"` → `zip`. Install via AltStore Classic / Sideloadly / TrollStore (7-day expiry, 3-app free limit, Developer Mode on iOS 18+).

## Repo-specific gotchas
- Root path contains a space (`Developing Lab`): always quote paths; in PowerShell use `workdir` param and `; if ($?) { }`, never `&&` or `cd` inside command.
- Never run bare `**/*` glob/grep at root — the `.app` has thousands of `.lproj`/`.strings`/`.bundle` files and truncates results. Scope to `Tweak/`, `scripts/`, `.github/`.
- Never `Read` the `YouTubeMusic` binary. For reverse work use `scripts/dump_classes.sh` (class-dump + `frida-trace -U -m "*Quality*" -m "*Adaptive*" -m "*StreamingData*" + `strings`) on macOS/CI.
- Python RE runs on this Windows host (unlike the dylib build): use isolated `.venv-re/`; validate with `pip list` before installing (`capstone` + `frida` already present, `lief`/`macholib` usually missing). Prefer `macholib` (light, pure-Python headers) then `LIEF MachO.parse(..., ParserConfig.quick)` then Capstone ARM64 over `mmap` windows — never `read()` the full 171 MB. `LIEF` is read-only triage here, not the injector.
- Keep tweak silent in production: no `NSLog` verbose; `#ifdef DEBUG` only.
