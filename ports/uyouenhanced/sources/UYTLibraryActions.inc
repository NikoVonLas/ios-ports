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
@interface UYTLibraryMenuVC : UITableViewController
@property(nonatomic,copy) NSArray<UYTLibraryAction *> *actions;
@end
@implementation UYTLibraryMenuVC
- (void)viewDidLoad {
    [super viewDidLoad]; self.tableView.backgroundColor=UYTLibrarySurface(); self.tableView.tintColor=UIColor.whiteColor;
    self.tableView.separatorColor=[UIColor colorWithWhite:1 alpha:0.1]; self.tableView.rowHeight=48; self.tableView.tableFooterView=[UIView new];
    if (@available(iOS 13.0, *)) self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.actions.count+1; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)index {
    UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"action"];
    if (!cell) cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"action"];
    UYTLibraryAction *action=index.row<self.actions.count?self.actions[index.row]:nil;
    cell.textLabel.text=action?action.title:@"Отмена"; cell.textLabel.font=[UIFont systemFontOfSize:16];
    cell.textLabel.textColor=action.destructive?[UIColor colorWithRed:1 green:0.4 blue:0.4 alpha:1]:UIColor.whiteColor;
    cell.backgroundColor=UYTLibrarySurface(); UIView *selection=[UIView new]; selection.backgroundColor=[UIColor colorWithWhite:1 alpha:0.12]; cell.selectedBackgroundView=selection;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)index {
    UYTLibraryAction *action=index.row<self.actions.count?self.actions[index.row]:nil;
    [self dismissViewControllerAnimated:YES completion:^{ if (action.handler) action.handler(action); }];
}
@end
@interface UYTLibraryButton : UIButton
@property(nonatomic,copy) NSArray<UYTLibraryAction *> *actions;
@end
@implementation UYTLibraryButton
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self=[super initWithFrame:frame])) {
        self.tintColor=UIColor.whiteColor;
        [self setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        [self addTarget:self action:@selector(showActions) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}
- (void)showActions {
    UIResponder *responder = self;
    while (responder && ![responder isKindOfClass:UIViewController.class]) responder=responder.nextResponder;
    UIViewController *presenter=(UIViewController *)responder;
    if (!presenter || presenter.presentedViewController || !self.actions.count) return;
    UYTLibraryMenuVC *sheet=[[UYTLibraryMenuVC alloc] initWithStyle:UITableViewStylePlain]; sheet.actions=self.actions;
    sheet.modalPresentationStyle=UIModalPresentationPopover;
    sheet.preferredContentSize=CGSizeMake(300,MIN(480,(self.actions.count+1)*48));
    sheet.popoverPresentationController.backgroundColor=UYTLibrarySurface();
    sheet.popoverPresentationController.sourceView=self;
    sheet.popoverPresentationController.sourceRect=self.bounds;
    [presenter presentViewController:sheet animated:YES completion:nil];
}
@end
