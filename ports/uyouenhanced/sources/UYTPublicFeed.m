#import "UYTPublicFeed.h"
#import "UYTDirectFormats.h"

NSDictionary *UYTYouTubeInitialData(NSData *data) {
    if (!data.length || data.length>6*1024*1024) return nil;
    NSString *html=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!html) return nil;
    NSRegularExpression *marker=[NSRegularExpression regularExpressionWithPattern:@"(?:var\\s+ytInitialData|window\\[\"ytInitialData\"\\]|ytInitialData)\\s*=\\s*\\{" options:0 error:nil];
    for (NSTextCheckingResult *match in [marker matchesInString:html options:0 range:NSMakeRange(0,html.length)]) {
        NSUInteger start=NSMaxRange(match.range)-1, end=start; NSInteger depth=0;
        BOOL quoted=NO, escaped=NO;
        for (;end<html.length;end++) {
            unichar c=[html characterAtIndex:end];
            if (quoted) {
                if (escaped) escaped=NO;
                else if (c=='\\') escaped=YES;
                else if (c=='"') quoted=NO;
            } else if (c=='"') quoted=YES;
            else if (c=='{') depth++;
            else if (c=='}' && --depth==0) { end++; break; }
        }
        if (depth || quoted || end>html.length) continue;
        NSData *json=[[html substringWithRange:NSMakeRange(start,end-start)] dataUsingEncoding:NSUTF8StringEncoding];
        id value=[NSJSONSerialization JSONObjectWithData:json options:0 error:nil];
        if ([value isKindOfClass:NSDictionary.class]) return value;
    }
    return nil;
}
static NSString *UYTFeedText(id value) {
    if ([value isKindOfClass:NSString.class]) return value;
    if (![value isKindOfClass:NSDictionary.class]) return @"";
    for (NSString *key in @[@"content",@"simpleText"]) if ([value[key] isKindOfClass:NSString.class]) return value[key];
    NSMutableString *text=[NSMutableString string];
    if ([value[@"runs"] isKindOfClass:NSArray.class]) for (id run in value[@"runs"]) {
        if ([run isKindOfClass:NSDictionary.class] && [run[@"text"] isKindOfClass:NSString.class]) [text appendString:run[@"text"]];
    }
    return text;
}
static id UYTFeedPath(id object, NSArray *keys) {
    for (NSString *key in keys) {
        if (![object isKindOfClass:NSDictionary.class]) return nil;
        object=object[key];
    }
    return object;
}
static NSString *UYTFeedDuration(id object, NSUInteger depth) {
    if (depth>20) return @"";
    if ([object isKindOfClass:NSDictionary.class]) {
        NSString *text=UYTFeedText(object[@"text"]);
        if (text.length && [text rangeOfString:@"^(?:[0-9]+:)?[0-9]{1,2}:[0-9]{2}$" options:NSRegularExpressionSearch].location!=NSNotFound) return text;
        for (id child in [object allValues]) { NSString *result=UYTFeedDuration(child,depth+1); if (result.length) return result; }
    } else if ([object isKindOfClass:NSArray.class]) for (id child in object) { NSString *result=UYTFeedDuration(child,depth+1); if (result.length) return result; }
    return @"";
}
static void UYTCollectVideos(id object, NSMutableArray *videos, NSMutableSet *seen, NSUInteger depth) {
    if (depth>40 || videos.count>=100) return;
    if ([object isKindOfClass:NSArray.class]) { for (id child in object) UYTCollectVideos(child,videos,seen,depth+1); return; }
    if (![object isKindOfClass:NSDictionary.class]) return;
    NSDictionary *renderer=nil; BOOL modern=NO;
    for (NSString *key in @[@"videoRenderer",@"gridVideoRenderer",@"playlistVideoRenderer"]) if ([object[key] isKindOfClass:NSDictionary.class]) { renderer=object[key]; break; }
    if (!renderer && [object[@"lockupViewModel"] isKindOfClass:NSDictionary.class]) {
        NSDictionary *lockup=object[@"lockupViewModel"];
        if ([lockup[@"contentType"] isEqual:@"LOCKUP_CONTENT_TYPE_VIDEO"]) { renderer=lockup; modern=YES; }
    }
    if (renderer) {
        NSString *identifier=renderer[modern?@"contentId":@"videoId"];
        NSString *title=UYTFeedText(modern?UYTFeedPath(renderer,@[@"metadata",@"lockupMetadataViewModel",@"title"]):renderer[@"title"]);
        if (UYTValidVideoID(identifier) && title.length && ![seen containsObject:identifier]) {
            NSString *duration=modern?UYTFeedDuration(renderer[@"contentImage"],0):UYTFeedText(renderer[@"lengthText"]);
            if (!duration.length) duration=UYTFeedDuration(renderer[@"thumbnailOverlays"],0);
            [videos addObject:@{@"videoID":identifier,@"title":title,@"durationText":duration ?: @""}]; [seen addObject:identifier];
        }
        return; // Do not collect menu commands or related-video tracking payloads.
    }
    // Traverse only feed containers; keep their array order and ignore Shorts,
    // ads, navigation menus, sidebars and unrelated tracking data.
    for (NSString *key in @[@"contents",@"content",@"tabs",@"tabRenderer",@"twoColumnBrowseResultsRenderer",@"singleColumnBrowseResultsRenderer",@"sectionListRenderer",@"itemSectionRenderer",@"shelfRenderer",@"horizontalListRenderer",@"expandedShelfContentsRenderer",@"gridRenderer",@"richGridRenderer",@"richItemRenderer",@"richSectionRenderer",@"richShelfRenderer",@"playlistVideoListRenderer",@"items"])
        if (object[key]) UYTCollectVideos(object[key],videos,seen,depth+1);
}
NSArray<NSDictionary *> *UYTPublicVideos(NSDictionary *data) {
    if (![data isKindOfClass:NSDictionary.class]) return @[];
    NSMutableArray *videos=[NSMutableArray array]; UYTCollectVideos(data[@"contents"],videos,[NSMutableSet set],0); return videos;
}
