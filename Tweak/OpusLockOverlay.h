#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Pill mínima no interactiva que muestra el stream actual.
/// Todo el UI ocurre en main thread. Auto-hide 6 s.
@interface OpusLockOverlay : NSObject

+ (instancetype)shared;

/// Muestra `CODEC • BITRATE • itagN • SAMPLE` (ej. `OPUS • 256k • itag774 • 48kHz`).
- (void)showWithCodec:(NSString *)codec
              bitrate:(NSString *)bitrate
                 itag:(NSInteger)itag
           sampleRate:(NSString *)sampleRate;

/// Atajo: deriva los textos desde el dict de `OpusLockPolicy infoForItag:`.
- (void)showWithInfo:(nullable NSDictionary<NSString *, id> *)info itag:(NSInteger)itag;

@end

NS_ASSUME_NONNULL_END
