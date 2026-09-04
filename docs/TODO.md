# TODO — mejoras pendientes o en proceso (archivo vivo)

Estados: `Pendiente|En proceso|Bloqueado|Hecho|Descartado`. Al completar: marcar `Hecho` aquí y añadir fila en `CHANGES.md`. IDs estables, nunca reutilizar.

| ID | Estado | Mejora pendiente | Criterio de cierre | refs |
|---|---|---|---|---|
| TODO-001 | Hecho | Esqueleto: `Makefile` LIBRARY + `Tweak/OpusLock*` + `control` + `entitlements` | `make -n package` ok | `AGENTS.md` Layout |
| TODO-002 | Hecho | `scripts/re/` triage Mach-O Windows + `requirements-re.txt` | JSON con hits `itag/adaptiveFormats` sin cargar binario | `scripts/re/macho_triage.py` |
| TODO-003 | Hecho | `scripts/inject.sh` + `scripts/dump_classes.sh` | Flujo documentado y `shellcheck` limpio | `README.md` §3–4 |
| TODO-004 | Hecho | CI `build.yml` dylib-only | Artifact descargable en Actions | `.github/workflows/build.yml` |
| TODO-005 | Hecho | Validar build real en CI (primer run verde) | Artifact `OpusLock.dylib` arm64 | Actions run 33829983258 |
| TODO-006 | Pendiente | Prueba en dispositivo: pill muestra `774/141` en WiFi y celular | Captura + itag pill | `README.md` §5 || TODO-007 | Pendiente | Confirmar claves prefs `Always High` con Frida en build 9.35.2 | `frida-trace` hits | `scripts/dump_classes.sh` |
| TODO-008 | Pendiente | Soporte protobuf `player` (hoy solo JSON; protobuf se deja intacto) | Sin regresión playback | `Tweak/OpusLock.m` §2 |
| TODO-009 | Pendiente | Verificar botón "OpusLock" en menú cuenta + pantalla ajustes en 9.35.2 | Captura sección + switch on/off funcional | `Tweak/OpusLockSettings.m` |
| TODO-010 | Pendiente | Verificar pill vía player-response en dispositivo (reproduce y confirma itag) | Captura pill + "Último stream" con itag | Run 33832131335 |
| TODO-011 | En proceso | Diagnosticar con sección DIAGNÓSTICO: captura de `resp.*`, `sd.*`, `ham.*` tras reproducir | Captura DIAGNÓSTICO → decide hook definitivo | Run 33832699696 |
| TODO-012 | En proceso | Bisección freeze: probar build 33833948032 (observer-only) y reportar; si congela, togglear HOOKS uno por uno | App usable + culpable identificado | Run 33833948032 |
