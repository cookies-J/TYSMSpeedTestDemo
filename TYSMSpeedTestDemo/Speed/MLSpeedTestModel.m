//
//  MLSpeedTestModel.m
//  MLife
//
//  Created by jele lam on 19/1/2020.
//  Copyright © 2020 CookiesJ. All rights reserved.
//

#import "MLSpeedTestModel.h"
@interface MLSpeedTestClientModel ()
@property (nonatomic, strong) NSNumber *lat;
@property (nonatomic, strong) NSNumber *lon;
@end
@implementation MLSpeedTestClientModel
+(NSDictionary<NSString *,id> *)modelCustomPropertyMapper {
    return @{
             @"country":@"_country",
             @"ip":@"_ip",
             @"isp":@"_isp",
             @"ispdlavg":@"_ispdlavg",
             @"isprating":@"_isprating",
             @"ispulavg":@"_ispulavg",
             @"lat":@"_lat",
             @"loggedin":@"_loggedin",
             @"lon":@"_lon",
             @"rating":@"_rating",
             };
}

- (CLLocation *)location {
    if (_location == nil) {
        _location = [[CLLocation alloc] initWithLatitude:_lat.doubleValue longitude:_lon.doubleValue];
    }
    return _location;
}

@end

@implementation MLSpeedTestDownloadModel
+ (NSDictionary<NSString *,id> *)modelCustomPropertyMapper {
    return @{
             @"initialtest":@"_initialtest",
             @"mintestsize":@"_mintestsize",
             @"testlength":@"_testlength",
             @"threadsperurl":@"_threadsperurl",
             };
}
@end

@implementation MLSpeedTestUploadModel
+ (NSDictionary<NSString *,id> *)modelCustomPropertyMapper {
    return @{
             @"initialtest":@"_initialtest",
             @"maxchunkcount":@"_maxchunkcount",
             @"maxchunksize":@"_maxchunksize",
             @"mintestsize":@"_mintestsize",
             @"ratio":@"_ratio",
             @"testlength":@"_testlength",
             @"threads":@"_threads",
             @"threadsperurl":@"_threadsperurl",
             };
}
@end

@interface MLSpeedTestServerConfigModel ()

@end

@implementation MLSpeedTestServerConfigModel
+(NSDictionary<NSString *,id> *)modelCustomPropertyMapper {
    return @{
             @"preferredserverid":@"_preferredserverid",
             @"threadcount":@"_threadcount",
             @"forcepingid":@"_forcepingid",
             @"notonmap":@"_notonmap",
             @"ignoreids" : @"_ignoreids",
             };
}

@end


@implementation MLSpeedTestThreadsModel
+(NSDictionary<NSString *,id> *)modelCustomPropertyMapper {
    return @{
             @"downloadThreadsCount":@"downloadThreadsCount",
             @"uploadThreadsCount":@"uploadThreadsCount",
             };
}
@end

@implementation MLSpeedTestSizesModel
+(NSDictionary<NSString *,id> *)modelCustomPropertyMapper {
    return @{
             @"downloadSizes":@"downloadSizes",
             @"uploadSizes":@"uploadSizes",
             };
}
@end

@implementation MLSpeedTestLengthModel
+(NSDictionary<NSString *,id> *)modelCustomPropertyMapper {
    return @{
             @"downloadLength":@"downloadLength",
             @"uploadLength":@"uploadLength",
             };
}
@end

@implementation MLSpeedTestCountModel
+(NSDictionary<NSString *,id> *)modelCustomPropertyMapper {
    return @{
             @"uploadCount":@"uploadCount",
             @"downloadCount":@"downloadCount",
             };
}
@end

@interface MLSpeedTestModel ()
@property (nonatomic, strong) MLSpeedTestDownloadModel *download;
@property (nonatomic, strong) MLSpeedTestUploadModel *upload;
@property (nonatomic, strong) MLSpeedTestServerConfigModel *serverConfig;
@end

@implementation MLSpeedTestModel
+(NSDictionary<NSString *,id> *)modelCustomPropertyMapper {
    return @{
             @"serverConfig":@"server-config",
             };
}

+(NSDictionary<NSString *,id> *)modelContainerPropertyGenericClass {
    return @{
        @"client" : [MLSpeedTestClientModel class],
        @"download" : [MLSpeedTestDownloadModel class],
        @"upload" : [MLSpeedTestUploadModel class],
        @"serverConfig" : [MLSpeedTestServerConfigModel class],
    };
}

- (void)configure {
    self.ignoreServers = [self.serverConfig.ignoreids componentsSeparatedByString:@","];
    
    NSArray *upSize = @[@(32768), @(65536), @(131072), @(262144), @(524288), @(1048576), @(7340032)];
    
    NSRange upRange = NSMakeRange(self.upload.ratio.intValue-1, upSize.count - self.upload.ratio.intValue+1);
    
    NSArray *downloadSize = @[@(350), @(500), @(750), @(1000), @(1500), @(2000), @(2500),
                              @(3000), @(3500), @(4000)];
    
    self.sizes = [MLSpeedTestSizesModel modelWithDictionary:@{
        @"uploadSizes" : [upSize subarrayWithRange:upRange],
        @"downloadSizes" : downloadSize,
    }];
    
    
    self.counts = [MLSpeedTestCountModel modelWithDictionary:@{
        @"downloadCount" :self.download.threadsperurl,
            @"uploadCount" : @((int)ceil(self.upload.maxchunkcount.intValue/self.sizes.uploadSizes.count))
    }];
    
    self.threads = [MLSpeedTestThreadsModel modelWithDictionary:@{
        @"downloadThreadsCount" : @(self.serverConfig.threadcount.intValue *2),
            @"uploadThreadsCount" : self.upload.threads
    }];
    
    self.lengths = [MLSpeedTestLengthModel modelWithDictionary:@{
        @"downloadLength" : self.download.testlength,
            @"uploadLength" : self.upload.testlength,
    }];
    
    self.maxUpload = @(self.counts.uploadCount.intValue * self.sizes.uploadSizes.count);
}

@end
