#import "OpusLockOverlay.h"

@interface OpusLockOverlay ()
@property (nonatomic, strong, nullable) UIWindow *window;
@property (nonatomic, strong, nullable) UILabel *label;
@property (nonatomic, strong, nullable) NSTimer *hideTimer;
@end

@implementation OpusLockOverlay

+ (instancetype)shared {
    static OpusLockOverlay *s = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s = [[self alloc] init];
    });
    return s;
}

- (void)showWithInfo:(nullable NSDictionary<NSString *, id> *)info itag:(NSInteger)itag {
    NSString *codec = info[@"codec"];
    if (![codec isKindOfClass:[NSString class]] || codec.length == 0) codec = @"???";
    NSNumber *kbps = info[@"bitrateKbps"];
    NSString *bitrate = [kbps isKindOfClass:[NSNumber class]]
        ? [NSString stringWithFormat:@"%@k", kbps] : @"?k";
    NSNumber *hz = info[@"sampleRateHz"];
    NSString *sample = [hz isKindOfClass:[NSNumber class]]
        ? (hz.integerValue >= 1000
           ? [NSString stringWithFormat:@"%gkHz", hz.doubleValue / 1000.0]
           : [NSString stringWithFormat:@"%@Hz", hz])
        : @"?Hz";
    [self showWithCodec:codec bitrate:bitrate itag:itag sampleRate:sample];
}

- (void)showWithCodec:(NSString *)codec
              bitrate:(NSString *)bitrate
                 itag:(NSInteger)itag
           sampleRate:(NSString *)sampleRate {
    // Todo UI en main; las llamadas llegan desde KVO/red en hilos arbitrarios.
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showWithCodec:codec bitrate:bitrate itag:itag sampleRate:sampleRate];
        });
        return;
    }
    @try {
        NSString *text = [NSString stringWithFormat:@"%@ • %@ • itag%ld • %@",
                          codec, bitrate, (long)itag, sampleRate];
        [self ensureWindow];
        self.label.text = text;
        [self.label sizeToFit];
        CGRect f = self.label.frame;
        f.size.width += 24.0;
        f.size.height = 28.0;
        self.label.frame = f;
        self.label.layer.cornerRadius = 14.0;
        self.window.frame = CGRectMake(
            (UIScreen.mainScreen.bounds.size.width - f.size.width) / 2.0,
            UIScreen.mainScreen.bounds.size.height - 140.0,
            f.size.width, f.size.height);
        self.window.hidden = NO;
        self.window.alpha = 1.0;

        [self.hideTimer invalidate];
        self.hideTimer = [NSTimer scheduledTimerWithTimeInterval:6.0
                                                         target:self
                                                       selector:@selector(hide)
                                                       userInfo:nil
                                                        repeats:NO];
    } @catch (__unused NSException *e) {
        // Nunca romper la app por el overlay.
    }
}

- (void)hide {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self hide]; });
        return;
    }
    [UIView animateWithDuration:0.4 animations:^{
        self.window.alpha = 0.0;
    } completion:^(__unused BOOL finished) {
        self.window.hidden = YES;
    }];
}

- (void)ensureWindow {
    if (self.window && self.label) return;
    UIWindow *w = [[UIWindow alloc] initWithFrame:CGRectZero];
    // iOS 13+: colgar la ventana de la escena activa para que sea visible.
    if (@available(iOS 13.0, *)) {
        @try {
            UIApplication *app = UIApplication.sharedApplication;
            for (UIScene *scene in app.connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]] &&
                    scene.activationState == UISceneActivationStateForegroundActive) {
                    w.windowScene = (UIWindowScene *)scene;
                    break;
                }
            }
            if (!w.windowScene) {
                UIWindow *key = nil;
                for (UIScene *scene in app.connectedScenes) {
                    if ([scene isKindOfClass:[UIWindowScene class]]) {
                        for (UIWindow *cand in ((UIWindowScene *)scene).windows) {
                            if (cand.isKeyWindow) { key = cand; break; }
                        }
                    }
                }
                if (key.windowScene) w.windowScene = key.windowScene;
            }
        } @catch (__unused NSException *e) { }
    }
    w.windowLevel = UIWindowLevelStatusBar + 1;
    w.backgroundColor = UIColor.clearColor;
    w.hidden = YES;
    // No interactiva: jamás roba toques.
    w.userInteractionEnabled = NO;

    UILabel *l = [[UILabel alloc] initWithFrame:CGRectZero];
    l.font = [UIFont monospacedDigitSystemFontOfSize:11.0 weight:UIFontWeightSemibold];
    l.textColor = UIColor.whiteColor;
    l.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.7];
    l.textAlignment = NSTextAlignmentCenter;
    l.layer.masksToBounds = YES;
    l.userInteractionEnabled = NO;
    [w addSubview:l];
    l.frame = w.bounds;
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    self.window = w;
    self.label = l;
}

@end
