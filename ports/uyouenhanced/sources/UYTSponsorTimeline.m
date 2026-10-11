#import "UYTSponsorTimeline.h"
#import "UYTSponsor.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <math.h>

static id UYTTRead(id object, NSString *name) {
    SEL sel=NSSelectorFromString(name);
    NSMethodSignature *signature=[object methodSignatureForSelector:sel];
    if (![object respondsToSelector:sel] || !signature || signature.numberOfArguments!=2 || signature.methodReturnType[0]!='@') return nil;
    @try { return ((id(*)(id,SEL))objc_msgSend)(object,sel); } @catch (__unused NSException *e) { return nil; }
}
static id UYTTField(id object, NSString *name) {
    @try { return [object valueForKey:name]; } @catch (__unused NSException *e) { return nil; }
}
@interface UYTSponsorTimelineView : UIView
@property(nonatomic,copy) NSArray *ranges;
@property(nonatomic,weak) id player;
@property(nonatomic,copy) NSArray *segments;
@property(nonatomic) double duration;
@property(nonatomic) BOOL announced;
@end
@implementation UYTSponsorTimelineView
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self=[super initWithFrame:frame])) {
        self.userInteractionEnabled=NO; self.accessibilityElementsHidden=YES;
        self.opaque=NO; self.backgroundColor=UIColor.clearColor; self.clipsToBounds=YES;
    }
    return self;
}
- (void)drawRect:(CGRect)rect {
    [[UIColor colorWithRed:0 green:0.86 blue:0.34 alpha:1] setFill];
    CGFloat width=self.bounds.size.width, height=self.bounds.size.height;
    for (NSArray *range in self.ranges) {
        CGFloat start=[range[0] doubleValue]*width, end=[range[1] doubleValue]*width;
        UIRectFill(CGRectMake(start,0,MAX(end-start,1),height));
    }
}
@end
static char UYTTimelineKey;
static UYTSponsorTimelineView *UYTTimeline(UIView *bar, BOOL create) {
    UYTSponsorTimelineView *view=objc_getAssociatedObject(bar,&UYTTimelineKey);
    if (!view && create) {
        view=[[UYTSponsorTimelineView alloc] initWithFrame:CGRectZero];
        objc_setAssociatedObject(bar,&UYTTimelineKey,view,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [bar addSubview:view];
    }
    return view;
}
static void UYTTApply(UYTSponsorTimelineView *view, NSArray *segments, double duration, CGRect frame) {
    NSArray *ranges=UYTSponsorEnabled()?UYTSponsorMarkerRanges(segments,duration):@[];
    if (![view.ranges isEqual:ranges]) { view.ranges=ranges; [view setNeedsDisplay]; }
    if (!CGRectEqualToRect(view.frame,frame)) { view.frame=frame; [view setNeedsDisplay]; }
    view.hidden=!ranges.count || CGRectIsEmpty(frame);
    if (!view.hidden && !view.announced) {
        view.announced=YES;
        NSLog(@"[UYTNative] SponsorBlock timeline attached bar=%@ segments=%lu",NSStringFromClass(view.superview.class),(unsigned long)ranges.count);
    }
}
static BOOL UYTTIsView(id value) { return [value isKindOfClass:UIView.class]; }
static void UYTTCollectTracks(UIView *view, UIView *bar, NSMutableArray *tracks, NSInteger depth) {
    if (depth>3) return;
    for (UIView *child in view.subviews) {
        if ([child isKindOfClass:UYTSponsorTimelineView.class]) continue;
        NSString *name=NSStringFromClass(child.class);
        CGRect rect=[child convertRect:child.bounds toView:bar];
        if (([name containsString:@"RectangleDecoration"] || [name containsString:@"ProgressDecoration"]) &&
            rect.size.width>0 && rect.size.height>0 && rect.size.height<=16) [tracks addObject:child];
        else UYTTCollectTracks(child,bar,tracks,depth+1);
    }
}
void UYTLayoutSponsorTimeline(UIView *bar) {
    UYTSponsorTimelineView *view=UYTTimeline(bar,NO); if (!view) return;
    NSMutableArray *tracks=[NSMutableArray array];
    id oldTracks=UYTTField(bar,@"_segmentViews");
    if ([oldTracks isKindOfClass:NSArray.class]) for (id track in oldTracks) if (UYTTIsView(track) && [track isDescendantOfView:bar]) [tracks addObject:track];
    UYTTCollectTracks(bar,bar,tracks,0);
    // Legacy YouTube used a plain UIView for its progress and buffer tracks.
    for (NSString *key in @[@"_progressBar",@"_bufferedProgressBar",@"_quietProgressBar"]) {
        id track=UYTTField(bar,key);
        if (UYTTIsView(track) && [track isDescendantOfView:bar]) [tracks addObject:track];
    }
    CGRect frame=CGRectNull;
    UIView *reference=nil;
    for (UIView *track in tracks) {
        CGRect rect=[track convertRect:track.bounds toView:bar];
        if (rect.size.width<=0 || rect.size.height<=0 || rect.size.height>16) continue;
        frame=CGRectIsNull(frame)?rect:CGRectUnion(frame,rect); reference=track;
    }
    if (CGRectIsNull(frame) || frame.size.height>16) { view.hidden=YES; return; }
    // Keep markers above the played/buffered fill and below the draggable dot.
    UIView *topTrack=reference;
    while (topTrack.superview && topTrack.superview!=bar) topTrack=topTrack.superview;
    if (topTrack.superview==bar && [bar.subviews indexOfObjectIdenticalTo:view]<=[bar.subviews indexOfObjectIdenticalTo:topTrack]) [bar insertSubview:view aboveSubview:topTrack];
    for (UIView *child in bar.subviews) {
        if ([NSStringFromClass(child.class) containsString:@"Scrubber"] && [bar.subviews indexOfObjectIdenticalTo:child]<[bar.subviews indexOfObjectIdenticalTo:view]) [bar bringSubviewToFront:child];
    }
    id dot=UYTTField(bar,@"_scrubberCircle");
    if (UYTTIsView(dot)) {
        UIView *topDot=dot;
        while (topDot.superview && topDot.superview!=bar) topDot=topDot.superview;
        if (topDot.superview==bar && [bar.subviews indexOfObjectIdenticalTo:topDot]<[bar.subviews indexOfObjectIdenticalTo:view]) [bar bringSubviewToFront:topDot];
    }
    UYTTApply(view,view.segments,view.duration,frame);
}
void UYTRefreshSponsorTimeline(id player, NSArray *segments) {
    id overlay=UYTTRead(UYTTRead(player,@"view"),@"overlayView");
    if (!overlay) overlay=UYTTRead(UYTTRead(player,@"activeVideoPlayerOverlay"),@"videoPlayerOverlayView");
    id container=UYTTRead(overlay,@"playerBar");
    id bar=UYTTRead(container,@"modularPlayerBar");
    if (bar && !UYTTIsView(bar)) bar=UYTTRead(bar,@"view");
    if (!UYTTIsView(bar)) bar=UYTTRead(container,@"segmentablePlayerBar");
    if (!UYTTIsView(bar)) bar=UYTTRead(container,@"playerBar");
    if (!UYTTIsView(bar)) return;
    UYTSponsorTimelineView *view=UYTTimeline(bar,YES);
    if (view.player!=player) { view.player=player; view.announced=NO; }
    double duration=0;
    if ([player respondsToSelector:NSSelectorFromString(@"currentVideoTotalMediaTime")])
        duration=((double(*)(id,SEL))objc_msgSend)(player,NSSelectorFromString(@"currentVideoTotalMediaTime"));
    BOOL ad=[player respondsToSelector:NSSelectorFromString(@"isPlayingAd")] && ((BOOL(*)(id,SEL))objc_msgSend)(player,NSSelectorFromString(@"isPlayingAd"));
    view.segments=ad?@[]:segments; view.duration=duration;
    UYTLayoutSponsorTimeline(bar);
}
static void UYTTOfflineWalk(UIView *view, NSArray *segments, double duration, NSInteger depth, NSInteger *budget) {
    if (depth>12 || (*budget)--<=0) return;
    NSString *name=NSStringFromClass(view.class);
    // Match only AVKit's time scrubber, never the volume slider.
    if ([view isKindOfClass:UISlider.class] && ([name containsString:@"AVScrubber"] || [name containsString:@"PlaybackControlsTimeSlider"])) {
        UISlider *slider=(UISlider *)view;
        CGRect frame=[slider trackRectForBounds:slider.bounds];
        UYTTApply(UYTTimeline(view,YES),segments,duration,frame);
        return;
    }
    for (UIView *child in view.subviews) if (![child isKindOfClass:UYTSponsorTimelineView.class]) UYTTOfflineWalk(child,segments,duration,depth+1,budget);
}
void UYTRefreshOfflineTimeline(UIView *root, NSArray *segments, double duration) {
    NSInteger budget=300; UYTTOfflineWalk(root,segments,duration,0,&budget);
}
