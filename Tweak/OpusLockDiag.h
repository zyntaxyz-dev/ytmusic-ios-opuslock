#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Diagnóstico en memoria (sin logs): qué hooks se instalaron y cuántas
/// veces dispararon. La pantalla de ajustes lo muestra en DIAGNÓSTICO.
/// Thread-safe. Valores cortos pensados para celdas.
FOUNDATION_EXPORT void OpusLockDiagSet(NSString *key, NSString *value);
FOUNDATION_EXPORT void OpusLockDiagCount(NSString *key);

/// Filas ordenadas `@[ @[clave, valor] ]` para la tabla. Nunca vacío.
FOUNDATION_EXPORT NSArray<NSArray<NSString *> *> *OpusLockDiagRows(void);

NS_ASSUME_NONNULL_END
