#include <limits.h>
@interface UYTDirectGroup : NSObject
@property(nonatomic,strong) NSMutableArray<NSURLSessionTask *> *members;
- (void)resume;
- (void)suspend;
- (void)cancel;
@end
@implementation UYTDirectGroup
- (instancetype)init { if ((self=[super init])) _members=[NSMutableArray array]; return self; }
- (void)resume { for (NSURLSessionTask *t in self.members) [t resume]; }
- (void)suspend { for (NSURLSessionTask *t in self.members) [t suspend]; }
- (void)cancel { for (NSURLSessionTask *t in self.members) [t cancel]; }
@end

static unsigned long long UYTMediaFileSize(NSString *path) {
    return [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil][NSFileSize] unsignedLongLongValue];
}
static unsigned long long UYTPreparationFreeSpace(NSString *directory) {
    NSNumber *available=nil;
    [[NSURL fileURLWithPath:directory] getResourceValue:&available forKey:NSURLVolumeAvailableCapacityForImportantUsageKey error:nil];
    if (available) return available.unsignedLongLongValue;
    NSNumber *free=[NSFileManager.defaultManager attributesOfFileSystemForPath:directory error:nil][NSFileSystemFreeSize];
    return free?free.unsignedLongLongValue:ULLONG_MAX;
}
static NSString *UYTPreparationSpaceError(unsigned long long required,unsigned long long available) {
    return [NSString stringWithFormat:@"Не хватает места для видео. Нужно ещё %.1f ГБ, свободно %.1f ГБ. Подготовка создаёт отдельный файл с видео и звуком.",required/1e9,available/1e9];
}
static NSString *UYTMediaError(NSString *message, NSError *error) {
    if (!error) return message;
    NSMutableString *text=[NSMutableString stringWithFormat:@"%@ (%@: %ld)",message,error.domain,(long)error.code];
    NSError *underlying=error.userInfo[NSUnderlyingErrorKey];
    if (underlying) [text appendFormat:@"; %@: %ld",underlying.domain,(long)underlying.code];
    return text;
}
@implementation UYTOfflineStore (Direct)
- (NSString *)directDirectory:(NSString *)identifier {
    NSString *dir=[[self indexPath].stringByDeletingLastPathComponent stringByAppendingPathComponent:[@"Files" stringByAppendingPathComponent:identifier]];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil]; return dir;
}
- (NSMutableDictionary *)directItem:(NSString *)identifier {
    for (NSMutableDictionary *item in self.items) if ([item[@"id"] isEqual:identifier]) return item; return nil;
}
- (BOOL)canPrepareItem:(NSDictionary *)item {
    if (![item[@"kind"] isEqual:@"direct"] || ![item[@"id"] isKindOfClass:NSString.class]) return NO;
    NSString *directory=[self directDirectory:item[@"id"]];
    return UYTMediaFileSize([directory stringByAppendingPathComponent:@"audio.m4a"])>0 && UYTMediaFileSize([directory stringByAppendingPathComponent:@"video.mp4"])>0;
}
- (void)setupDirectSession {
    self.exports=[NSMutableDictionary dictionary];
    self.preparationBackgroundTasks=[NSMutableDictionary dictionary];
    __weak UYTOfflineStore *weakSelf=self;
    self.preparationObserver=[NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *notification){
        UYTOfflineStore *store=weakSelf;
        for (NSMutableDictionary *item in store.items) if ([item[@"state"] isEqual:@"waiting"] && [store canPrepareItem:item]) [store mergeDirect:item];
    }];
    NSURLSessionConfiguration *config=[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"com.nikovonlas.uyt.offline.direct.v1"]; config.discretionary=NO; config.allowsCellularAccess=YES;
    self.directSession=[NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:NSOperationQueue.mainQueue];
    [self.directSession getAllTasksWithCompletionHandler:^(NSArray<__kindof NSURLSessionTask *> *tasks){ dispatch_async(dispatch_get_main_queue(), ^{
        for (NSURLSessionTask *task in tasks) {
            NSString *identifier=[task.taskDescription componentsSeparatedByString:@":"].firstObject; if (!identifier.length) continue;
            UYTDirectGroup *group=self.tasks[identifier]; if (!group) { group=[UYTDirectGroup new]; self.tasks[identifier]=group; }
            if ([group isKindOfClass:UYTDirectGroup.class]) [group.members addObject:task];
        }
        for (NSMutableDictionary *item in self.items) if ([item[@"kind"] isEqual:@"direct"] && [@[@"loading",@"paused",@"processing",@"waiting"] containsObject:item[@"state"]]) {
            NSString *dir=[self directDirectory:item[@"id"]];
            if ([[NSFileManager defaultManager] fileExistsAtPath:[dir stringByAppendingPathComponent:@"audio.m4a"]] && [[NSFileManager defaultManager] fileExistsAtPath:[dir stringByAppendingPathComponent:@"video.mp4"]]) { item[@"state"]=@"loading"; [self mergeDirect:item]; }
            else if (!self.tasks[item[@"id"]]) { item[@"state"]=@"failed"; item[@"error"]=@"Загрузка прервана. Скачайте ролик заново через меню."; }
        }
        for (NSMutableDictionary *item in self.items) if ([item[@"kind"] isEqual:@"direct"] && [item[@"state"] isEqual:@"failed"]) {
            NSString *directory=[self directDirectory:item[@"id"]];
            NSLog(@"[UYTNative] Stored failure target=%@ height=%@ reason=%@ videoBytes=%llu audioBytes=%llu",item[@"videoID"],item[@"height"],item[@"error"],UYTMediaFileSize([directory stringByAppendingPathComponent:@"video.mp4"]),UYTMediaFileSize([directory stringByAppendingPathComponent:@"audio.m4a"]));
            // One diagnostic recovery of old generic mux failures, retaining inputs.
            if ([item[@"error"] hasPrefix:@"Не удалось подготовить видео"] && ![item[@"preparationAttemptVersion"] isEqual:@"local18"] && [self canPrepareItem:item]) {
                item[@"preparationAttemptVersion"]=@"local18";
                [self mergeDirect:item];
            }
        }
        [self save];
    }); }];
}
- (void)startDirect:(NSDictionary *)formats video:(NSDictionary *)video {
    UYTFetchSponsorSegments(formats[@"videoID"], ^(NSArray *segments) {});
    NSMutableArray *replaced=[NSMutableArray array];
    unsigned long long reclaimable=0;
    for (NSMutableDictionary *old in [self.items copy]) {
        if (![old[@"videoID"] isEqual:formats[@"videoID"]] || ![old[@"height"] isEqual:video[@"height"]]) continue;
        if ([@[@"loading",@"paused",@"processing",@"waiting",@"ready"] containsObject:old[@"state"]]) {
            NSLog(@"[UYTNative] Menu download already present target=%@ state=%@",old[@"videoID"],old[@"state"]); return;
        }
        if ([old[@"kind"] isEqual:@"direct"] && [old[@"state"] isEqual:@"failed"]) {
            [replaced addObject:old];
            NSString *directory=[self directDirectory:old[@"id"]];
            for (NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:nil]) reclaimable+=UYTMediaFileSize([directory stringByAppendingPathComponent:name]);
        }
    }
    unsigned long long videoBytes=[video[@"contentLength"] longLongValue],audioBytes=[formats[@"audio"][@"contentLength"] longLongValue];
    // Keep space for both downloaded tracks AND the final merged file.
    if (videoBytes>0 && audioBytes>0 && videoBytes<ULLONG_MAX/4 && audioBytes<ULLONG_MAX/4) {
        unsigned long long required=2*(videoBytes+audioBytes)+64*1024*1024;
        unsigned long long available=UYTPreparationFreeSpace([self indexPath].stringByDeletingLastPathComponent);
        if (available!=ULLONG_MAX && required>available && required-available>reclaimable) {
            UIViewController *presenter=UYTKeyWindow().rootViewController; while (presenter.presentedViewController) presenter=presenter.presentedViewController;
            UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Недостаточно места" message:UYTPreparationSpaceError(required,available) preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Понятно" style:UIAlertActionStyleDefault handler:nil]]; [presenter presentViewController:alert animated:YES completion:nil];
            NSLog(@"[UYTNative] Download space check target=%@ required=%llu available=%llu",formats[@"videoID"],required,available); return;
        }
    }
    for (NSMutableDictionary *old in replaced) {
        [NSFileManager.defaultManager removeItemAtPath:[self directDirectory:old[@"id"]] error:nil]; [self.items removeObject:old];
    }
    NSString *identifier=NSUUID.UUID.UUIDString;
    NSMutableDictionary *item=[@{@"id":identifier,@"kind":@"direct",@"videoID":formats[@"videoID"],@"title":formats[@"title"],@"height":video[@"height"],@"state":@"loading",@"progress":@0} mutableCopy];
    if (videoBytes>0 && videoBytes<ULLONG_MAX/4) item[@"videoExpectedBytes"]=@(videoBytes);
    if (audioBytes>0 && audioBytes<ULLONG_MAX/4) item[@"audioExpectedBytes"]=@(audioBytes);
    UYTDirectGroup *group=[UYTDirectGroup new]; self.tasks[identifier]=group;
    [self.items insertObject:item atIndex:0];
    NSDictionary *parts=@{@"audio":formats[@"audio"],@"video":video};
    for (NSString *part in @[@"audio",@"video"]) {
        NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:parts[part][@"url"]]];
        [request setValue:@"com.google.android.youtube/21.08.266 (Linux; U; Android 11) gzip" forHTTPHeaderField:@"User-Agent"];
        NSURLSessionDownloadTask *task=[self.directSession downloadTaskWithRequest:request]; task.taskDescription=[identifier stringByAppendingFormat:@":%@",part]; [group.members addObject:task];
    }
    [self save]; [group resume]; NSLog(@"[UYTNative] Menu download started target=%@ height=%@",formats[@"videoID"],video[@"height"]);
}
- (void)directFailed:(NSMutableDictionary *)item message:(NSString *)message {
    if (!item) return; [self.tasks[item[@"id"]] cancel]; [self.tasks removeObjectForKey:item[@"id"]];
    [self.exports[item[@"id"]] cancelExport]; [self.exports removeObjectForKey:item[@"id"]];
    [self finishPreparation:item[@"id"]];
    item[@"state"]=@"failed"; item[@"error"]=message; [self save];
    NSLog(@"[UYTNative] Menu download failed target=%@ reason=%@",item[@"videoID"],message);
}
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)task didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    NSArray *parts=[task.taskDescription componentsSeparatedByString:@":"]; if (parts.count!=2) return;
    NSMutableDictionary *item=[self directItem:parts[0]]; if (!item) return;
    if (totalBytesExpectedToWrite>0) item[[parts[1] stringByAppendingString:@"Progress"]]=@(MIN(1.0,(double)totalBytesWritten/totalBytesExpectedToWrite));
    item[@"progress"]=@(0.98*([item[@"audioProgress"] doubleValue]+[item[@"videoProgress"] doubleValue])/2);
    NSInteger step=(NSInteger)([item[@"progress"] doubleValue]*4);
    if (!item[@"loggedProgressStep"] || step>[item[@"loggedProgressStep"] integerValue]) {
        item[@"loggedProgressStep"]=@(step);
        NSLog(@"[UYTNative] Menu download progress target=%@ percent=%.0f",item[@"videoID"],[item[@"progress"] doubleValue]*100);
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:UYTOfflineChanged object:nil];
}
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)task didFinishDownloadingToURL:(NSURL *)location {
    NSArray *parts=[task.taskDescription componentsSeparatedByString:@":"]; if (parts.count!=2) return;
    NSMutableDictionary *item=[self directItem:parts[0]]; if (!item || [item[@"state"] isEqual:@"failed"]) return;
    NSInteger status=[(NSHTTPURLResponse *)task.response statusCode];
    if (status<200 || status>=300) { [self directFailed:item message:[NSString stringWithFormat:@"YouTube не отдал файл (HTTP %ld). Попробуйте скачать заново.",(long)status]]; return; }
    unsigned long long expected=[item[[parts[1] stringByAppendingString:@"ExpectedBytes"]] unsignedLongLongValue];
    unsigned long long received=UYTMediaFileSize(location.path);
    if (!received || (expected && expected!=received)) {
        NSLog(@"[UYTNative] Incomplete media part=%@ target=%@ expected=%llu received=%llu",parts[1],item[@"videoID"],expected,received);
        [self directFailed:item message:@"YouTube передал неполный файл. Повторите скачивание через меню ролика."]; return;
    }
    NSString *name=[parts[1] isEqual:@"audio"]?@"audio.m4a":@"video.mp4";
    NSString *destination=[[self directDirectory:parts[0]] stringByAppendingPathComponent:name];
    [[NSFileManager defaultManager] removeItemAtPath:destination error:nil]; NSError *error=nil;
    if (![[NSFileManager defaultManager] moveItemAtURL:location toURL:[NSURL fileURLWithPath:destination] error:&error]) { [self directFailed:item message:@"Не удалось сохранить файл на iPad. Проверьте свободное место."]; return; }
    item[[parts[1] stringByAppendingString:@"Progress"]]=@1; [self save];
    NSLog(@"[UYTNative] Menu received part=%@ target=%@ bytes=%lld",parts[1],item[@"videoID"],task.countOfBytesReceived);
}
- (void)directTask:(NSURLSessionTask *)task completed:(NSError *)error {
    NSString *identifier=[task.taskDescription componentsSeparatedByString:@":"].firstObject; NSMutableDictionary *item=[self directItem:identifier];
    if (!item || [item[@"state"] isEqual:@"failed"]) return;
    if (error) { [self directFailed:item message:[NSString stringWithFormat:@"Загрузка прервалась (%ld). Повторите через меню ролика.",(long)error.code]]; return; }
    UYTDirectGroup *group=self.tasks[identifier]; [group.members removeObject:task];
    NSString *dir=[self directDirectory:identifier];
    if ([[NSFileManager defaultManager] fileExistsAtPath:[dir stringByAppendingPathComponent:@"audio.m4a"]] && [[NSFileManager defaultManager] fileExistsAtPath:[dir stringByAppendingPathComponent:@"video.mp4"]]) [self mergeDirect:item];
}
- (void)mergeDirect:(NSMutableDictionary *)item {
    NSString *identifier=item[@"id"]; if (self.exports[identifier] || [item[@"state"] isEqual:@"processing"]) return;
    if (UIApplication.sharedApplication.applicationState!=UIApplicationStateActive) {
        item[@"state"]=@"waiting"; item[@"progress"]=@0.99; [self save];
        NSLog(@"[UYTNative] Preparation waiting for foreground target=%@",item[@"videoID"]); return;
    }
    item[@"state"]=@"processing"; item[@"progress"]=@0.99; [self save];
    NSString *dir=[self directDirectory:identifier];
    unsigned long long required=UYTMediaFileSize([dir stringByAppendingPathComponent:@"video.mp4"])+UYTMediaFileSize([dir stringByAppendingPathComponent:@"audio.m4a"])+64*1024*1024;
    unsigned long long available=UYTPreparationFreeSpace(dir);
    if (available!=ULLONG_MAX && available<required) {
        [self directFailed:item message:UYTPreparationSpaceError(required,available)]; return;
    }
    item[@"preparationAttemptVersion"]=@"local18";
    [item removeObjectForKey:@"error"];
    NSLog(@"[UYTNative] Preparation start target=%@ videoBytes=%llu audioBytes=%llu",item[@"videoID"],UYTMediaFileSize([dir stringByAppendingPathComponent:@"video.mp4"]),UYTMediaFileSize([dir stringByAppendingPathComponent:@"audio.m4a"]));
    // Load tracks away from the UI thread; large videos can take time to inspect.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0), ^{
        AVURLAsset *video=[AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:[dir stringByAppendingPathComponent:@"video.mp4"]] options:nil];
        AVURLAsset *audio=[AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:[dir stringByAppendingPathComponent:@"audio.m4a"]] options:nil];
        AVAssetTrack *vt=[video tracksWithMediaType:AVMediaTypeVideo].firstObject,*at=[audio tracksWithMediaType:AVMediaTypeAudio].firstObject;
        double videoSeconds=CMTimeGetSeconds(vt.timeRange.duration),audioSeconds=CMTimeGetSeconds(at.timeRange.duration);
        NSLog(@"[UYTNative] Preparation tracks target=%@ videoTrack=%d audioTrack=%d videoSeconds=%.3f audioSeconds=%.3f",item[@"videoID"],vt!=nil,at!=nil,videoSeconds,audioSeconds);
        AVMutableComposition *composition=[AVMutableComposition composition]; NSError *error=nil; BOOL valid=vt && at;
        if (valid) {
            AVMutableCompositionTrack *v=[composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
            valid=[v insertTimeRange:vt.timeRange ofTrack:vt atTime:kCMTimeZero error:&error]; v.preferredTransform=vt.preferredTransform;
            AVMutableCompositionTrack *a=[composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
            if (valid) valid=[a insertTimeRange:CMTimeRangeMake(at.timeRange.start,CMTimeMinimum(at.timeRange.duration,vt.timeRange.duration)) ofTrack:at atTime:kCMTimeZero error:&error];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![self directItem:identifier] || ![item[@"state"] isEqual:@"processing"]) return;
            if (UIApplication.sharedApplication.applicationState!=UIApplicationStateActive) { item[@"state"]=@"waiting"; [self save]; return; }
            if (!valid) { [self directFailed:item message:UYTMediaError(@"Не удалось соединить видео со звуком.",error)]; return; }
            AVAssetExportSession *export=[[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetPassthrough];
            if (!export || ![export.supportedFileTypes containsObject:AVFileTypeMPEG4]) { [self directFailed:item message:@"Этот формат видео не поддерживается iPad."]; return; }
            // Each attempt owns its output: an old cancellation callback must
            // never remove the file of a new foreground retry.
            NSURL *output=[NSURL fileURLWithPath:[dir stringByAppendingPathComponent:[NSString stringWithFormat:@"offline-%@.mp4",NSUUID.UUID.UUIDString]]];
            // This file is played locally; do not perform the extra fast-start pass.
            export.outputURL=output; export.outputFileType=AVFileTypeMPEG4; export.shouldOptimizeForNetworkUse=NO; self.exports[identifier]=export;
            if (!self.preparationOwnsIdleTimer) {
                self.preparationSavedIdleTimer=UIApplication.sharedApplication.idleTimerDisabled;
                self.preparationOwnsIdleTimer=YES; UIApplication.sharedApplication.idleTimerDisabled=YES;
            }
            __weak UYTOfflineStore *weakSelf=self;
            UIBackgroundTaskIdentifier background=[UIApplication.sharedApplication beginBackgroundTaskWithName:@"Подготовка офлайн-видео" expirationHandler:^{
                UYTOfflineStore *store=weakSelf;
                if (store.exports[identifier]!=export) return;
                item[@"state"]=@"waiting"; [export cancelExport]; [store save];
                NSLog(@"[UYTNative] Preparation suspended, inputs retained target=%@",item[@"videoID"]);
                [store finishPreparation:identifier];
            }];
            if (background!=UIBackgroundTaskInvalid) self.preparationBackgroundTasks[identifier]=@(background);
            [export exportAsynchronouslyWithCompletionHandler:^{ dispatch_async(dispatch_get_main_queue(), ^{
                if (self.exports[identifier]!=export) { [[NSFileManager defaultManager] removeItemAtURL:output error:nil]; return; }
                [self.exports removeObjectForKey:identifier]; [self.tasks removeObjectForKey:identifier];
                [self finishPreparation:identifier];
                if (![self directItem:identifier]) { [[NSFileManager defaultManager] removeItemAtPath:dir error:nil]; return; }
                if ([item[@"state"] isEqual:@"waiting"]) {
                    [[NSFileManager defaultManager] removeItemAtURL:output error:nil];
                    if (UIApplication.sharedApplication.applicationState==UIApplicationStateActive) [self mergeDirect:item];
                    return;
                }
                AVURLAsset *result=[AVURLAsset URLAssetWithURL:output options:nil];
                BOOL complete=export.status==AVAssetExportSessionStatusCompleted && [result tracksWithMediaType:AVMediaTypeVideo].count && [result tracksWithMediaType:AVMediaTypeAudio].count;
                if (complete) {
                    NSString *prefix=[NSHomeDirectory().stringByResolvingSymlinksInPath stringByAppendingString:@"/"]; NSString *path=output.path.stringByResolvingSymlinksInPath;
                    if (![path hasPrefix:prefix]) { [self directFailed:item message:@"Не удалось сохранить путь к видео."]; return; }
                    item[@"location"]=[path substringFromIndex:prefix.length]; item[@"state"]=@"ready"; item[@"progress"]=@1;
                    if (isfinite(videoSeconds) && videoSeconds>0) item[@"duration"]=@(videoSeconds);
                    [[NSFileManager defaultManager] removeItemAtPath:[dir stringByAppendingPathComponent:@"audio.m4a"] error:nil]; [[NSFileManager defaultManager] removeItemAtPath:[dir stringByAppendingPathComponent:@"video.mp4"] error:nil]; [self save];
                } else {
                    NSLog(@"[UYTNative] Preparation failed target=%@ exportStatus=%ld outputBytes=%llu code=%@:%ld",item[@"videoID"],(long)export.status,UYTMediaFileSize(output.path),export.error.domain,(long)export.error.code);
                    [[NSFileManager defaultManager] removeItemAtURL:output error:nil];
                    if (UIApplication.sharedApplication.applicationState!=UIApplicationStateActive) { item[@"state"]=@"waiting"; [self save]; }
                    else [self directFailed:item message:UYTMediaError(@"Не удалось подготовить видео для просмотра. В меню можно повторить подготовку без скачивания.",export.error)];
                }
                NSLog(@"[UYTNative] Menu download completed target=%@ videoAndAudio=%d",item[@"videoID"],complete);
            }); }];
        });
    });
}
- (void)finishPreparation:(NSString *)identifier {
    NSNumber *task=self.preparationBackgroundTasks[identifier];
    if (task) { [self.preparationBackgroundTasks removeObjectForKey:identifier]; [UIApplication.sharedApplication endBackgroundTask:task.unsignedIntegerValue]; }
    if (!self.exports.count && self.preparationOwnsIdleTimer) {
        UIApplication.sharedApplication.idleTimerDisabled=self.preparationSavedIdleTimer; self.preparationOwnsIdleTimer=NO;
    }
}
@end
