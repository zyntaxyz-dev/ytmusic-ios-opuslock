/// OpusLock — capa modelo YT.
///
/// Diagnóstico del fallo de la pill v1.0: YTM reproduce vía su stack propio
/// (HAMPlayer, verificado en binario) y trae InnerTube por Cronet, así que
/// los hooks `AVPlayer`/`NSURLSession` casi nunca disparan. YTMusicUltimate
/// (`AVSwitching.x`) demuestra el punto correcto: `YTIPlayerResponse`
/// (con `ytm_isAudioOnlyPlayable`) y `YTMSettings`
/// (`allowAudioOnlyManualQualitySelection`) existen y son estables —
/// verificados en 9.35.2 con `macho_triage.py`.
///
/// Este archivo swizzlea el getter de `streamingData` de `YTIPlayerResponse`
/// (descubierto por enumeración, no hardcodeado) para:
///  1. Reordenar `adaptiveFormats` in-place (774 primero) si el switch está ON.
///  2. Registrar SIEMPRE el mejor formato de audio (itag real) → pill + ajustes.
///
/// Si la clase, el getter o los accessors GPB no coinciden, no se instala
/// nada y el núcleo anterior sigue intacto.

#import "OpusLockPlayerResponse.h"
#import "OpusLock.h"
#import "OpusLockPolicy.h"
#import "OpusLockOverlay.h"
#import "OpusLockDiag.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <string.h>

// ---------------------------------------------------------------------------
// Utilidades runtime
// ---------------------------------------------------------------------------

/// Getter por probe directo: `class_getInstanceMethod` dispara
/// `+resolveInstanceMethod:`, así que encuentra accessors GPB `@dynamic`
/// que la enumeración de métodos NO lista. Devuelve NULL si no existe.
static Method OpusLockProbeGetter(Class cls, NSArray<NSString *> *names) {
    @try {
        for (NSString *n in names) {
            SEL s = NSSelectorFromString(n);
            Method m = class_getInstanceMethod(cls, s);
            if (m && method_getNumberOfArguments(m) == 2) {
                char ret[8] = {0};
                method_getReturnType(m, ret, sizeof(ret));
                if (ret[0] == '@') return m;
            }
        }
    } @catch (__unused NSException *e) { }
    return NULL;
}

/// Fallback: barrido de la tabla de métodos (solo métodos reales compilados).
static SEL OpusLockFindObjectGetter(Class cls, NSString *substr) {
    @try {
        NSString *want = substr.lowercaseString;
        Class c = cls;
        for (int depth = 0; depth < 4 && c != Nil; depth++) {
            unsigned int n = 0;
            Method *methods = class_copyMethodList(c, &n);
            for (unsigned int i = 0; i < n; i++) {
                SEL sel = method_getName(methods[i]);
                if (method_getNumberOfArguments(methods[i]) != 2) continue;
                char ret[8] = {0};
                method_getReturnType(methods[i], ret, sizeof(ret));
                if (ret[0] != '@') continue;
                NSString *name = NSStringFromSelector(sel).lowercaseString;
                if ([name containsString:want] &&
                    ![name containsString:@"count"] &&
                    ![name containsString:@"add"] &&
                    ![name hasPrefix:@"set"]) {
                    free(methods);
                    return sel;
                }
            }
            free(methods);
            c = class_getSuperclass(c);
        }
    } @catch (__unused NSException *e) { }
    return NULL;
}

typedef int32_t (*OpusLockInt32Fn)(id, SEL);
typedef id (*OpusLockObjectFn)(id, SEL);

static NSInteger OpusLockItagOfElement(id el) {
    @try {
        SEL s = NSSelectorFromString(@"itag");
        if (![el respondsToSelector:s]) return -1;
        OpusLockInt32Fn f = (OpusLockInt32Fn)objc_msgSend;
        return (NSInteger)f(el, s);
    } @catch (__unused NSException *e) {
        return -1;
    }
}

