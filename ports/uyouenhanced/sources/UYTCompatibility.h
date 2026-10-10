#import <UIKit/UIKit.h>

// Local fallbacks, deliberately scoped to this port (no UIKit swizzling).
static inline UIColor *UYTColor(NSString *name) {
    if (@available(iOS 13.0, *)) {
        SEL selector = NSSelectorFromString(name);
        if ([UIColor respondsToSelector:selector]) return [UIColor performSelector:selector];
    }
    if ([name containsString:@"Background"] || [name containsString:@"Fill"])
        return [UIColor colorWithWhite:[name hasPrefix:@"secondary"] ? 0.15 : 0.09 alpha:1];
    if ([name hasPrefix:@"secondary"] || [name hasPrefix:@"tertiary"])
        return [UIColor colorWithWhite:0.65 alpha:1];
    return UIColor.whiteColor;
}
static inline UIImage *UYTIcon(NSString *name) {
    if (@available(iOS 13.0, *)) return [UIImage systemImageNamed:name];
    NSDictionary *glyphs = @{@"ellipsis":@"•••", @"play.rectangle":@"▶", @"arrow.down.circle":@"↓", @"arrow.up.arrow.down":@"↕", @"gearshape":@"⚙"};
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(24,24)];
    return [[renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [(glyphs[name] ?: @"•") drawInRect:CGRectMake(0,0,24,24) withAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:18], NSForegroundColorAttributeName:UIColor.blackColor}];
    }] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}
static inline UIWindow *UYTKeyWindow(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes)
            if ([scene isKindOfClass:UIWindowScene.class] && scene.activationState == UISceneActivationStateForegroundActive)
                for (UIWindow *window in ((UIWindowScene *)scene).windows) if (window.isKeyWindow) return window;
    }
    for (UIWindow *window in UIApplication.sharedApplication.windows) if (window.isKeyWindow) return window;
    return UIApplication.sharedApplication.keyWindow;
}
