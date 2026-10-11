#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "UYTOffline.h"
#import "UYTDirectFormats.h"

static id UYTPRead(id object,NSString *key) {
    SEL selector=NSSelectorFromString(key);
    if ([object respondsToSelector:selector]) {
        NSMethodSignature *signature=[object methodSignatureForSelector:selector];
        if (signature.numberOfArguments==2 && signature.methodReturnType[0]=='@') return ((id(*)(id,SEL))objc_msgSend)(object,selector);
    }
    @try { return [object valueForKey:key]; } @catch (__unused NSException *exception) { return nil; }
}
static const void *UYTPBoundVideoKey=&UYTPBoundVideoKey;
static NSString *UYTPNodeID(id node) {
    // Modern feed nodes keep the InnerTube card controller as their responder,
    // while their ELM controller only exposes a C++ materialization instance.
    id responder=UYTPRead(node,@"parentResponder");
    for (NSString *key in @[@"_entry",@"entry",@"elementEntry"]) {
        NSString *identifier=UYTVideoIDForCard(UYTPRead(responder,key));
        if (identifier) return identifier;
    }
    for (NSString *key in @[@"inlinePlaybackRenderer",@"_inlinePlaybackRenderer",@"videoRenderer",@"_videoRenderer"]) {
        NSString *identifier=UYTVideoIDForCard(UYTPRead(node,key)); if (identifier) return identifier;
    }
    return UYTVideoIDForCard(UYTPRead(node,@"element")) ?: UYTVideoIDForCard(UYTPRead(node,@"controller")) ?: UYTVideoIDForCard(node);
}
static NSString *UYTPFields(id object) {
    NSMutableArray *names=[NSMutableArray array];
    for (Class cls=[object class]; cls && cls!=NSObject.class && names.count<80; cls=class_getSuperclass(cls)) {
        unsigned int count=0; Ivar *ivars=class_copyIvarList(cls,&count);
        for (unsigned int i=0;i<count && names.count<80;i++) [names addObject:@(ivar_getName(ivars[i]))]; free(ivars);
    }
    return [NSString stringWithFormat:@"%@:%@",NSStringFromClass([object class]),[names componentsJoinedByString:@","]];
}
static NSString *UYTPCardID(UIView *cell,CGPoint point) {
    id bound=objc_getAssociatedObject(cell,UYTPBoundVideoKey);
    NSString *boundID=UYTVideoIDForCard(bound); if (boundID) return boundID;
    NSString *saved=UYTPRead(cell,@"representedID"); if (UYTValidVideoID(saved)) return saved;
    NSMutableArray *queue=[NSMutableArray arrayWithObject:cell]; NSUInteger remaining=80;
    while (queue.count && remaining--) {
        UIView *view=queue.firstObject; [queue removeObjectAtIndex:0];
        if (!CGRectContainsPoint([view convertRect:view.bounds toView:cell],point)) continue;
        NSString *associated=UYTVideoIDForCard(objc_getAssociatedObject(view,UYTPBoundVideoKey));
        if (associated) return associated;
        id node=UYTPRead(view,@"keepalive_node") ?: UYTPRead(view,@"node");
        if (node) {
            NSString *identifier=UYTPNodeID(node);
            if (identifier) return identifier;
        }
        [queue addObjectsFromArray:view.subviews];
    }
    for (NSString *key in @[@"renderer",@"_renderer",@"cellController",@"_cellController"]) {
        NSString *identifier=UYTVideoIDForCard(UYTPRead(cell,key)); if (identifier) return identifier;
    }
    static NSUInteger diagnostics=0;
    if (diagnostics++<3) {
        NSMutableArray *classes=[NSMutableArray array],*views=[NSMutableArray arrayWithObject:cell]; NSUInteger limit=16;
        while (views.count && limit--) {
            UIView *view=views.firstObject; [views removeObjectAtIndex:0];
            if (!CGRectContainsPoint([view convertRect:view.bounds toView:cell],point)) continue;
            id node=UYTPRead(view,@"keepalive_node") ?: UYTPRead(view,@"node");
            [classes addObject:[NSString stringWithFormat:@"%@/node:%@/controller:%@/bound:%@",NSStringFromClass(view.class),NSStringFromClass([node class]),NSStringFromClass([UYTPRead(node,@"controller") class]),NSStringFromClass([objc_getAssociatedObject(view,UYTPBoundVideoKey) class])]];
            [views addObjectsFromArray:view.subviews];
        }
        NSLog(@"[UYTNative] Preview identity path=%@",[classes componentsJoinedByString:@","]);
        id root=UYTPRead(cell,@"node");
        NSLog(@"[UYTNative] Preview identity fields node=%@ responder=%@ element=%@ controller=%@",UYTPFields(root),UYTPFields(UYTPRead(root,@"parentResponder")),UYTPFields(UYTPRead(root,@"element")),UYTPFields(UYTPRead(root,@"controller")));
    }
    return nil;
}
static CGRect UYTPThumbnail(UIView *cell) {
    UIView *cover=UYTPRead(cell,@"cover"); if ([cover isKindOfClass:UIView.class]) return [cover convertRect:cover.bounds toView:cell];
    CGRect best=CGRectZero; CGFloat area=0;
    NSMutableArray *queue=[NSMutableArray arrayWithObject:cell]; NSUInteger remaining=100;
    while (queue.count && remaining--) {
        UIView *view=queue.firstObject; [queue removeObjectAtIndex:0]; [queue addObjectsFromArray:view.subviews];
        if (view==cell || view.hidden || view.tag==947237) continue;
        CGRect frame=[view convertRect:view.bounds toView:cell]; CGFloat ratio=frame.size.width/MAX(frame.size.height,1);
        NSString *name=NSStringFromClass(view.class).lowercaseString;
        BOOL image=[view isKindOfClass:UIImageView.class] || [name containsString:@"thumbnail"] || [name containsString:@"image"];
        if (image && frame.size.width>=80 && ratio>=1.3 && ratio<=2.3 && CGRectContainsRect(cell.bounds,frame) && frame.size.width*frame.size.height>area) { best=frame; area=frame.size.width*frame.size.height; }
    }
    if (area) return best;
    CGFloat width=cell.bounds.size.width,height=cell.bounds.size.height;
    // Layer-backed Elements cards can have no separate thumbnail UIView.
    // Large cards use the top 16:9 region; compact rows use the leading thumbnail.
    return height>=width*9/16?CGRectMake(0,0,width,width*9/16):CGRectMake(0,0,MIN(width,height*16/9),height);
}
@interface UYTCardPreview : NSObject <UIGestureRecognizerDelegate>
@property(nonatomic,weak) UIView *cell;
@property(nonatomic,strong) AVPlayer *player;
@property(nonatomic,strong) AVPlayerLayer *layer;
@property(nonatomic,strong) UIView *overlay;
@property(nonatomic,strong) UIActivityIndicatorView *spinner;
@property(nonatomic,strong) NSURLSessionDataTask *task;
@property(nonatomic,strong) NSArray<AVURLAsset *> *loadingAssets;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic,strong) NSString *videoID;
@property(nonatomic,strong) NSDate *started;
@property(nonatomic) NSUInteger generation;
@property(nonatomic) BOOL displayed;
- (void)stop;
@end
static UYTCardPreview *UYTPActive;
static const void *UYTPGestureKey=&UYTPGestureKey;
@implementation UYTCardPreview
- (instancetype)init { if ((self=[super init])) [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stop) name:UIApplicationWillResignActiveNotification object:nil]; return self; }
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch {
    for (UIView *view=touch.view;view && view!=gesture.view;view=view.superview) if ([view isKindOfClass:UIControl.class]) return NO;
    return YES;
}
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture {
    UIView *cell=gesture.view;
    if (!cell.window || cell.bounds.size.width<80 || cell.bounds.size.height<45 || !CGRectContainsPoint(UYTPThumbnail(cell),[gesture locationInView:cell])) return NO;
    NSString *identifier=UYTPCardID(cell,[gesture locationInView:cell]);
    NSLog(@"[UYTNative] Preview card class=%@ target=%@ bound=%@",NSStringFromClass(cell.class),identifier ?: @"missing",NSStringFromClass([objc_getAssociatedObject(cell,UYTPBoundVideoKey) class]));
    if (!identifier) return NO; self.cell=cell; self.videoID=identifier; return YES;
}
- (void)hold:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state==UIGestureRecognizerStateBegan) [self start];
    else if (gesture.state==UIGestureRecognizerStateEnded || gesture.state==UIGestureRecognizerStateCancelled || gesture.state==UIGestureRecognizerStateFailed) [self stop];
}
- (void)start {
    [UYTPActive stop]; UYTPActive=self;
    NSUInteger generation=++self.generation; NSString *videoID=[self.videoID copy];
    self.displayed=NO;
    self.overlay=[[UIView alloc] initWithFrame:UYTPThumbnail(self.cell)]; self.overlay.tag=947237; self.overlay.userInteractionEnabled=NO; self.overlay.clipsToBounds=YES; self.overlay.layer.cornerRadius=8;
    [self.cell addSubview:self.overlay];
    self.spinner=[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite]; self.spinner.frame=CGRectMake(8,8,24,24); [self.overlay addSubview:self.spinner]; [self.spinner startAnimating];
    self.started=NSDate.date; self.timer=[NSTimer timerWithTimeInterval:0.2 target:self selector:@selector(tick) userInfo:nil repeats:YES]; [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    NSURL *local=UYTLocalPreviewURL(videoID);
    if (local) { [self playURL:local generation:generation]; return; }
    __weak UYTCardPreview *weakSelf=self;
    self.task=[[NSURLSession sharedSession] dataTaskWithRequest:UYTPlayerRequest(videoID) completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
        NSDictionary *json=(!error && [(NSHTTPURLResponse *)response statusCode]==200 && data.length<6*1024*1024)?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
        NSDictionary *format=UYTPreviewFormat(json,videoID);
        dispatch_async(dispatch_get_main_queue(), ^{
            UYTCardPreview *owner=weakSelf; if (!owner || owner.generation!=generation || UYTPActive!=owner) return;
            owner.task=nil;
            if (!format) { NSLog(@"[UYTNative] Preview unavailable target=%@ http=%ld error=%@:%ld",videoID,(long)[(NSHTTPURLResponse *)response statusCode],error.domain,(long)error.code); [owner stop]; return; }
            [owner playFormat:format generation:generation];
        });
    }]; [self.task resume];
}
- (void)playFormat:(NSDictionary *)format generation:(NSUInteger)generation {
    NSURL *videoURL=[NSURL URLWithString:format[@"video"][@"url"]];
    if ([format[@"muxed"] boolValue]) { [self playURL:videoURL generation:generation]; return; }
    AVURLAsset *video=[AVURLAsset URLAssetWithURL:videoURL options:nil],*audio=[AVURLAsset URLAssetWithURL:[NSURL URLWithString:format[@"audio"][@"url"]] options:nil];
    self.loadingAssets=@[video,audio];
    dispatch_group_t group=dispatch_group_create();
    for (AVURLAsset *asset in @[video,audio]) {
        dispatch_group_enter(group);
        [asset loadValuesAsynchronouslyForKeys:@[@"tracks",@"duration"] completionHandler:^{ dispatch_group_leave(group); }];
    }
    __weak UYTCardPreview *weakSelf=self;
    dispatch_group_notify(group,dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0), ^{
        AVAssetTrack *v=[video tracksWithMediaType:AVMediaTypeVideo].firstObject,*a=[audio tracksWithMediaType:AVMediaTypeAudio].firstObject;
        double seconds=MIN(15,MIN(CMTimeGetSeconds(video.duration),CMTimeGetSeconds(audio.duration)));
        AVMutableComposition *composition=[AVMutableComposition composition]; NSError *error=nil; BOOL ready=v && a && isfinite(seconds) && seconds>0;
        if (ready) {
            CMTimeRange range=CMTimeRangeMake(kCMTimeZero,CMTimeMakeWithSeconds(seconds,600));
            AVMutableCompositionTrack *vt=[composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
            AVMutableCompositionTrack *at=[composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
            ready=[vt insertTimeRange:range ofTrack:v atTime:kCMTimeZero error:&error] && [at insertTimeRange:range ofTrack:a atTime:kCMTimeZero error:&error]; vt.preferredTransform=v.preferredTransform;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            UYTCardPreview *owner=weakSelf; if (!owner || owner.generation!=generation || UYTPActive!=owner) return;
            if (!ready) { NSLog(@"[UYTNative] Preview composition failed target=%@ error=%@:%ld",owner.videoID,error.domain,(long)error.code); [owner stop]; return; }
            owner.loadingAssets=nil;
            [owner playItem:[AVPlayerItem playerItemWithAsset:composition] generation:generation local:NO];
        });
    });
}
- (void)playURL:(NSURL *)url generation:(NSUInteger)generation {
    [self playItem:[AVPlayerItem playerItemWithURL:url] generation:generation local:url.isFileURL];
}
- (void)playItem:(AVPlayerItem *)item generation:(NSUInteger)generation local:(BOOL)local {
    if (self.generation!=generation || UYTPActive!=self) return;
    item.preferredForwardBufferDuration=2;
    self.player=[AVPlayer playerWithPlayerItem:item]; self.player.muted=NO;
    self.layer=[AVPlayerLayer playerLayerWithPlayer:self.player]; self.layer.videoGravity=AVLayerVideoGravityResizeAspect; self.layer.frame=self.overlay.bounds;
    [self.overlay.layer insertSublayer:self.layer atIndex:0]; [self.player play];
    NSLog(@"[UYTNative] Preview started target=%@ local=%d audio=1 limit=15",self.videoID,local);
}
- (void)tick {
    UIView *cell=self.cell;
    if (!cell.window || UYTPActive!=self || -self.started.timeIntervalSinceNow>35) { [self stop]; return; }
    for (UIView *parent=cell.superview;parent;parent=parent.superview) if ([parent isKindOfClass:UIScrollView.class]) {
        UIScrollView *scroll=(UIScrollView *)parent;
        if (scroll.dragging || scroll.decelerating || !CGRectIntersectsRect([cell convertRect:cell.bounds toView:parent],parent.bounds)) { [self stop]; return; }
    }
    if (self.player.currentItem.status==AVPlayerItemStatusFailed) { NSLog(@"[UYTNative] Preview failed target=%@ error=%@:%ld",self.videoID,self.player.currentItem.error.domain,(long)self.player.currentItem.error.code); [self stop]; return; }
    self.overlay.frame=UYTPThumbnail(cell); self.layer.frame=self.overlay.bounds;
    if (self.layer.readyForDisplay) {
        [self.spinner stopAnimating];
        if (!self.displayed) { self.displayed=YES; NSLog(@"[UYTNative] Preview visible target=%@",self.videoID); }
    }
    double time=CMTimeGetSeconds(self.player.currentTime),duration=CMTimeGetSeconds(self.player.currentItem.duration);
    if (isfinite(time) && (time>=15 || (isfinite(duration) && duration>0 && time>=duration-0.1))) [self stop];
}
- (void)stop {
    self.generation++; [self.task cancel]; self.task=nil;
    for (AVURLAsset *asset in self.loadingAssets) [asset cancelLoading]; self.loadingAssets=nil; [self.timer invalidate]; self.timer=nil;
    [self.player pause]; [self.player replaceCurrentItemWithPlayerItem:nil]; self.player=nil;
    [self.layer removeFromSuperlayer]; self.layer=nil; [self.overlay removeFromSuperview]; self.overlay=nil; self.spinner=nil;
    if (UYTPActive==self) UYTPActive=nil;
}
@end
static void UYTPInstall(UIView *cell) {
    if (!cell.window || objc_getAssociatedObject(cell,UYTPGestureKey)) return;
    UYTCardPreview *handler=[UYTCardPreview new]; handler.cell=cell;
    UILongPressGestureRecognizer *gesture=[[UILongPressGestureRecognizer alloc] initWithTarget:handler action:@selector(hold:)]; gesture.minimumPressDuration=0.5; gesture.allowableMovement=10; gesture.delegate=handler;
    [cell addGestureRecognizer:gesture];
    NSMutableArray *views=[NSMutableArray arrayWithObject:cell]; NSUInteger remaining=100;
    while (views.count && remaining--) {
        UIView *view=views.firstObject; [views removeObjectAtIndex:0]; [views addObjectsFromArray:view.subviews];
        for (UIGestureRecognizer *other in view.gestureRecognizers) if (other!=gesture && [other isKindOfClass:UILongPressGestureRecognizer.class]) [other requireGestureRecognizerToFail:gesture];
    }
    objc_setAssociatedObject(cell,UYTPGestureKey,handler,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
%hook UICollectionViewCell
- (void)didMoveToWindow {
    %orig;
    UYTPInstall((UIView *)self);
    if (!((UIView *)self).window) [((UYTCardPreview *)objc_getAssociatedObject(self,UYTPGestureKey)) stop];
}
- (void)prepareForReuse {
    [((UYTCardPreview *)objc_getAssociatedObject(self,UYTPGestureKey)) stop];
    objc_setAssociatedObject(self,UYTPBoundVideoKey,nil,OBJC_ASSOCIATION_COPY_NONATOMIC);
    %orig;
}
%end
%hook UITableViewCell
- (void)didMoveToWindow {
    %orig;
    UYTPInstall((UIView *)self);
    if (!((UIView *)self).window) [((UYTCardPreview *)objc_getAssociatedObject(self,UYTPGestureKey)) stop];
}
- (void)prepareForReuse {
    [((UYTCardPreview *)objc_getAssociatedObject(self,UYTPGestureKey)) stop];
    objc_setAssociatedObject(self,UYTPBoundVideoKey,nil,OBJC_ASSOCIATION_COPY_NONATOMIC);
    %orig;
}
%end

// Bind identities when the native card controller supplies its own renderer.
// This avoids walking a whole feed, and also handles layer-backed Elements cards.
static void UYTPBind(id controller,id renderer) {
    static BOOL binding=NO;
    if (binding || !NSThread.isMainThread) return;
    binding=YES;
    @try {
        id cell=UYTPRead(controller,@"cell");
        if ([cell isKindOfClass:UIView.class]) objc_setAssociatedObject(cell,UYTPBoundVideoKey,renderer,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @finally { binding=NO; }
}
%hook YTElementsCellController
- (id)cell {
    id cell=%orig;
    id renderer=UYTPRead(self,@"_entry");
    if ([cell isKindOfClass:UIView.class] && renderer) objc_setAssociatedObject(cell,UYTPBoundVideoKey,renderer,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return cell;
}
- (id)elementEntry {
    id renderer=%orig;
    UYTPBind(self,renderer);
    return renderer;
}
%end
%hook YTVideoCellController
- (id)cell {
    id cell=%orig;
    id renderer=UYTPRead(self,@"_entry");
    if ([cell isKindOfClass:UIView.class] && renderer) objc_setAssociatedObject(cell,UYTPBoundVideoKey,renderer,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return cell;
}
- (id)entry {
    id renderer=%orig;
    UYTPBind(self,renderer);
    return renderer;
}
%end