static NSString * _Nullable OpusLockStringOfElement(id el, NSString *selName) {
    @try {
        SEL s = NSSelectorFromString(selName);
        if (![el respondsToSelector:s]) return nil;
        OpusLockObjectFn f = (OpusLockObjectFn)objc_msgSend;
        id v = f(el, s);
        return [v isKindOfClass:[NSString class]] ? v : nil;
    } @catch (__unused NSException *e) {
        return nil;
    }
}

// ---------------------------------------------------------------------------
// Reorden + registro sobre el objeto streamingData
// ---------------------------------------------------------------------------

static NSArray * _Nullable OpusLockAdaptiveArray(id sd) {
    @try {
        // 1) Probe directo (resuelve @dynamic). 2) Barrido como fallback.
        Method m = OpusLockProbeGetter(object_getClass(sd),
                                       @[@"adaptiveFormatsArray", @"adaptiveFormats"]);
        SEL arr = m ? method_getName(m)
                    : OpusLockFindObjectGetter(object_getClass(sd), @"adaptiveformats");
        if (arr == NULL) {
            OpusLockDiagSet(@"sd.array", @"NO hallado");
            return nil;
        }
        OpusLockDiagSet(@"sd.array", NSStringFromSelector(arr));
        OpusLockObjectFn f = (OpusLockObjectFn)objc_msgSend;
        id v = f(sd, arr);
        return [v isKindOfClass:[NSArray class]] ? v : nil;
    } @catch (__unused NSException *e) {
        return nil;
    }
}

static void OpusLockReorderStreamingData(id sd) {
    @try {
        if (!OpusLockIsEnabled()) return; // switch OFF: no tocar
        NSArray *arr = OpusLockAdaptiveArray(sd);
        if (!arr || arr.count < 2) return;
        OpusLockDiagCount(@"sd.arrays");
        NSArray *ranked = [arr sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
            NSUInteger ra = [OpusLockPolicy rankForItag:OpusLockItagOfElement(a)];
            NSUInteger rb = [OpusLockPolicy rankForItag:OpusLockItagOfElement(b)];
            if (ra < rb) return NSOrderedAscending;
            if (ra > rb) return NSOrderedDescending;
            return NSOrderedSame;
        }];
        if ([arr isKindOfClass:[NSMutableArray class]]) {
            [(NSMutableArray *)arr setArray:ranked];
        } else {
            // GPB a veces expone copia inmutable: intento KVC best-effort.
            for (NSString *key in @[@"adaptiveFormatsArray", @"adaptiveFormats"]) {
                @try {
                    [sd setValue:ranked forKey:key];
                    break;
                } @catch (__unused NSException *e) { }
            }
        }
    } @catch (__unused NSException *e) { }
}

/// Registra el mejor formato de audio y dispara la pill. Siempre (info).
static void OpusLockRecordFromStreamingData(id sd) {
    @try {
        NSArray *arr = OpusLockAdaptiveArray(sd);
        if (!arr || arr.count == 0) return;
        OpusLockDiagCount(@"sd.arrays");
        NSURL *bestURL = nil;
        NSDictionary *bestInfo = nil;
        NSInteger bestItag = -1;
        NSUInteger bestRank = NSUIntegerMax;
        for (id el in arr) {
            NSString *mime = OpusLockStringOfElement(el, @"mimeType");
            if (mime && [mime rangeOfString:@"audio"
                                    options:NSCaseInsensitiveSearch].location == NSNotFound) {
                continue; // solo audio
            }
            OpusLockDiagCount(@"sd.audio");
            NSString *urlStr = OpusLockStringOfElement(el, @"url");
            if (!urlStr) urlStr = OpusLockStringOfElement(el, @"URL");
            if (!urlStr) continue;
            NSURL *u = [NSURL URLWithString:urlStr];
            NSInteger itag = [OpusLockPolicy itagFromURL:u];
            if (itag < 0) continue;
            NSUInteger r = [OpusLockPolicy rankForItag:itag];
            if (r < bestRank) {
                bestRank = r;
                bestURL = u;
                bestItag = itag;
                bestInfo = [OpusLockPolicy infoForItag:itag];
                if (r == 0) break;
            }
        }
        if (bestItag >= 0) {
            (void)bestURL;
            OpusLockDiagCount(@"sd.recorded");
            OpusLockRecordPlayback(bestItag, bestInfo);
            [[OpusLockOverlay shared] showWithInfo:bestInfo itag:bestItag];
        }
    } @catch (__unused NSException *e) { }
}

