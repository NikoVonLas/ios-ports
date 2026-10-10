#import <YouTubeHeader/YTPlayerViewController.h>
#import <YouTubeHeader/YTSingleVideoTime.h>
#import <objc/runtime.h>
#import <math.h>
#import "UYTSponsor.h"
#import "UYTDirectFormats.h"

static char UYTSponsorVideoKey, UYTSponsorRangesKey, UYTSponsorLastSeekKey;
static void UYTUpdateSponsor(YTPlayerViewController *player) {
    if (![player respondsToSelector:@selector(currentVideoID)]) return;
    NSString *videoID = player.currentVideoID;
    if (!UYTValidVideoID(videoID)) return;
    if ([objc_getAssociatedObject(player,&UYTSponsorVideoKey) isEqual:videoID]) return;
    objc_setAssociatedObject(player,&UYTSponsorVideoKey,videoID,OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(player,&UYTSponsorRangesKey,@[],OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(player,&UYTSponsorLastSeekKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak YTPlayerViewController *weakPlayer = player;
    UYTFetchSponsorSegments(videoID, ^(NSArray *ranges) {
        if ([objc_getAssociatedObject(weakPlayer,&UYTSponsorVideoKey) isEqual:videoID])
            objc_setAssociatedObject(weakPlayer,&UYTSponsorRangesKey,ranges,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    });
}
static void UYTMaybeSkip(YTPlayerViewController *player) {
    UYTUpdateSponsor(player);
    if (!UYTSponsorEnabled() || ![player respondsToSelector:@selector(currentVideoMediaTime)] ||
        ![player respondsToSelector:@selector(currentVideoTotalMediaTime)] ||
        ([player respondsToSelector:@selector(isPlayingAd)] && player.isPlayingAd) ||
        ([player respondsToSelector:@selector(isMDXActive)] && player.isMDXActive)) return;
    double time = player.currentVideoMediaTime;
    double end = UYTSponsorSkipEnd(objc_getAssociatedObject(player,&UYTSponsorRangesKey),time,player.currentVideoTotalMediaTime);
    if (end < 0) { objc_setAssociatedObject(player,&UYTSponsorLastSeekKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); return; }
    NSNumber *last = objc_getAssociatedObject(player,&UYTSponsorLastSeekKey);
    if (last && fabs(last.doubleValue-end) < 0.05) return;
    objc_setAssociatedObject(player,&UYTSponsorLastSeekKey,@(end),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if ([player respondsToSelector:@selector(scrubToTime:)]) [player scrubToTime:end];
    else if ([player respondsToSelector:@selector(seekToTime:)]) [player seekToTime:end];
}
%hook YTPlayerViewController
- (void)singleVideo:(id)video currentVideoTimeDidChange:(YTSingleVideoTime *)time {
    %orig;
    UYTMaybeSkip(self);
}
- (void)potentiallyMutatedSingleVideo:(id)video currentVideoTimeDidChange:(YTSingleVideoTime *)time {
    %orig;
    UYTMaybeSkip(self);
}
%end
