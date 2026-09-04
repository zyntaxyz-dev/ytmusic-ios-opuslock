#import "OpusLockPolicy.h"

@implementation OpusLockPolicy

+ (NSArray<NSNumber *> *)fallbackChain {
    static NSArray<NSNumber *> *chain = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        chain = @[@774, @141, @251, @140, @250, @249, @139, @600, @599];
    });
    return chain;
}

+ (nullable NSDictionary<NSString *, id> *)infoForItag:(NSInteger)itag {
    static NSDictionary<NSNumber *, NSDictionary<NSString *, id> *> *table = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        table = @{
            @774 : @{@"codec": @"OPUS", @"bitrateKbps": @256, @"sampleRateHz": @48000, @"label": @"high"},
            @141 : @{@"codec": @"AAC",  @"bitrateKbps": @256, @"sampleRateHz": @44100, @"label": @"high"},
            @251 : @{@"codec": @"OPUS", @"bitrateKbps": @128, @"sampleRateHz": @48000, @"label": @"medium"},
            @140 : @{@"codec": @"AAC",  @"bitrateKbps": @128, @"sampleRateHz": @44100, @"label": @"medium"},
            @250 : @{@"codec": @"OPUS", @"bitrateKbps": @70,  @"sampleRateHz": @48000, @"label": @"low"},
            @249 : @{@"codec": @"OPUS", @"bitrateKbps": @50,  @"sampleRateHz": @48000, @"label": @"low"},
            @139 : @{@"codec": @"AAC",  @"bitrateKbps": @48,  @"sampleRateHz": @44100, @"label": @"low"},
            @600 : @{@"codec": @"OPUS", @"bitrateKbps": @35,  @"sampleRateHz": @48000, @"label": @"low"},
            @599 : @{@"codec": @"AAC",  @"bitrateKbps": @30,  @"sampleRateHz": @44100, @"label": @"low"},
        };
    });
    return table[@(itag)];
}

+ (NSInteger)itagFromURL:(nullable NSURL *)url {
    if (!url) return -1;
    NSURLComponents *parts = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    for (NSURLQueryItem *item in parts.queryItems) {
        if ([item.name isEqualToString:@"itag"]) {
            return item.value.integerValue;
        }
    }
    // Fallback: regex sobre la URL cruda (algunas URLs van firmadas/escapadas).
    static NSRegularExpression *re = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        re = [NSRegularExpression regularExpressionWithPattern:@"[?&]itag=(\\d+)"
                                                       options:0 error:NULL];
    });
    NSString *s = url.absoluteString;
    NSTextCheckingResult *m = [re firstMatchInString:s options:0 range:NSMakeRange(0, s.length)];
    if (m && m.numberOfRanges == 2) {
        return [[s substringWithRange:[m rangeAtIndex:1]] integerValue];
    }
    return -1;
}

+ (NSUInteger)rankForItag:(NSInteger)itag {
    return [[self fallbackChain] indexOfObject:@(itag)];
}

+ (nullable NSURL *)bestURLFromURLs:(NSArray<NSURL *> *)urls {
    NSURL *best = nil;
    NSUInteger bestRank = NSUIntegerMax;
    for (NSURL *u in urls) {
        NSUInteger r = [self rankForItag:[self itagFromURL:u]];
        if (r < bestRank) {
            bestRank = r;
            best = u;
            if (r == 0) break;
        }
    }
    return best;
}

static NSInteger OpusLockItagOfFormat(NSDictionary *f) {
    id v = f[@"itag"];
    if ([v respondsToSelector:@selector(integerValue)]) return [v integerValue];
    return -1;
}

+ (NSArray<NSDictionary *> *)rankedFormatsFromAdaptiveFormats:(NSArray<NSDictionary *> *)formats {
    return [formats sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        NSUInteger ra = [self rankForItag:OpusLockItagOfFormat(a)];
        NSUInteger rb = [self rankForItag:OpusLockItagOfFormat(b)];
        if (ra < rb) return NSOrderedAscending;
        if (ra > rb) return NSOrderedDescending;
        return NSOrderedSame;
    }];
}

@end