// ---------------------------------------------------------------------------
// Swizzle del getter streamingData
// ---------------------------------------------------------------------------

typedef id (*OpusLockSdIMP)(id, SEL);
static OpusLockSdIMP gOrigSd = NULL;

static id OpusLock_streamingData(id self, SEL _cmd) {
    id sd = nil;
    @try {
        sd = gOrigSd(self, _cmd);
    } @catch (__unused NSException *e) {
        return nil;
    }
    @try {
        OpusLockDiagCount(@"resp.calls");
        if (sd) {
            OpusLockReorderStreamingData(sd);
            OpusLockRecordFromStreamingData(sd);
        }
    } @catch (__unused NSException *e) { }
    return sd;
}

// ---------------------------------------------------------------------------
// BOOL getters forzados (YTMSettings* allowAudioOnlyManualQualitySelection)
// ---------------------------------------------------------------------------

#define OPUSLOCK_MAX_BOOLHOOKS 4
static struct { Class cls; IMP orig; } gBoolHooks[OPUSLOCK_MAX_BOOLHOOKS];
static int gBoolHookCount = 0;

typedef BOOL (*OpusLockBoolIMP)(id, SEL);

static BOOL OpusLock_boolYes(id self, SEL _cmd) {
    @try {
        if (!OpusLockIsEnabled()) {
            for (int i = 0; i < gBoolHookCount; i++) {
                if ([self isKindOfClass:gBoolHooks[i].cls]) {
                    OpusLockBoolIMP o = (OpusLockBoolIMP)gBoolHooks[i].orig;
                    return o(self, _cmd);
                }
            }
        }
    } @catch (__unused NSException *e) { }
    return YES;
}

static void OpusLockForceBoolGetter(NSArray<NSString *> *classNames, NSString *selName) {
    @try {
        SEL sel = NSSelectorFromString(selName);
        for (NSString *name in classNames) {
            if (gBoolHookCount >= OPUSLOCK_MAX_BOOLHOOKS) break;
            Class cls = NSClassFromString(name);
            if (cls == Nil) continue;
            Method m = class_getInstanceMethod(cls, sel);
            if (!m || method_getNumberOfArguments(m) != 2) continue;
            char ret[8] = {0};
            method_getReturnType(m, ret, sizeof(ret));
            if (ret[0] != 'B' && ret[0] != 'c' && ret[0] != 'C') continue;
            const char *types = method_getTypeEncoding(m);
            gBoolHooks[gBoolHookCount].cls = cls;
            gBoolHooks[gBoolHookCount].orig = method_getImplementation(m);
            gBoolHookCount++;
            if (class_addMethod(cls, sel, (IMP)OpusLock_boolYes, types)) {
                gBoolHooks[gBoolHookCount - 1].orig =
                    method_getImplementation(class_getInstanceMethod(cls, sel));
            } else {
                method_setImplementation(m, (IMP)OpusLock_boolYes);
            }
        }
    } @catch (__unused NSException *e) { }
}

// ---------------------------------------------------------------------------
// Discovery HAM* (vía backup): inventario una sola vez para Diagnóstico.
// ---------------------------------------------------------------------------

