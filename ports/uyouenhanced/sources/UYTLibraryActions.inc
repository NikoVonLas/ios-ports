@interface UYTLibraryAction : NSObject
@property(nonatomic,copy) NSString *title;
@property(nonatomic,copy) void (^handler)(UYTLibraryAction *);
@property(nonatomic) BOOL destructive;
+ (instancetype)actionWithTitle:(NSString *)title image:(UIImage *)image identifier:(id)identifier handler:(void (^)(UYTLibraryAction *))handler;
@end
@implementation UYTLibraryAction
+ (instancetype)actionWithTitle:(NSString *)title image:(UIImage *)image identifier:(id)identifier handler:(void (^)(UYTLibraryAction *))handler {
    UYTLibraryAction *action = [self new]; action.title=title; action.handler=handler; return action;
}
@end
@interface UYTLibraryButton : UIButton
@property(nonatomic,copy) NSArray<UYTLibraryAction *> *actions;
@end
@implementation UYTLibraryButton
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self=[super initWithFrame:frame])) [self addTarget:self action:@selector(showActions) forControlEvents:UIControlEventTouchUpInside];
    return self;
}
- (void)showActions {
    UIResponder *responder = self;
    while (responder && ![responder isKindOfClass:UIViewController.class]) responder=responder.nextResponder;
    UIViewController *presenter=(UIViewController *)responder;
    if (!presenter || presenter.presentedViewController || !self.actions.count) return;
    UIAlertController *sheet=[UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (UYTLibraryAction *action in self.actions) {
        [sheet addAction:[UIAlertAction actionWithTitle:action.title style:action.destructive?UIAlertActionStyleDestructive:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ if (action.handler) action.handler(action); }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView=self;
    sheet.popoverPresentationController.sourceRect=self.bounds;
    [presenter presentViewController:sheet animated:YES completion:nil];
}
@end
