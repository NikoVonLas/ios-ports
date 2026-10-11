#import "UYTSponsor.h"
#import "UYTDirectFormats.h"
#import <math.h>

BOOL UYTSponsorEnabled(void) {
    id value = [NSUserDefaults.standardUserDefaults objectForKey:@"UYT.sponsor.enabled"];
    return value ? [value boolValue] : YES;
}
NSArray *UYTParseSponsorSegments(id json) {
    if (![json isKindOfClass:NSArray.class]) return @[];
    NSMutableArray *result = [NSMutableArray array];
    for (id entry in json) {
        if (![entry isKindOfClass:NSDictionary.class] || ![entry[@"category"] isEqual:@"sponsor"] ||
            (entry[@"actionType"] && ![entry[@"actionType"] isEqual:@"skip"])) continue;
        id range = entry[@"segment"];
        if (![range isKindOfClass:NSArray.class] || [range count] != 2 ||
            ![range[0] isKindOfClass:NSNumber.class] || ![range[1] isKindOfClass:NSNumber.class]) continue;
        double start = [range[0] doubleValue], end = [range[1] doubleValue];
        if (isfinite(start) && isfinite(end) && start >= 0 && end > start) [result addObject:@[@(start),@(end)]];
    }
    return [result sortedArrayUsingComparator:^NSComparisonResult(NSArray *a, NSArray *b) { return [a[0] compare:b[0]]; }];
}
double UYTSponsorSkipEnd(NSArray *segments, double time, double duration) {
    if (!isfinite(time) || time < 0 || !isfinite(duration) || duration <= 0 || time >= duration) return -1;
    double end = -1;
    for (NSArray *range in segments) {
        double start = [range[0] doubleValue], stop = [range[1] doubleValue];
        if (start <= time && time < stop) end = MAX(end,stop);
        // Coalesce touching/overlapping intervals to avoid repeated seeks.
        if (end >= 0 && start <= end) end = MAX(end,stop);
    }
    return end > time ? MIN(end,duration) : -1;
}
NSArray *UYTSponsorMarkerRanges(NSArray *segments, double duration) {
    if (!isfinite(duration) || duration <= 0) return @[];
    NSMutableArray *markers=[NSMutableArray array];
    for (id range in segments) {
        if (![range isKindOfClass:NSArray.class] || [range count]!=2 ||
            ![range[0] isKindOfClass:NSNumber.class] || ![range[1] isKindOfClass:NSNumber.class]) continue;
        double start=[range[0] doubleValue], end=[range[1] doubleValue];
        if (!isfinite(start) || !isfinite(end) || start<0 || end<=start || start>=duration) continue;
        [markers addObject:@[@(start/duration),@(MIN(end,duration)/duration)]];
    }
    return markers;
}
static NSString *UYTSponsorPath(NSString *videoID) {
    if (!UYTValidVideoID(videoID)) return nil;
    NSString *directory = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"UYTOffline/SponsorBlock"];
    [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    return [directory stringByAppendingPathComponent:[videoID stringByAppendingPathExtension:@"plist"]];
}
void UYTFetchSponsorSegments(NSString *videoID, void (^completion)(NSArray *)) {
    NSString *path = UYTSponsorPath(videoID);
    if (!path) { completion(@[]); return; }
    NSDictionary *cached = [NSDictionary dictionaryWithContentsOfFile:path];
    NSArray *previous = UYTParseSponsorSegments(cached[@"entries"]);
    // Show cached segments immediately, including while offline.
    if (cached) completion(previous);
    if ([cached[@"date"] isKindOfClass:NSDate.class] && -[cached[@"date"] timeIntervalSinceNow] < 86400) return;
    NSURLComponents *url = [NSURLComponents componentsWithString:@"https://sponsor.ajay.app/api/skipSegments"];
    url.queryItems = @[[NSURLQueryItem queryItemWithName:@"videoID" value:videoID], [NSURLQueryItem queryItemWithName:@"categories" value:@"[\"sponsor\"]"]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url.URL]; request.timeoutInterval = 12;
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error) {
        NSInteger status = [(NSHTTPURLResponse *)response statusCode];
        id entries = !error && status == 200 && data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if (!error && status == 404) entries = @[];
        if (![entries isKindOfClass:NSArray.class]) { if (!cached) dispatch_async(dispatch_get_main_queue(), ^{ completion(@[]); }); return; }
        NSArray *ranges = UYTParseSponsorSegments(entries);
        NSMutableArray *clean = [NSMutableArray array];
        for (NSArray *range in ranges) [clean addObject:@{@"category":@"sponsor", @"actionType":@"skip", @"segment":range}];
        [@{@"entries":clean,@"date":NSDate.date} writeToFile:path atomically:YES];
        dispatch_async(dispatch_get_main_queue(), ^{ completion(ranges); });
    }] resume];
}
