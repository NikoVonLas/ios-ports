#import "UYTShortsFilter.h"
BOOL UYTShortsComponent(NSString *text) {
    if (![text isKindOfClass:NSString.class] || text.length>256*1024) return NO;
    for (NSString *marker in @[@"shorts_shelf",@"shorts_video_cell",@"shorts_grid_shelf",@"shorts_lockup",@"youtube_shorts_24"]) if ([text containsString:marker]) return YES;
    return [text containsString:@"compact_video.eml"] && [text containsString:@"youtube_shorts_"];
}
