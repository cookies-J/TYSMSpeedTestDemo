//
//  MLSpeedTest.m
//  MLife
//
//  Created by jele lam on 13/1/2020.
//  Copyright © 2020 CookiesJ. All rights reserved.
//

#import "MLSpeedTest.h"
#import "XMLDictionary.h"
#import "MLSpeedTestModel.h"
#import "FCFileManager.h"

static NSString const *kTYSMSpeedTestServerConfigFileName = @"speedtest-config";
static NSString const *kTYSMSpeedTestServerStaticFileName = @"speedtest-servers-static";

@interface MLSpeedTest () <NSURLSessionDataDelegate>
@property (nonatomic, strong) dispatch_queue_t speed_test_queue;
@property (nonatomic, strong) dispatch_semaphore_t speed_test_sema;
@property (nonatomic, strong) dispatch_group_t speed_test_group;
@property (nonatomic, assign) NSInteger step;

@property (nonatomic, strong) NSURLSessionConfiguration *sessionConfig;
@property (nonatomic, strong) NSURLSession *session;

@property (nonatomic, strong) MLSpeedTestModel *model;
/**
 获取服务器配置请求任务
 @discussion 在此处声明的原因是让用户可以手动停止正在进行的网络请求
 */
@property (nonatomic, strong) NSURLSessionTask *configServerTasks;

/**
获取服务器延时请求任务
@discussion 在此处声明的原因是让用户可以手动停止正在进行的网络请求
*/
@property (nonatomic, strong) NSArray <NSURLSessionTask *> *latencyServerTasks;


/**
获取服务器下载任务
@discussion 在此处声明的原因是让用户可以手动停止正在进行的网络请求
*/
@property (nonatomic, strong) NSArray <NSURLSessionDataTask *> *downloadServerTasks;

/**
获取服务器上传任务
@discussion 在此处声明的原因是让用户可以手动停止正在进行的网络请求
*/
@property (nonatomic, strong) NSArray <NSURLSessionDataTask *> *uploadServerTasks;


/// 服务器列表(按距离由近至远排序）
@property (nonatomic, strong) NSArray *bestServers;

/// 测试服务器列表(按延迟时间排序)
@property (nonatomic, strong) NSArray *testServers;


@end

@implementation MLSpeedTest

- (instancetype)initWithQueue:(nullable dispatch_queue_t)queue {
    if (self = [super init]) {
        if (queue != nil) {
            self.speed_test_queue = queue;
        } else {
            self.speed_test_queue = dispatch_queue_create("speed_test_queue", DISPATCH_QUEUE_CONCURRENT);
        }
        
        self.speed_test_group = dispatch_group_create();
        self.speed_test_sema = dispatch_semaphore_create(6);
        
//        dispatch_async(self.speed_test_queue, ^{
//            self.bestServers = [self prepareBestServers];
//        });
        
        
    }
    return self;
}


