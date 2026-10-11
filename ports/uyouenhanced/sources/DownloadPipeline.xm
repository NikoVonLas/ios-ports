// Recover legacy download formats from the currently playing video's own data.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "UYTOffline.h"

static id UYTRead(id object, NSString *name) {
    SEL sel = NSSelectorFromString(name);
    if (![object respondsToSelector:sel]) return nil;
    @try { return ((id (*)(id, SEL))objc_msgSend)(object, sel); }
    @catch (__unused NSException *e) { return nil; }
}
static BOOL UYTFlag(id object, NSString *name) {
    SEL sel = NSSelectorFromString(name);
    if (![object respondsToSelector:sel]) return NO;
    @try { return ((BOOL (*)(id, SEL))objc_msgSend)(object, sel); }
    @catch (__unused NSException *e) { return NO; }
}
static NSArray *UYTArray(id object) { return [object isKindOfClass:NSArray.class] ? object : @[]; }
static BOOL UYTHasURL(id format) {
    id value = UYTRead(format, @"URL");
    NSURL *url = [value isKindOfClass:NSURL.class] ? value :
        ([value isKindOfClass:NSString.class] ? [NSURL URLWithString:value] : nil);
    return [@[@"https", @"http"] containsObject:url.scheme.lowercaseString ?: @""];
}
static id UYTVideo(id item) { return UYTRead(item, @"video"); }
static NSString *UYTVideoID(id item) {
    id value = UYTRead(UYTRead(UYTVideo(item), @"videoDetails"), @"videoId");
    return [value isKindOfClass:NSString.class] ? value : nil;
}

@interface UYTPlayerItemAdapter : NSObject
@property(nonatomic, strong) id original;
@property(nonatomic, strong) NSArray *selectableAudioFormats;
@property(nonatomic, strong) NSArray *selectableVideoFormats;
- (id)video;
@end
@implementation UYTPlayerItemAdapter
- (id)video { return UYTVideo(self.original); }
- (id)forwardingTargetForSelector:(SEL)sel {
    return [self.original respondsToSelector:sel] ? self.original : [super forwardingTargetForSelector:sel];
}
@end

static __weak id UYTLatestPlayerItem;
%hook YTSingleVideoController
- (void)setPlayerItem:(id)item {
    UYTLatestPlayerItem = item;
    %orig;
}
%end

@interface DownloadsManager : NSObject
- (UIViewController *)topViewController;
- (void)dismissHUD;
@end

%hook DownloadsManager
- (void)getLinksLocallyPlayerItem:(id)item videoID:(id)videoID sourceView:(id)sourceView isShorts:(BOOL)isShorts {
    NSString *requestedID = [videoID isKindOfClass:NSString.class] ? videoID : nil;
    id selected = item;
    id captured = UYTLatestPlayerItem;
    // Never substitute the streams of a different video.
    if ((!selected || !UYTVideo(selected)) && requestedID.length &&
        [UYTVideoID(captured) isEqualToString:requestedID]) selected = captured;
    NSArray *nativeAudio = UYTArray(UYTRead(selected, @"selectableAudioFormats"));
    NSArray *nativeVideo = UYTArray(UYTRead(selected, @"selectableVideoFormats"));
    NSMutableArray *audio = [NSMutableArray array], *video = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    void (^add)(id, NSInteger) = ^(id format, NSInteger kind) {
        if (!format || !UYTHasURL(format)) return;
        NSString *identity = [NSString stringWithFormat:@"%@:%ld", UYTRead(format, @"URL"), (long)kind];
        if ([seen containsObject:identity]) return;
        [seen addObject:identity];
        if (kind == 1) [audio addObject:format];
        if (kind == 2) [video addObject:format];
    };
    for (id f in nativeAudio) add(f, 1);
    for (id f in nativeVideo) add(f, 2);
    if (audio.count && video.count) {
        %orig(selected, videoID, sourceView, isShorts);
        return;
    }
    id streaming = UYTRead(UYTVideo(selected), @"streamingData");
    NSArray *adaptive = UYTArray(UYTRead(streaming, @"adaptiveStreams"));
    for (id f in adaptive) {
        if (UYTFlag(f, @"isAudio")) add(f, 1);
        if (UYTFlag(f, @"isVideo")) add(f, 2);
    }
    NSArray *raw = UYTArray(UYTRead(UYTRead(streaming, @"streamingData"), @"adaptiveFormatsArray"));
    Class cls = NSClassFromString(@"MLFormat");
    SEL initializer = NSSelectorFromString(@"initWithFormatStream:");
    if ([cls instancesRespondToSelector:initializer]) {
        for (id entry in raw) {
            @try {
                id allocated = [cls alloc];
                id f = ((id (*)(id, SEL, id))objc_msgSend)(allocated, initializer, entry);
                if (UYTFlag(f, @"isAudio")) add(f, 1);
                if (UYTFlag(f, @"isVideo")) add(f, 2);
            } @catch (__unused NSException *e) {}
        }
    }
    NSString *diagnostic = [NSString stringWithFormat:@"%@; A%lu V%lu S%lu R%lu -> A%lu V%lu",
        NSStringFromClass([selected class]) ?: @"нет плеера", (unsigned long)nativeAudio.count,
        (unsigned long)nativeVideo.count, (unsigned long)adaptive.count, (unsigned long)raw.count,
        (unsigned long)audio.count, (unsigned long)video.count];
    NSLog(@"[UYTNative] %@", diagnostic);
    if (audio.count && video.count) {
        UYTPlayerItemAdapter *adapter = [UYTPlayerItemAdapter new];
        adapter.original = selected;
        adapter.selectableAudioFormats = audio;
        adapter.selectableVideoFormats = video;
        %orig(adapter, videoID, sourceView, isShorts);
        return;
    }
    id hlsValue = UYTRead(UYTRead(streaming, @"streamingData"), @"hlsManifestURL");
    NSURL *hls = [hlsValue isKindOfClass:NSString.class] ? [NSURL URLWithString:hlsValue] : nil;
    NSString *title = UYTRead(UYTRead(UYTVideo(selected), @"videoDetails"), @"title");
    dispatch_async(dispatch_get_main_queue(), ^{
        [self dismissHUD];
        if (UYTOfferOffline(hls, requestedID, title, [self topViewController])) return;
        UIViewController *vc = [self topViewController];
        while (vc.presentedViewController) vc = vc.presentedViewController;
        if (!vc || [vc isKindOfClass:UIAlertController.class]) return;
        NSString *message = [NSString stringWithFormat:@"YouTube не передал загрузчику прямые аудио- и видеопотоки. Откройте ролик, запустите воспроизведение и повторите.\n\nДиагностика: %@", diagnostic];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"uYou: потоки недоступны"
            message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [vc presentViewController:alert animated:YES completion:nil];
    });
}
%end

%hook DownloadsPagerVC
- (void)viewDidLoad {
    %orig;
    UYTInstallOfflineButton((UIViewController *)self);
}
- (void)viewDidLayoutSubviews {
    %orig;
    UIView *library = [((UIViewController *)self).view viewWithTag:947231];
    if (library) [((UIViewController *)self).view bringSubviewToFront:library];
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    UYTInstallOfflineButton((UIViewController *)self);
}
%end
