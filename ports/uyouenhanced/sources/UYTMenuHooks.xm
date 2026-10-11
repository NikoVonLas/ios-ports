#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "UYTOffline.h"
#import "UYTDirectFormats.h"
#import "UYTCompatibility.h"

static id UYTMRead(id obj, NSString *name) {
    SEL sel=NSSelectorFromString(name);
    if (![obj respondsToSelector:sel]) return nil;
    NSMethodSignature *signature=[obj methodSignatureForSelector:sel];
    if (!signature || signature.numberOfArguments!=2 || signature.methodReturnType[0]!='@') return nil;
    @try { return ((id(*)(id,SEL))objc_msgSend)(obj,sel); } @catch (__unused NSException *e) { return nil; }
}
static BOOL UYTMVideoField(NSString *name) {
    NSString *n=[[name lowercaseString] stringByReplacingOccurrencesOfString:@"_" withString:@""];
    return [n containsString:@"video"] && ([n hasSuffix:@"id"] || [n hasSuffix:@"ids"] || [n hasSuffix:@"idarray"]);
}
static void UYTMCollect(id obj, NSString *field, NSMutableSet *ids, NSHashTable *seen, NSInteger depth, NSInteger *budget) {
    if (!obj || depth>9 || (*budget)--<=0) return;
    if ([obj isKindOfClass:NSString.class]) { if (UYTMVideoField(field) && UYTValidVideoID(obj)) [ids addObject:obj]; return; }
    if ([obj isKindOfClass:NSNumber.class] || [obj isKindOfClass:NSData.class] || [obj isKindOfClass:NSURL.class] || [seen containsObject:obj]) return;
    [seen addObject:obj];
    if ([obj isKindOfClass:NSDictionary.class]) { for (id key in obj) if ([key isKindOfClass:NSString.class]) UYTMCollect(obj[key],key,ids,seen,depth+1,budget); return; }
    if ([obj isKindOfClass:NSArray.class]) { for (id value in obj) UYTMCollect(value,field,ids,seen,depth+1,budget); return; }
    NSMutableOrderedSet *names=[NSMutableOrderedSet orderedSetWithArray:@[@"videoId",@"videoID",@"offlineVideoID",@"offlineVideoId",@"contentVideoID",@"command",@"context",@"commandContext",@"params",@"parameters",@"commandParameters",@"renderer",@"endpoint",@"watchEndpoint",@"offlineVideoEndpoint",@"model",@"element",@"firstSubmessage",@"serviceEndpoint",@"navigationEndpoint",@"menuRenderer",@"rendererModel"]];
    id descriptor=UYTMRead(obj,@"descriptor"); id fields=UYTMRead(descriptor,@"fields");
    if ([fields isKindOfClass:NSArray.class]) for (id f in fields) { id name=UYTMRead(f,@"name"); if ([name isKindOfClass:NSString.class]) [names addObject:name]; }
    for (Class cls=[obj class]; cls && cls!=NSObject.class; cls=class_getSuperclass(cls)) {
        unsigned int count=0; Method *methods=class_copyMethodList(cls,&count);
        for (unsigned int i=0;i<count;i++) {
            NSString *name=NSStringFromSelector(method_getName(methods[i])); NSString *lower=name.lowercaseString;
            if (![name containsString:@":"] && ([lower containsString:@"video"] || [lower containsString:@"command"] || [lower containsString:@"param"] || [lower containsString:@"endpoint"] || [lower containsString:@"context"])) [names addObject:name];
        } free(methods);
    }
    for (Class cls=[obj class]; cls && cls!=NSObject.class; cls=class_getSuperclass(cls)) {
        unsigned int count=0; Ivar *ivars=class_copyIvarList(cls,&count);
        for (unsigned int i=0;i<count;i++) {
            const char *type=ivar_getTypeEncoding(ivars[i]);
            NSString *name=@(ivar_getName(ivars[i])); NSString *lower=name.lowercaseString;
            if (type && type[0]=='@' && ([lower containsString:@"video"] || [lower containsString:@"renderer"] || [lower containsString:@"endpoint"] || [lower containsString:@"command"] || [lower isEqualToString:@"_model"])) {
                UYTMCollect(object_getIvar(obj,ivars[i]),name,ids,seen,depth+1,budget);
            }
        } free(ivars);
    }
    for (NSString *name in names) UYTMCollect(UYTMRead(obj,name),name,ids,seen,depth+1,budget);
}
static NSSet *UYTMIDs(id object) { NSMutableSet *ids=[NSMutableSet set]; NSInteger budget=500; UYTMCollect(object,@"",ids,[NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality],0,&budget); return ids; }
static UIViewController *UYTMTop(void) {
    UIWindow *window=UYTKeyWindow();
    UIViewController *vc=window.rootViewController;
    while (vc.presentedViewController && !vc.presentedViewController.isBeingDismissed) vc=vc.presentedViewController;
    return vc;
}
static NSString *UYTMTarget;
static CFTimeInterval UYTMTargetTime;
static void UYTMStart(NSString *videoID) {
    NSString *target=[videoID copy]; UYTMTarget=nil;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,450*NSEC_PER_MSEC),dispatch_get_main_queue(), ^{ UYTDownloadFromMenu(target,UYTMTop()); });
}
BOOL UYTHandleDownloadSheet(id controller,id command,id context) {
    id options=UYTMRead(command,@"listOptionArray"); if (![options isKindOfClass:NSArray.class]) return NO;
    BOOL upsell=NO;
    for (id element in options) {
        id properties=UYTMRead(element,@"properties"); id sub=UYTMRead(properties,@"firstSubmessage"); id identifier=UYTMRead(sub,@"identifier");
        if ([identifier isKindOfClass:NSString.class] && [identifier containsString:@"offline_upsell_dialog"]) upsell=YES;
        if (!identifier && [[properties description] containsString:@"offline_upsell_dialog"]) upsell=YES;
    }
    NSSet *ids=UYTMIDs(context); if (ids.count!=1) ids=UYTMIDs(command);
    NSLog(@"[UYTNative] Menu sheet context=%@ targetCount=%lu upsell=%d",NSStringFromClass([context class]),(unsigned long)ids.count,upsell);
    if (!upsell) {
        UYTMTarget=ids.count==1?[ids.anyObject copy]:nil; UYTMTargetTime=CACurrentMediaTime(); return NO;
    }
    NSString *target=ids.count==1?ids.anyObject:((CACurrentMediaTime()-UYTMTargetTime<45)?UYTMTarget:nil);
    UYTMStart(target); return YES;
}

