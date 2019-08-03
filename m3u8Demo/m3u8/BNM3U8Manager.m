//
//  BNM3U8Manager.m
//  m3u8Demo
//
//  Created by Bennie on 6/14/19.
//  Copyright © 2019 Bennie. All rights reserved.
//

#import "BNM3U8Manager.h"
#import "BNM3U8DownloadOperation.h"

#define LOCK(lock) dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
#define UNLOCK(lock) dispatch_semaphore_signal(lock);

@implementation BNM3U8ManagerConfig
@end

@interface BNM3U8Manager()
@property (nonatomic,strong) BNM3U8ManagerConfig *config;
///用于取消操作，成功后移除
@property (nonatomic,strong) NSMutableDictionary <NSString*, BNM3U8DownloadOperation*> *downloadOperationsMap;
@property (nonatomic,strong) dispatch_semaphore_t operationSemaphore;
@property (nonatomic,strong) NSOperationQueue *downloadQueue;
@end

@implementation BNM3U8Manager

+ (instancetype)shareInstanceWithConfig:(BNM3U8ManagerConfig*)config
{
    static BNM3U8Manager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = BNM3U8Manager.new;
        manager.config = config;
        manager.operationSemaphore = dispatch_semaphore_create(1);
        manager.downloadQueue = [[NSOperationQueue alloc]init];
        manager.downloadQueue.maxConcurrentOperationCount = manager.config.videoMaxConcurrenceCount;
        manager.downloadOperationsMap = NSMutableDictionary.new;
    });
    return manager;
}


#pragma mark -
/*下载队列中添加
 创建operation  添加到queue中。 系统控制执行
 */
- (void)downloadVideoWithConfig:(BNM3U8DownloadConfig *)config resultBlock:(BNM3U8DownloadResultBlock)resultBlock{
    NSParameterAssert(config.url);
    BNM3U8DownloadOperation *operation =  BNM3U8DownloadOperation.new;
    operation.config = config;
    LOCK(_operationSemaphore);
    [_downloadOperationsMap setValue:operation forKey:config.url];
    [_downloadQueue addOperation:operation];
    UNLOCK(_operationSemaphore);
}

/*取消某个下载operation。找到对应的operation并 执行他的cannel方法，queue不提供对单个operation的取消处理，相应的queue提供全局的取消处理
 */
- (void)cannel:(NSString *)url{
    LOCK(_operationSemaphore);
    [self _cannel:url];
    UNLOCK(_operationSemaphore);
}

///unsafe thread
- (void)_cannel:(NSString *)url{
    BNM3U8DownloadOperation *operation = [_downloadOperationsMap valueForKey:url];
    NSParameterAssert(operation);
    if (!operation.isCancelled) {
#pragma TODO:
        ///cannel,if call the callbackBlock? and how its action in de operation queue??
        [operation cancel];
    }
    ///remove
    [_downloadOperationsMap removeObjectForKey:url];
}

/*全部取消,遍历operation cnnel. queue的cannel all operation 只能在创建/重新创建或者 dealloc时执行*/
- (void)cancelAll{
    LOCK(_operationSemaphore);
    NSArray *urls = _downloadOperationsMap.allKeys;
    [urls enumerateObjectsUsingBlock:^(NSString * _Nonnull url, NSUInteger idx, BOOL * _Nonnull stop) {
        [self _cannel:url];
    }];
    UNLOCK(_operationSemaphore);
}

/*queue 能实现，发起的不能挂起*/
- (void)suspend{
    _downloadQueue.suspended = YES;
}

@end
