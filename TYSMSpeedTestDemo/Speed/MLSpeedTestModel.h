//
//  MLSpeedTestModel.h
//  MLife
//
//  Created by jele lam on 19/1/2020.
//  Copyright © 2020 CookiesJ. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "NSObject+YYModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface MLSpeedTestClientModel : NSObject
@property (nonatomic, copy) NSString *ip;
@property (nonatomic, copy) NSString *isp;
@property (nonatomic, copy) NSString *country;
@property (nonatomic, strong) NSNumber *ispdlavg;
@property (nonatomic, strong) NSNumber *ispulavg;
@property (nonatomic, strong) NSNumber *loggedin;
@property (nonatomic, strong) NSNumber *isprating;
@property (nonatomic, strong) NSNumber *rating;
@property (nonatomic, strong) CLLocation *location;

//<client ip="120.239.26.168" lat="20.8634" lon="110.0181" isp="China Mobile Guangdong" ="3.7" ="0" ="0" ispulavg="0" ="0" ="CN" />

@end

@interface MLSpeedTestDownloadModel : NSObject
@property (nonatomic, copy) NSString *initialtest;
@property (nonatomic, copy) NSString *mintestsize;
@property (nonatomic, strong) NSNumber *testlength;
@property (nonatomic, strong) NSNumber *threadsperurl;

@end

@interface MLSpeedTestUploadModel : NSObject
@property (nonatomic, copy) NSString *initialtest;
@property (nonatomic, copy) NSString *mintestsize;
@property (nonatomic, strong) NSNumber *testlength;
@property (nonatomic, strong) NSNumber *threadsperurl;
@property (nonatomic, strong) NSNumber *ratio;
@property (nonatomic, strong) NSNumber *threads;
@property (nonatomic, strong) NSNumber *maxchunksize;
@property (nonatomic, strong) NSNumber *maxchunkcount;
@end

@interface MLSpeedTestServerConfigModel : NSObject
@property (nonatomic, copy) NSString *country;
@property (nonatomic, strong) NSNumber *threadcount;
@property (nonatomic, copy) NSString *ignoreids;
@property (nonatomic, copy) NSString *notonmap;
@property (nonatomic, strong) NSNumber *forcepingid;
@property (nonatomic, strong) NSNumber *preferredserverid;

@end

@interface MLSpeedTestThreadsModel : NSObject
@property (nonatomic, strong) NSNumber *downloadThreadsCount;
@property (nonatomic, strong) NSNumber *uploadThreadsCount;
@end

@interface MLSpeedTestSizesModel : NSObject
@property (nonatomic, strong) NSArray *downloadSizes;
@property (nonatomic, strong) NSArray *uploadSizes;
@end

@interface MLSpeedTestLengthModel : NSObject
@property (nonatomic, strong) NSNumber *downloadLength;
@property (nonatomic, strong) NSNumber *uploadLength;
@end

@interface MLSpeedTestCountModel : NSObject
@property (nonatomic, strong) NSNumber *downloadCount;
@property (nonatomic, strong) NSNumber *uploadCount;
@end

@interface MLSpeedTestModel : NSObject <YYModel>
@property (nonatomic, strong) MLSpeedTestClientModel *client;
@property (nonatomic, strong) NSArray *ignoreServers;
@property (nonatomic, strong) MLSpeedTestThreadsModel *threads;
@property (nonatomic, strong) MLSpeedTestSizesModel *sizes;
@property (nonatomic, strong) MLSpeedTestLengthModel *lengths;
@property (nonatomic, strong) MLSpeedTestCountModel *counts;
@property (nonatomic, strong) NSNumber *maxUpload;

- (void)configure;
@end

NS_ASSUME_NONNULL_END
