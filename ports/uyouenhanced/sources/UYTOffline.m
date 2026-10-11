#import "UYTOffline.h"
#import "UYTDirectFormats.h"
#import "UYTCompatibility.h"
#import "UYTSponsor.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

static NSString *const UYTOfflineChanged = @"UYTOfflineChanged";
static UIColor *UYTLibraryBackground(void) { return [UIColor colorWithWhite:15.0/255.0 alpha:1]; }
static UIColor *UYTLibrarySurface(void) { return [UIColor colorWithWhite:39.0/255.0 alpha:1]; }
static UIColor *UYTLibrarySecondaryText(void) { return [UIColor colorWithWhite:170.0/255.0 alpha:1]; }
static UIColor *UYTLibraryAccent(void) { return [UIColor colorWithRed:1 green:0 blue:0.2 alpha:1]; }
@interface UYTOfflineStore : NSObject <AVAssetDownloadDelegate>
@property(nonatomic,strong) NSMutableArray<NSMutableDictionary *> *items;
@property(nonatomic,strong) AVAssetDownloadURLSession *session;
@property(nonatomic,strong) NSMutableDictionary<NSString *,id> *tasks;
@property(nonatomic,strong) NSURLSession *directSession;
@property(nonatomic,strong) NSMutableDictionary<NSString *,AVAssetExportSession *> *exports;
@property(nonatomic,strong) NSMutableDictionary<NSString *,NSNumber *> *preparationBackgroundTasks;
@property(nonatomic,strong) id preparationObserver;
@property(nonatomic) BOOL preparationSavedIdleTimer;
@property(nonatomic) BOOL preparationOwnsIdleTimer;
+ (instancetype)shared;
- (NSString *)indexPath;
- (void)save;
- (void)startURL:(NSURL *)url videoID:(NSString *)videoID title:(NSString *)title height:(int)height;
- (NSURL *)localURL:(NSDictionary *)item;
@end
@interface UYTOfflineStore (Direct) <NSURLSessionDownloadDelegate>
- (void)setupDirectSession;
- (void)startDirect:(NSDictionary *)formats video:(NSDictionary *)video;
- (void)mergeDirect:(NSMutableDictionary *)item;
- (void)directTask:(NSURLSessionTask *)task completed:(NSError *)error;
- (void)directFailed:(NSMutableDictionary *)item message:(NSString *)message;
- (NSString *)directDirectory:(NSString *)identifier;
- (NSMutableDictionary *)directItem:(NSString *)identifier;
- (BOOL)canPrepareItem:(NSDictionary *)item;
- (void)finishPreparation:(NSString *)identifier;
@end
@interface UYTOfflineVC : UIViewController <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UITextFieldDelegate>
@property(nonatomic,strong) UICollectionView *grid;
@property(nonatomic,strong) UITextField *search;
@property(nonatomic,strong) NSArray<UIButton *> *filterButtons;
@property(nonatomic) NSInteger selectedFilter;
@property(nonatomic,strong) UILabel *summaryLabel;
@property(nonatomic,strong) NSArray<NSDictionary *> *visibleItems;
@property(nonatomic,strong) NSMutableSet *coverRequests;
@property(nonatomic,strong) NSMutableSet *durationRequests;
@property(nonatomic,strong) NSCache *coverCache;
@property(nonatomic) BOOL sortByTitle;
@property(nonatomic) BOOL modalLibrary;
@property(nonatomic) CGFloat lastWidth;
- (void)refresh;
- (void)showOptions;
@end

