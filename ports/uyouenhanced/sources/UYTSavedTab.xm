#import <UIKit/UIKit.h>
#import "UYTCompatibility.h"
#import <objc/message.h>
#import <objc/runtime.h>

static NSString *const UYTSavedTitle = @"Сохранённое";
static id UYTSavedRead(id object, NSString *name) {
    SEL selector=NSSelectorFromString(name);
    if (![object respondsToSelector:selector]) return nil;
    NSMethodSignature *signature=[object methodSignatureForSelector:selector];
    if (!signature || signature.numberOfArguments!=2 || signature.methodReturnType[0]!='@') return nil;
    @try { return ((id(*)(id,SEL))objc_msgSend)(object,selector); } @catch (__unused NSException *e) { return nil; }
}
static UIImage *UYTDiskette(BOOL selected) {
    static UIImage *outline,*filled; static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(24,24)];
        UIImage *(^draw)(BOOL)=^UIImage *(BOOL fill){
            return [[renderer imageWithActions:^(UIGraphicsImageRendererContext *context){
                [UIColor.blackColor setStroke]; [UIColor.blackColor setFill];
                UIBezierPath *body=[UIBezierPath bezierPath];
                [body moveToPoint:CGPointMake(4,3)]; [body addLineToPoint:CGPointMake(17,3)];
                [body addLineToPoint:CGPointMake(21,7)]; [body addLineToPoint:CGPointMake(21,21)];
                [body addLineToPoint:CGPointMake(3,21)]; [body addLineToPoint:CGPointMake(3,4)]; [body closePath];
                body.lineWidth=1.8; body.lineJoinStyle=kCGLineJoinRound;
                if (fill) {
                    [body fill]; CGContextSetBlendMode(context.CGContext,kCGBlendModeClear);
                    [[UIBezierPath bezierPathWithRect:CGRectMake(7,3,8,6)] fill];
                    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(7,13,10,8) cornerRadius:1] fill];
                    CGContextSetBlendMode(context.CGContext,kCGBlendModeNormal);
                    [[UIBezierPath bezierPathWithRect:CGRectMake(12,4,2,4)] fill];
                } else {
                    [body stroke];
                    UIBezierPath *label=[UIBezierPath bezierPathWithRect:CGRectMake(7,3,8,6)]; label.lineWidth=1.5; [label stroke];
                    UIBezierPath *panel=[UIBezierPath bezierPathWithRoundedRect:CGRectMake(7,13,10,8) cornerRadius:1]; panel.lineWidth=1.5; [panel stroke];
                    [[UIBezierPath bezierPathWithRect:CGRectMake(12,4,2,4)] fill];
                }
            }] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        };
        outline=draw(NO); filled=draw(YES);
    });
    return selected?filled:outline;
}
static BOOL UYTIsSavedName(id name) {
    return [name isKindOfClass:NSString.class] && ([name isEqual:@"uYou"] || [name isEqual:@"com.miro.uyou"] || [name isEqual:UYTSavedTitle]);
}
// Normalise the model, not frames: YouTube can render the bar again after login
// or rotation, and uYou inserts its item while reading this same array.
static void UYTArrangeTabs(NSMutableArray *items) {
    if (![items isKindOfClass:NSMutableArray.class]) return;
    id saved=nil, account=nil;
    NSMutableArray *remove=[NSMutableArray array];
    NSMutableArray *identifiers=[NSMutableArray array];
    for (id support in [items copy]) {
        SEL onlySelector=NSSelectorFromString(@"hasPivotBarIconOnlyItemRenderer");
        BOOL iconOnly=[support respondsToSelector:onlySelector] && ((BOOL(*)(id,SEL))objc_msgSend)(support,onlySelector);
        id item=UYTSavedRead(support,iconOnly?@"pivotBarIconOnlyItemRenderer":@"pivotBarItemRenderer");
        NSString *identifier=UYTSavedRead(item,@"pivotIdentifier");
        if (![identifier isKindOfClass:NSString.class]) continue;
        [identifiers addObject:identifier];
        if ((iconOnly && !identifier.length) || [@[@"FEshorts",@"FEuploads",@"FEupload",@"FEcreation",@"FEcreate"] containsObject:identifier]) [remove addObject:support];
        if (UYTIsSavedName(identifier)) saved=support;
        if ([@[@"FEyou",@"FEaccount",@"FElibrary"] containsObject:identifier]) account=support;
    }
    [items removeObjectsInArray:remove];
    if (saved && account && [items indexOfObject:saved]+1!=[items indexOfObject:account]) {
        [items removeObjectIdenticalTo:saved];
        NSUInteger index=[items indexOfObjectIdenticalTo:account];
        if (index!=NSNotFound) [items insertObject:saved atIndex:index];
    }
    static NSString *last;
    NSString *signature=[identifiers componentsJoinedByString:@","];
    if (![last isEqual:signature]) {
        last=signature;
        NSLog(@"[UYTNative] Tabs source=%@ removed=%lu saved-before-account=%d",signature,(unsigned long)remove.count,saved && account);
    }
}
static void UYTSavedDescendants(UIView *view, NSMutableArray<UIView *> *result) {
    if (result.count>100) return;
    for (UIView *child in view.subviews) { [result addObject:child]; UYTSavedDescendants(child,result); }
}
static const void *UYTSavedViewKey=&UYTSavedViewKey;
static BOOL UYTIsSavedView(UIView *view) {
    if ([objc_getAssociatedObject(view,UYTSavedViewKey) boolValue] || UYTIsSavedName(view.accessibilityLabel) || [view.accessibilityLabel hasPrefix:@"Сохранённое,"] || [view.accessibilityLabel hasPrefix:@"uYou,"]) return YES;
    if (![NSStringFromClass(view.class) isEqual:@"YTPivotBarItemView"]) return NO;
    for (NSString *key in @[@"renderer",@"_item"]) {
        id item=UYTSavedRead(view,key);
        if (!item) { @try { item=[view valueForKey:key]; } @catch (__unused NSException *e) {} }
        if (UYTIsSavedName(UYTSavedRead(item,@"pivotIdentifier"))) return YES;
    }
    return NO;
}
static BOOL UYTSavedSelected(UIView *view) {
    id button=UYTSavedRead(view,@"navigationButton");
    return (view.accessibilityTraits&UIAccessibilityTraitSelected)!=0 || ([button isKindOfClass:UIControl.class] && ((UIControl *)button).selected);
}
static UIView *UYTSavedAncestor(UIView *view) {
    for (UIView *parent=view.superview;parent;parent=parent.superview)
        if ([NSStringFromClass(parent.class) isEqual:@"YTPivotBarItemView"]) return UYTIsSavedView(parent)?parent:nil;
    return nil;
}
static void UYTStyleSavedTab(UIView *view) {
    BOOL saved=UYTIsSavedView(view);
    NSMutableArray<UIView *> *children=[NSMutableArray array]; UYTSavedDescendants(view,children);
    for (UIView *child in children) if ([child isKindOfClass:UILabel.class] && UYTIsSavedName(((UILabel *)child).text)) saved=YES;
    if (!saved) return;
    objc_setAssociatedObject(view,UYTSavedViewKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    BOOL selected=UYTSavedSelected(view);
    id navigation=UYTSavedRead(view,@"navigationButton");
    if ([navigation isKindOfClass:UIControl.class]) selected|=((UIControl *)navigation).selected;
    UIColor *tint=UYTColor(@"labelColor");
    for (UIView *child in children) if ([child isKindOfClass:UILabel.class]) {
        UILabel *label=(UILabel *)child;
        if (UYTIsSavedName(label.text)) { label.text=UYTSavedTitle; label.adjustsFontSizeToFitWidth=YES; label.minimumScaleFactor=0.75; tint=label.textColor; }
    }
    for (UIView *child in children) {
        if ([child isKindOfClass:UIButton.class] && (child==navigation || ((UIButton *)child).currentImage || UYTIsSavedName(((UIButton *)child).currentTitle))) {
            UIButton *button=(UIButton *)child;
            if (UYTIsSavedName(button.currentTitle)) {
                [button setTitle:UYTSavedTitle forState:UIControlStateNormal];
                [button setTitle:UYTSavedTitle forState:UIControlStateSelected];
            }
            [button setImage:UYTDiskette(NO) forState:UIControlStateNormal];
            [button setImage:UYTDiskette(YES) forState:UIControlStateSelected];
        }
        if ([child isKindOfClass:UIImageView.class] && child.bounds.size.width>=16 && child.bounds.size.width<=40 && child.bounds.size.height>=16 && child.bounds.size.height<=40) {
            UIImageView *icon=(UIImageView *)child; icon.image=UYTDiskette(selected); icon.contentMode=UIViewContentModeScaleAspectFit; icon.tintColor=tint;
        }
        if (UYTIsSavedName(child.accessibilityLabel)) child.accessibilityLabel=UYTSavedTitle;
    }
    view.accessibilityLabel=UYTSavedTitle;
    static BOOL reported=NO; if (!reported) { reported=YES; NSLog(@"[UYTNative] Saved tab styled title=Сохранённое icon=diskette"); }
}

%hook YTIPivotBarRenderer
- (id)itemsArray {
    id items=%orig;
    UYTArrangeTabs(items);
    return items;
}
+ (id)pivotSupportedRenderersWithBrowseId:(id)browseId title:(id)title iconType:(int)iconType {
    if (UYTIsSavedName(title) || [browseId isEqual:@"uYou"]) title=UYTSavedTitle;
    return %orig(browseId,title,iconType);
}
%end

%hook YTPivotBarItemView
- (void)layoutSubviews {
    %orig;
    UYTStyleSavedTab((UIView *)self);
}
%end

// Native child buttons update their images after the pivot view's layout.
// Substitute at that update too, so returning to Home cannot restore uYou's glyph.
%hook UIImageView
- (void)setImage:(UIImage *)image {
    UIView *saved=UYTSavedAncestor((UIView *)self);
    if (saved && ((UIView *)self).bounds.size.width<=40 && ((UIView *)self).bounds.size.height<=40) image=UYTDiskette(UYTSavedSelected(saved));
    %orig(image);
}
%end
%hook YTQTMButton
- (void)setImage:(UIImage *)image {
    UIView *saved=UYTSavedAncestor((UIView *)self);
    if (saved) image=UYTDiskette(UYTSavedSelected(saved));
    %orig(image);
}
%end

static void UYTStyleElementsSavedTab(UIView *view) {
    if (!UYTIsSavedView(view) || view.bounds.size.height<20 || view.bounds.size.height>100) return;
    BOOL selected=UYTSavedSelected(view);
    NSMutableArray *children=[NSMutableArray array]; UYTSavedDescendants(view,children);
    UIView *target=nil;
    for (UIView *child in children) {
        if (child.tag==947235) continue;
        CGSize size=child.bounds.size;
        if (size.width>=20 && size.width<=36 && size.height>=20 && size.height<=36 && ![child isKindOfClass:UILabel.class]) { target=child; break; }
    }
    if (!target) return;
    UIView *host=target.superview;
    UIImageView *icon=(UIImageView *)[host viewWithTag:947235];
    if (!icon) {
        icon=[UIImageView new]; icon.tag=947235; icon.userInteractionEnabled=NO;
        icon.isAccessibilityElement=NO;
        [host addSubview:icon];
    }
    icon.frame=[target convertRect:target.bounds toView:host]; target.hidden=YES;
    icon.contentMode=UIViewContentModeScaleAspectFit; icon.tintColor=UIColor.whiteColor; icon.image=UYTDiskette(selected);
    [host bringSubviewToFront:icon];
    static BOOL reported=NO; if (!reported) { reported=YES; NSLog(@"[UYTNative] Elements Saved icon mounted class=%@ selected=%d",NSStringFromClass(view.class),selected); }
}
void UYTUpdateSavedTabsInView(UIView *root) {
    if (!root) return;
    NSMutableArray *queue=[NSMutableArray arrayWithObject:root]; NSUInteger remaining=1200;
    while (queue.count && remaining--) {
        UIView *view=queue.firstObject; [queue removeObjectAtIndex:0];
        if (view.hidden || view.tag==947234 || view.tag==947235) continue;
        CGRect frame=[view convertRect:view.bounds toView:view.window ?: root];
        if (CGRectGetMaxY(frame)>(view.window ?: root).bounds.size.height-110 && UYTIsSavedView(view)) {
            if ([NSStringFromClass(view.class) isEqual:@"YTPivotBarItemView"]) UYTStyleSavedTab(view);
            else UYTStyleElementsSavedTab(view);
        }
        [queue addObjectsFromArray:view.subviews];
    }
}
%hook YTPivotBarView
- (void)layoutSubviews {
    %orig;
    UYTUpdateSavedTabsInView((UIView *)self);
}
%end
%hook _ASDisplayView
- (void)layoutSubviews {
    %orig;
    UIView *view=(UIView *)self;
    if (view.window && view.bounds.size.height>=20 && view.bounds.size.height<=100 && CGRectGetMaxY([view convertRect:view.bounds toView:view.window])>view.window.bounds.size.height-110 && UYTIsSavedView(view)) UYTStyleElementsSavedTab(view);
}
%end
