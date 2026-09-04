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

// ---------------------------------------------------------------------------
// Hooks con interruptor (bisección en dispositivo; los de instalación
// requieren reiniciar, reorder aplica al instante).
// ---------------------------------------------------------------------------

/// Defs `@[ @{@"key", @"title", @"detail"} ]` para la UI de ajustes.
FOUNDATION_EXPORT NSArray<NSDictionary<NSString *, NSString *> *> *OpusLockHookDefs(void);
FOUNDATION_EXPORT BOOL OpusLockHookOn(NSString *key, BOOL dflt);

/// Swizzle solo si el método está definido DIRECTO en cls (nunca hereda).
/// Evita guardar nuestro propio IMP como "original" (recursión infinita).
FOUNDATION_EXPORT BOOL OpusLockSwizzleDirect(Class cls, SEL sel,
                                             IMP newIMP, IMP _Nullable *outOrig);

NS_ASSUME_NONNULL_END
