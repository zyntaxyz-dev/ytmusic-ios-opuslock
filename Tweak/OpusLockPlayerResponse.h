#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Hooks de la capa modelo YT (referencia: YTMusicUltimate `AVSwitching.x`,
/// que demuestra que `YTIPlayerResponse` / `YTMSettings` son estables).
/// Todo resuelto por runtime con fallback silencioso.
FOUNDATION_EXPORT void OpusLockInstallPlayerResponseHook(void);

/// Inventario HAM* (lazy; llamable desde la UI, corre una sola vez).
FOUNDATION_EXPORT void OpusLockDiscoverHAM(void);

NS_ASSUME_NONNULL_END
