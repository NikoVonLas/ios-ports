#import "UYTDirectFormats.h"
BOOL UYTValidVideoID(id value) {
    if (![value isKindOfClass:NSString.class] || [value length]!=11) return NO;
    return [value rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"] invertedSet]].location==NSNotFound;
}
static BOOL UYTMediaURL(id value) { return [value isKindOfClass:NSString.class] && [[[NSURL URLWithString:value] scheme].lowercaseString isEqual:@"https"]; }
NSString *UYTVideoIDFromInput(NSString *input) {
    if (![input isKindOfClass:NSString.class]) return nil;
    if (UYTValidVideoID(input)) return input;
    NSURLComponents *url=[NSURLComponents componentsWithString:input];
    if (![@[@"http",@"https"] containsObject:url.scheme.lowercaseString]) return nil;
    NSString *host=url.host.lowercaseString, *identifier=nil;
    NSArray *parts=[url.path componentsSeparatedByString:@"/"];
    if ([host isEqual:@"youtu.be"] && parts.count==2) identifier=parts[1];
    else if ([@[@"youtube.com",@"www.youtube.com",@"m.youtube.com",@"music.youtube.com"] containsObject:host]) {
        if ([url.path isEqual:@"/watch"]) for (NSURLQueryItem *item in url.queryItems) if ([item.name isEqual:@"v"]) { if (identifier) return nil; identifier=item.value; }
        if (parts.count==3 && [@[@"shorts",@"embed",@"live"] containsObject:parts[1]]) identifier=parts[2];
    }
    return UYTValidVideoID(identifier)?identifier:nil;
}
NSDictionary *UYTDirectFormats(NSDictionary *response, NSString *requestedID) {
    if (![response isKindOfClass:NSDictionary.class] || !UYTValidVideoID(requestedID)) return nil;
    NSDictionary *details=response[@"videoDetails"], *status=response[@"playabilityStatus"], *streaming=response[@"streamingData"];
    if (![details isKindOfClass:NSDictionary.class] || ![status isKindOfClass:NSDictionary.class] || ![streaming isKindOfClass:NSDictionary.class]) return nil;
    if (![details[@"videoId"] isEqual:requestedID] || ![status[@"status"] isEqual:@"OK"]) return nil;
    NSArray *formats=streaming[@"adaptiveFormats"]; if (![formats isKindOfClass:NSArray.class]) return nil;
    NSMutableDictionary *byHeight=[NSMutableDictionary dictionary]; NSDictionary *audio=nil;
    for (NSDictionary *f in formats) {
        if (![f isKindOfClass:NSDictionary.class] || !UYTMediaURL(f[@"url"]) || ![f[@"mimeType"] isKindOfClass:NSString.class]) continue;
        NSString *mime=f[@"mimeType"];
        long long bitrate=[f[@"bitrate"] isKindOfClass:NSNumber.class]?[f[@"bitrate"] longLongValue]:0;
        long long audioBitrate=[audio[@"bitrate"] isKindOfClass:NSNumber.class]?[audio[@"bitrate"] longLongValue]:0;
        if ([mime hasPrefix:@"audio/mp4"] && [mime containsString:@"mp4a"] && (!audio || bitrate>audioBitrate)) audio=f;
        NSInteger height=[f[@"height"] isKindOfClass:NSNumber.class]?[f[@"height"] integerValue]:0;
        if ([mime hasPrefix:@"video/mp4"] && [mime containsString:@"avc1"] && height>0 && height<=1080) {
            NSString *key=[NSString stringWithFormat:@"%ld",(long)height]; NSDictionary *prior=byHeight[key];
            long long priorBitrate=[prior[@"bitrate"] isKindOfClass:NSNumber.class]?[prior[@"bitrate"] longLongValue]:0;
            if (!prior || bitrate>priorBitrate) byHeight[key]=f;
        }
    }
    if (!audio || !byHeight.count) return nil;
    NSArray *videos=[byHeight.allValues sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){ NSInteger ah=[a[@"height"] integerValue],bh=[b[@"height"] integerValue]; return ah>bh?NSOrderedAscending:ah<bh?NSOrderedDescending:NSOrderedSame; }];
    return @{@"videoID":requestedID,@"title":[details[@"title"] isKindOfClass:NSString.class]?details[@"title"]:@"Видео",@"audio":audio,@"videos":videos};
}
