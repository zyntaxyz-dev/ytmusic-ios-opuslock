#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Pantalla propia de ajustes (se presenta desde el menú de cuenta,
/// mismo punto de entrada que YTMusicUltimate). Todo UIKit público.
@interface OpusLockSettingsController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@end

/// Instala el botón "OpusLock" en `YTMAvatarAccountView`
/// (`-setAccountMenuUpperButtons:lowerButtons:`). Silencioso si la clase
/// o el selector no existen en esta versión de la app.
FOUNDATION_EXPORT void OpusLockInstallAccountMenuHook(void);

NS_ASSUME_NONNULL_END
