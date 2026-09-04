#import "OpusLockDiag.h"

static NSLock *OpusLockDiagLock(void) {
    static NSLock *lock = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lock = [[NSLock alloc] init];
    });
    return lock;
}

static NSMutableDictionary<NSString *, id> *OpusLockDiagStore(void) {
    static NSMutableDictionary<NSString *, id> *store = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        store = [[NSMutableDictionary alloc] init];
    });
    return store;
}

void OpusLockDiagSet(NSString *key, NSString *value) {
    @try {
        if (!key || !value) return;
        [OpusLockDiagLock() lock];
        OpusLockDiagStore()[key] = value;
        [OpusLockDiagLock() unlock];
    } @catch (__unused NSException *e) { }
}

void OpusLockDiagCount(NSString *key) {
    @try {
        if (!key) return;
        [OpusLockDiagLock() lock];
        NSMutableDictionary *s = OpusLockDiagStore();
        long n = [s[key] longValue];
        s[key] = [NSString stringWithFormat:@"%ld", n + 1];
        [OpusLockDiagLock() unlock];
    } @catch (__unused NSException *e) { }
}

NSArray<NSArray<NSString *> *> *OpusLockDiagRows(void) {
    NSArray<NSString *> *order = @[
        @"resp.class", @"resp.getter", @"resp.hook", @"resp.calls",
        @"sd.array", @"sd.arrays", @"sd.elements", @"sd.audio", @"sd.recorded",
        @"bool.hooks",
        @"menu.hook",
        @"ham.classes", @"ham.sample",
    ];
    NSMutableArray *rows = [NSMutableArray arrayWithCapacity:order.count];
    @try {
        [OpusLockDiagLock() lock];
        NSDictionary *s = [OpusLockDiagStore() copy];
        [OpusLockDiagLock() unlock];
        for (NSString *k in order) {
            NSString *v = s[k];
            if (![v isKindOfClass:[NSString class]] || v.length == 0) v = @"—";
            [rows addObject:@[k, v]];
        }
    } @catch (__unused NSException *e) { }
    return rows;
}
