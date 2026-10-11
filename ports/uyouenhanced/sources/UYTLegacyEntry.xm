#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "UYTCompatibility.h"
#import "UYTOffline.h"
#import "UYTDirectFormats.h"

// NSLog from this old runtime is not reliably forwarded over USB. Keep a small
// cache-only diagnostic with versions, UI mounting and error codes, never URLs
// with account data, request bodies, cookies or credentials.
static void UYTLegacyRecord(NSDictionary *values) {
    dispatch_async(dispatch_get_main_queue(), ^{
        static NSMutableDictionary *state;
        if (!state) state=[NSMutableDictionary new];
        [state addEntriesFromDictionary:values];
        NSString *directory=[NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES) firstObject];
        if (!directory) return;
        [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
        NSData *data=[NSJSONSerialization dataWithJSONObject:state options:NSJSONWritingPrettyPrinted error:nil];
        [data writeToFile:[directory stringByAppendingPathComponent:@"UYTLegacyRuntime.json"] options:NSDataWritingAtomic error:nil];
    });
}

// The native iOS 12 binary remains 16.42.3. The server rejects that client
// version; 20.10.3 was verified to accept the same anonymous browse request.
%hook YTVersionUtils
+ (NSString *)appVersion {
    NSString *version=%orig;
    return [version compare:@"20.10.3" options:NSNumericSearch]==NSOrderedAscending ? @"20.10.3" : version;
}
%end

static void UYTLegacyNetworkProbe(void) {
    static BOOL started=NO;
    if (started || UIApplication.sharedApplication.applicationState!=UIApplicationStateActive) return;
    started=YES;
    NSURLSessionConfiguration *config=NSURLSessionConfiguration.ephemeralSessionConfiguration;
    config.HTTPCookieStorage=nil; config.URLCredentialStorage=nil;
    config.timeoutIntervalForRequest=15;
    NSURLSession *session=[NSURLSession sessionWithConfiguration:config];
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://www.youtube.com/"]];
    request.HTTPMethod=@"HEAD";
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
        NSInteger status=[response isKindOfClass:NSHTTPURLResponse.class]?((NSHTTPURLResponse *)response).statusCode:0;
        NSLog(@"[UYTLegacy] Network probe HTTP=%ld error=%@/%ld",(long)status,error.domain?:@"none",(long)error.code);
        UYTLegacyRecord(@{@"networkHTTP":@(status),@"networkErrorDomain":error.domain?:@"none",@"networkErrorCode":@(error.code)});
        [session finishTasksAndInvalidate];
    }] resume];
}

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
    UYTLegacyRecord(@{@"keyWindow":window?NSStringFromClass(window.class):@"none"});
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
    NSLog(@"[UYTLegacy] Saved launcher mounted");
    UYTLegacyRecord(@{@"savedLauncherMounted":@YES});
}
%hook YTElementsDefaultSheetController
+ (void)showSheetController:(id)controller showCommand:(id)command commandContext:(id)context handler:(id)handler {
    if (UYTHandleDownloadSheet(controller,command,context)) return;
    %orig;
}
%end
%ctor {
    %init;
    NSLog(@"[UYTLegacy] Loaded native=%@ server-version=20.10.3",[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]);
    UYTLegacyRecord(@{@"nativeVersion":[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]?:@"unknown",@"serverVersion":@"20.10.3",@"versionClassPresent":@(NSClassFromString(@"YTVersionUtils")!=Nil)});
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){ UYTMountLegacyLauncher(); UYTLegacyNetworkProbe(); }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(), ^{ UYTMountLegacyLauncher(); UYTLegacyNetworkProbe(); });
}
