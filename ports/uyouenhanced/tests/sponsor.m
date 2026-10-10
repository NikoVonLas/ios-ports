#import <Foundation/Foundation.h>
#import "UYTSponsor.h"
#import "UYTDirectFormats.h"
#import <math.h>
int main(void) { @autoreleasepool {
    NSArray *segments=UYTParseSponsorSegments(@[
        @{@"category":@"sponsor",@"actionType":@"skip",@"segment":@[@10,@20]},
        @{@"category":@"sponsor",@"segment":@[@19,@25]},
        @{@"category":@"sponsor",@"segment":@[@25,@30]},
        @{@"category":@"intro",@"segment":@[@0,@8]},
        @{@"category":@"sponsor",@"actionType":@"mute",@"segment":@[@50,@60]},
        @{@"category":@"sponsor",@"segment":@[@(-1),@8]},
        @{@"category":@"sponsor",@"segment":@[@8,@4]},
        @{@"category":@"sponsor",@"segment":@[@4,@(NAN)]},
        @{@"category":@"sponsor",@"segment":@[@"4",@8]}, NSNull.null]);
    NSCAssert(segments.count==3,@"Malformed/non-sponsor/mute intervals must be rejected");
    NSCAssert(UYTSponsorSkipEnd(segments,9,100)==-1,@"Never skip before sponsor");
    NSCAssert(UYTSponsorSkipEnd(segments,10,100)==30,@"Coalesce touching and overlapping sponsor intervals");
    NSCAssert(UYTSponsorSkipEnd(segments,15,27)==27,@"Clamp end to media duration");
    NSCAssert(UYTSponsorSkipEnd(segments,29,27)==-1,@"Never seek backward for invalid media time");
    NSCAssert(UYTSponsorSkipEnd(segments,30,100)==-1,@"Exact end must not loop");
    NSCAssert(UYTSponsorSkipEnd(segments,15,NAN)==-1,@"Unknown duration must not seek");
    NSCAssert(UYTSponsorSkipEnd(@[],15,100)==-1,@"No segments (404/offline cache miss) must preserve playback");
    NSCAssert([UYTVideoIDFromInput(@"https://youtu.be/jNQXAC9IVRw?t=12") isEqual:@"jNQXAC9IVRw"],@"Short link");
    NSCAssert([UYTVideoIDFromInput(@"https://www.youtube.com/watch?v=jNQXAC9IVRw") isEqual:@"jNQXAC9IVRw"],@"Watch link");
    NSCAssert([UYTVideoIDFromInput(@"https://m.youtube.com/shorts/jNQXAC9IVRw") isEqual:@"jNQXAC9IVRw"],@"Shorts link");
    NSCAssert(!UYTVideoIDFromInput(@"https://youtube.com.evil.invalid/watch?v=jNQXAC9IVRw"),@"Reject spoofed host");
    NSCAssert(!UYTVideoIDFromInput(@"https://youtube.com/watch?v=jNQXAC9IVRw&v=M7lc1UVf-VE"),@"Reject ambiguous IDs");
    NSCAssert(!UYTVideoIDFromInput(@"file:///watch?v=jNQXAC9IVRw"),@"Reject local URLs");
    puts("PASS: SponsorBlock input validation, overlaps, duration, empty response, URL identity");
} return 0; }
