/// OpusLock — dylib puro para YouTube Music iOS (jailed/sideload, sin jailbreak).
///
/// Estrategia (defensiva: las clases YT están ofuscadas y cambian por versión):
///  1. Prefs best-effort: pide "Always High" en claves conocidas de calidad.
///     Claves desconocidas son inofensivas; el enforcement real es (2).
///  2. Red: reordena `streamingData.adaptiveFormats` en respuestas JSON del
///     endpoint InnerTube `player` para que el 774 quede primero. Si el body
///     es protobuf o el parse falla, se deja intacto (nunca se rompe playback).
///  3. Player: observa `AVPlayer.currentItem` (API pública) para mostrar la
///     pill con codec/bitrate/itag/sampleRate del stream real.
///
/// Sin dependencias (no Substrate). Silencioso en producción (#ifdef DEBUG).

#import <objc/runtime.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#import "OpusLock.h"
#import "OpusLockPolicy.h"
#import "OpusLockOverlay.h"
#import "OpusLockSettings.h"
#import "OpusLockPlayerResponse.h"

NSString * const OpusLockVersion = @"1.0.0";

#ifdef DEBUG
#define OPUSLOCK_LOG(fmt, ...) NSLog(@"[OpusLock] " fmt, ##__VA_ARGS__)
#else
#define OPUSLOCK_LOG(...) do {} while (0)
#endif

// ---------------------------------------------------------------------------
// Estado global (ver OpusLock.h). Lock simple: escrituras raras, lecturas UI.
// ---------------------------------------------------------------------------

static NSString * const kOpusLockEnabledKey = @"OpusLockEnabled";

static NSLock *OpusLockStateLock(void) {
    static NSLock *lock = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lock = [[NSLock alloc] init];
    });
    return lock;
}

static NSInteger gLastItag = -1;
static NSDictionary *gLastInfo = nil;
static BOOL gEnabledCached = NO;
static BOOL gEnabledLoaded = NO;

BOOL OpusLockIsEnabled(void) {
    @try {
        [OpusLockStateLock() lock];
        if (!gEnabledLoaded) {
            id v = [[NSUserDefaults standardUserDefaults] objectForKey:kOpusLockEnabledKey];
            gEnabledCached = (v == nil) ? YES : [v boolValue];
            gEnabledLoaded = YES;
        }
        BOOL e = gEnabledCached;
        [OpusLockStateLock() unlock];
        return e;
    } @catch (__unused NSException *e) {
        return YES;
    }
}

void OpusLockSetEnabled(BOOL enabled) {
    @try {
        [OpusLockStateLock() lock];
        gEnabledCached = enabled;
        gEnabledLoaded = YES;
        [OpusLockStateLock() unlock];
        [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kOpusLockEnabledKey];
    } @catch (__unused NSException *e) { }
}

NSInteger OpusLockLastItag(void) {
    @try {
        [OpusLockStateLock() lock];
        NSInteger i = gLastItag;
        [OpusLockStateLock() unlock];
        return i;
    } @catch (__unused NSException *e) {
        return -1;
    }
}

NSDictionary * _Nullable OpusLockLastInfo(void) {
    @try {
        [OpusLockStateLock() lock];
        NSDictionary *info = gLastInfo;
        [OpusLockStateLock() unlock];
        return info;
    } @catch (__unused NSException *e) {
        return nil;
    }
}

void OpusLockRecordPlayback(NSInteger itag, NSDictionary * _Nullable info) {
    @try {
        [OpusLockStateLock() lock];
        gLastItag = itag;
        gLastInfo = info;
        [OpusLockStateLock() unlock];
    } @catch (__unused NSException *e) { }
}

// ---------------------------------------------------------------------------
// 1. Prefs best-effort
// ---------------------------------------------------------------------------

static void OpusLockForcePrefs(void) {
    @try {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        // Candidatas documentadas/observadas en builds YTM; si no existen,
        // escribirlas es inofensivo. El enforcement real está en la capa de red.
        NSArray<NSString *> *keys = @[
            @"audio_quality_wifi",
            @"audio_quality_mobile",
            @"audio_quality",
            @"ytm_audio_quality_wifi",
            @"ytm_audio_quality_mobile"
        ];
        // "Always High" suele ser el índice/valor máximo; se intenta string e int.
        for (NSString *k in keys) {
            @try {
                id cur = [d objectForKey:k];
                if ([cur isKindOfClass:[NSString class]]) {
                    [d setObject:@"always_high" forKey:k];
                } else {
                    [d setInteger:3 forKey:k];
                }
            } @catch (__unused NSException *e) { }
        }
        [d synchronize];
    } @catch (__unused NSException *e) { }
}

