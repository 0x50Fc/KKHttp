//
//  KKJSHttp.m
//  KKHttp
//
//  Created by hailong11 on 2017/12/27.
//  Copyright © 2017年 mofang.cn. All rights reserved.
//

#import "KKHttp.h"

@implementation KKJSHttp

-(instancetype) initWithHttp:(id<KKHttp>) http {
    if((self = [super init])) {
        _http = http;
    }
    return self;
}

-(void) dealloc {
    [_http cancel:self];
}

-(void) cancel {
    [_http cancel:self];
}

-(void) recycle {
    [_http cancel:self];
    _http = nil;
}

-(id<KKHttpTask>) send:(JSValue *) options {
    
    KKHttpOptions * opt = [[KKHttpOptions alloc] init];
    
    opt.url = [[options valueForProperty:@"url"] toString];
    opt.method = [[options valueForProperty:@"method"] toString];
    opt.type = [[options valueForProperty:@"type"] toString];
    {
        id v = [[options valueForProperty:@"headers"] toDictionary];
        if(v) {
            opt.headers = [NSMutableDictionary dictionaryWithDictionary:v];
        }
    }
    opt.data = [[options valueForProperty:@"data"] toDictionary];
    opt.timeout = [[options valueForProperty:@"timeout"] toDouble];
    
    __strong JSValue * onload = [options valueForProperty:@"onload"];
    __strong JSValue * onfail = [options valueForProperty:@"onfail"];

    opt.onload = ^(id data, NSError * error, id weakObject) {
        if(error) {
            
            NSArray * arguments = @[[JSValue valueWithNullInContext:onload.context],[error localizedDescription]];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [onload callWithArguments:arguments];
            });
            
            
        } else {
            
            NSArray * arguments = @[data];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [onload callWithArguments:arguments];
            });
        }
    };
    
    opt.onfail = ^(NSError *error, id weakObject) {
        NSArray * arguments = @[[error localizedDescription]];
        dispatch_async(dispatch_get_main_queue(), ^{
            [onfail callWithArguments:arguments];
        });
    };
    
    return [_http send:opt weakObject:self];
}

@end