- (void)startTestLatency:(TYSMSpeedTestResultBlock)result {
    // 取出 100 个服务器
    // 可变数组，需要对里面增加延时计算操作
    NSMutableArray *mServers = [NSMutableArray arrayWithArray:[self.bestServers subarrayWithRange:NSMakeRange(0, 100)]];
   
    // 进行延时测试
    NSMutableArray <NSURLSessionTask*> *mLatencyServerTask = [NSMutableArray array];
    
    [mServers enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSURL *URL = [NSURL URLWithString:obj[@"_url"]];
        
        NSURLSessionTask *serverTask = [self.session dataTaskWithURL:URL completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (error) {
                obj[@"latencyTime"] = @(2001);
                dispatch_group_leave(self.speed_test_group);
                return ;
            }
            
            if (((NSHTTPURLResponse*)response).statusCode != 200) {
                obj[@"latencyTime"] = @(2000);
                dispatch_group_leave(self.speed_test_group);
                return ;
            }
            
//            NSLog(@"%zu:%@\n %@\n%@",idx,URL ,response,[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            obj[@"latencyTime"] = @(@(CFAbsoluteTimeGetCurrent()).doubleValue - [obj[@"latencyTime"] doubleValue]);
            dispatch_group_leave(self.speed_test_group);
        }];
        [mLatencyServerTask addObject:serverTask];
    }];
    
    self.latencyServerTasks = [mLatencyServerTask copy];
    
    [mLatencyServerTask removeAllObjects];
    mLatencyServerTask = nil;
    
    
    
    
    for (NSInteger idx = 0 ;idx < self.latencyServerTasks.count; idx ++) {
        dispatch_group_enter(self.speed_test_group);
        
        dispatch_group_async(self.speed_test_group, self.speed_test_queue, ^{
//            CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
            mServers[idx][@"latencyTime"] = @(CFAbsoluteTimeGetCurrent());
//            DDLogDebug(@"正在测试第 %zu 条：%@ %@",idx,mServers[idx][@"_url"],[NSThread currentThread]);
            [self.latencyServerTasks[idx] resume];
            
        });
    }
    
    dispatch_group_notify(self.speed_test_group, dispatch_get_main_queue(), ^{
        
        //    从延时最短到长方式从新排序服务器列表。
        [mServers sortWithOptions:NSSortConcurrent usingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            return [obj1[@"latencyTime"] compare:obj2[@"latencyTime"]];
        }];
            
//        过滤服务器
        __block NSRange arrayRange = NSMakeRange(0, 0);
        [mServers enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj[@"latencyTime"] integerValue] == 2000 ||
                [obj[@"latencyTime"] integerValue] == 2001) {
            } else {
//                DDLogDebug(@"在 %lu 位置结束",idx+1);
                arrayRange = NSMakeRange(0, idx+1);
                *stop = YES;
            }
        }];
        
        self.testServers = [mServers subarrayWithRange:arrayRange];
        [mServers removeAllObjects];
        NSLog(@"得到 %lu 个测试服务器： %@",self.testServers.count,self.testServers);

        result();
    });
    
}

- (void)nStartTestDownload:(TYSMSpeedTestResultBlock)result {
    NSMutableArray <NSURL *> *mURLs = [NSMutableArray array];
    NSString *testHostString = self.testServers.firstObject[@"_host"];
    
    for (NSNumber *size in self.model.sizes.downloadSizes) {
        NSString *urlStr = [NSString stringWithFormat:@"http://%@/random%@x%@.jpg?x=%.1f",
        testHostString,
        size.stringValue ,size.stringValue,
        CFAbsoluteTimeGetCurrent()
        ];
        
        dispatch_apply(self.model.counts.downloadCount.intValue, self.speed_test_queue, ^(size_t idx) {
            [mURLs addObject:[NSURL URLWithString:urlStr]];
        });
    }
    
    
}