// ---------------------------------------------------------------------------
// 2. Reescritura de adaptiveFormats (endpoint player, solo JSON)
// ---------------------------------------------------------------------------

static NSData * _Nullable OpusLockReorderedPlayerData(NSData *data) {
    @try {
        if (!OpusLockIsEnabled()) return nil; // OFF: no tocar nada.
        if (!data || data.length == 0 || data.length > 8 * 1024 * 1024) return nil;
        NSError *err = nil;
        id json = [NSJSONSerialization JSONObjectWithData:data
                                                 options:NSJSONReadingMutableContainers
                                                   error:&err];
        if (err || ![json isKindOfClass:[NSMutableDictionary class]]) return nil;
        NSMutableDictionary *root = json;
        id sd = root[@"streamingData"];
        if (![sd isKindOfClass:[NSMutableDictionary class]]) return nil;
        id formats = ((NSMutableDictionary *)sd)[@"adaptiveFormats"];
        if (![formats isKindOfClass:[NSArray class]] || [(NSArray *)formats count] < 2) return nil;
        NSArray *ranked = [OpusLockPolicy rankedFormatsFromAdaptiveFormats:formats];
        ((NSMutableDictionary *)sd)[@"adaptiveFormats"] = ranked;
        NSData *out = [NSJSONSerialization dataWithJSONObject:root options:0 error:&err];
        if (err) return nil;
        OPUSLOCK_LOG(@"adaptiveFormats reordered (%lu)", (unsigned long)ranked.count);
        return out;
    } @catch (__unused NSException *e) {
        return nil;
    }
}

static BOOL OpusLockIsPlayerRequest(NSURLRequest *req) {
    @try {
        NSString *host = req.URL.host.lowercaseString;
        NSString *path = req.URL.path.lowercaseString;
        if (!host || !path) return NO;
        BOOL yt = ([host containsString:@"youtubei.googleapis.com"] ||
                   [host containsString:@"music.youtube.com"] ||
                   [host containsString:@"youtube.com"]);
        return yt && [path containsString:@"player"];
    } @catch (__unused NSException *e) {
        return NO;
    }
}

// Swizzle: -[NSURLSession dataTaskWithRequest:completionHandler:]
typedef NSURLSessionDataTask * (*OpusLockDataTaskIMP)(id, SEL, NSURLRequest *, void (^)(NSData *, NSURLResponse *, NSError *));

static OpusLockDataTaskIMP gOrigDataTask = NULL;

static NSURLSessionDataTask *OpusLock_dataTaskWithRequest(id self, SEL _cmd,
                                                          NSURLRequest *request,
                                                          void (^completion)(NSData *, NSURLResponse *, NSError *)) {
    if (!OpusLockIsPlayerRequest(request) || !completion) {
        return gOrigDataTask(self, _cmd, request, completion);
    }
    void (^wrapped)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *resp, NSError *error) {
        @try {
            NSData *fixed = (data && !error) ? OpusLockReorderedPlayerData(data) : nil;
            completion(fixed ?: data, resp, error);
        } @catch (__unused NSException *e) {
            completion(data, resp, error);
        }
    };
    return gOrigDataTask(self, _cmd, request, wrapped);
}

// ---------------------------------------------------------------------------
// 3. Observación del stream real (API pública AVFoundation)
// ---------------------------------------------------------------------------

