#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "UYTShortsFilter.h"
static BOOL UYTShortsItem(id item) {
    for (NSString *name in @[@"hasReelShelfRenderer",@"hasReelItemRenderer"]) {
        SEL selector=NSSelectorFromString(name);
        if ([item respondsToSelector:selector] && ((BOOL(*)(id,SEL))objc_msgSend)(item,selector)) return YES;
    }
    return UYTShortsComponent([item description]);
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
    if (UYTShortsComponent([(id)self description])) return [NSData data];
    return %orig;
}
%end
