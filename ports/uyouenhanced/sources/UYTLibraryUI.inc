@interface UYTVideoCell : UICollectionViewCell
@property(nonatomic,strong) UIImageView *cover;
@property(nonatomic,strong) UILabel *nameLabel;
@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,strong) UIProgressView *progress;
@property(nonatomic,strong) UYTLibraryButton *more;
@property(nonatomic,copy) NSString *representedID;
@end
@implementation UYTVideoCell
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.cover = [UIImageView new]; self.cover.contentMode = UIViewContentModeScaleAspectFill;
        self.cover.clipsToBounds = YES; self.cover.layer.cornerRadius = 12;
        self.cover.backgroundColor = UYTColor(@"secondarySystemGroupedBackgroundColor");
        self.nameLabel = [UILabel new]; self.nameLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]; self.nameLabel.numberOfLines = 2;
        self.nameLabel.textColor=UYTColor(@"labelColor");
        self.statusLabel = [UILabel new]; self.statusLabel.font = [UIFont systemFontOfSize:14]; self.statusLabel.textColor = UIColor.whiteColor; self.statusLabel.textAlignment=NSTextAlignmentCenter; self.statusLabel.layer.cornerRadius=7; self.statusLabel.clipsToBounds=YES;
        self.more = [[UYTLibraryButton alloc] initWithFrame:CGRectZero]; [self.more setImage:UYTIcon(@"ellipsis") forState:UIControlStateNormal]; self.more.accessibilityLabel = @"Действия с видео";
        self.progress = [UIProgressView new]; self.progress.trackTintColor = UYTColor(@"tertiarySystemFillColor");
        for (UIView *v in @[self.cover,self.nameLabel,self.statusLabel,self.more,self.progress]) { v.translatesAutoresizingMaskIntoConstraints = NO; [self.contentView addSubview:v]; }
        [NSLayoutConstraint activateConstraints:@[
            [self.cover.topAnchor constraintEqualToAnchor:self.contentView.topAnchor], [self.cover.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor], [self.cover.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor], [self.cover.heightAnchor constraintEqualToAnchor:self.cover.widthAnchor multiplier:9.0/16.0],
            [self.nameLabel.topAnchor constraintEqualToAnchor:self.cover.bottomAnchor constant:10], [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor], [self.nameLabel.trailingAnchor constraintEqualToAnchor:self.more.leadingAnchor constant:-4],
            [self.more.topAnchor constraintEqualToAnchor:self.cover.bottomAnchor constant:4], [self.more.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:4], [self.more.widthAnchor constraintEqualToConstant:44], [self.more.heightAnchor constraintEqualToConstant:44],
            [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.cover.leadingAnchor constant:10], [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.cover.trailingAnchor constant:-10], [self.statusLabel.topAnchor constraintEqualToAnchor:self.cover.topAnchor constant:10], [self.statusLabel.heightAnchor constraintEqualToConstant:28],
            [self.progress.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor], [self.progress.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor], [self.progress.bottomAnchor constraintEqualToAnchor:self.cover.bottomAnchor constant:-2], [self.progress.heightAnchor constraintEqualToConstant:4]
        ]];
    } return self;
}
- (void)prepareForReuse { [super prepareForReuse]; self.cover.image = nil; self.representedID = nil; self.more.actions = nil; }
@end