static void OpusLockShowForPlayerItem(AVPlayerItem * _Nullable item) {
    @try {
        if (!item) return;
        AVAsset *asset = item.asset;
        NSURL *url = nil;
        if ([asset isKindOfClass:[AVURLAsset class]]) {
            url = ((AVURLAsset *)asset).URL;
        }
        NSInteger itag = [OpusLockPolicy itagFromURL:url];
        if (itag < 0) {
            // Aún sin URL resoluble (p.ej. HLS): no mostrar nada inventado.
            OPUSLOCK_LOG(@"item sin itag (url=%@)", url);
            return;
        }
        NSDictionary *info = [OpusLockPolicy infoForItag:itag];
        OpusLockRecordPlayback(itag, info);
        // Si el accessLog trae bitrate medido, úsalo para el texto.
        NSString *measured = nil;
        @try {
            AVPlayerItemAccessLog *log = item.accessLog;
            AVPlayerItemAccessLogEvent *ev = log.events.lastObject;
            if (ev && ev.indicatedBitrate > 0) {
                measured = [NSString stringWithFormat:@"%gk", ev.indicatedBitrate / 1000.0];
            }
        } @catch (__unused NSException *e) { }
        if (measured) {
            NSMutableDictionary *m = [NSMutableDictionary dictionaryWithDictionary:info ?: @{}];
            // Conserva codec/sample del itag; el bitrate mostrado es el medido.
            [[OpusLockOverlay shared] showWithCodec:(m[@"codec"] ?: @"???")
                                            bitrate:measured
                                               itag:itag
                                         sampleRate:([m[@"sampleRateHz"] integerValue] >= 1000
                                                     ? [NSString stringWithFormat:@"%gkHz", [m[@"sampleRateHz"] doubleValue] / 1000.0]
                                                     : @"?Hz")];
        } else {
            [[OpusLockOverlay shared] showWithInfo:info itag:itag];
        }
        OPUSLOCK_LOG(@"now playing itag=%ld url=%@", (long)itag, url);
    } @catch (__unused NSException *e) { }
}

typedef void (*OpusLockReplaceIMP)(id, SEL, AVPlayerItem *);

static OpusLockReplaceIMP gOrigReplace = NULL;

static void OpusLock_replaceCurrentItem(id self, SEL _cmd, AVPlayerItem *item) {
    @try {
        gOrigReplace(self, _cmd, item);
    } @catch (__unused NSException *e) {
        return;
    }
    // El asset puede resolverse un poco después del replace; reintento corto.
    __weak id weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        @try {
            AVPlayer *p = (AVPlayer *)weakSelf;
            if ([p isKindOfClass:[AVPlayer class]]) {
                OpusLockShowForPlayerItem(p.currentItem);
            } else {
                OpusLockShowForPlayerItem(item);
            }
        } @catch (__unused NSException *e) { }
    });
}

static void OpusLockSwizzle(Class cls, SEL orig, IMP repl, const char *types, void **saveOrig) {
    @try {
        if (!cls) return;
        Method m = class_getInstanceMethod(cls, orig);
        if (!m) {
            OPUSLOCK_LOG(@"sin método %@ en %@", NSStringFromSelector(orig), cls);
            return;
        }
        if (saveOrig) *saveOrig = (void *)method_getImplementation(m);
        // addMethod protege contra swizzles heredados.
        if (class_addMethod(cls, orig, repl, types)) {
            Method added = class_getInstanceMethod(cls, orig);
            if (saveOrig) *saveOrig = (void *)method_getImplementation(added);
        } else {
            method_setImplementation(m, repl);
        }
    } @catch (__unused NSException *e) { }
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

__attribute__((constructor))
static void OpusLockInit(void) {
    @autoreleasepool {
        @try {
            OpusLockForcePrefs();
            Class session = NSClassFromString(@"NSURLSession");
            if (!session) session = [NSURLSession class];
            OpusLockSwizzle(session,
                            @selector(dataTaskWithRequest:completionHandler:),
                            (IMP)OpusLock_dataTaskWithRequest,
                            "@@:@?",
                            (void **)&gOrigDataTask);
            OpusLockSwizzle([AVPlayer class],
                            @selector(replaceCurrentItemWithPlayerItem:),
                            (IMP)OpusLock_replaceCurrentItem,
                            "v@:@",
                            (void **)&gOrigReplace);
            OpusLockInstallAccountMenuHook(); // botón "OpusLock" en menú cuenta
            OpusLockInstallPlayerResponseHook(); // reorder + pill vía YTIPlayerResponse
            OPUSLOCK_LOG(@"init v%@", OpusLockVersion);
        } @catch (__unused NSException *e) {
            // Jamás crashear el host.
        }
    }
}
