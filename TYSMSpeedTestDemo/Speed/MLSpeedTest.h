//
//  MLSpeedTest.h
//  MLife
//
//  Created by jele lam on 13/1/2020.
//  Copyright © 2020 CookiesJ. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_CLOSED_ENUM(NSUInteger,TYSMSpeedTestType) {
    TYSMSpeedTestTypeLatency,
    TYSMSpeedTestTypeDownload,
    TYSMSpeedTestTypeUpload,
};

NS_ASSUME_NONNULL_BEGIN

typedef void(^TYSMSpeedTestResultBlock)(void);

@interface MLSpeedTest : NSObject
/**
 初始化。指定 queue
@param queue 工作队列，默认全局线程
*/
- (instancetype)initWithQueue:(nullable dispatch_queue_t )queue;

/**
初始化服务器
@param result 回调延时时间 ms
*/
- (void)prepareTestServer:(TYSMSpeedTestResultBlock)result;
/**
 测试服务器延时
 @param result 回调延时时间 ms
 */
- (void)startTestLatency:(TYSMSpeedTestResultBlock)result;

/**
测试实时下载速度
@param result 回调下载速度
*/
- (void)startTestDownload:(TYSMSpeedTestResultBlock)result;

/**
测试实时上传速度
@param result 回调上传速度
*/
- (void)startTestUpload:(TYSMSpeedTestResultBlock)result;

/**
停止任务
@param result 回调当前的任务
*/
- (void)stopTest:(TYSMSpeedTestResultBlock)result;

/**
 设置延时超时
 @param timestamp 传入 -1 默认 5 秒。
 */
- (void)setLatencyTimeOut:(NSInteger)timestamp;

/**
 设置下载持续时长
 @param timestamp 传入 -1 默认 5 秒。
*/
- (void)setDownloadTimeOut:(NSInteger)timestamp;

/**
 设置上传持续时长
 @param timestamp 传入 -1 默认 5 秒。
*/
- (void)setUploadTimeOut:(NSInteger)timestamp;


@end

NS_ASSUME_NONNULL_END