- (void)startTestDownload:(TYSMSpeedTestResultBlock)result {
    // 下载块大小
    NSArray *downSize = @[@"350", @"500", @"750", @"1000", @"1500", @"2000", @"2500",@"3000", @"3500", @"4000"];
    
    // 配置下载链接
    NSMutableArray <NSURL *> *mURLs = [NSMutableArray array];
    
    NSString *testHostString = self.testServers.firstObject[@"_host"];
    
    NSMutableArray <NSMutableURLRequest *> *mRequests = [NSMutableArray array];
    
    
    for (NSNumber *size in self.model.sizes.downloadSizes) {
        NSString *urlStr = [NSString stringWithFormat:@"http://%@/random%@x%@.jpg?x=%.1f",
        testHostString,
        size.stringValue ,size.stringValue,
        CFAbsoluteTimeGetCurrent()
        ];
        
        
        dispatch_apply(self.model.counts.downloadCount.intValue, dispatch_queue_create("serial_queue", DISPATCH_QUEUE_SERIAL), ^(size_t idx) {
            [mURLs addObject:[NSURL URLWithString:urlStr]];
            
            NSMutableURLRequest *mRequest = [NSMutableURLRequest requestWithURL:mURLs.lastObject cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:CLTimeIntervalMax];
            [mRequest setHTTPMethod:@"GET"];
            [mRequest setAllowsCellularAccess:YES];
            [mRequest setTimeoutInterval:self.model.lengths.downloadLength.integerValue];
            
            [mRequest addValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];
            [mRequest addValue:@"Mozilla/5.0 (Darwin-18.5.0-x86_64-i386-64bit; U; 64bit; en-us) Python/2.7.10 (KHTML, like Gecko) speedtest-cli/2.1.1"
            forHTTPHeaderField:@"User-Agent"];
            
            [mRequests addObject:mRequest];
        });
        
        
    }
    
//    [downSize enumerateObjectsUsingBlock:^(NSString * _Nonnull size, NSUInteger idx, BOOL * _Nonnull stop) {
//
//        NSString *urlStr = [NSString stringWithFormat:@"http://%@/random%@x%@.jpg?x=%.1f",
//                            testHostString,
//                            size,size,
//                            CFAbsoluteTimeGetCurrent()
//                            ];
//        [mURLs addObject:[NSURL URLWithString:urlStr]];
//
//        NSMutableURLRequest *mRequest = [NSMutableURLRequest requestWithURL:mURLs.lastObject cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:CLTimeIntervalMax];
//        [mRequest setHTTPMethod:@"GET"];
//        [mRequest setAllowsCellularAccess:YES];
//        [mRequest addValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];
//        [mRequest addValue:@"Mozilla/5.0 (Darwin-18.5.0-x86_64-i386-64bit; U; 64bit; en-us) Python/2.7.10 (KHTML, like Gecko) speedtest-cli/2.1.1"
//        forHTTPHeaderField:@"User-Agent"];
//
//        [mRequests addObject:mRequest];
//    }];
    
    // 进行下载测试
    NSMutableArray <NSURLSessionDataTask*> *mDownloadServerTask = [NSMutableArray array];
    
//    NSURLSession *session = [NSURLSession sessionWithConfiguration:self.sessionConfig delegate:self delegateQueue:[[NSOperationQueue alloc] init]];
    
//    [mRequests enumerateObjectsUsingBlock:^(NSMutableURLRequest * _Nonnull mRequest, NSUInteger idx, BOOL * _Nonnull stop) {
//        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:mRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
//            if (error) {
//                // DDLogError(@"%@",error);
//                dispatch_group_leave(self.speed_test_group);
//                return;
//            }
//
//            NSLog(@"%lu",data.length);
//            dispatch_group_leave(self.speed_test_group);
//        }];
//       
////        NSURLSessionDataTask *task = [session dataTaskWithRequest:mRequest];
//        
//        [mDownloadServerTask addObject:task];
//    }];
    __block NSUInteger dataLen = 0;
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    
    for (NSInteger idx = 0; idx < 200; idx ++) {
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:mRequests[1] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (error) {
//                // DDLogError(@"%@",error);
                dispatch_group_leave(self.speed_test_group);
                return;
            }
            
            
            dataLen += data.length;
            
            NSLog(@"%.1f M",(dataLen /( CFAbsoluteTimeGetCurrent() - startTime))/ 1000.0/1000.0);
            
            dispatch_group_leave(self.speed_test_group);
        }];
        
        //        NSURLSessionDataTask *task = [session dataTaskWithRequest:mRequest];
        
        [mDownloadServerTask addObject:task];
    }
    
    self.downloadServerTasks = [mDownloadServerTask copy];
    [mDownloadServerTask removeAllObjects];
    mDownloadServerTask = nil;
    
    for (NSURLSessionTask *task in self.downloadServerTasks) {
    
        dispatch_group_enter(self.speed_test_group);
     
        dispatch_group_async(self.speed_test_group, self.speed_test_queue, ^{
            [task resume];
        });
        
    }
    
    dispatch_group_notify(self.speed_test_group, dispatch_get_main_queue(), ^{
        NSLog(@"============测试下载功能结束==========");
        result();
    });
    
    
}

