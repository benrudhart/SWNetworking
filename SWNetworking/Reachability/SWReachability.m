//
//  SWReachability.m
//  SWNetworking
//
//  Created by Saman Kumara on 5/22/15.
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
// THE SOFT
//https://github.com/skywite
//

#import <ifaddrs.h>
#import <netdb.h>
#import <sys/socket.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <objc/runtime.h>

#import "SWReachability.h"


@interface SWReachabilityHandler : NSObject

@property (nonatomic , copy) void (^changedStatus)(SWNetworkingReachabilityStatus changedStatus);

@end


@implementation SWReachabilityHandler


- (void) checkNetworkStatus:(NSNotification *)notice{
    
    self.changedStatus([SWReachability getCurrentNetworkStatus]);
    
}


@end

NSString *kSWReachabilityChangedNotification = @"kSWReachabilityChangedNotification";
static const char KConnectionHandler;

static void SWReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info)

{
    
    NSCAssert(info != NULL, @"info was NULL in SWReachabilityCallback");
    
    [[NSNotificationCenter defaultCenter] postNotificationName: kSWReachabilityChangedNotification object: nil];
    
}



@interface SWReachability(){
}
@property (nonatomic, assign)  SCNetworkReachabilityRef reachability;

@end
@implementation SWReachability

+(SWNetworkingReachabilityStatus)getCurrentNetworkStatus{
    SWReachability *reachability = [[SWReachability alloc]init];
    return reachability.networkReachabilityStatus;
}

+(BOOL)connected{
    SWReachability *reachability = [[SWReachability alloc]init];
    return [reachability connected];
}

+(void)checkCurrentStatus:(void (^)(SWNetworkingReachabilityStatus currentStatus)) currentStatus statusChange:(void (^)(SWNetworkingReachabilityStatus changedStatus))changedStatus{
    
    SWReachabilityHandler *handler = [[SWReachabilityHandler alloc]init];
    
    objc_setAssociatedObject(self, &KConnectionHandler, handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    handler.changedStatus = changedStatus;
    
    [[NSNotificationCenter defaultCenter] addObserver:handler
                                             selector:@selector(checkNetworkStatus:) name:kSWReachabilityChangedNotification object:nil];
    

    SWReachability *reachability = [[SWReachability alloc]init];

    currentStatus(reachability.networkReachabilityStatus);
    

    [reachability startNotifying];
    
}

- (BOOL)connected {
    return self.networkReachabilityStatus != SWNetworkingReachabilityStatusNotReachable;
}

- (SWNetworkingReachabilityStatus)networkReachabilityStatus {
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
    
    self.reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr*)&zeroAddress);
    
    if (self.reachability == NULL) {
        return SWNetworkingReachabilityStatusNotReachable; // fallback to notReachable
    }
    
    SCNetworkReachabilityFlags flags;
    if (!SCNetworkReachabilityGetFlags(self.reachability, &flags)) {
        return SWNetworkingReachabilityStatusNotReachable; // fallback to notReachable
    }
    
    if (!(flags & kSCNetworkReachabilityFlagsReachable)) {
        // we're not reachable
        return SWNetworkingReachabilityStatusNotReachable;
    }
    
    // we're reachable
    
#if	TARGET_OS_IPHONE
    if (flags & kSCNetworkReachabilityFlagsIsWWAN) {
        return SWNetworkingReachabilityStatusReachableViaWWAN;
    }
#endif
    
    return SWNetworkingReachabilityStatusReachableViaWiFi;
}

-(void)startNotifying{
    

    SCNetworkReachabilityContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
        
    if (SCNetworkReachabilitySetCallback(self.reachability, SWReachabilityCallback, &context)){
        
        SCNetworkReachabilityScheduleWithRunLoop(self.reachability, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    }
}
- (void)stopNotifying

{
    if (self.reachability != NULL){
        
        SCNetworkReachabilityUnscheduleFromRunLoop(self.reachability, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    }
    
}


@end
