//
//  DevLuaLoader.m
//  VideoPlsLuaViewManagerSDK
//
//  Created by peter on 2019/7/22.
//  Copyright © 2019 videopls. All rights reserved.
//

#import "DevLuaLoader.h"

#import <VideoOS/VideoPlsLuaViewManagerSDK/VPLConstant.h>
#import <VideoOS/VideoPlsUtilsPlatformSDK/VPUPPathUtil.h>
#import <VideoOS/VideoPlsUtilsPlatformSDK/VPUPMD5Util.h>
#import <VideoOS/VideoPlsUtilsPlatformSDK/VPUPPrefetchManager.h>
#import <VideoOS/VideoPlsUtilsPlatformSDK/VPUPRandomUtil.h>

NSInteger const DevLuaLoaderDownloadRetryCount = 2;

@implementation DevLuaLoaderObject

- (instancetype)init {
    self = [super init];
    if (self) {
        self.statisticsList = [[VPUPTrafficStatisticsList alloc] init];
    }
    return self;
}

+ (instancetype)objectWithFilesList:(NSArray *)filesList destinationPath:(NSString *)destinationPath {
    DevLuaLoaderObject *loadObject = [[DevLuaLoaderObject alloc] init];
    loadObject.filesList = filesList;
    
    NSMutableArray *filesUrl = [NSMutableArray arrayWithCapacity:0];
    NSMutableArray *filesName = [NSMutableArray arrayWithCapacity:0];
    for (NSDictionary *file in filesList) {
        NSString *url = [file objectForKey:@"url"];
        [filesUrl addObject:url];
        NSString *fileName = [url lastPathComponent];
        [filesName addObject:fileName];
    }
    
    loadObject.filesUrl = filesUrl;
    loadObject.filesName = filesName;
    
    loadObject.destinationPath = destinationPath;
    loadObject.tempFilePath = [destinationPath stringByAppendingPathComponent:[NSString stringWithFormat:@"temp%@", [VPUPRandomUtil randomMKTempStringByLength:8]]];
    
    return loadObject;
}

@end


@interface DevLuaLoader()

@property (nonatomic, strong) VPUPPrefetchManager *prefetchManager;
@property (nonatomic, strong) dispatch_queue_t luaLoaderQueue;

- (void)callbackComplete:(DevLuaLoaderCompletionBlock)complete withError:(NSError *)error;

- (void)callbackComplete:(DevLuaLoaderCompletionBlock)complete withError:(NSError *)error withStatistics:(VPUPTrafficStatisticsList *)trafficList;

@end


@implementation DevLuaLoader

+ (instancetype)sharedLoader {
    static DevLuaLoader *_sharedLoader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedLoader = [[self alloc] init];
    });
    return _sharedLoader;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _luaLoaderQueue = dispatch_queue_create("com.videopls.lua.loader", DISPATCH_QUEUE_SERIAL);
    }
    
    return self;
}

- (VPUPPrefetchManager *)prefetchManager {
    if (!_prefetchManager) {
        _prefetchManager = [[VPUPPrefetchManager alloc] init];
    }
    return _prefetchManager;
}

- (void)checkAndDownloadFilesList:(NSArray *)filesList complete:(DevLuaLoaderCompletionBlock)complete {
    [self checkAndDownloadFilesList:filesList resumePath:[VPUPPathUtil lOSPath] complete:complete];
}

- (void)checkAndDownloadFilesList:(NSArray *)filesList resumePath:(NSString *)resumePath complete:(DevLuaLoaderCompletionBlock)complete {
    if ([[NSFileManager defaultManager] fileExistsAtPath:resumePath]) {
        [self checkFilesListWithLocal:filesList resumePath:resumePath complete:complete];
    }
    else {
        NSError *error = [NSError errorWithDomain:VPLErrorDomain code:-3001 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"resumePath do not exists"]}];
        [self callbackComplete:complete withError:error];
    }
}

