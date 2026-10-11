static UIImage *UYTLibraryMoreIcon(void) {
    UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(24,24)];
    return [[renderer imageWithActions:^(UIGraphicsImageRendererContext *context){
        [UIColor.whiteColor setFill];
        for (NSUInteger i=0;i<3;i++) [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(10.5,4.5+i*6,3,3)] fill];
    }] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}
static NSString *UYTLibraryDuration(double seconds) {
    if (!isfinite(seconds) || seconds<=0) return @"";
    NSInteger total=(NSInteger)floor(seconds), hours=total/3600, minutes=(total%3600)/60;
    return hours?[NSString stringWithFormat:@"%ld:%02ld:%02ld",(long)hours,(long)minutes,(long)(total%60)]:[NSString stringWithFormat:@"%ld:%02ld",(long)minutes,(long)(total%60)];
}
@interface UYTVideoCell : UICollectionViewCell
@property(nonatomic,strong) UIImageView *cover;
@property(nonatomic,strong) UILabel *nameLabel;
@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,strong) UILabel *durationLabel;
@property(nonatomic,strong) UIProgressView *progress;
@property(nonatomic,strong) UYTLibraryButton *more;
@property(nonatomic,copy) NSString *representedID;
@end
@implementation UYTVideoCell
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.cover = [UIImageView new]; self.cover.contentMode = UIViewContentModeScaleAspectFill;
        self.cover.clipsToBounds = YES; self.cover.layer.cornerRadius = 8;
        self.cover.backgroundColor = UYTLibrarySurface();
        self.nameLabel = [UILabel new]; self.nameLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium]; self.nameLabel.numberOfLines = 2;
        self.nameLabel.textColor=UIColor.whiteColor;
        self.statusLabel = [UILabel new]; self.statusLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium]; self.statusLabel.textColor = UIColor.whiteColor; self.statusLabel.textAlignment=NSTextAlignmentCenter; self.statusLabel.layer.cornerRadius=4; self.statusLabel.clipsToBounds=YES; self.statusLabel.hidden=YES;
        self.durationLabel=[UILabel new]; self.durationLabel.font=[UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightSemibold]; self.durationLabel.textColor=UIColor.whiteColor; self.durationLabel.backgroundColor=[UIColor colorWithWhite:0 alpha:0.8]; self.durationLabel.textAlignment=NSTextAlignmentCenter; self.durationLabel.layer.cornerRadius=4; self.durationLabel.clipsToBounds=YES;
        self.more = [[UYTLibraryButton alloc] initWithFrame:CGRectZero]; [self.more setImage:UYTLibraryMoreIcon() forState:UIControlStateNormal]; self.more.accessibilityLabel = @"Действия с видео";
        self.progress = [UIProgressView new]; self.progress.trackTintColor = [UIColor colorWithWhite:1 alpha:0.2]; self.progress.progressTintColor=UYTLibraryAccent();
        for (UIView *v in @[self.cover,self.nameLabel,self.statusLabel,self.durationLabel,self.more,self.progress]) { v.translatesAutoresizingMaskIntoConstraints = NO; [self.contentView addSubview:v]; }
        [NSLayoutConstraint activateConstraints:@[
            [self.cover.topAnchor constraintEqualToAnchor:self.contentView.topAnchor], [self.cover.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor], [self.cover.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor], [self.cover.heightAnchor constraintEqualToAnchor:self.cover.widthAnchor multiplier:9.0/16.0],
            [self.nameLabel.topAnchor constraintEqualToAnchor:self.cover.bottomAnchor constant:8], [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor], [self.nameLabel.trailingAnchor constraintEqualToAnchor:self.more.leadingAnchor constant:-4],
            [self.more.topAnchor constraintEqualToAnchor:self.cover.bottomAnchor], [self.more.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor], [self.more.widthAnchor constraintEqualToConstant:44], [self.more.heightAnchor constraintEqualToConstant:44],
            [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.cover.leadingAnchor constant:10], [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.cover.trailingAnchor constant:-10], [self.statusLabel.topAnchor constraintEqualToAnchor:self.cover.topAnchor constant:10], [self.statusLabel.heightAnchor constraintEqualToConstant:28],
            [self.durationLabel.trailingAnchor constraintEqualToAnchor:self.cover.trailingAnchor constant:-8], [self.durationLabel.bottomAnchor constraintEqualToAnchor:self.cover.bottomAnchor constant:-8], [self.durationLabel.heightAnchor constraintEqualToConstant:20], [self.durationLabel.widthAnchor constraintGreaterThanOrEqualToConstant:44],
            [self.progress.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor], [self.progress.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor], [self.progress.bottomAnchor constraintEqualToAnchor:self.cover.bottomAnchor], [self.progress.heightAnchor constraintEqualToConstant:3]
        ]];
    } return self;
}
- (void)prepareForReuse { [super prepareForReuse]; self.cover.image = nil; self.representedID = nil; self.more.actions = nil; self.statusLabel.hidden=YES; self.durationLabel.hidden=YES; self.durationLabel.text=nil; self.progress.hidden=YES; }
@end

