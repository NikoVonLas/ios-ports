#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <YouTubeHeader/YTMainAppControlsOverlayView.h>
#import <YouTubeHeader/YTModularPlayerBarView.h>
#import <YouTubeHeader/YTSegmentableInlinePlayerBarView.h>
#import <YouTubeHeader/YTInlinePlayerBarView.h>
#import "UYTOffline.h"
#import "UYTDirectFormats.h"
#import "UYTSponsorTimeline.h"

static id UYTPCRead(id object, NSString *key) {
    @try { return [object valueForKey:key]; } @catch (__unused NSException *e) { return nil; }
}
static UIImage *UYTDownloadIcon(void) {
    static UIImage *image; static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(24,24)];
        image=[[renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
            [UIColor.whiteColor setStroke];
            UIBezierPath *p=[UIBezierPath bezierPath]; p.lineWidth=2; p.lineCapStyle=kCGLineCapRound; p.lineJoinStyle=kCGLineJoinRound;
            [p moveToPoint:CGPointMake(12,3)]; [p addLineToPoint:CGPointMake(12,15)];
            [p moveToPoint:CGPointMake(7,10)]; [p addLineToPoint:CGPointMake(12,15)]; [p addLineToPoint:CGPointMake(17,10)];
            [p moveToPoint:CGPointMake(4,16)]; [p addLineToPoint:CGPointMake(4,21)]; [p addLineToPoint:CGPointMake(20,21)]; [p addLineToPoint:CGPointMake(20,16)]; [p stroke];
        }] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    });
    return image;
}
static id UYTPCPlayer(UIView *controls) {
    id player=UYTPCRead(controls,@"playerViewController");
    if ([player respondsToSelector:NSSelectorFromString(@"currentVideoID")]) return player;
    UIResponder *responder=controls;
    for (NSInteger depth=0; responder && depth<15; depth++,responder=responder.nextResponder)
        if ([responder respondsToSelector:NSSelectorFromString(@"currentVideoID")]) return responder;
    return nil;
}
@interface UYTPlayerDownloadAction : NSObject
@property(nonatomic,weak) UIView *controls;
- (void)download;
@end
@implementation UYTPlayerDownloadAction
- (void)download {
    id player=UYTPCPlayer(self.controls);
    NSString *videoID=UYTPCRead(player,@"currentVideoID");
    if (!UYTValidVideoID(videoID)) return;
    UIViewController *presenter=[player isKindOfClass:UIViewController.class]?player:nil;
    while (presenter.presentedViewController && !presenter.presentedViewController.isBeingDismissed) presenter=presenter.presentedViewController;
    if (!presenter || [presenter isKindOfClass:UIAlertController.class]) return;
    NSLog(@"[UYTNative] Player download tapped target=%@",videoID);
    UYTDownloadFromMenu(videoID,presenter);
}
@end
static char UYTPCButtonKey, UYTPCActionKey, UYTPCPlacementKey;
static UIView *UYTPCButton(YTMainAppControlsOverlayView *controls) {
    UIView *button=objc_getAssociatedObject(controls,&UYTPCButtonKey);
    if (button) return button;
    id old=UYTPCRead(controls,@"uYouButton");
    if ([old isKindOfClass:UIControl.class] && [old respondsToSelector:@selector(setImage:forState:)]) button=old;
    if (!button && [controls respondsToSelector:@selector(buttonWithImage:accessibilityLabel:verticalContentPadding:)]) {
        CGFloat padding=0;
        if ([controls.class respondsToSelector:@selector(topButtonAdditionalPadding)]) padding=[controls.class topButtonAdditionalPadding];
        button=[controls buttonWithImage:UYTDownloadIcon() accessibilityLabel:@"Скачать видео" verticalContentPadding:padding];
        id container=UYTPCRead(controls,@"_topControlsAccessibilityContainerView");
        [( [container isKindOfClass:UIView.class] ? container : controls) addSubview:button];
    }
    if (![button isKindOfClass:UIControl.class] || ![button respondsToSelector:@selector(setImage:forState:)]) return nil;
    [(UIButton *)button setImage:UYTDownloadIcon() forState:UIControlStateNormal];
    button.tintColor=UIColor.whiteColor;
    if ([button respondsToSelector:@selector(setCustomTintColor:)]) [(YTQTMButton *)button setCustomTintColor:UIColor.whiteColor];
    button.accessibilityLabel=@"Скачать видео"; button.accessibilityIdentifier=@"UYT.player.download";
    UYTPlayerDownloadAction *action=[UYTPlayerDownloadAction new]; action.controls=controls;
    [(UIControl *)button removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [(UIControl *)button addTarget:action action:@selector(download) forControlEvents:UIControlEventTouchUpInside];
    objc_setAssociatedObject(controls,&UYTPCActionKey,action,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(controls,&UYTPCButtonKey,button,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    for (NSString *key in @[@"decreasePlaybackRateButtonView",@"increasePlaybackRateButtonView",@"resetPlaybackRateButtonView"]) {
        UIView *speed=UYTPCRead(controls,key);
        if ([speed isKindOfClass:UIView.class]) speed.accessibilityLabel=[key hasPrefix:@"decrease"]?@"Уменьшить скорость":[key hasPrefix:@"increase"]?@"Увеличить скорость":@"Обычная скорость";
    }
    return button;
}
static NSString *UYTPCSemantic(UIView *button) {
    NSMutableString *text=[NSMutableString stringWithFormat:@"%@ %@",button.accessibilityIdentifier?:@"",button.accessibilityLabel?:@""];
    if ([button isKindOfClass:UIControl.class]) {
        UIControl *control=(UIControl *)button;
        for (id target in control.allTargets) for (NSString *action in [control actionsForTarget:target forControlEvent:UIControlEventTouchUpInside]) [text appendFormat:@" %@",action];
    }
    return text.lowercaseString;
}
static NSString *UYTPCPlacement(NSMutableArray *buttons, UIView *download) {
    NSUInteger oldIndex=[buttons indexOfObjectIdenticalTo:download];
    [buttons removeObjectIdenticalTo:download];
    NSUInteger captions=NSNotFound, settings=NSNotFound;
    for (NSUInteger i=0;i<buttons.count;i++) {
        id button=buttons[i]; if (![button isKindOfClass:UIView.class]) continue;
        NSString *text=UYTPCSemantic(button);
        if ([text containsString:@"caption"] || [text containsString:@"subtitle"] || [text containsString:@"субтитр"]) captions=i;
        if ([text containsString:@"overflow"] || [text containsString:@"settings"] || [text containsString:@"настройк"]) settings=i;
    }
    NSUInteger index;
    NSString *placement;
    if (captions!=NSNotFound && settings!=NSNotFound && captions!=settings) { index=MIN(captions,settings)+1; placement=@"between-captions-settings"; }
    else if (settings!=NSNotFound) { index=settings+1; placement=@"next-to-settings"; }
    else { index=oldIndex==NSNotFound?0:MIN(oldIndex,buttons.count); placement=@"native-slot"; }
    [buttons insertObject:download atIndex:MIN(index,buttons.count)];
    return placement;
}
%hook YTMainAppControlsOverlayView
- (NSMutableArray *)topControls {
    id originalControls=%orig;
    NSMutableArray *buttons=[originalControls mutableCopy];
    if (!buttons) return buttons;
    UIView *download=UYTPCButton(self); if (!download) return buttons;
    // A newer uYou hook may recreate its original button after initialization.
    id original=UYTPCRead(self,@"uYouButton");
    if ([original isKindOfClass:UIView.class] && original!=download) { [buttons removeObjectIdenticalTo:original]; [original setHidden:YES]; }
    NSString *placement=UYTPCPlacement(buttons,download);
    if (![objc_getAssociatedObject(self,&UYTPCPlacementKey) isEqual:placement]) {
        objc_setAssociatedObject(self,&UYTPCPlacementKey,placement,OBJC_ASSOCIATION_COPY_NONATOMIC);
        NSLog(@"[UYTNative] Player download placement=%@ controls=%lu",placement,(unsigned long)buttons.count);
    }
    return buttons;
}
- (void)setTopOverlayVisible:(BOOL)visible isAutonavCanceledState:(BOOL)canceled {
    %orig;
    UIView *button=objc_getAssociatedObject(self,&UYTPCButtonKey);
    button.alpha=visible && !canceled?1:0;
}
%end
%hook YTModularPlayerBarView
- (void)layoutSubviews {
    %orig;
    UYTLayoutSponsorTimeline(self);
}
%end
%hook YTSegmentableInlinePlayerBarView
- (void)layoutSubviews {
    %orig;
    UYTLayoutSponsorTimeline(self);
}
%end
%hook YTInlinePlayerBarView
- (void)layoutSubviews {
    %orig;
    UYTLayoutSponsorTimeline(self);
}
%end
