#import "UYTShortsFilter.h"
static BOOL UYTContainsMarker(NSData *data,NSString *marker) {
    NSData *needle=[marker dataUsingEncoding:NSUTF8StringEncoding];
    return [data rangeOfData:needle options:0 range:NSMakeRange(0,data.length)].location!=NSNotFound;
}
BOOL UYTShortsData(NSData *data) {
    if (![data isKindOfClass:NSData.class] || !data.length || data.length>256*1024) return NO;
    for (NSString *marker in @[@"shorts_shelf",@"shorts_video_cell",@"shorts_grid_shelf",@"shorts_lockup",@"youtube_shorts_24"]) if (UYTContainsMarker(data,marker)) return YES;
    return UYTContainsMarker(data,@"compact_video.eml") && UYTContainsMarker(data,@"youtube_shorts_");
}
BOOL UYTShortsComponent(NSString *text) {
    if (![text isKindOfClass:NSString.class] || text.length>256*1024) return NO;
    return UYTShortsData([text dataUsingEncoding:NSUTF8StringEncoding]);
}
