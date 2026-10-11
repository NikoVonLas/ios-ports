#import <Foundation/Foundation.h>
#import "UYTShortsFilter.h"
int main(void) { @autoreleasepool {
    NSCAssert(UYTShortsComponent(@"component: shorts_shelf.eml"),@"Shelf removed");
    NSCAssert(UYTShortsComponent(@"shorts_video_cell.eml"),@"Standalone cell removed");
    NSCAssert(UYTShortsComponent(@"compact_video.eml icon: youtube_shorts_outline"),@"Compact short removed");
    NSCAssert(!UYTShortsComponent(@"compact_video.eml title: Review of YouTube Shorts"),@"Ordinary video mentioning Shorts kept");
    NSCAssert(!UYTShortsComponent(@"video_card.eml"),@"Regular video kept");
    NSCAssert(!UYTShortsComponent((id)@42),@"Malformed marker data ignored");
    const unsigned char binary[]={0xff,0,0x0a,16,'s','h','o','r','t','s','_','s','h','e','l','f',0xfe};
    NSCAssert(UYTShortsData([NSData dataWithBytes:binary length:sizeof(binary)]),@"Binary protobuf markers do not need UTF-8 decoding");
    NSCAssert(!UYTShortsData([@"Review of YouTube Shorts" dataUsingEncoding:NSUTF8StringEncoding]),@"Title bytes kept");
    puts("PASS: Shorts shelf, individual and compact markers; ordinary videos retained");
} return 0; }