static NSString *UYTThumbnailPath(NSString *videoID) {
    if (![videoID isKindOfClass:NSString.class] || videoID.length != 11 || [videoID rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"] invertedSet]].location != NSNotFound) return nil;
    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"UYTOffline/Covers"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return [dir stringByAppendingPathComponent:[videoID stringByAppendingPathExtension:@"jpg"]];
}

static NSUInteger UYTCoverCost(UIImage *image) { return (NSUInteger)(image.size.width*image.scale*image.size.height*image.scale*4); }
static void UYTFetchCover(NSString *videoID, NSUInteger variant, void (^completion)(UIImage *, NSData *)) {
    NSArray *names=@[@"maxresdefault",@"sddefault",@"hqdefault",@"mqdefault"];
    if (variant>=names.count) { completion(nil,nil); return; }
    NSURL *url=[NSURL URLWithString:[NSString stringWithFormat:@"https://i.ytimg.com/vi/%@/%@.jpg",videoID,names[variant]]];
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url]; request.timeoutInterval=12;
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
        UIImage *image=(!error && [(NSHTTPURLResponse *)response statusCode]==200 && data.length<=4*1024*1024)?[UIImage imageWithData:data]:nil;
        CGFloat width=image.size.width*image.scale;
        // Missing resolutions may return a small placeholder instead of HTTP 404.
        if (image && width>=(variant==3?160:480) && width<=4096) completion(image,data);
        else if (error) completion(nil,nil);
        else UYTFetchCover(videoID,variant+1,completion);
    }] resume];
}

