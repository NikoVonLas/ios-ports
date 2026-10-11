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
    NSDictionary *small=@{@"mimeType":@"video/mp4; codecs=\"avc1.42001E\"",@"url":@"https://example.invalid/preview",@"height":@360};
    NSDictionary *preview=UYTPreviewFormat(response(vid,@[audio,video,small,av1]),vid);
    NSCAssert([preview[@"video"][@"height"] isEqual:@360] && preview[@"audio"] && ![preview[@"muxed"] boolValue],@"Preview keeps sound and chooses low-resolution AVC");
    NSCAssert(!UYTPreviewFormat(response(vid,@[small]),vid),@"Sound requested: reject silent-only streams");
    NSCAssert(!UYTPreviewFormat(response(@"M7lc1UVf-VE",@[audio,small]),vid),@"Preview must reject mismatched video identity");
    NSCAssert(!UYTPreviewFormat(response(vid,@[audio,broken]),vid),@"Malformed preview format must not crash");
    NSDictionary *muxed=@{@"mimeType":@"video/mp4; codecs=\"avc1.42001E, mp4a.40.2\"",@"url":@"https://example.invalid/muxed",@"height":@360};
    NSMutableDictionary *withMuxed=[response(vid,@[audio,small]) mutableCopy]; withMuxed[@"streamingData"]=@{@"formats":@[muxed],@"adaptiveFormats":@[audio,small]};
    NSCAssert([UYTPreviewFormat(withMuxed,vid)[@"muxed"] boolValue],@"Prefer video+audio stream to composition");
    NSMutableDictionary *live=[withMuxed mutableCopy]; live[@"videoDetails"]=@{@"videoId":vid,@"isLiveContent":@YES};
    NSCAssert(!UYTPreviewFormat(live,vid),@"No bounded preview for live broadcast");
    live[@"videoDetails"]=@{@"videoId":vid,@"isLiveContent":@YES,@"lengthSeconds":@"17030"};
    NSCAssert(UYTPreviewFormat(live,vid),@"Finished live recording with finite duration can preview");
    live[@"videoDetails"]=@{@"videoId":vid,@"isLiveContent":@YES,@"lengthSeconds":@"17030",@"isLive":@YES};
    NSCAssert(!UYTPreviewFormat(live,vid),@"Active live broadcast remains excluded even with a reported length");
    live[@"videoDetails"]=@{@"videoId":vid,@"isLiveContent":@YES,@"lengthSeconds":@"17030"};
    live[@"microformat"]=@{@"playerMicroformatRenderer":@{@"liveBroadcastDetails":@{@"isLiveNow":@YES}}};
    NSCAssert(!UYTPreviewFormat(live,vid),@"Broadcast metadata also distinguishes live from recording");
    NSCAssert(!UYTPlayerRequest(@"../bad"),@"Invalid IDs cannot initiate requests");
    NSMutableData *thumbnail=[NSMutableData dataWithBytes:"\xff\0" length:2];
    [thumbnail appendData:[@"https://i.ytimg.com/vi/jNQXAC9IVRw/hqdefault.jpg https://i9.ytimg.com/vi_webp/jNQXAC9IVRw/mqdefault.webp?x=1" dataUsingEncoding:NSUTF8StringEncoding]];
    NSCAssert([UYTVideoIDFromThumbnailData(thumbnail) isEqual:@"jNQXAC9IVRw"],@"Repeated card thumbnail ID survives binary protobuf");
    [thumbnail appendData:[@" https://i.ytimg.com/vi/M7lc1UVf-VE/hqdefault.jpg" dataUsingEncoding:NSUTF8StringEncoding]];
    NSCAssert(!UYTVideoIDFromThumbnailData(thumbnail),@"Mixed-video container must not choose an arbitrary preview");
    NSCAssert(!UYTVideoIDFromThumbnailData([@"https://example.invalid/vi/jNQXAC9IVRw/hqdefault.jpg https://yt3.ggpht.com/avatar" dataUsingEncoding:NSUTF8StringEncoding]),@"Only video-cover hosts/paths supply identity");
    puts("PASS: selected video identity, audio required, A10 codec compatibility, malformed response and ID validation");
} return 0; }
