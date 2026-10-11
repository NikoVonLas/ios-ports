#import <UIKit/UIKit.h>
#import "UYTCompatibility.h"
#import <objc/message.h>

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
static void UYTStyleSavedTab(UIView *view) {
    id item=UYTSavedRead(view,@"renderer");
    if (!item) { @try { item=[view valueForKey:@"_item"]; } @catch (__unused NSException *e) {} }
    BOOL saved=UYTIsSavedName(UYTSavedRead(item,@"pivotIdentifier"));
    NSMutableArray<UIView *> *children=[NSMutableArray array]; UYTSavedDescendants(view,children);
    for (UIView *child in children) if ([child isKindOfClass:UILabel.class] && UYTIsSavedName(((UILabel *)child).text)) saved=YES;
    if (!saved) return;
    BOOL selected=(view.accessibilityTraits&UIAccessibilityTraitSelected)!=0;
    id navigation=UYTSavedRead(view,@"navigationButton");
    if ([navigation isKindOfClass:UIControl.class]) selected|=((UIControl *)navigation).selected;
    UIColor *tint=UYTColor(@"labelColor");
    for (UIView *child in children) if ([child isKindOfClass:UILabel.class]) {
        UILabel *label=(UILabel *)child;
        if (UYTIsSavedName(label.text)) { label.text=UYTSavedTitle; label.adjustsFontSizeToFitWidth=YES; label.minimumScaleFactor=0.75; tint=label.textColor; }
    }
    for (UIView *child in children) {
        if ([child isKindOfClass:UIButton.class] && UYTIsSavedName(((UIButton *)child).currentTitle)) {
            UIButton *button=(UIButton *)child;
            [button setTitle:UYTSavedTitle forState:UIControlStateNormal];
            [button setTitle:UYTSavedTitle forState:UIControlStateSelected];
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
