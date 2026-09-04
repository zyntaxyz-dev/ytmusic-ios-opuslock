# CHANGES — control de mejoras y cambios vitales (archivo vivo)

Regla: añadir una fila por cada cambio vital. Nunca reescribir ni borrar filas. Ver `TODO.md` para pendientes.

| Fecha (UTC) | Tipo | Alcance | Cambio vital | Verificación |
|---|---|---|---|---|
| 2026-09-04 | docs | AGENTS.md | Instrucciones iniciales del repo | Lectura `AGENTS.md` |
| 2026-09-04 | fix-domain | policy | Corrección: `251`=Opus ~128k, máx real `774/141` + fallback `774>141>251>140>250>249>139` | Docs bitrate + help YTM |
| 2026-09-04 | arch | tweak | Decisión: dylib ObjC puro + swizzling (sin Substrate), CI solo-dylib, pill mínima | Respuestas usuario |
| 2026-09-04 | feat | tweak | `Tweak/OpusLock{,Policy,Overlay}.{h,m}`: reorder `adaptiveFormats`, fallback itags, pill auto-hide main-thread | Revisión código |
| 2026-09-04 | feat | build | `Makefile` LIBRARY arm64 + `control` + `entitlements.plist` + `.gitignore` | `make -n package` (CI macOS) |
| 2026-09-04 | feat | ci | `.github/workflows/build.yml` (macos-14 + setup-theos, artifact dylib) | Run Actions |
| 2026-09-04 | feat | tooling | `scripts/inject.sh`, `scripts/dump_classes.sh`, `scripts/re/` (triage Mach-O Windows) | `shellcheck` + run triage |
| 2026-09-04 | docs | docs | `README.md` + `docs/CHANGES.md` + `docs/TODO.md` iniciales | Lectura |
| 2026-09-04 | feat | release | Primer release: repo público + tag `v1.0.0` + build CI verde (`OpusLock.dylib` arm64 ~97KB) | Artifact `OpusLock-dylib` run 33829983258 |
| 2026-09-04 | fix-domain | ci | Fixes build: `theos-action` correcto, sin scheme `roothide`, `@end` huérfano y `[hz.integerValue]` | Runs 33829088752→33829983258 |
| 2026-09-04 | feat | settings | Botón "OpusLock" en menú cuenta + pantalla ajustes (patrón YTMU, runtime dinámico, switch on/off, último stream) | Run verde 33831343671, dylib ~120KB |
| 2026-09-04 | fix-domain | settings | Fix ARC `NSInvocation.target` (strong local + balance alloc/init) | Runs 33830855430→33831343671 |
