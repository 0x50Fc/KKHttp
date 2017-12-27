//
//  KKHttp.h
//  KKView
//
//  Created by 张海龙 on 2017/10/26.
//  Copyright © 2017年 ziyouker.com. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString * KKHttpOptionsTypeText;
extern NSString * KKHttpOptionsTypeJSON;
extern NSString * KKHttpOptionsTypeData;
extern NSString * KKHttpOptionsTypeURI;
extern NSString * KKHttpOptionsTypeImage;

extern NSString * KKHttpOptionsGET;
extern NSString * KKHttpOptionsPOST;

typedef void (^KKHttpOnLoad)(id data,NSError * error, id weakObject);
typedef void (^KKHttpOnFail)(NSError * error, id weakObject);
typedef void (^KKHttpOnResponse)(NSHTTPURLResponse * response, id weakObject);
typedef void (^KKHttpOnProcess)(long long value, long long maxValue,id weakObject);

@interface KKHttpOptions : NSObject {
    
}
    
@property(nonatomic,strong) NSString * url;
@property(nonatomic,strong) NSString * method;
@property(nonatomic,strong) id data;
@property(nonatomic,strong) NSMutableDictionary * headers;
@property(nonatomic,strong) NSString * type;
@property(nonatomic,assign) NSTimeInterval timeout;

@property(nonatomic,copy) KKHttpOnLoad onload;
@property(nonatomic,copy) KKHttpOnFail onfail;
@property(nonatomic,copy) KKHttpOnResponse onresponse;
@property(nonatomic,copy) KKHttpOnProcess onprocess;

@property(nonatomic,strong,readonly) NSString * absoluteUrl;
@property(nonatomic,strong,readonly) NSString * key;
@property(nonatomic,strong,readonly) NSURLRequest * request;
    
-(instancetype) initWithURL:(NSString *) url;
                                 
+(NSString *) pathWithURI:(NSString *) uri;
+(NSString *) cacheKeyWithURL:(NSString *) url;
+(NSString *) cachePathWithURL:(NSString *) url;
+(NSString *) cacheTmpPathWithURL:(NSString *) url;
    
@end

@interface KKHttpBody : NSObject {
 
}
    
@property(nonatomic,strong,readonly) NSString * contentType;
@property(nonatomic,strong,readonly) NSData * data;
    
-(void) add:(NSString *) key value:(NSString *) value;
-(void) add:(NSString *) key data:(NSData *) data type:(NSString *) type name:(NSString *) name;

@end

@interface KKHttpTask : NSObject {
    
}
    
@property(nonatomic,assign,readonly) NSUInteger identity;
@property(nonatomic,strong,readonly) KKHttpOptions * options;
@property(nonatomic,strong,readonly) NSString * key;
@property(nonatomic,weak,readonly) id weakObject;
    
-(void) cancel;
    
@end

@interface KKHttp : NSObject

@property(nonatomic,strong,readonly) dispatch_queue_t io;
@property(nonatomic,strong,readonly) NSURLSession * session;
   
-(instancetype) init;
    
-(instancetype) initWithConfiguration:(NSURLSessionConfiguration *) configuration;
    
-(KKHttpTask *) send:(KKHttpOptions *) options weakObject:(id) weakObject ;

-(KKHttpTask *) get:(NSString *) url data:(id) data type:(NSString *) type onload:(KKHttpOnLoad) onload onfail:(KKHttpOnFail) onfail weakObject:(id) weakObject;
    
-(KKHttpTask *) post:(NSString *) url data:(id) data type:(NSString *) type onload:(KKHttpOnLoad) onload onfail:(KKHttpOnFail) onfail weakObject:(id) weakObject;
  
-(void) cancel:(id) weakObject;
    
+(KKHttp *) main;

+(UIImage *) imageWithURL:(NSString *) url;

+(NSString *) stringValue:(id) value defaultValue:(NSString *) defaultValue;

@end
