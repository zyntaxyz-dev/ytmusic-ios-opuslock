#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Versión del tweak (visible para tooling, no se loguea en producción).
FOUNDATION_EXPORT NSString * const OpusLockVersion;

// ---------------------------------------------------------------------------
// Estado global (thread-safe). Lo escribe el núcleo, lo lee la UI de ajustes.
// ---------------------------------------------------------------------------

/// Interruptor "Forzar máxima calidad" (default YES). Persistido en prefs.
FOUNDATION_EXPORT BOOL OpusLockIsEnabled(void);
FOUNDATION_EXPORT void OpusLockSetEnabled(BOOL enabled);

/// Último stream observado por el player. -1 / nil si aún ninguno.
FOUNDATION_EXPORT NSInteger OpusLockLastItag(void);
FOUNDATION_EXPORT NSDictionary<NSString *, id> * _Nullable OpusLockLastInfo(void);
FOUNDATION_EXPORT void OpusLockRecordPlayback(NSInteger itag,
                                              NSDictionary<NSString *, id> * _Nullable info);

NS_ASSUME_NONNULL_END