static void OpusLockDiscoverHAM(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @try {
            unsigned int ncls = 0;
            Class *classes = objc_copyClassList(&ncls);
            if (!classes) {
                OpusLockDiagSet(@"ham.classes", @"0");
                return;
            }
            NSArray<NSString *> *wants = @[@"format", @"stream", @"track",
                                           @"response", @"quality", @"audio"];
            NSMutableArray<NSString *> *ham = [NSMutableArray array];
            NSMutableArray<NSString *> *samples = [NSMutableArray array];
            for (unsigned int i = 0; i < ncls; i++) {
                const char *cname = class_getName(classes[i]);
                if (!cname || strncmp(cname, "HAM", 3) != 0) continue;
                [ham addObject:[NSString stringWithUTF8String:cname]];
                if (samples.count >= 3) continue;
                unsigned int nm = 0;
                Method *methods = class_copyMethodList(classes[i], &nm);
                int perClass = 0;
                for (unsigned int j = 0; j < nm && perClass < 2; j++) {
                    NSString *sname =
                        NSStringFromSelector(method_getName(methods[j])).lowercaseString;
                    for (NSString *w in wants) {
                        if ([sname containsString:w]) {
                            [samples addObject:[NSString stringWithFormat:
                                @"%s.%@", cname, NSStringFromSelector(method_getName(methods[j]))]];
                            perClass++;
                            break;
                        }
                    }
                    if (samples.count >= 3) break;
                }
                free(methods);
            }
            free(classes);
            OpusLockDiagSet(@"ham.classes",
                            [NSString stringWithFormat:@"%lu", (unsigned long)ham.count]);
            OpusLockDiagSet(@"ham.sample", samples.count > 0
                            ? [samples componentsJoinedByString:@" | "] : @"sin candidatos");
        } @catch (__unused NSException *e) { }
    });
}

// ---------------------------------------------------------------------------
// Entry
// ---------------------------------------------------------------------------

void OpusLockInstallPlayerResponseHook(void) {
    @try {
        Class resp = NSClassFromString(@"YTIPlayerResponse");
        OpusLockDiagSet(@"resp.class", resp != Nil ? @"SÍ hallada" : @"NO hallada");
        if (resp != Nil) {
            // Probe directo primero (resuelve @dynamic GPB); barrido fallback.
            Method m = OpusLockProbeGetter(resp, @[@"streamingData"]);
            SEL getter = m ? method_getName(m)
                           : OpusLockFindObjectGetter(resp, @"streamingdata");
            OpusLockDiagSet(@"resp.getter",
                            getter != NULL ? NSStringFromSelector(getter) : @"NO hallado");
            if (getter != NULL) {
                m = class_getInstanceMethod(resp, getter);
                if (m) {
                    gOrigSd = (OpusLockSdIMP)method_getImplementation(m);
                    const char *types = method_getTypeEncoding(m);
                    if (class_addMethod(resp, getter, (IMP)OpusLock_streamingData, types)) {
                        gOrigSd = (OpusLockSdIMP)method_getImplementation(
                            class_getInstanceMethod(resp, getter));
                    } else {
                        method_setImplementation(m, (IMP)OpusLock_streamingData);
                    }
                    OpusLockDiagSet(@"resp.hook", @"instalado");
                } else {
                    OpusLockDiagSet(@"resp.hook", @"sin método");
                }
            } else {
                OpusLockDiagSet(@"resp.hook", @"no instalado");
            }
        } else {
            OpusLockDiagSet(@"resp.getter", @"—");
            OpusLockDiagSet(@"resp.hook", @"no instalado");
        }
        // Ayuda a la app a elegir audio de alta calidad (respeta el switch).
        int before = gBoolHookCount;
        OpusLockForceBoolGetter(@[@"YTMSettings", @"YTMSettingsImpl"],
                                @"allowAudioOnlyManualQualitySelection");
        OpusLockDiagSet(@"bool.hooks",
                        [NSString stringWithFormat:@"%d/2", gBoolHookCount - before]);
        OpusLockDiscoverHAM();
    } @catch (__unused NSException *e) { }
}
