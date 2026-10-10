#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "UYTCompatibility.h"
#import "UYTOffline.h"
#import "UYTDirectFormats.h"

@interface UYTLegacyLauncher : NSObject
+ (instancetype)shared;
- (void)openLibrary;
@end
@implementation UYTLegacyLauncher
+ (instancetype)shared { static UYTLegacyLauncher *object; static dispatch_once_t once; dispatch_once(&once, ^{ object=[self new]; }); return object; }
- (void)openLibrary {
    UIViewController *presenter=UYTKeyWindow().rootViewController;
    while (presenter.presentedViewController) presenter=presenter.presentedViewController;
    if (presenter && ![presenter isKindOfClass:UIAlertController.class]) UYTOpenLibrary(presenter);
}
@end
static void UYTMountLegacyLauncher(void) {
    UIWindow *window=UYTKeyWindow();
    if (!window || [window viewWithTag:947232]) return;
    UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
    button.tag=947232; button.accessibilityLabel=@"Сохранённое: офлайн-библиотека";
    [button setTitle:@"▣ Сохранённое" forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.backgroundColor=[UIColor colorWithWhite:0.12 alpha:0.95]; button.layer.cornerRadius=18;
    button.contentEdgeInsets=UIEdgeInsetsMake(8,14,8,14);
    [button addTarget:UYTLegacyLauncher.shared action:@selector(openLibrary) forControlEvents:UIControlEventTouchUpInside];
    button.translatesAutoresizingMaskIntoConstraints=NO; [window addSubview:button];
    [NSLayoutConstraint activateConstraints:@[
        [button.trailingAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.trailingAnchor constant:-16],
        [button.bottomAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.bottomAnchor constant:-62],
        [button.heightAnchor constraintGreaterThanOrEqualToConstant:44]
    ]];
}
%hook YTElementsDefaultSheetController
+ (void)showSheetController:(id)controller showCommand:(id)command commandContext:(id)context handler:(id)handler {
    if (UYTHandleDownloadSheet(controller,command,context)) return;
    %orig;
}
%end
%ctor {
    %init;
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){ UYTMountLegacyLauncher(); }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(), ^{ UYTMountLegacyLauncher(); });
}
