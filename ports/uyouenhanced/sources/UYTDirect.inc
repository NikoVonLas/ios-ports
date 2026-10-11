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
    NSURLSessionConfiguration *config=[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"com.nikovonlas.uyt.offline.direct.v1"]; config.discretionary=NO; config.allowsCellularAccess=YES;
    self.directSession=[NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:NSOperationQueue.mainQueue];
    [self.directSession getAllTasksWithCompletionHandler:^(NSArray<__kindof NSURLSessionTask *> *tasks){ dispatch_async(dispatch_get_main_queue(), ^{
        for (NSURLSessionTask *task in tasks) {
            NSString *identifier=[task.taskDescription componentsSeparatedByString:@":"].firstObject; if (!identifier.length) continue;
            UYTDirectGroup *group=self.tasks[identifier]; if (!group) { group=[UYTDirectGroup new]; self.tasks[identifier]=group; }
            if ([group isKindOfClass:UYTDirectGroup.class]) [group.members addObject:task];
        }
        for (NSMutableDictionary *item in self.items) if ([item[@"kind"] isEqual:@"direct"] && [@[@"loading",@"paused",@"processing"] containsObject:item[@"state"]]) {
            NSString *dir=[self directDirectory:item[@"id"]];
            if ([[NSFileManager defaultManager] fileExistsAtPath:[dir stringByAppendingPathComponent:@"audio.m4a"]] && [[NSFileManager defaultManager] fileExistsAtPath:[dir stringByAppendingPathComponent:@"video.mp4"]]) { item[@"state"]=@"loading"; [self mergeDirect:item]; }
            else if (!self.tasks[item[@"id"]]) { item[@"state"]=@"failed"; item[@"error"]=@"Загрузка прервана. Скачайте ролик заново через меню."; }
        }
        for (NSMutableDictionary *item in self.items) if ([item[@"kind"] isEqual:@"direct"] && [item[@"state"] isEqual:@"failed"]) {
            NSString *directory=[self directDirectory:item[@"id"]];
            NSLog(@"[UYTNative] Stored failure target=%@ height=%@ reason=%@ videoBytes=%llu audioBytes=%llu",item[@"videoID"],item[@"height"],item[@"error"],UYTMediaFileSize([directory stringByAppendingPathComponent:@"video.mp4"]),UYTMediaFileSize([directory stringByAppendingPathComponent:@"audio.m4a"]));
            // One diagnostic recovery of old generic mux failures, retaining inputs.
            if ([item[@"error"] hasPrefix:@"Не удалось подготовить видео"] && ![item[@"preparationAttemptVersion"] isEqual:@"local16"] && [self canPrepareItem:item]) {
                item[@"preparationAttemptVersion"]=@"local16";
                [self mergeDirect:item];
            }
        }
        [self save];
    }); }];
}
- (void)startDirect:(NSDictionary *)formats video:(NSDictionary *)video {
    UYTFetchSponsorSegments(formats[@"videoID"], ^(NSArray *segments) {});
    for (NSMutableDictionary *old in [self.items copy]) {
        if (![old[@"videoID"] isEqual:formats[@"videoID"]] || ![old[@"height"] isEqual:video[@"height"]]) continue;
        if ([@[@"loading",@"paused",@"processing",@"ready"] containsObject:old[@"state"]]) {
            NSLog(@"[UYTNative] Menu download already present target=%@ state=%@",old[@"videoID"],old[@"state"]); return;
        }
        if ([old[@"kind"] isEqual:@"direct"] && [old[@"state"] isEqual:@"failed"]) {
            [[NSFileManager defaultManager] removeItemAtPath:[self directDirectory:old[@"id"]] error:nil];
            [self.items removeObject:old];
        }
    }
    NSString *identifier=NSUUID.UUID.UUIDString;
    NSMutableDictionary *item=[@{@"id":identifier,@"kind":@"direct",@"videoID":formats[@"videoID"],@"title":formats[@"title"],@"height":video[@"height"],@"state":@"loading",@"progress":@0} mutableCopy];
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
    item[@"state"]=@"processing"; item[@"progress"]=@0.99; [self save];
    NSString *dir=[self directDirectory:identifier];
    item[@"preparationAttemptVersion"]=@"local16";
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
            if (!valid) { [self directFailed:item message:UYTMediaError(@"Не удалось соединить видео со звуком.",error)]; return; }
            AVAssetExportSession *export=[[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetPassthrough];
            if (!export || ![export.supportedFileTypes containsObject:AVFileTypeMPEG4]) { [self directFailed:item message:@"Этот формат видео не поддерживается iPad."]; return; }
            NSURL *output=[NSURL fileURLWithPath:[dir stringByAppendingPathComponent:@"offline.mp4"]]; [[NSFileManager defaultManager] removeItemAtURL:output error:nil];
            // This file is played locally; do not perform the extra fast-start pass.
            export.outputURL=output; export.outputFileType=AVFileTypeMPEG4; export.shouldOptimizeForNetworkUse=NO; self.exports[identifier]=export;
            [export exportAsynchronouslyWithCompletionHandler:^{ dispatch_async(dispatch_get_main_queue(), ^{
                [self.exports removeObjectForKey:identifier]; [self.tasks removeObjectForKey:identifier];
                if (![self directItem:identifier]) { [[NSFileManager defaultManager] removeItemAtPath:dir error:nil]; return; }
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
                    [self directFailed:item message:UYTMediaError(@"Не удалось подготовить видео для просмотра. В меню можно повторить подготовку без скачивания.",export.error)];
                }
                NSLog(@"[UYTNative] Menu download completed target=%@ videoAndAudio=%d",item[@"videoID"],complete);
            }); }];
        });
    });
}
@end
