void UYTDownloadFromMenu(NSString *videoID, UIViewController *presenter) {
    if (!presenter) return;
    if (!UYTValidVideoID(videoID)) {
        UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Не удалось определить ролик" message:@"Откройте меню нужного видео ещё раз и повторите скачивание." preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Понятно" style:UIAlertActionStyleDefault handler:nil]]; [presenter presentViewController:a animated:YES completion:nil];
        NSLog(@"[UYTNative] Menu download rejected: no unambiguous video ID"); return;
    }
    NSDictionary *body=@{@"context":@{@"client":@{@"clientName":@"ANDROID",@"clientVersion":@"21.08.266",@"androidSdkVersion":@30,@"osName":@"Android",@"osVersion":@"11",@"userAgent":@"com.google.android.youtube/21.08.266 (Linux; U; Android 11) gzip",@"hl":@"ru",@"gl":@"US"}},@"videoId":videoID,@"params":@"2AMB",@"playbackContext":@{@"contentPlaybackContext":@{@"html5Preference":@"HTML5_PREF_WANTS"}},@"contentCheckOk":@YES,@"racyCheckOk":@YES};
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://youtubei.googleapis.com/youtubei/v1/player?prettyPrint=false"]]; request.HTTPMethod=@"POST"; request.timeoutInterval=25;
    request.HTTPBody=[NSJSONSerialization dataWithJSONObject:body options:0 error:nil]; [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"com.google.android.youtube/21.08.266 (Linux; U; Android 11) gzip" forHTTPHeaderField:@"User-Agent"];
    UIAlertController *loading=[UIAlertController alertControllerWithTitle:@"Получаем варианты качества…" message:nil preferredStyle:UIAlertControllerStyleAlert];
    __block BOOL cancelled=NO; __block NSURLSessionDataTask *task=nil;
    [loading addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:^(UIAlertAction *a){ cancelled=YES; [task cancel]; task=nil; }]];
    [presenter presentViewController:loading animated:YES completion:nil];
    task=[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
        NSDictionary *json=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
        NSDictionary *formats=UYTDirectFormats(json,videoID);
        dispatch_async(dispatch_get_main_queue(), ^{
            task=nil;
            if (cancelled) return;
            [loading dismissViewControllerAnimated:YES completion:^{
                if (!formats) {
                    NSString *message=error?@"Не удалось связаться с YouTube. Проверьте подключение и повторите.":@"YouTube не предоставил доступные видео и звук. Этот ролик пока не получится скачать из списка.";
                    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Не удалось скачать" message:message preferredStyle:UIAlertControllerStyleAlert];
                    [a addAction:[UIAlertAction actionWithTitle:@"Понятно" style:UIAlertActionStyleDefault handler:nil]]; [presenter presentViewController:a animated:YES completion:nil];
                    NSLog(@"[UYTNative] Menu resolve failed http=%ld target=%@",(long)[(NSHTTPURLResponse *)response statusCode],videoID); return;
                }
                UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"Скачать видео" message:formats[@"title"] preferredStyle:UIAlertControllerStyleActionSheet];
                for (NSDictionary *video in formats[@"videos"]) {
                    NSString *label=[NSString stringWithFormat:@"%@p",video[@"height"]];
                    [sheet addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
                        [[UYTOfflineStore shared] startDirect:formats video:video];
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,400*NSEC_PER_MSEC),dispatch_get_main_queue(), ^{ UYTPresentLibrary(presenter); });
                    }]];
                }
                [sheet addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
                sheet.popoverPresentationController.sourceView=presenter.view; sheet.popoverPresentationController.sourceRect=CGRectMake(CGRectGetMidX(presenter.view.bounds),CGRectGetMidY(presenter.view.bounds),1,1);
                [presenter presentViewController:sheet animated:YES completion:nil];
                NSLog(@"[UYTNative] Menu resolve target verified=%@ qualities=%lu",videoID,(unsigned long)[formats[@"videos"] count]);
            }];
        });
    }];
    [task resume];
}
