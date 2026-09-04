#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Tabla de calidad verificada (YTMusic 2026):
/// 774 = Opus ~256k/48kHz (máximo real), 141 = AAC 256k/44.1kHz,
/// 251 = Opus ~128k (NO es 256k), 140 = AAC 128k. El resto son low.
@interface OpusLockPolicy : NSObject

/// Cadena de fallback de mayor a menor calidad.
+ (NSArray<NSNumber *> *)fallbackChain;

/// Info conocida de un itag: @{@"codec": NSString, @"bitrateKbps": NSNumber,
/// @"sampleRateHz": NSNumber, @"label": NSString}. Nil si desconocido.
+ (nullable NSDictionary<NSString *, id> *)infoForItag:(NSInteger)itag;

/// Extrae `itag=` de la query de una URL de `*.googlevideo.com`. -1 si no hay.
+ (NSInteger)itagFromURL:(nullable NSURL *)url;

/// Posición en fallbackChain (menor = mejor). NSNotFound si desconocido.
+ (NSUInteger)rankForItag:(NSInteger)itag;

/// Elige la mejor URL disponible según fallbackChain. Nil si vacía.
+ (nullable NSURL *)bestURLFromURLs:(NSArray<NSURL *> *)urls;

/// Ordena formatos InnerTube (`adaptiveFormats`: dicts con `itag` y `url`)
/// de mayor a menor calidad. Los itags desconocidos van al final.
+ (NSArray<NSDictionary *> *)rankedFormatsFromAdaptiveFormats:(NSArray<NSDictionary *> *)formats;

@end

NS_ASSUME_NONNULL_END