- (void)startTestUpload:(TYSMSpeedTestResultBlock)result {
    
    NSString *testHostString = self.testServers.firstObject[@"_url"];
    NSMutableArray <NSMutableURLRequest *> *mRequests = [NSMutableArray array];

//    NSURL *URL = [NSURL URLWithString:[@"http://" stringByAppendingString:testHostString]];
    NSURL *URL = [NSURL URLWithString:testHostString];
    for (NSNumber *size in self.model.sizes.uploadSizes) {
        
        dispatch_apply(self.model.maxUpload.intValue, dispatch_queue_create("serial_queue", DISPATCH_QUEUE_SERIAL), ^(size_t idx) {

            NSMutableURLRequest *mRequest = [NSMutableURLRequest requestWithURL:URL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:CLTimeIntervalMax];
            [mRequest setHTTPMethod:@"POST"];
            [mRequest setAllowsCellularAccess:YES];
            [mRequest setTimeoutInterval:self.model.lengths.uploadLength.integerValue];
            [mRequest addValue:size.stringValue forHTTPHeaderField:@"Content-length"];
            [mRequest addValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];
            [mRequest addValue:@"Mozilla/5.0 (Darwin-18.5.0-x86_64-i386-64bit; U; 64bit; en-us) Python/2.7.10 (KHTML, like Gecko) speedtest-cli/2.1.1"
            forHTTPHeaderField:@"User-Agent"];

            [mRequest setHTTPBody:[NSMutableData dataWithLength:size.integerValue]];
            [mRequests addObject:mRequest];
            
        });
        
    }
    
    NSMutableArray <NSURLSessionDataTask*> *mUploadServerTask = [NSMutableArray array];
    __block NSUInteger dataLen = 0;
    
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    
    [mRequests enumerateObjectsUsingBlock:^(NSMutableURLRequest * _Nonnull request, NSUInteger idx, BOOL * _Nonnull stop) {
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (error) {
//                // DDLogError(@"%@",error);
                dispatch_group_leave(self.speed_test_group);
                return;
            }
            
            dataLen += request.HTTPBody.length;

            NSLog(@"%.1f M",(dataLen /( CFAbsoluteTimeGetCurrent() - startTime))/ 1000.0/1000.0);
            dispatch_group_leave(self.speed_test_group);
        }];
        
        [mUploadServerTask addObject:task];
    }];
    
    self.uploadServerTasks = [mUploadServerTask copy];
    [mUploadServerTask removeAllObjects];
    mUploadServerTask = nil;
    
    [mRequests enumerateObjectsUsingBlock:^(NSMutableURLRequest * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        dispatch_group_enter(self.speed_test_group);
        
        dispatch_group_async(self.speed_test_group, self.speed_test_queue, ^{
            [self.uploadServerTasks[idx] resume];
        });
        
    }];
    
    dispatch_group_notify(self.speed_test_group, dispatch_get_main_queue(), ^{
        NSLog(@"============测试上传功能结束==========");
        result();
    });
}

- (void)stopTest:(TYSMSpeedTestResultBlock)result {
//    DDLogDebug(@"停止所有任务");
    if (self.configServerTasks.state != NSURLSessionTaskStateCompleted) {
        [self.configServerTasks cancel];
        NSLog(@"停止准备服务器");
    }
    
    [self.downloadServerTasks enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(NSURLSessionTask * _Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
        if (task.state != NSURLSessionTaskStateCompleted) {
            [task suspend];
            [task cancel];
        }
    }];
    
    self.downloadServerTasks = nil;
    self.configServerTasks = nil;
    result();
}

- (void)suspendTest:(TYSMSpeedTestResultBlock)result {
    [self.downloadServerTasks enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(NSURLSessionTask * _Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
        if (task.state == NSURLSessionTaskStateRunning) {
            [task suspend];
        }
    }];
    
    result();

}

- (void)resumeTest:(TYSMSpeedTestResultBlock)result {
    [self.downloadServerTasks enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(NSURLSessionTask * _Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
        if (task.state == NSURLSessionTaskStateSuspended) {
            [task resume];
        }
    }];
    
    result();

}


