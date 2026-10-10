#import <Foundation/Foundation.h>
#import "UYTDirectFormats.h"
static NSDictionary *response(NSString *identifier,NSArray *formats) { return @{@"videoDetails":@{@"videoId":identifier,@"title":@"Тест"},@"playabilityStatus":@{@"status":@"OK"},@"streamingData":@{@"adaptiveFormats":formats}}; }
int main(void) { @autoreleasepool {
    NSString *vid=@"jNQXAC9IVRw";
    NSDictionary *audio=@{@"mimeType":@"audio/mp4; codecs=\"mp4a.40.2\"",@"url":@"https://example.invalid/a",@"bitrate":@128000};
    NSDictionary *video=@{@"mimeType":@"video/mp4; codecs=\"avc1.640028\"",@"url":@"https://example.invalid/v",@"height":@720,@"bitrate":@2000000};
    NSDictionary *av1=@{@"mimeType":@"video/mp4; codecs=\"av01.0.08M.08\"",@"url":@"https://example.invalid/av1",@"height":@1080};
    NSCAssert(UYTValidVideoID(vid)&&!UYTValidVideoID(@"../bad/path")&&!UYTValidVideoID(NSNull.null),@"strict video ID validation");
    NSCAssert(UYTDirectFormats(response(@"M7lc1UVf-VE",@[audio,video]),vid)==nil,@"must reject a different video's response");
    NSCAssert(UYTDirectFormats(response(vid,@[video]),vid)==nil,@"must reject video without audio");
    NSCAssert(UYTDirectFormats(response(vid,@[audio,av1]),vid)==nil,@"must reject AV1-only video on iPad A10");
    NSDictionary *result=UYTDirectFormats(response(vid,@[audio,video,av1]),vid);
    NSCAssert([result[@"videos"] count]==1&&[result[@"videoID"] isEqual:vid],@"must select AVC plus AAC for exactly the requested video");
    NSCAssert(UYTDirectFormats((id)NSNull.null,vid)==nil,@"must reject malformed response");
    NSDictionary *broken=@{@"mimeType":@"video/mp4; codecs=\"avc1\"",@"url":@"https://example.invalid/bad",@"height":NSNull.null,@"bitrate":NSNull.null};
    NSCAssert(UYTDirectFormats(response(vid,@[audio,broken]),vid)==nil,@"Malformed numeric fields must not crash");
    puts("PASS: selected video identity, audio required, A10 codec compatibility, malformed response and ID validation");
} return 0; }
