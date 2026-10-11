#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "UYTShortsFilter.h"
static char UYTShortsDataKey,UYTShortsResultKey;
static BOOL UYTShortsElement(id renderer,NSData *data) {
    if (objc_getAssociatedObject(renderer,&UYTShortsDataKey)==data) return [objc_getAssociatedObject(renderer,&UYTShortsResultKey) boolValue];
    BOOL shorts=UYTShortsData(data);
    objc_setAssociatedObject(renderer,&UYTShortsDataKey,data,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(renderer,&UYTShortsResultKey,@(shorts),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return shorts;
}
static BOOL UYTShortsItem(id item) {
    for (NSString *name in @[@"hasReelShelfRenderer",@"hasReelItemRenderer"]) {
        SEL selector=NSSelectorFromString(name);
        if ([item respondsToSelector:selector] && ((BOOL(*)(id,SEL))objc_msgSend)(item,selector)) return YES;
    }
    SEL has=NSSelectorFromString(@"hasElementRenderer"),get=NSSelectorFromString(@"elementRenderer");
    if ([item respondsToSelector:has] && ((BOOL(*)(id,SEL))objc_msgSend)(item,has) && [item respondsToSelector:get]) {
        id renderer=((id(*)(id,SEL))objc_msgSend)(item,get);
        SEL elementData=NSSelectorFromString(@"elementData");
        if ([renderer respondsToSelector:elementData]) {
            ((id(*)(id,SEL))objc_msgSend)(renderer,elementData);
            return [objc_getAssociatedObject(renderer,&UYTShortsResultKey) boolValue];
        }
    }
    return NO;
}
static id UYTRemoveShorts(id items) {
    if (![items isKindOfClass:NSMutableArray.class]) return items;
    NSIndexSet *remove=[items indexesOfObjectsPassingTest:^BOOL(id item,NSUInteger index,BOOL *stop){ return UYTShortsItem(item); }];
    if (remove.count) { [items removeObjectsAtIndexes:remove]; NSLog(@"[UYTNative] Shorts feed filtered removed=%lu",(unsigned long)remove.count); }
    return items;
}
%hook YTIItemSectionRenderer
- (id)contentsArray {
    id items=%orig;
    return UYTRemoveShorts(items);
}
%end
%hook YTIHorizontalListRenderer
- (id)itemsArray {
    id items=%orig;
    return UYTRemoveShorts(items);
}
%end
%hook YTIElementRenderer
- (NSData *)elementData {
    NSData *data=%orig;
    return UYTShortsElement(self,data)?[NSData data]:data;
}
%end