@implementation UYTOfflineVC
- (void)viewDidLoad {
    [super viewDidLoad]; self.view.backgroundColor = UYTLibraryBackground(); self.view.tintColor=UIColor.whiteColor;
    if (@available(iOS 13.0, *)) self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
    self.title = @"Сохранённое"; self.visibleItems = @[]; self.coverRequests = [NSMutableSet set]; self.durationRequests=[NSMutableSet set]; self.coverCache = [NSCache new];
    self.coverCache.countLimit = 40; self.coverCache.totalCostLimit=24*1024*1024;
    UILabel *title = [UILabel new]; title.text = @"Сохранённое";
    title.textColor=UIColor.whiteColor;
    title.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    self.summaryLabel = [UILabel new]; self.summaryLabel.font = [UIFont systemFontOfSize:14]; self.summaryLabel.textColor = [UIColor colorWithRed:1 green:0.55 blue:0.55 alpha:1]; self.summaryLabel.hidden=YES;
    UIButton *options=[UIButton buttonWithType:UIButtonTypeSystem]; [options setImage:UYTIcon(@"gearshape") forState:UIControlStateNormal]; options.accessibilityLabel=@"Настройки SponsorBlock и дизлайков";
    [options addTarget:self action:@selector(showOptions) forControlEvents:UIControlEventTouchUpInside];
    [options.widthAnchor constraintEqualToConstant:44].active=YES;
    UIStackView *heading = [[UIStackView alloc] initWithArrangedSubviews:@[title,options]]; heading.alignment = UIStackViewAlignmentCenter; heading.spacing = 12;
    [options.heightAnchor constraintEqualToConstant:44].active=YES;
    options.tintColor=UIColor.whiteColor;
    self.search = [UITextField new]; self.search.delegate=self;
    self.search.textColor=UIColor.whiteColor; self.search.tintColor=UIColor.whiteColor;
    self.search.backgroundColor=UYTLibrarySurface(); self.search.layer.cornerRadius=8;
    self.search.font=[UIFont systemFontOfSize:16]; self.search.returnKeyType=UIReturnKeySearch;
    self.search.autocapitalizationType=UITextAutocapitalizationTypeNone; self.search.autocorrectionType=UITextAutocorrectionTypeNo;
    self.search.clearButtonMode=UITextFieldViewModeWhileEditing;
    self.search.attributedPlaceholder=[[NSAttributedString alloc] initWithString:@"Найти видео" attributes:@{NSForegroundColorAttributeName:UYTLibrarySecondaryText()}];
    UIView *searchInset=[[UIView alloc] initWithFrame:CGRectMake(0,0,40,44)];
    UIImageView *searchIcon=[[UIImageView alloc] initWithImage:UYTIcon(@"magnifyingglass")]; searchIcon.frame=CGRectMake(12,12,20,20); searchIcon.tintColor=UYTLibrarySecondaryText(); [searchInset addSubview:searchIcon];
    self.search.leftView=searchInset; self.search.leftViewMode=UITextFieldViewModeAlways;
    self.search.rightView=[[UIView alloc] initWithFrame:CGRectMake(0,0,12,44)]; self.search.rightViewMode=UITextFieldViewModeUnlessEditing;
    [self.search addTarget:self action:@selector(searchChanged:) forControlEvents:UIControlEventEditingChanged];
    [self.search.heightAnchor constraintEqualToConstant:44].active=YES;
    NSMutableArray *chips=[NSMutableArray array];
    for (NSString *text in @[@"Все",@"Скачанные",@"Загружаются"]) {
        UIButton *chip=[UIButton buttonWithType:UIButtonTypeSystem]; chip.tag=chips.count;
        [chip setTitle:text forState:UIControlStateNormal]; chip.titleLabel.font=[UIFont systemFontOfSize:14 weight:UIFontWeightMedium]; chip.layer.cornerRadius=8; chip.contentEdgeInsets=UIEdgeInsetsMake(0,12,0,12);
        [chip addTarget:self action:@selector(selectFilter:) forControlEvents:UIControlEventTouchUpInside];
        [chip setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [chips addObject:chip];
    }
    self.filterButtons=chips; self.selectedFilter=0;
    UIStackView *filters=[[UIStackView alloc] initWithArrangedSubviews:chips]; filters.spacing=8; filters.translatesAutoresizingMaskIntoConstraints=NO;
    UIScrollView *filterScroll=[UIScrollView new]; filterScroll.showsHorizontalScrollIndicator=NO; [filterScroll addSubview:filters];
    [NSLayoutConstraint activateConstraints:@[
        [filterScroll.heightAnchor constraintEqualToConstant:44],
        [filters.leadingAnchor constraintEqualToAnchor:filterScroll.contentLayoutGuide.leadingAnchor], [filters.trailingAnchor constraintEqualToAnchor:filterScroll.contentLayoutGuide.trailingAnchor],
        [filters.topAnchor constraintEqualToAnchor:filterScroll.contentLayoutGuide.topAnchor constant:4], [filters.bottomAnchor constraintEqualToAnchor:filterScroll.contentLayoutGuide.bottomAnchor constant:-4], [filterScroll.contentLayoutGuide.heightAnchor constraintEqualToAnchor:filterScroll.frameLayoutGuide.heightAnchor]
    ]];
    UYTLibraryButton *sort = [[UYTLibraryButton alloc] initWithFrame:CGRectZero]; [sort setImage:UYTIcon(@"arrow.up.arrow.down") forState:UIControlStateNormal]; sort.accessibilityLabel = @"Сортировка";
    __weak UYTOfflineVC *weakSelf = self;
    sort.actions = @[
        [UYTLibraryAction actionWithTitle:@"Сначала новые" image:nil identifier:nil handler:^(UYTLibraryAction *a){ weakSelf.sortByTitle = NO; [weakSelf refresh]; }],
        [UYTLibraryAction actionWithTitle:@"По названию" image:nil identifier:nil handler:^(UYTLibraryAction *a){ weakSelf.sortByTitle = YES; [weakSelf refresh]; }]];
    UIStackView *filterRow = [[UIStackView alloc] initWithArrangedSubviews:@[filterScroll,sort]]; filterRow.spacing = 12; [sort.widthAnchor constraintEqualToConstant:44].active = YES;
    UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[heading,self.summaryLabel,self.search,filterRow]]; header.axis = UILayoutConstraintAxisVertical; header.spacing = 8;
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new]; layout.minimumInteritemSpacing = 16; layout.minimumLineSpacing = 16;
    self.grid = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout]; self.grid.backgroundColor = UIColor.clearColor; self.grid.dataSource = self; self.grid.delegate = self; self.grid.alwaysBounceVertical = YES; self.grid.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.grid registerClass:UYTVideoCell.class forCellWithReuseIdentifier:@"video"];
    header.translatesAutoresizingMaskIntoConstraints = NO; self.grid.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:header]; [self.view addSubview:self.grid];
    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8], [header.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16], [header.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
        [self.grid.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:12], [self.grid.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16], [self.grid.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16], [self.grid.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
    if (self.modalLibrary) self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Готово" style:UIBarButtonItemStyleDone target:self action:@selector(close)];
    if (self.modalLibrary) { self.navigationController.navigationBar.tintColor=UIColor.whiteColor; self.navigationController.navigationBar.barStyle=UIBarStyleBlack; self.navigationController.navigationBar.barTintColor=UYTLibraryBackground(); }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh) name:UYTOfflineChanged object:nil];
    [self refresh];
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; if (fabs(self.lastWidth-self.grid.bounds.size.width)>1) { self.lastWidth=self.grid.bounds.size.width; [self.grid.collectionViewLayout invalidateLayout]; } }
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)showOptions {
    UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"SponsorBlock и дизлайки" message:@"SponsorBlock пропускает спонсорские вставки. Дизлайки — оценка Return YouTube Dislike, а не точная статистика YouTube." preferredStyle:UIAlertControllerStyleActionSheet];
    sheet.view.tintColor=UIColor.whiteColor;
    if (@available(iOS 13.0, *)) sheet.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
    BOOL sponsor=UYTSponsorEnabled();
    [sheet addAction:[UIAlertAction actionWithTitle:sponsor?@"Выключить SponsorBlock":@"Включить SponsorBlock" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ [NSUserDefaults.standardUserDefaults setBool:!sponsor forKey:@"UYT.sponsor.enabled"]; }]];
    id ryd=[NSUserDefaults.standardUserDefaults objectForKey:@"RYD-ENABLED"];
    BOOL enabled=ryd?[ryd boolValue]:YES;
    [sheet addAction:[UIAlertAction actionWithTitle:enabled?@"Выключить дизлайки":@"Включить дизлайки" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ [NSUserDefaults.standardUserDefaults setBool:!enabled forKey:@"RYD-ENABLED"]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Закрыть" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView=self.view;
    sheet.popoverPresentationController.sourceRect=CGRectMake(CGRectGetMidX(self.view.bounds),40,1,1);
    [self presentViewController:sheet animated:YES completion:nil];
}
- (void)selectFilter:(UIButton *)sender { self.selectedFilter=sender.tag; [self refresh]; }
- (void)searchChanged:(UITextField *)field { [self refresh]; }
- (BOOL)textFieldShouldReturn:(UITextField *)field { [field resignFirstResponder]; return YES; }
- (void)refresh {
    NSArray *all = [UYTOfflineStore shared].items; NSMutableArray *filtered = [NSMutableArray array]; NSInteger failed=0;
    for (UIButton *chip in self.filterButtons) {
        BOOL selected=chip.tag==self.selectedFilter; chip.selected=selected; chip.accessibilityTraits=UIAccessibilityTraitButton|(selected?UIAccessibilityTraitSelected:0);
        chip.backgroundColor=selected?UIColor.whiteColor:UYTLibrarySurface();
        [chip setTitleColor:selected?UYTLibraryBackground():UIColor.whiteColor forState:UIControlStateNormal];
        [chip setTitleColor:UYTLibraryBackground() forState:UIControlStateSelected];
    }
    NSString *query = [self.search.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    for (NSDictionary *item in all) {
        NSString *state = item[@"state"]; BOOL downloaded = [state isEqual:@"ready"]; BOOL active = [state isEqual:@"loading"] || [state isEqual:@"paused"] || [state isEqual:@"processing"] || [state isEqual:@"waiting"];
        failed += [state isEqual:@"failed"];
        if (self.selectedFilter==1 && !downloaded) continue;
        if (self.selectedFilter==2 && !active) continue;
        if (query.length && [item[@"title"] rangeOfString:query options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch].location==NSNotFound) continue;
        [filtered addObject:item];
    }
    if (self.sortByTitle) [filtered sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){ return [a[@"title"] localizedStandardCompare:b[@"title"]]; }];
    self.visibleItems = filtered;
    self.summaryLabel.hidden=failed==0;
    self.summaryLabel.text=failed?[NSString stringWithFormat:@"Не удалось скачать: %ld. Подробности в меню ролика.",(long)failed]:nil;
    if (!filtered.count) {
        UILabel *empty = [UILabel new]; empty.numberOfLines=0; empty.textAlignment=NSTextAlignmentCenter; empty.textColor=UYTLibrarySecondaryText(); empty.font=[UIFont systemFontOfSize:18];
        empty.text = query.length ? @"Ничего не найдено\nПопробуйте другое название" : self.selectedFilter==2 ? @"Сейчас ничего не загружается" : @"Здесь будут ваши видео\nСкачайте ролик стрелкой в плеере";
        self.grid.backgroundView=empty;
    } else self.grid.backgroundView=nil;
    [self.grid reloadData];
}
- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section { return self.visibleItems.count; }
- (CGSize)collectionView:(UICollectionView *)view layout:(UICollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)index {
    CGFloat width=view.bounds.size.width; NSInteger columns=width>=900?3:width>=560?2:1; CGFloat cellWidth=floor((width-16*(columns-1))/columns); return CGSizeMake(cellWidth,cellWidth*9/16+64);
}
- (void)loadCover:(NSDictionary *)item intoCell:(UYTVideoCell *)cell {
    NSString *videoID=item[@"videoID"]; NSString *path=UYTThumbnailPath(videoID);
    cell.cover.tintColor=UYTLibrarySecondaryText();
    UIImage *cached=videoID?[self.coverCache objectForKey:videoID]:nil;
    if (!cached && path) { cached=[UIImage imageWithContentsOfFile:path]; if (cached) [self.coverCache setObject:cached forKey:videoID cost:UYTCoverCost(cached)]; }
    cell.cover.image=cached?:UYTIcon(@"play.rectangle");
    cell.cover.contentMode=cached?UIViewContentModeScaleAspectFill:UIViewContentModeCenter;
    if ((cached && cached.size.width*cached.scale>=640) || !path || [self.coverRequests containsObject:videoID]) return;
    [self.coverRequests addObject:videoID];
    __weak UYTOfflineVC *weakSelf=self;
    CGFloat cachedWidth=cached.size.width*cached.scale;
    UYTFetchCover(videoID,0,^(UIImage *image,NSData *data){
        if (!image || image.size.width*image.scale<cachedWidth) return;
        [data writeToFile:path options:NSDataWritingAtomic error:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.coverCache setObject:image forKey:videoID cost:UYTCoverCost(image)];
            for (UYTVideoCell *visible in weakSelf.grid.visibleCells) if ([visible.representedID isEqual:videoID]) { visible.cover.image=image; visible.cover.contentMode=UIViewContentModeScaleAspectFill; }
        });
    });
}
- (void)loadDuration:(NSDictionary *)item intoCell:(UYTVideoCell *)cell {
    NSString *text=UYTLibraryDuration([item[@"duration"] doubleValue]);
    cell.durationLabel.text=text; cell.durationLabel.hidden=!text.length;
    NSString *identifier=item[@"id"], *videoID=item[@"videoID"];
    if (text.length || ![item[@"state"] isEqual:@"ready"] || !identifier || [self.durationRequests containsObject:identifier]) return;
    NSURL *url=[UYTOfflineStore.shared localURL:item]; if (!url) return;
    [self.durationRequests addObject:identifier];
    static dispatch_queue_t queue; static dispatch_once_t once;
    dispatch_once(&once, ^{ queue=dispatch_queue_create("com.nikovonlas.uyt.library-metadata",DISPATCH_QUEUE_SERIAL); });
    __weak UYTOfflineVC *weakSelf=self;
    dispatch_async(queue, ^{
        @autoreleasepool {
            AVURLAsset *asset=[AVURLAsset URLAssetWithURL:url options:@{AVURLAssetPreferPreciseDurationAndTimingKey:@NO}];
            double seconds=CMTimeGetSeconds(asset.duration); if (!isfinite(seconds) || seconds<=0) return;
            dispatch_async(dispatch_get_main_queue(), ^{
                NSMutableDictionary *current=[UYTOfflineStore.shared directItem:identifier]; if (!current) return;
                current[@"duration"]=@(seconds); [UYTOfflineStore.shared save];
                for (UYTVideoCell *visible in weakSelf.grid.visibleCells) if ([visible.representedID isEqual:videoID]) { visible.durationLabel.text=UYTLibraryDuration(seconds); visible.durationLabel.hidden=NO; }
            });
        }
    });
}
- (UICollectionViewCell *)collectionView:(UICollectionView *)view cellForItemAtIndexPath:(NSIndexPath *)index {
    UYTVideoCell *cell=[view dequeueReusableCellWithReuseIdentifier:@"video" forIndexPath:index]; NSDictionary *item=self.visibleItems[index.item]; NSString *state=item[@"state"];
    cell.representedID=item[@"videoID"]; cell.nameLabel.text=item[@"title"];
    BOOL active=[state isEqual:@"loading"] || [state isEqual:@"paused"] || [state isEqual:@"processing"] || [state isEqual:@"waiting"];
    BOOL failed=[state isEqual:@"failed"];
    cell.statusLabel.hidden=!failed; cell.statusLabel.text=failed?@"Не удалось скачать":nil;
    cell.statusLabel.backgroundColor=[UIColor colorWithRed:0.5 green:0.12 blue:0.15 alpha:0.95];
    cell.progress.hidden=!active; cell.progress.progress=[item[@"progress"] floatValue];
    cell.progress.progressTintColor=[state isEqual:@"paused"]?UYTLibrarySecondaryText():UYTLibraryAccent();
    [self loadDuration:item intoCell:cell];
    [self loadCover:item intoCell:cell];
    NSMutableArray *actions=[NSMutableArray array]; __weak UYTOfflineVC *weakSelf=self;
    if (active && ![state isEqual:@"processing"] && ![state isEqual:@"waiting"]) [actions addObject:[UYTLibraryAction actionWithTitle:[state isEqual:@"paused"]?@"Продолжить загрузку":@"Приостановить" image:nil identifier:nil handler:^(UYTLibraryAction *a){
        UYTOfflineStore *store=[UYTOfflineStore shared]; id task=store.tasks[item[@"id"]];
        if (task) { BOOL resume=[item[@"state"] isEqual:@"paused"]; if (resume) [task resume]; else [task suspend]; ((NSMutableDictionary *)item)[@"state"]=resume?@"loading":@"paused"; [store save]; }
    }]];
    [actions addObject:[UYTLibraryAction actionWithTitle:@"Открыть в YouTube" image:UYTIcon(@"arrow.up.right.square") identifier:nil handler:^(UYTLibraryAction *a){
        NSString *videoID=item[@"videoID"]; if (!UYTThumbnailPath(videoID)) return;
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://www.youtube.com/watch?v=%@",videoID]] options:@{} completionHandler:nil];
    }]];
    if ([state isEqual:@"failed"]) [actions addObject:[UYTLibraryAction actionWithTitle:@"Повторить скачивание" image:UYTIcon(@"arrow.clockwise") identifier:nil handler:^(UYTLibraryAction *a){ UYTDownloadFromMenu(item[@"videoID"],weakSelf); }]];
    if ([state isEqual:@"failed"] && [UYTOfflineStore.shared canPrepareItem:item]) [actions insertObject:[UYTLibraryAction actionWithTitle:@"Повторить подготовку" image:nil identifier:nil handler:^(UYTLibraryAction *a){ [UYTOfflineStore.shared mergeDirect:(NSMutableDictionary *)item]; }] atIndex:0];
    if ([state isEqual:@"failed"]) [actions addObject:[UYTLibraryAction actionWithTitle:@"Почему не скачалось" image:UYTIcon(@"info.circle") identifier:nil handler:^(UYTLibraryAction *a){
        UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Загрузка не завершена" message:item[@"error"] preferredStyle:UIAlertControllerStyleAlert];
        alert.view.tintColor=UIColor.whiteColor;
        [alert addAction:[UIAlertAction actionWithTitle:@"Понятно" style:UIAlertActionStyleDefault handler:nil]]; [weakSelf presentViewController:alert animated:YES completion:nil];
    }]];
    UYTLibraryAction *remove=[UYTLibraryAction actionWithTitle:active?@"Отменить и удалить":@"Удалить с iPad" image:UYTIcon(@"trash") identifier:nil handler:^(UYTLibraryAction *a){ [weakSelf deleteItem:item]; }]; remove.destructive=YES; [actions addObject:remove];
    cell.more.actions=actions; return cell;
}
- (void)deleteItem:(NSDictionary *)item {
    UYTOfflineStore *store=[UYTOfflineStore shared]; [store.tasks[item[@"id"]] cancel]; [store.tasks removeObjectForKey:item[@"id"]];
    [store.exports[item[@"id"]] cancelExport]; [store.exports removeObjectForKey:item[@"id"]];
    [store finishPreparation:item[@"id"]];
    if ([item[@"kind"] isEqual:@"direct"]) [[NSFileManager defaultManager] removeItemAtPath:[store directDirectory:item[@"id"]] error:nil];
    NSURL *url=[store localURL:item]; if (url) [[NSFileManager defaultManager] removeItemAtURL:url error:nil]; [store.items removeObject:(NSMutableDictionary *)item]; [store save];
}
- (void)collectionView:(UICollectionView *)view didSelectItemAtIndexPath:(NSIndexPath *)index {
    NSDictionary *item=self.visibleItems[index.item]; if (![item[@"state"] isEqual:@"ready"]) return;
    NSURL *url=[[UYTOfflineStore shared] localURL:item];
    if (!url || ![[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
        UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Видео не найдено" message:@"Файл был удалён. Откройте ролик в YouTube и скачайте его заново." preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Понятно" style:UIAlertActionStyleDefault handler:nil]]; [self presentViewController:a animated:YES completion:nil]; return;
    }
    UYTOfflinePlayer *player=[UYTOfflinePlayer new]; player.player=[AVPlayer playerWithURL:url]; [player configureSponsorForVideo:item[@"videoID"]];
    [self presentViewController:player animated:YES completion:^{[player.player play];}]; NSLog(@"[UYTNative] HLS playback from local file");
}
@end
