#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "UYTOffline.h"
#import "UYTDirectFormats.h"

static id UYTHomeRead(id object,NSString *key) {
    SEL selector=NSSelectorFromString(key);
    if ([object respondsToSelector:selector]) {
        NSMethodSignature *signature=[object methodSignatureForSelector:selector];
        if (signature.numberOfArguments==2 && signature.methodReturnType[0]=='@') return ((id(*)(id,SEL))objc_msgSend)(object,selector);
    }
    @try { return [object valueForKey:key]; } @catch (__unused NSException *e) { return nil; }
}
static NSString *UYTHomeIdentifier(id object,NSUInteger depth) {
    if (!object) return nil;
    if ([object isKindOfClass:NSString.class]) return [object hasPrefix:@"FE"]?object:nil;
    for (NSString *key in @[@"browseId",@"browseID"]) {
        id identifier=UYTHomeRead(object,key);
        if ([identifier isKindOfClass:NSString.class] && [identifier length]) return identifier;
    }
    if (depth>=3) return nil;
    for (NSString *key in @[@"browseEndpoint",@"navigationEndpoint",@"navEndpoint",@"_navEndpoint",@"browseRequest"]) {
        NSString *identifier=UYTHomeIdentifier(UYTHomeRead(object,key),depth+1); if (identifier) return identifier;
    }
    // The controller's private endpoint ivar changed in recent YouTube builds.
    // Inspect only navigation/browse objects, never response bodies or UI text.
    for (Class cls=[object class];cls && cls!=UIViewController.class && cls!=NSObject.class;cls=class_getSuperclass(cls)) {
        unsigned int count=0; Ivar *ivars=class_copyIvarList(cls,&count);
        NSString *found=nil;
        for (unsigned int i=0;i<count && !found;i++) {
            if (ivar_getTypeEncoding(ivars[i])[0]!='@') continue;
            NSString *name=[NSString stringWithUTF8String:ivar_getName(ivars[i])];
            if (![name.lowercaseString containsString:@"nav"] && ![name.lowercaseString containsString:@"browse"] && ![name.lowercaseString containsString:@"endpoint"] && ![name.lowercaseString containsString:@"request"]) continue;
            found=UYTHomeIdentifier(object_getIvar(object,ivars[i]),depth+1);
        }
        free(ivars); if (found) return found;
    }
    return nil;
}
static BOOL UYTIsHomeController(UIViewController *controller) {
    NSString *identifier=UYTHomeIdentifier(controller,0);
    static const void *logged=&logged;
    if (!objc_getAssociatedObject(controller,logged)) {
        objc_setAssociatedObject(controller,logged,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        NSLog(@"[UYTNative] Browse controller=%@ id=%@",NSStringFromClass(controller.class),[identifier isKindOfClass:NSString.class]?identifier:@"unknown");
        if (!identifier) {
            NSMutableArray *fields=[NSMutableArray array];
            for (Class cls=controller.class;cls && cls!=UIViewController.class;cls=class_getSuperclass(cls)) {
                unsigned int count=0; Ivar *ivars=class_copyIvarList(cls,&count);
                for (unsigned int i=0;i<count;i++) {
                    NSString *name=[NSString stringWithUTF8String:ivar_getName(ivars[i])];
                    if ([name.lowercaseString containsString:@"nav"] || [name.lowercaseString containsString:@"browse"] || [name.lowercaseString containsString:@"endpoint"] || [name.lowercaseString containsString:@"request"]) [fields addObject:name];
                }
                free(ivars);
            }
            NSLog(@"[UYTNative] Browse endpoint fields=%@",[fields componentsJoinedByString:@","]);
        }
    }
    return [identifier isEqual:@"FEwhat_to_watch"] || [identifier isEqual:@"FEhome"];
}
static CGFloat UYTHomeSearchBottom(UIView *root, UIView *view, NSUInteger *remaining) {
    if (!*remaining || view.tag==947234 || view.hidden) return 0; (*remaining)--;
    NSString *identifier=view.accessibilityIdentifier.lowercaseString ?: @"";
    NSString *label=view.accessibilityLabel.lowercaseString ?: @"";
    NSString *className=NSStringFromClass(view.class).lowercaseString;
    BOOL search=([className containsString:@"search"] || [identifier containsString:@"search"] || [label hasPrefix:@"поиск"] || [label hasPrefix:@"search"]);
    CGFloat bottom=0;
    CGRect frame=[view convertRect:view.bounds toView:root];
    CGRect windowFrame=[view convertRect:view.bounds toView:view.window];
    if (search && CGRectGetMinY(windowFrame)>=0 && CGRectGetMinY(windowFrame)<240 && frame.size.height>=20 && frame.size.height<=100) {
        // Preserve the entire search row, including compass and microphone.
        UIView *row=view;
        for (UIView *parent=view.superview;parent && parent!=view.window;parent=parent.superview) {
            CGRect candidate=[parent convertRect:parent.bounds toView:root];
            if (candidate.size.height>=36 && candidate.size.height<=100 && candidate.size.width>=root.bounds.size.width*0.5 && CGRectGetMinY(candidate)<240) row=parent;
        }
        bottom=CGRectGetMaxY([row convertRect:row.bounds toView:root]);
    }
    if ([identifier isEqual:@"id.yoodle.logo"] || [identifier isEqual:@"id.youtube.logo"]) view.hidden=YES;
    for (UIView *child in view.subviews) bottom=MAX(bottom,UYTHomeSearchBottom(root,child,remaining));
    return bottom;
}
static void UYTInstallHome(UIViewController *controller);
static void UYTInstallHome(UIViewController *controller) {
    if (!UYTIsHomeController(controller)) return;
    static const void *childKey=&childKey;
    UIViewController *popular=objc_getAssociatedObject(controller,childKey);
    if (!popular) {
        popular=UYTMakePopularController(); [controller addChildViewController:popular];
        popular.view.tag=947234; popular.view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        [controller.view addSubview:popular.view]; [popular didMoveToParentViewController:controller];
        objc_setAssociatedObject(controller,childKey,popular,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSUInteger remaining=1200;
    // The native search/compass/microphone row may belong to the outer header,
    // rather than to YTBrowseViewController's own subtree.
    UIView *surface=controller.view.window ?: controller.view;
    CGFloat searchBottom=UYTHomeSearchBottom(controller.view,surface,&remaining);
    CGFloat top=MAX(controller.view.safeAreaInsets.top,searchBottom>0?searchBottom+4:0);
    if (!searchBottom && !controller.view.window) { popular.view.hidden=YES; return; }
    popular.view.hidden=NO;
    static const void *diagnosticKey=&diagnosticKey;
    if (!objc_getAssociatedObject(controller,diagnosticKey) && controller.view.window) {
        objc_setAssociatedObject(controller,diagnosticKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        __weak UIViewController *weakController=controller;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(), ^{
            UIViewController *owner=weakController; if (!owner.view.window) return;
            NSMutableArray *queue=[NSMutableArray arrayWithObject:owner.view.window]; NSUInteger limit=1200, printed=0;
            while (queue.count && limit-- && printed<50) {
                UIView *view=queue.firstObject; [queue removeObjectAtIndex:0]; if (view.hidden || view.tag==947234) continue;
                CGRect rect=[view convertRect:view.bounds toView:owner.view.window];
                if (((rect.origin.y>=0 && rect.origin.y<240) || CGRectGetMaxY(rect)>owner.view.window.bounds.size.height-110) && rect.size.height>=16 && rect.size.height<=120) {
                    NSLog(@"[UYTNative] Home chrome class=%@ id=%@ frame=%@ saved=%d selected=%d",NSStringFromClass(view.class),view.accessibilityIdentifier ?: @"",NSStringFromCGRect(rect),[view.accessibilityLabel containsString:@"uYou"] || [view.accessibilityLabel containsString:@"Сохранённое"],(view.accessibilityTraits&UIAccessibilityTraitSelected)!=0); printed++;
                }
                [queue addObjectsFromArray:view.subviews];
            }
            UYTInstallHome(owner);
            UYTUpdateSavedTabsInView(owner.view.window);
        });
    }
    CGRect frame=controller.view.bounds; frame.origin.y=top; frame.size.height=MAX(0,frame.size.height-top-controller.view.safeAreaInsets.bottom);
    if (!CGRectEqualToRect(popular.view.frame,frame)) {
        popular.view.frame=frame;
        NSLog(@"[UYTNative] Public home mounted search-bottom=%.0f feed-top=%.0f",searchBottom,top);
    }
    [controller.view bringSubviewToFront:popular.view];
}
void UYTOpenPopularVideo(NSString *videoID, UIViewController *controller) {
    if (!UYTValidVideoID(videoID)) return;
    Class commandClass=NSClassFromString(@"YTICommand"), eventClass=NSClassFromString(@"YTCommandResponderEvent");
    SEL create=NSSelectorFromString(@"watchNavigationEndpointWithVideoID:"), factory=NSSelectorFromString(@"eventWithCommand:fromView:displayTitle:firstResponder:");
    @try {
        if ([commandClass respondsToSelector:create] && [eventClass respondsToSelector:factory]) {
            id command=((id(*)(id,SEL,id))objc_msgSend)(commandClass,create,videoID);
            id event=((id(*)(id,SEL,id,id,id,id))objc_msgSend)(eventClass,factory,command,controller.view,nil,controller.parentViewController);
            SEL send=NSSelectorFromString(@"send");
            if ([event respondsToSelector:send]) { ((void(*)(id,SEL))objc_msgSend)(event,send); return; }
        }
    } @catch (__unused NSException *e) {}
    [UIApplication.sharedApplication openURL:[NSURL URLWithString:[@"https://www.youtube.com/watch?v=" stringByAppendingString:videoID]] options:@{} completionHandler:nil];
}
%hook YTBrowseViewController
- (void)viewDidLayoutSubviews {
    %orig;
    UYTInstallHome((UIViewController *)self);
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    UYTInstallHome((UIViewController *)self);
}
%end
%hook YTNavigationBarTitleView
- (void)layoutSubviews {
    %orig;
    for (UIView *child in ((UIView *)self).subviews) if ([child.accessibilityIdentifier isEqual:@"id.yoodle.logo"]) child.hidden=YES;
}
%end