#pragma mark - 初始化服务器
- (void)prepareTestServer:(TYSMSpeedTestResultBlock)result {
//- (NSArray *)prepareBestServers {
    
    // DDLogDebug(@"开始");
    
    // TODO: 获取当前 ip 地址，得到坐标
    NSError *fileError = nil;
    __block NSDictionary *serverConfigDic = [NSDictionary dictionaryWithXMLData:[FCFileManager readFileAtPathAsData:kTYSMSpeedTestServerConfigFileName error:&fileError]];
    
    if (fileError) {
        // DDLogError(@"%@",fileError);
    }
    
    if (serverConfigDic == nil) {
        
        NSMutableURLRequest *request =[[NSMutableURLRequest alloc] init];
        [request setHTTPMethod:@"GET"];
        [request setValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];
        [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
        [request setAllowsCellularAccess:YES];
        [request setTimeoutInterval:5];
        [request setURL:[NSURL URLWithString:@"https://www.speedtest.net/speedtest-config.php"]];
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        NSLog(@"准备请求");
        self.configServerTasks = [self.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            NSLog(@"得到数据");
            if (error) {
                // DDLogError(@"%@",error);
                dispatch_semaphore_signal(sema);
                return;
            }
            
            [FCFileManager createFileAtPath:kTYSMSpeedTestServerConfigFileName
                                withContent:data
                                  overwrite:YES
                                      error:&error];
            
            serverConfigDic = [NSDictionary dictionaryWithXMLData:data];
            
            if (error) {
                // DDLogError(@"%@",error);
            }
            
            dispatch_semaphore_signal(sema);
        }];
        
        [self.configServerTasks resume];
        NSLog(@"等待数据");
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    }
    NSLog(@"本地 IP 信息\n%@",serverConfigDic[@"client"]);
    
    self.model = [MLSpeedTestModel modelWithDictionary:serverConfigDic];
    [self.model configure];
    
    // TODO: 打开本地保存的服务器列表
    NSDictionary *xmlDic = [NSDictionary dictionaryWithXMLFile:[[NSBundle mainBundle] pathForResource:kTYSMSpeedTestServerStaticFileName ofType:@"xml"]];
    
    NSMutableDictionary *mServerStaticDic = [NSMutableDictionary dictionaryWithDictionary:xmlDic];
    
    NSArray *array = [mServerStaticDic[@"servers"][@"server"] copy];
    
    // 计算每个服务器坐标与本机 IP 坐标的距离
    CGFloat lat = ((NSString *) serverConfigDic[@"client"][@"_lat"]).doubleValue;
    CGFloat lon = ((NSString *) serverConfigDic[@"client"][@"_lon"]).doubleValue;
    CLLocation *myIPLocation = [[CLLocation alloc] initWithLatitude:lat longitude:lon];
    
    // 串行队列，用于同步写入
    dispatch_queue_t rw_serial_queue = dispatch_queue_create("rw_serial_queue", DISPATCH_QUEUE_SERIAL);
    dispatch_apply(array.count, rw_serial_queue, ^(size_t idx) {
        @autoreleasepool {
            CGFloat lat = ((NSString *) array[idx][@"_lat"]).doubleValue;
            CGFloat lon = ((NSString *) array[idx][@"_lon"]).doubleValue;
            CLLocation *currentLocation = [[CLLocation alloc] initWithLatitude:lat longitude:lon];
            mServerStaticDic[@"servers"][@"server"][idx][@"distance"] = @([myIPLocation distanceFromLocation:currentLocation]);
        }
    });
    
    //    从近到远的方式从新排序服务器列表。
    [mServerStaticDic[@"servers"][@"server"] sortWithOptions:NSSortConcurrent usingComparator:^NSComparisonResult(NSDictionary  *_Nonnull obj1, NSDictionary *_Nonnull obj2) {
        return [obj1[@"distance"] compare:obj2[@"distance"]];
    }];
    
    self.bestServers = [mServerStaticDic[@"servers"][@"server"] copy];
    result();
}


#pragma mark - delegate
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    NSLog(@"%lu",data.length);

}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    NSLog(@"%@",task);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    NSLog(@"%@",response);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask willCacheResponse:(NSCachedURLResponse *)proposedResponse completionHandler:(void (^)(NSCachedURLResponse * _Nullable))completionHandler {
    NSLog(@"%@",dataTask);
}

#pragma mark - loadLazy
- (NSURLSessionConfiguration *)sessionConfig {
    if (_sessionConfig == nil) {
        _sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        [_sessionConfig setHTTPAdditionalHeaders: @{
            @"User-Agent": @"Mozilla/5.0 (Darwin-18.5.0-x86_64-i386-64bit; U; 64bit; en-us) Python/2.7.10 (KHTML, like Gecko) speedtest-cli/2.1.1"
        }
         ];
        [_sessionConfig setAllowsCellularAccess:YES];
        _sessionConfig.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        _sessionConfig.URLCache = nil;
        _sessionConfig.timeoutIntervalForRequest = 5;
        //        [_sessionConfig setTimeoutIntervalForRequest:10];
    }
    return _sessionConfig;
}

- (NSURLSession *)session {
    if (_session == nil) {
        _session = [NSURLSession sessionWithConfiguration:self.sessionConfig];
    }
    return _session;
}

@end