- (void)checkFilesListWithLocal:(NSArray *)fileList resumePath:(NSString *)resumePath complete:(DevLuaLoaderCompletionBlock)complete {
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.luaLoaderQueue, ^{
        NSMutableArray *downloadFileList = [NSMutableArray arrayWithCapacity:0];
        for (NSDictionary *dict in fileList) {
            NSString *url = [dict objectForKey:@"url"];
            NSString *fileName = [url lastPathComponent];
            NSString *localPath = [resumePath stringByAppendingString:[NSString stringWithFormat:@"/%@", fileName]];

            if ([[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
//#ifdef DEBUG
//#else
                NSString *fileMD5 = [VPUPMD5Util md5File:localPath size:0];
                if (![[dict objectForKey:@"md5"] isEqualToString:fileMD5]) {
                    [downloadFileList addObject:dict];
                }
//#endif
            }
            else {
                [downloadFileList addObject:dict];
            }
        }
        if (downloadFileList.count > 0) {
            DevLuaLoaderObject *loaderObject = [DevLuaLoaderObject objectWithFilesList:downloadFileList destinationPath:resumePath];
            [weakSelf downloadLuaFilesWithLoaderObject:loaderObject complete:complete];
        }
        else {
            [weakSelf callbackComplete:complete withError:nil];
        }
    });
}

- (void)downloadLuaFilesWithLoaderObject:(DevLuaLoaderObject *)loaderObject complete:(DevLuaLoaderCompletionBlock)complete {
    [self downloadLuaFilesWithLoaderObject:loaderObject complete:complete repeatCount:0];
}

- (void)downloadLuaFilesWithLoaderObject:(DevLuaLoaderObject *)loaderObject complete:(DevLuaLoaderCompletionBlock)complete repeatCount:(NSInteger)repeatCount {
    
    if (!loaderObject || !loaderObject.filesList || loaderObject.filesList.count == 0) {
        [self callbackComplete:complete withError:nil];
        return;
    }
    
    __block DevLuaLoaderObject *blockObject = loaderObject;
    
    __weak typeof(self) weakSelf = self;
    
    [self.prefetchManager prefetchURLs:loaderObject.filesUrl
                             fileNames:loaderObject.filesName
                       destinationPath:loaderObject.tempFilePath
                       completionBlock:^(NSUInteger numberOfFinishedUrls, NSUInteger numberOfSkippedUrls) {
                           if (numberOfSkippedUrls > 0) {
                               if (repeatCount == 0) {
                                   [self downloadLuaFilesWithLoaderObject:blockObject complete:complete repeatCount:1];
                               } else {
                                   NSError *error = [NSError errorWithDomain:VPLErrorDomain code:-3002 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Download file error, success count %ld, faild count %ld", numberOfFinishedUrls, numberOfSkippedUrls]}];
//                                   [weakSelf callbackComplete:complete withError:error];
                                   [weakSelf checkDownloadObject:blockObject complete:complete skippedCount:numberOfSkippedUrls];
                               }
                           }
                           else {
//                               [weakSelf checkDownloadFilesList:filesList complete:complete];
                               [weakSelf checkDownloadObject:blockObject complete:complete];
                           }
                       }];
}

- (void)checkDownloadObject:(DevLuaLoaderObject *)loaderObject complete:(DevLuaLoaderCompletionBlock)complete {
    [self checkDownloadObject:loaderObject complete:complete skippedCount:0];
}

- (void)checkDownloadObject:(DevLuaLoaderObject *)loaderObject complete:(DevLuaLoaderCompletionBlock)complete skippedCount:(NSInteger)skippedCount {
    __weak typeof(self) weakSelf = self;
    
    dispatch_async(self.luaLoaderQueue, ^{
        NSInteger failedCount = skippedCount;
        NSMutableArray *downloadFiles = [NSMutableArray arrayWithCapacity:0];
        for (NSInteger i = 0; i < loaderObject.filesList.count; i++) {
            NSString *fileName = [loaderObject.filesName objectAtIndex:i];
            NSString *fileUrl = [loaderObject.filesUrl objectAtIndex:i];
            NSString *localPath = [loaderObject.tempFilePath stringByAppendingPathComponent:fileName];
            [downloadFiles addObject:localPath];
            NSDictionary *dict = [loaderObject.filesList objectAtIndex:i];
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
                NSString *fileMD5 = [VPUPMD5Util md5File:localPath size:0];
                if (![[dict objectForKey:@"md5"] isEqualToString:fileMD5]) {
                    failedCount += 1;
                } else {
                    [loaderObject.statisticsList addFileTrafficByName:fileName fileUrl:fileUrl filePath:localPath];
                }
            }
        }
        
        if (failedCount == 0) {
            NSMutableArray *moveErrors = [NSMutableArray arrayWithCapacity:0];
            for (NSString *fileName in loaderObject.filesName) {
                NSError *removeError = nil;
                NSString *targetPath = [loaderObject.destinationPath stringByAppendingString:[NSString stringWithFormat:@"/%@", fileName]];
                NSString *sourcePath = [loaderObject.tempFilePath stringByAppendingString:[NSString stringWithFormat:@"/%@", fileName]];
                if ([[NSFileManager defaultManager] fileExistsAtPath:targetPath]) {
                    [[NSFileManager defaultManager] removeItemAtPath:targetPath error:&removeError];
                }
                NSError *copyError = nil;
                [[NSFileManager defaultManager] copyItemAtPath:sourcePath toPath:targetPath error:&copyError];
                if (removeError) {
                    [moveErrors addObject:removeError];
                }
                if (copyError) {
                    [moveErrors addObject:copyError];
                }
            }
            if (moveErrors.count > 0) {
                NSError *error = [NSError errorWithDomain:VPLErrorDomain code:-3003 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Download file copy to target path error"]}];
                [self callbackComplete:complete withError:error withStatistics:loaderObject.statisticsList];
            }
            else {
                [self callbackComplete:complete withError:nil withStatistics:loaderObject.statisticsList];
            }
        }
        else {
            NSError *error = [NSError errorWithDomain:VPLErrorDomain code:-3004 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Download file data error"]}];
            [weakSelf callbackComplete:complete withError:error withStatistics:loaderObject.statisticsList];
        }
        
        [[NSFileManager defaultManager] removeItemAtPath:loaderObject.tempFilePath error:nil];
    });
}

/*
- (void)checkDownloadFilesList:(NSArray *)filesList complete:(DevLuaLoaderCompletionBlock)complete {
    
    __weak typeof(self) weakSelf = self;
    
    dispatch_async(self.luaLoaderQueue, ^{
        NSInteger failedCount = 0;
        NSMutableArray *downloadFiles = [NSMutableArray arrayWithCapacity:0];
        NSMutableArray *filesName = [NSMutableArray arrayWithCapacity:0];
        for (NSDictionary *dict in filesList) {
            NSString *url = [dict objectForKey:@"url"];
            NSString *fileName = [url lastPathComponent];
            NSString *localPath = [self.tempFilePath stringByAppendingString:fileName];
            [filesName addObject:fileName];
            [downloadFiles addObject:localPath];
            if ([[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
                NSString *fileMD5 = [VPUPMD5Util md5File:localPath size:0];
                if (![[dict objectForKey:@"md5"] isEqualToString:fileMD5]) {
                    failedCount += 1;
                }
            }
        }
        if (failedCount == 0) {
            NSMutableArray *moveErrors = [NSMutableArray arrayWithCapacity:0];
            for (NSString *fileName in filesName) {
                NSError *removeError = nil;
                NSString *targetPath = [self.resumePath stringByAppendingString:[NSString stringWithFormat:@"/%@", fileName]];
                NSString *sourcePath = [self.tempFilePath stringByAppendingString:[NSString stringWithFormat:@"/%@", fileName]];
                if ([[NSFileManager defaultManager] fileExistsAtPath:targetPath]) {
                    [[NSFileManager defaultManager] removeItemAtPath:targetPath error:&removeError];
                }
                NSError *copyError = nil;
                [[NSFileManager defaultManager] copyItemAtPath:sourcePath toPath:targetPath error:&copyError];
                if (removeError) {
                    [moveErrors addObject:removeError];
                }
                if (copyError) {
                    [moveErrors addObject:copyError];
                }
            }
            if (moveErrors.count > 0) {
                NSError *error = [NSError errorWithDomain:DevLuaErrorDomain code:-3003 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Download file copy to target path error"]}];
                [self callbackComplete:complete withError:error];
            }
            else {
                [self callbackComplete:complete withError:nil];
            }
        }
        else {
            NSError *error = [NSError errorWithDomain:DevLuaErrorDomain code:-3004 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Download file data error"]}];
            [weakSelf callbackComplete:complete withError:error];
        }
        [[NSFileManager defaultManager] removeItemAtPath:self.tempFilePath error:nil];
    });
}
 */

- (void)callbackComplete:(DevLuaLoaderCompletionBlock)complete withError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (complete) {
            complete(error, nil);
        }
    });
}

- (void)callbackComplete:(DevLuaLoaderCompletionBlock)complete withError:(NSError *)error withStatistics:(VPUPTrafficStatisticsList *)trafficList {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (complete) {
            complete(error, trafficList);
        }
    });
}

@end
