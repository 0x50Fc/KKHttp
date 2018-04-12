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

+(NSString *) kk_getString:(JSValue *) object key:(NSString *) key {
    JSValue * v = [object valueForProperty:key];
    if([v isNull] || [v isUndefined] ){
        return nil;
    }
    return [v toString];
}

-(id<KKHttpTask>) send:(JSValue *) options {
    
    KKHttpOptions * opt = [[KKHttpOptions alloc] init];
    
    opt.url = [KKJSHttp kk_getString:options key:@"url"];
    opt.method = [KKJSHttp kk_getString:options key:@"method"];
    opt.type = [KKJSHttp kk_getString:options key:@"type"];
    {
        id v = [[options valueForProperty:@"headers"] toDictionary];
        if(v) {
            opt.headers = [NSMutableDictionary dictionaryWithDictionary:v];
        }
    }
    opt.data = [[options valueForProperty:@"data"] toDictionary];
    opt.timeout = [[options valueForProperty:@"timeout"] toDouble];
    opt.host = [KKJSHttp kk_getString:options key:@"host"];
    
    __strong JSValue * onload = [options valueForProperty:@"onload"];
    __strong JSValue * onfail = [options valueForProperty:@"onfail"];
    __strong JSValue * onresponse = [options valueForProperty:@"onresponse"];

    if([onload isObject]) {
        
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
    
    }
    
    if([onfail isObject]) {
        opt.onfail = ^(NSError *error, id weakObject) {
            NSArray * arguments = @[[error localizedDescription]];
            dispatch_async(dispatch_get_main_queue(), ^{
                [onfail callWithArguments:arguments];
            });
        };
    }
    
    if([onresponse isObject]) {
        
        opt.onresponse = ^(NSHTTPURLResponse *response, id weakObject) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                NSMutableDictionary * data = [NSMutableDictionary dictionaryWithCapacity:4];
                data[@"code"] = @(response.statusCode);
                data[@"status"] = [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode];
                data[@"headers"] = [response allHeaderFields];
                [onresponse callWithArguments:@[data]];
            });
            
        };
    }
    
    return [_http send:opt weakObject:self];
}

@end