@implementation UYTOfflineStore
+ (instancetype)shared {
    static UYTOfflineStore *store; static dispatch_once_t once;
    dispatch_once(&once, ^{ store = [UYTOfflineStore new]; }); return store;
}
- (NSString *)indexPath {
    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"UYTOffline"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return [dir stringByAppendingPathComponent:@"index.plist"];
}
- (instancetype)init {
    if ((self = [super init])) {
        _items = [NSMutableArray array]; _tasks = [NSMutableDictionary dictionary];
        for (NSDictionary *entry in [NSArray arrayWithContentsOfFile:[self indexPath]])
            if ([entry isKindOfClass:NSDictionary.class] && [entry[@"id"] isKindOfClass:NSString.class]) {
                [_items addObject:[entry mutableCopy]];
                NSLog(@"[UYTNative] Library item target=%@ state=%@ kind=%@ height=%@ error=%@",entry[@"videoID"],entry[@"state"],entry[@"kind"],entry[@"height"],entry[@"error"]);
            }
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"com.nikovonlas.uyt.offline.hls.v1"];
        config.discretionary = NO; config.allowsCellularAccess = YES;
        _session = [AVAssetDownloadURLSession sessionWithConfiguration:config assetDownloadDelegate:self delegateQueue:NSOperationQueue.mainQueue];
        [_session getAllTasksWithCompletionHandler:^(NSArray<__kindof NSURLSessionTask *> *tasks) {
            dispatch_async(dispatch_get_main_queue(), ^{
                for (NSURLSessionTask *task in tasks) if (task.taskDescription.length) self.tasks[task.taskDescription] = task;
                for (NSMutableDictionary *item in self.items) {
                    if (![item[@"kind"] isEqual:@"direct"] && ([item[@"state"] isEqual:@"loading"] || [item[@"state"] isEqual:@"paused"]) && !self.tasks[item[@"id"]]) {
                        item[@"state"] = @"failed"; item[@"error"] = @"Загрузка прервана. Откройте ролик и скачайте заново.";
                    }
                }
                [self save];
            });
        }];
        [self setupDirectSession];
    } return self;
}
- (NSMutableDictionary *)itemForTask:(NSURLSessionTask *)task {
    for (NSMutableDictionary *item in self.items) if ([item[@"id"] isEqual:task.taskDescription]) return item;
    return nil;
}
- (void)save {
    [self.items writeToFile:[self indexPath] atomically:YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:UYTOfflineChanged object:nil];
}
- (NSURL *)localURL:(NSDictionary *)item {
    NSString *relative = item[@"location"];
    if (![relative isKindOfClass:NSString.class] || !relative.length || [relative hasPrefix:@"/"] || [relative.pathComponents containsObject:@".."]) return nil;
    return [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:relative]];
}
- (void)startURL:(NSURL *)url videoID:(NSString *)videoID title:(NSString *)title height:(int)height {
    NSString *identifier = NSUUID.UUID.UUIDString;
    UYTFetchSponsorSegments(videoID, ^(NSArray *segments) {});
    NSMutableDictionary *item = [@{@"id":identifier, @"videoID":videoID ?: @"", @"title":title ?: @"Видео", @"state":@"loading", @"progress":@0, @"height":@(height)} mutableCopy];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    NSMutableDictionary *options = [NSMutableDictionary dictionary];
    if (@available(iOS 14.0, *)) {
        options[AVAssetDownloadTaskMinimumRequiredPresentationSizeKey] = [NSValue valueWithCGSize:CGSizeMake(height * 16.0/9.0, height)]; options[AVAssetDownloadTaskPrefersHDRKey] = @NO;
    } else {
        options[AVAssetDownloadTaskMinimumRequiredMediaBitrateKey] = @(height >= 1080 ? 4000000 : height >= 720 ? 2000000 : 500000);
    }
    AVAssetDownloadTask *task = [self.session assetDownloadTaskWithURLAsset:asset assetTitle:item[@"title"] assetArtworkData:nil options:options];
    if (task) { task.taskDescription = identifier; self.tasks[identifier] = task; }
    else { item[@"state"] = @"failed"; item[@"error"] = @"Не удалось создать загрузку."; }
    [self.items insertObject:item atIndex:0]; [self save];
    NSLog(@"[UYTNative] HLS task created=%d targetHeight=%d", task != nil, height);
    [task resume];
}
- (void)URLSession:(NSURLSession *)session assetDownloadTask:(AVAssetDownloadTask *)task didLoadTimeRange:(CMTimeRange)range totalTimeRangesLoaded:(NSArray<NSValue *> *)ranges timeRangeExpectedToLoad:(CMTimeRange)expected {
    double duration = CMTimeGetSeconds(expected.duration), loaded = 0;
    for (NSValue *value in ranges) loaded += CMTimeGetSeconds(value.CMTimeRangeValue.duration);
    NSMutableDictionary *item = [self itemForTask:task];
    if (duration > 0 && isfinite(duration) && isfinite(loaded)) item[@"progress"] = @(MIN(0.99,MAX(0,loaded/duration)));
    [[NSNotificationCenter defaultCenter] postNotificationName:UYTOfflineChanged object:nil];
}
- (void)URLSession:(NSURLSession *)session assetDownloadTask:(AVAssetDownloadTask *)task didFinishDownloadingToURL:(NSURL *)location {
    NSMutableDictionary *item = [self itemForTask:task];
    NSString *prefix = [NSHomeDirectory().stringByResolvingSymlinksInPath stringByAppendingString:@"/"];
    NSString *path = location.path.stringByResolvingSymlinksInPath;
    if ([path hasPrefix:prefix]) item[@"location"] = [path substringFromIndex:prefix.length];
    [self save];
    NSLog(@"[UYTNative] HLS received local asset=%d", item[@"location"] != nil);
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (session == self.directSession) { [self directTask:task completed:error]; return; }
    NSMutableDictionary *item = [self itemForTask:task]; if (!item) return;
    [self.tasks removeObjectForKey:task.taskDescription];
    NSURL *location = [self localURL:item];
    BOOL exists = location && [[NSFileManager defaultManager] fileExistsAtPath:location.path];
    BOOL offline = exists && [AVURLAsset URLAssetWithURL:location options:nil].assetCache.playableOffline;
    if (!error && offline) { item[@"state"] = @"ready"; item[@"progress"] = @1; }
    else {
        item[@"state"] = @"failed";
        item[@"error"] = error ? [NSString stringWithFormat:@"Не удалось скачать (%@, %ld).", error.domain, (long)error.code] : @"Видео загружено не полностью. Повторите скачивание.";
    }
    NSLog(@"[UYTNative] HLS complete error=%@:%ld exists=%d offline=%d", error.domain, (long)error.code, exists, offline);
    [self save];
}
@end

