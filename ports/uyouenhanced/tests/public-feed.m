#import <Foundation/Foundation.h>
#import "UYTPublicFeed.h"
#include <assert.h>
int main(int argc,const char **argv) { @autoreleasepool {
    NSDictionary *badge=@{@"thumbnailBadgeViewModel":@{@"text":@"1:23:45"}};
    NSDictionary *overlay=@{@"thumbnailBottomOverlayViewModel":@{@"badges":@[badge]}};
    NSDictionary *modern=@{@"lockupViewModel":@{
        @"contentId":@"fr0WIIZxvx0", @"contentType":@"LOCKUP_CONTENT_TYPE_VIDEO",
        @"metadata":@{@"lockupMetadataViewModel":@{@"title":@{@"content":@"Title } with \" quotes"}}},
        @"contentImage":@{@"thumbnailViewModel":@{@"overlays":@[overlay]}}
    }};
    NSDictionary *legacy=@{@"playlistVideoRenderer":@{@"videoId":@"3mqssh4sdYw",@"title":@{@"runs":@[@{@"text":@"First"},@{@"text":@" second"}]},@"lengthText":@{@"simpleText":@"35:02"}}};
    NSDictionary *duplicate=modern;
    NSDictionary *malformed=@{@"lockupViewModel":@{@"contentId":@"EAKcBGntjzc",@"contentType":@"LOCKUP_CONTENT_TYPE_VIDEO",@"metadata":@42}};
    NSDictionary *playlist=@{@"lockupViewModel":@{@"contentId":@"PLabcdefghijkl",@"contentType":@"LOCKUP_CONTENT_TYPE_PLAYLIST"}};
    NSDictionary *shorts=@{@"reelShelfRenderer":@{@"items":@[legacy]}};
    NSDictionary *json=@{@"contents":@{@"twoColumnBrowseResultsRenderer":@{@"tabs":@[@{@"tabRenderer":@{@"content":@{@"sectionListRenderer":@{@"contents":@[modern,legacy,duplicate,malformed,playlist,shorts]}}}}]}}};
    NSString *body=[[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:json options:0 error:nil] encoding:NSUTF8StringEncoding];
    NSData *html=[[@"<script>var ytInitialData = " stringByAppendingFormat:@"%@;</script>",body] dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *items=UYTPublicVideos(UYTYouTubeInitialData(html));
    assert(items.count==2); assert([items[0][@"videoID"] isEqual:@"fr0WIIZxvx0"]); assert([items[0][@"durationText"] isEqual:@"1:23:45"]); assert([items[1][@"title"] isEqual:@"First second"]);
    assert(!UYTYouTubeInitialData([@"var ytInitialData = {\"x\":\"unterminated" dataUsingEncoding:NSUTF8StringEncoding]));
    assert(!UYTYouTubeInitialData([@"<html>consent required</html>" dataUsingEncoding:NSUTF8StringEncoding]));
    assert(UYTPublicVideos((id)@42).count==0);
    if (argc>1) {
        NSData *real=[NSData dataWithContentsOfFile:[NSString stringWithUTF8String:argv[1]]];
        NSArray *videos=UYTPublicVideos(UYTYouTubeInitialData(real)); assert(videos.count>0);
        printf("Public YouTube payload: %lu videos, first=%s\n",(unsigned long)videos.count,[videos[0][@"videoID"] UTF8String]);
    }
    puts("Public feed parser: modern/legacy, ordering, duration, malformed input and Shorts exclusion passed");
} return 0; }
