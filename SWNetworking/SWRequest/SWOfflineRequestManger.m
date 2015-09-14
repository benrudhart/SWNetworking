//
//  SWOfflineRequestManger.m
//  SWNetworking
//
//  Created by Saman Kumara on 4/13/15.
//  Copyright (c) 2015 Saman Kumara. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//https://github.com/skywite
//

#import "SWOfflineRequestManger.h"
#import "SWReachability.h"
#import "SWRequestOperation.h"
#import "SWOperationManger.h"

NSString *const USER_DEFAULT_KEY = @"SWOfflineReqeustsOnUserDefault";

@interface SWOfflineRequestManger()

@property(nonatomic, assign) long expireTime;

@property(nonatomic, copy) void (^requestSuccessBlock)(SWRequestOperation *oparation, id responseObject);

@property(nonatomic, copy) void (^requestFailBlock)(SWRequestOperation *oparation,  NSError *error);

@end

static SWOfflineRequestManger *instance = nil;

static dispatch_once_t onceToken;

@implementation SWOfflineRequestManger

+ (instancetype)requestExpireTime:(long) seconds{
    
    dispatch_once(&onceToken, ^{
        instance = [[SWOfflineRequestManger alloc] init];
    });
    
    instance.expireTime = seconds;

    [instance startReachabilityStatus];
    
    return instance;
}

+ (instancetype)sharedInstance{
    
    dispatch_once(&onceToken, ^{
        instance = [[SWOfflineRequestManger alloc] init];
    });
    return instance;
}


-(void)requestSuccessBlock:(void (^)(SWRequestOperation *oparation, id responseObject))success requestFailBlock:(void (^)(SWRequestOperation *oparation,  NSError *error))fail{
    self.requestSuccessBlock = success;
    self.requestFailBlock = fail;
}
-(void)startReachabilityStatus{
    
    [SWReachability checkCurrentStatus:^(SWNetworingReachabilityStatus currentStatus) {
        if (currentStatus != SWNetworkReachabilityStatusNotReachable) {
            [self createOperations];
        }
    } statusChange:^(SWNetworingReachabilityStatus changedStatus) {
        
        if (changedStatus != SWNetworkReachabilityStatusNotReachable) {
            [self createOperations];
        }
    }];
}

-(void)createOperations{
    SWOperationManger *operationManager = [[SWOperationManger alloc]init];
    [operationManager setMaxOperationCount:3];
    for (SWRequestOperation *operetion in [self offlineOparations]) {
        
        __weak SWRequestOperation *weakOperation = operetion;
        [operationManager addOperationWithBlock:^{
            
            [[NSOperationQueue mainQueue] addOperationWithBlock: ^ {
                
                [operetion createConnection];
                
                [operetion setSuccess:^(SWRequestOperation *operationResponse, id responseObject) {
                    
                    if (self.requestSuccessBlock) {
                        self.requestSuccessBlock(operationResponse, responseObject);
                    }
                    
                    [self removeRequest:weakOperation];
                    
                } failure:^(SWRequestOperation *operationResponse, NSError *error) {
                    if (self.requestFailBlock) {
                        self.requestFailBlock(operationResponse, error);
                    }
                }];
            }];
        }];
    }

}

-(void)removeRequest:(SWRequestOperation *)requestOperation{
    
    NSData *selectedData;
    for (NSData *data in [self getSavedArray]) {
        SWRequestOperation * operation = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        if ([operation.requestSavedDate timeIntervalSinceReferenceDate] == [requestOperation.requestSavedDate timeIntervalSinceReferenceDate]){
            selectedData = data;
            break;
        }
    }
    
    if (selectedData) {
        NSMutableArray *array = [self getSavedArray];
        [array removeObject:selectedData];
        
        [[NSUserDefaults standardUserDefaults] setObject:array forKey:USER_DEFAULT_KEY];
        [[NSUserDefaults standardUserDefaults]synchronize];
    }
}
-(NSArray *)offlineOparations{
    
    NSMutableArray  *array = [[NSMutableArray alloc]init];
    
    for (NSData *data in [self getSavedArray]) {
        SWRequestOperation * operation = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        
        if ([operation.requestSavedDate timeIntervalSinceReferenceDate] > self.expireTime){
            [array addObject:operation];
        }
    }
    [self saveRequests:array];
    
    return array;
}

-(void)removeAllRequests{
    [self saveRequests:[[NSMutableArray alloc]init]];
}
-(void)saveRequests:(NSMutableArray *)list{
    
    NSMutableArray  *array = [[NSMutableArray alloc]init];

    for (SWRequestOperation *operation in list) {
        
        NSData* archivedOperation = [NSKeyedArchiver archivedDataWithRootObject:operation];
        [array addObject:archivedOperation];
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:array forKey:USER_DEFAULT_KEY];
    
    [[NSUserDefaults standardUserDefaults]synchronize];
}

-(BOOL)addRequestForSendLater:(SWRequestOperation *)requestOperation{
    
    requestOperation.requestSavedDate = [NSDate new];

    NSMutableArray *array = [self getSavedArray];
    
    NSData* archivedOperation = [NSKeyedArchiver archivedDataWithRootObject:requestOperation];
    
    [array addObject:archivedOperation];
    [[NSUserDefaults standardUserDefaults] setObject:array forKey:USER_DEFAULT_KEY];
    
    return [[NSUserDefaults standardUserDefaults]synchronize];
}

-(NSMutableArray *)getSavedArray{
    
    if ([[NSUserDefaults standardUserDefaults]objectForKey:USER_DEFAULT_KEY]) {
        return [[NSMutableArray alloc]initWithArray:[[NSUserDefaults standardUserDefaults]objectForKey:USER_DEFAULT_KEY]];
    }else{
        return [[NSMutableArray alloc]init];
    }
}



@end