static NSString *UYTThumbnailPath(NSString *videoID) {
    if (![videoID isKindOfClass:NSString.class] || videoID.length != 11 || [videoID rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"] invertedSet]].location != NSNotFound) return nil;
    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"UYTOffline/Covers"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return [dir stringByAppendingPathComponent:[videoID stringByAppendingPathExtension:@"jpg"]];
}

@implementation UYTOfflineVC
- (void)viewDidLoad {
    [super viewDidLoad]; self.view.backgroundColor = UYTColor(@"systemGroupedBackgroundColor");
    self.title = @"Сохранённое"; self.visibleItems = @[]; self.coverRequests = [NSMutableSet set]; self.coverCache = [NSCache new];
    self.coverCache.countLimit = 80;
    UILabel *title = [UILabel new]; title.text = @"Сохранённое";
    title.textColor=UYTColor(@"labelColor");
    title.font = [UIFont systemFontOfSize:32 weight:UIFontWeightBold];
    self.summaryLabel = [UILabel new]; self.summaryLabel.font = [UIFont systemFontOfSize:15]; self.summaryLabel.textColor = UYTColor(@"secondaryLabelColor");
    UIButton *help = [UIButton buttonWithType:UIButtonTypeSystem];
    [help setTitle:@"Как скачать" forState:UIControlStateNormal]; [help setImage:UYTIcon(@"arrow.down.circle") forState:UIControlStateNormal];
    [help addTarget:self action:@selector(showHelp) forControlEvents:UIControlEventTouchUpInside];
    UIButton *download=[UIButton buttonWithType:UIButtonTypeSystem]; [download setTitle:@"Скачать" forState:UIControlStateNormal];
    [download addTarget:self action:@selector(downloadLink) forControlEvents:UIControlEventTouchUpInside];
    UIButton *options=[UIButton buttonWithType:UIButtonTypeSystem]; [options setImage:UYTIcon(@"gearshape") forState:UIControlStateNormal]; options.accessibilityLabel=@"Настройки SponsorBlock и дизлайков";
    [options addTarget:self action:@selector(showOptions) forControlEvents:UIControlEventTouchUpInside];
    [options.widthAnchor constraintEqualToConstant:44].active=YES;
    UIStackView *heading = [[UIStackView alloc] initWithArrangedSubviews:@[title,download,help,options]]; heading.alignment = UIStackViewAlignmentCenter; heading.spacing = 12;
    [help setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    self.search = [UISearchBar new]; self.search.placeholder = @"Найти видео"; self.search.searchBarStyle = UISearchBarStyleMinimal; self.search.delegate = self; self.search.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.filters = [[UISegmentedControl alloc] initWithItems:@[@"Все",@"Скачанные",@"Загружаются"]]; self.filters.selectedSegmentIndex = 0;
    if (@available(iOS 13.0, *)) {} else { self.filters.tintColor=UIColor.whiteColor; }
    [self.filters addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    UYTLibraryButton *sort = [[UYTLibraryButton alloc] initWithFrame:CGRectZero]; [sort setImage:UYTIcon(@"arrow.up.arrow.down") forState:UIControlStateNormal]; sort.accessibilityLabel = @"Сортировка";
    __weak UYTOfflineVC *weakSelf = self;
    sort.actions = @[
        [UYTLibraryAction actionWithTitle:@"Сначала новые" image:nil identifier:nil handler:^(UYTLibraryAction *a){ weakSelf.sortByTitle = NO; [weakSelf refresh]; }],
        [UYTLibraryAction actionWithTitle:@"По названию" image:nil identifier:nil handler:^(UYTLibraryAction *a){ weakSelf.sortByTitle = YES; [weakSelf refresh]; }]];
    UIStackView *filterRow = [[UIStackView alloc] initWithArrangedSubviews:@[self.filters,sort]]; filterRow.spacing = 12; [sort.widthAnchor constraintEqualToConstant:44].active = YES;
    UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[heading,self.summaryLabel,self.search,filterRow]]; header.axis = UILayoutConstraintAxisVertical; header.spacing = 10;
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new]; layout.minimumInteritemSpacing = 20; layout.minimumLineSpacing = 24;
    self.grid = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout]; self.grid.backgroundColor = UIColor.clearColor; self.grid.dataSource = self; self.grid.delegate = self; self.grid.alwaysBounceVertical = YES; self.grid.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.grid registerClass:UYTVideoCell.class forCellWithReuseIdentifier:@"video"];
    header.translatesAutoresizingMaskIntoConstraints = NO; self.grid.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:header]; [self.view addSubview:self.grid];
    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:18], [header.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:24], [header.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-24],
        [self.grid.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:22], [self.grid.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:24], [self.grid.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-24], [self.grid.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
    if (self.modalLibrary) self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Готово" style:UIBarButtonItemStyleDone target:self action:@selector(close)];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh) name:UYTOfflineChanged object:nil];
    [self refresh];
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; if (fabs(self.lastWidth-self.grid.bounds.size.width)>1) { self.lastWidth=self.grid.bounds.size.width; [self.grid.collectionViewLayout invalidateLayout]; } }
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)showHelp {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Сохранить видео в дорогу" message:@"Нажмите многоточие рядом с роликом → «Скачать видео». Также можно скачать кнопкой uYou в плеере. Выберите качество и дождитесь статуса «Скачано».\n\nДля просмотра без интернета откройте эту вкладку и нажмите на обложку." preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Понятно" style:UIAlertActionStyleDefault handler:nil]]; [self presentViewController:a animated:YES completion:nil];
}
- (void)downloadLink {
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Скачать по ссылке" message:@"Вставьте ссылку на ролик YouTube." preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field){ field.placeholder=@"https://youtu.be/…"; field.keyboardType=UIKeyboardTypeURL; field.autocapitalizationType=UITextAutocapitalizationTypeNone; field.autocorrectionType=UITextAutocorrectionTypeNo; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Выбрать качество" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        NSString *input=[alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSString *videoID=UYTVideoIDFromInput(input);
        dispatch_async(dispatch_get_main_queue(), ^{ UYTDownloadFromMenu(videoID,self); });
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)showOptions {
    UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"SponsorBlock и дизлайки" message:@"SponsorBlock пропускает спонсорские вставки. Дизлайки — оценка Return YouTube Dislike, а не точная статистика YouTube." preferredStyle:UIAlertControllerStyleActionSheet];
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
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)text { [self refresh]; }
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar { [searchBar resignFirstResponder]; }
- (void)refresh {
    NSArray *all = [UYTOfflineStore shared].items; NSMutableArray *filtered = [NSMutableArray array]; NSInteger ready=0,loading=0,failed=0;
    NSString *query = [self.search.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    for (NSDictionary *item in all) {
        NSString *state = item[@"state"]; BOOL downloaded = [state isEqual:@"ready"]; BOOL active = [state isEqual:@"loading"] || [state isEqual:@"paused"] || [state isEqual:@"processing"];
        ready += downloaded; loading += active; failed += [state isEqual:@"failed"];
        if (self.filters.selectedSegmentIndex==1 && !downloaded) continue;
        if (self.filters.selectedSegmentIndex==2 && !active) continue;
        if (query.length && [item[@"title"] rangeOfString:query options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch].location==NSNotFound) continue;
        [filtered addObject:item];
    }
    if (self.sortByTitle) [filtered sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){ return [a[@"title"] localizedStandardCompare:b[@"title"]]; }];
    self.visibleItems = filtered;
    self.summaryLabel.text = failed ? [NSString stringWithFormat:@"Скачано: %ld · Загружается: %ld · Ошибки: %ld",(long)ready,(long)loading,(long)failed] : loading ? [NSString stringWithFormat:@"Скачано: %ld   Загружается: %ld",(long)ready,(long)loading] : ready ? @"Сохранённые видео доступны без интернета" : @"Соберите свою библиотеку для дороги";
    if (!filtered.count) {
        UILabel *empty = [UILabel new]; empty.numberOfLines=0; empty.textAlignment=NSTextAlignmentCenter; empty.textColor=UYTColor(@"secondaryLabelColor"); empty.font=[UIFont systemFontOfSize:18];
        empty.text = query.length ? @"Ничего не найдено\nПопробуйте другое название" : self.filters.selectedSegmentIndex==2 ? @"Сейчас ничего не загружается" : @"Здесь будут ваши видео\nНажмите многоточие у ролика → «Скачать видео»";
        self.grid.backgroundView=empty;
    } else self.grid.backgroundView=nil;
    [self.grid reloadData];
}
- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section { return self.visibleItems.count; }
- (CGSize)collectionView:(UICollectionView *)view layout:(UICollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)index {
    CGFloat width=view.bounds.size.width; NSInteger columns=width>=900?3:width>=560?2:1; CGFloat cellWidth=floor((width-20*(columns-1))/columns); return CGSizeMake(cellWidth,cellWidth*9/16+95);
}
- (void)loadCover:(NSDictionary *)item intoCell:(UYTVideoCell *)cell {
    NSString *videoID=item[@"videoID"]; NSString *path=UYTThumbnailPath(videoID);
    cell.cover.tintColor=UYTColor(@"tertiaryLabelColor");
    UIImage *cached = videoID ? [self.coverCache objectForKey:videoID] : nil;
    if (!cached && path) { cached=[UIImage imageWithContentsOfFile:path]; if (cached) [self.coverCache setObject:cached forKey:videoID]; }
    cell.cover.image=cached ?: UYTIcon(@"play.rectangle");
    cell.cover.contentMode=cached?UIViewContentModeScaleAspectFill:UIViewContentModeCenter;
    if (cached || !path || [self.coverRequests containsObject:videoID]) return;
    [self.coverRequests addObject:videoID];
    NSURL *url=[NSURL URLWithString:[NSString stringWithFormat:@"https://i.ytimg.com/vi/%@/mqdefault.jpg",videoID]];
    __weak UYTOfflineVC *weakSelf=self;
    [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
        if (error || [(NSHTTPURLResponse *)response statusCode]!=200 || data.length>2*1024*1024) return;
        UIImage *image=[UIImage imageWithData:data]; if (!image) return;
        [data writeToFile:path atomically:YES];
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.coverCache setObject:image forKey:videoID];
            for (UYTVideoCell *visible in weakSelf.grid.visibleCells) if ([visible.representedID isEqual:videoID]) { visible.cover.image=image; visible.cover.contentMode=UIViewContentModeScaleAspectFill; }
        });
    }] resume];
}
- (UICollectionViewCell *)collectionView:(UICollectionView *)view cellForItemAtIndexPath:(NSIndexPath *)index {
    UYTVideoCell *cell=[view dequeueReusableCellWithReuseIdentifier:@"video" forIndexPath:index]; NSDictionary *item=self.visibleItems[index.item]; NSString *state=item[@"state"];
    cell.representedID=item[@"videoID"]; cell.nameLabel.text=item[@"title"];
    BOOL active=[state isEqual:@"loading"] || [state isEqual:@"paused"] || [state isEqual:@"processing"];
    cell.statusLabel.text=[state isEqual:@"ready"]?@"Скачано · можно смотреть":[state isEqual:@"processing"]?@"Подготовка видео со звуком":[state isEqual:@"paused"]?@"На паузе":[state isEqual:@"loading"]?[NSString stringWithFormat:@"Скачивается: %.0f%%",[item[@"progress"] doubleValue]*100]:@"Не скачалось · откройте меню";
    cell.progress.hidden=!active; cell.progress.progress=[item[@"progress"] floatValue]; cell.statusLabel.textColor=UIColor.whiteColor; cell.statusLabel.backgroundColor=[([state isEqual:@"ready"]?UIColor.systemGreenColor:[state isEqual:@"failed"]?UIColor.systemRedColor:UIColor.systemBlueColor) colorWithAlphaComponent:0.92];
    [self loadCover:item intoCell:cell];
    NSMutableArray *actions=[NSMutableArray array]; __weak UYTOfflineVC *weakSelf=self;
    if (active && ![state isEqual:@"processing"]) [actions addObject:[UYTLibraryAction actionWithTitle:[state isEqual:@"paused"]?@"Продолжить загрузку":@"Приостановить" image:nil identifier:nil handler:^(UYTLibraryAction *a){
        UYTOfflineStore *store=[UYTOfflineStore shared]; id task=store.tasks[item[@"id"]];
        if (task) { BOOL resume=[item[@"state"] isEqual:@"paused"]; if (resume) [task resume]; else [task suspend]; ((NSMutableDictionary *)item)[@"state"]=resume?@"loading":@"paused"; [store save]; }
    }]];
    [actions addObject:[UYTLibraryAction actionWithTitle:@"Открыть в YouTube" image:UYTIcon(@"arrow.up.right.square") identifier:nil handler:^(UYTLibraryAction *a){
        NSString *videoID=item[@"videoID"]; if (!UYTThumbnailPath(videoID)) return;
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://www.youtube.com/watch?v=%@",videoID]] options:@{} completionHandler:nil];
    }]];
    if ([state isEqual:@"failed"]) [actions addObject:[UYTLibraryAction actionWithTitle:@"Повторить скачивание" image:UYTIcon(@"arrow.clockwise") identifier:nil handler:^(UYTLibraryAction *a){ UYTDownloadFromMenu(item[@"videoID"],weakSelf); }]];
    if ([state isEqual:@"failed"]) [actions addObject:[UYTLibraryAction actionWithTitle:@"Почему не скачалось" image:UYTIcon(@"info.circle") identifier:nil handler:^(UYTLibraryAction *a){
        UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Загрузка не завершена" message:item[@"error"] preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Понятно" style:UIAlertActionStyleDefault handler:nil]]; [weakSelf presentViewController:alert animated:YES completion:nil];
    }]];
    UYTLibraryAction *remove=[UYTLibraryAction actionWithTitle:active?@"Отменить и удалить":@"Удалить с iPad" image:UYTIcon(@"trash") identifier:nil handler:^(UYTLibraryAction *a){ [weakSelf deleteItem:item]; }]; remove.destructive=YES; [actions addObject:remove];
    cell.more.actions=actions; return cell;
}
- (void)deleteItem:(NSDictionary *)item {
    UYTOfflineStore *store=[UYTOfflineStore shared]; [store.tasks[item[@"id"]] cancel]; [store.tasks removeObjectForKey:item[@"id"]];
    [store.exports[item[@"id"]] cancelExport]; [store.exports removeObjectForKey:item[@"id"]];
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