#include "UYTDirect.inc"

static void UYTPresentLibrary(UIViewController *presenter) {
    if ([presenter isKindOfClass:UYTOfflineVC.class]) { [(UYTOfflineVC *)presenter refresh]; return; }
    while (presenter.presentedViewController && ![presenter.presentedViewController isKindOfClass:UIAlertController.class]) presenter = presenter.presentedViewController;
    if (presenter.presentedViewController) return;
    UYTOfflineVC *library = [UYTOfflineVC new]; library.modalLibrary = YES;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:library];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [presenter presentViewController:nav animated:YES completion:nil];
}
#include "UYTLibraryActions.inc"
#import "UYTSponsorTimeline.h"
#include "UYTOfflinePlayer.inc"
#include "UYTLibraryUI.inc"
#include "UYTMenuRequest.inc"

BOOL UYTOfferOffline(NSURL *url, NSString *videoID, NSString *title, UIViewController *presenter) {
    if (![url.scheme.lowercaseString isEqual:@"https"] || !presenter) return NO;
    while (presenter.presentedViewController) presenter = presenter.presentedViewController;
    if ([presenter isKindOfClass:UIAlertController.class]) return NO;
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Скачать для офлайн-просмотра" message:[NSString stringWithFormat:@"%@\nЕсли выбранного качества нет, скачается ближайшее доступное.", title ?: @"Видео"] preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSNumber *height in @[@360,@720,@1080]) {
        NSString *label = [NSString stringWithFormat:@"%@p",height];
        [sheet addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [[UYTOfflineStore shared] startURL:url videoID:videoID title:title height:height.intValue];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 400 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ UYTPresentLibrary(presenter); });
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Открыть офлайн-видео" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 400 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ UYTPresentLibrary(presenter); }); }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = presenter.view;
    sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds), CGRectGetMaxY(presenter.view.bounds)-60,1,1);
    [presenter presentViewController:sheet animated:YES completion:nil]; return YES;
}
void UYTInstallOfflineButton(UIViewController *controller) {
    UIView *existing = [controller.view viewWithTag:947231];
    if (existing) { [controller.view bringSubviewToFront:existing]; return; }
    UYTOfflineVC *library = [UYTOfflineVC new];
    [controller addChildViewController:library];
    library.view.tag = 947231; library.view.translatesAutoresizingMaskIntoConstraints = NO;
    [controller.view addSubview:library.view];
    [NSLayoutConstraint activateConstraints:@[[library.view.topAnchor constraintEqualToAnchor:controller.view.topAnchor], [library.view.leadingAnchor constraintEqualToAnchor:controller.view.leadingAnchor], [library.view.trailingAnchor constraintEqualToAnchor:controller.view.trailingAnchor], [library.view.bottomAnchor constraintEqualToAnchor:controller.view.bottomAnchor]]];
    [library didMoveToParentViewController:controller];
    NSLog(@"[UYTNative] Russian library mounted entries=%lu",(unsigned long)[UYTOfflineStore shared].items.count);
}

void UYTOpenLibrary(UIViewController *presenter) { UYTPresentLibrary(presenter); }