static char UYTMVideoKey;
%hook YTOfflineButtonPressedResponderEvent
- (id)initWithOfflineVideoID:(id)videoID playlistID:(id)playlistID offlineabilityRenderer:(id)renderer fromView:(id)view firstResponder:(id)responder {
    id event=%orig;
    if (UYTValidVideoID(videoID) && ![playlistID length]) {
        objc_setAssociatedObject(event,&UYTMVideoKey,[videoID copy],OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        NSLog(@"[UYTNative] Offline event captured target=%@",videoID);
    }
    return event;
}
+ (id)eventWithOfflineVideoID:(id)videoID fromView:(id)view firstResponder:(id)responder {
    id event=%orig;
    if (UYTValidVideoID(videoID)) objc_setAssociatedObject(event,&UYTMVideoKey,[videoID copy],OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return event;
}
- (void)send {
    NSString *videoID=objc_getAssociatedObject(self,&UYTMVideoKey);
    if (videoID) { UYTMStart(videoID); return; }
    %orig;
}
%end

// Legacy feed menus use YTDefaultSheetController, independently of Elements sheets.
static char UYTMSheetIDKey, UYTMActionWrappedKey;
static NSString *UYTMUnique(id object) { NSSet *ids=UYTMIDs(object); return ids.count==1?ids.anyObject:nil; }
static void UYTMDescribe(id object, NSString *where) {
    if (!object) return;
    NSMutableArray *fields=[NSMutableArray array];
    for (Class cls=[object class]; cls && cls!=NSObject.class; cls=class_getSuperclass(cls)) {
        unsigned int count=0; Ivar *ivars=class_copyIvarList(cls,&count);
        for (unsigned int i=0;i<count && fields.count<45;i++) {
            const char *type=ivar_getTypeEncoding(ivars[i]);
            if (type && type[0]=='@') [fields addObject:@(ivar_getName(ivars[i]))];
        } free(ivars);
    }
    NSLog(@"[UYTNative] Legacy %@ class=%@ fields=%@",where,NSStringFromClass([object class]),[fields componentsJoinedByString:@","]);
}
static void UYTMAttach(id sheet,id context) {
    NSString *videoID=UYTMUnique(context);
    if (videoID) objc_setAssociatedObject(sheet,&UYTMSheetIDKey,videoID,OBJC_ASSOCIATION_COPY_NONATOMIC);
    NSLog(@"[UYTNative] Legacy menu parent=%@ target=%@",NSStringFromClass([context class]),videoID?:@"missing");
    if (!videoID) UYTMDescribe(context,@"parent");
}
static void UYTMCaptureView(id sheet,UIView *view) {
    if (objc_getAssociatedObject(sheet,&UYTMSheetIDKey)) return;
    UIResponder *current=view;
    for (NSInteger i=0;current && i<7;i++,current=current.nextResponder) {
        // Never inspect a controller containing the entire feed or the active player.
        if ([current isKindOfClass:UIViewController.class]) break;
        NSString *videoID=UYTMUnique(current);
        if (videoID) { objc_setAssociatedObject(sheet,&UYTMSheetIDKey,videoID,OBJC_ASSOCIATION_COPY_NONATOMIC); break; }
    }
    NSLog(@"[UYTNative] Legacy anchor=%@ target=%@",NSStringFromClass(view.class),objc_getAssociatedObject(sheet,&UYTMSheetIDKey)?:@"missing");
    UYTMDescribe(view,@"anchor");
}
static void UYTMWrapAction(id sheet,id action) {
    if (objc_getAssociatedObject(action,&UYTMActionWrappedKey)) return;
    id identifier=UYTMRead(action,@"accessibilityIdentifier");
    if (!identifier) { @try { identifier=[action valueForKey:@"_accessibilityIdentifier"]; } @catch (__unused NSException *e) {} }
    id title=UYTMRead(action,@"title");
    BOOL download=[identifier isEqual:@"7"] || [title isEqual:@"Скачать видео"] || [title isEqual:@"Download video"];
    if (!download) return;
    SEL setter=NSSelectorFromString(@"setHandler:");
    if (![action respondsToSelector:setter]) { UYTMDescribe(action,@"download action without setter"); return; }
    NSString *actionID=UYTMUnique(action);
    id nativeHandler=[UYTMRead(action,@"handler") copy];
    __weak id weakSheet=sheet;
    void (^replacement)(void)=^{
        id currentSheet=weakSheet;
        NSString *videoID=actionID?:objc_getAssociatedObject(currentSheet,&UYTMSheetIDKey);
        NSLog(@"[UYTNative] Legacy download tapped target=%@",videoID?:@"missing");
        if (videoID) UYTMStart(videoID);
        else if (nativeHandler) ((void(^)(void))nativeHandler)();
        else UYTMStart(nil);
    };
    ((void(*)(id,SEL,id))objc_msgSend)(action,setter,[replacement copy]);
    objc_setAssociatedObject(action,&UYTMActionWrappedKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSLog(@"[UYTNative] Legacy download action replaced sheet=%@",NSStringFromClass([sheet class]));
    UYTMDescribe(sheet,@"sheet");
}
%hook YTDefaultSheetController
+ (id)sheetControllerWithParentResponder:(id)parent {
    id sheet=%orig;
    UYTMAttach(sheet,parent); return sheet;
}
+ (id)sheetControllerWithParentResponder:(id)parent forcedSheetStyle:(NSInteger)style {
    id sheet=%orig;
    UYTMAttach(sheet,parent); return sheet;
}
- (void)addAction:(id)action {
    UYTMWrapAction(self,action);
    %orig;
}
- (void)presentFromView:(UIView *)view animated:(BOOL)animated completion:(id)completion {
    UYTMCaptureView(self,view);
    %orig;
}
%end


// The current feed dispatches the offline endpoint directly, without a responder event.
static NSString *UYTMCommandID(id command) {
    NSString *videoID=UYTMUnique(command);
    if (videoID) return videoID;
    // GPB extension fields can be absent from Objective-C property reflection.
    // Read only exact video_id fields; never log the protobuf/command payload.
    NSString *description=[command description];
    if (![description isKindOfClass:NSString.class] || description.length>200000) return nil;
    NSRegularExpression *regex=[NSRegularExpression regularExpressionWithPattern:@"(?:video_id|videoId|videoID)\\s*:\\s*\"([A-Za-z0-9_-]{11})\"" options:0 error:nil];
    NSMutableSet *ids=[NSMutableSet set];
    for (NSTextCheckingResult *match in [regex matchesInString:description options:0 range:NSMakeRange(0,description.length)]) [ids addObject:[description substringWithRange:[match rangeAtIndex:1]]];
    return ids.count==1?ids.anyObject:nil;
}
static void UYTMEndpoint(id command,id entry) {
    NSString *videoID=UYTMCommandID(command)?:UYTMCommandID(entry);
    NSLog(@"[UYTNative] Offline endpoint command=%@ entry=%@ target=%@",NSStringFromClass([command class]),NSStringFromClass([entry class]),videoID?:@"missing");
    if (!videoID) { UYTMDescribe(command,@"endpoint"); UYTMDescribe(entry,@"entry"); }
    UYTMStart(videoID);
}
%hook YTOfflineVideoEndpointCommandHandlerImpl
- (void)executeWithCommand:(id)command entry:(id)entry fromView:(id)view sender:(id)sender {
    UYTMEndpoint(command,entry);
}
- (void)executeWithCommand:(id)command entry:(id)entry fromView:(id)view sender:(id)sender completionBlock:(id)completion {
    UYTMEndpoint(command,entry);
}
%end

%ctor {
    %init;
    NSLog(@"[UYTNative] local16 loaded offline-command-hook=1 media-client=android");
}
