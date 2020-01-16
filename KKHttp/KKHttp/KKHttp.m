//
//  KKHttp.m
//  KKView
//
//  Created by 张海龙 on 2017/10/26.
//  Copyright © 2017年 ziyouker.com. All rights reserved.
//

#import "KKHttp.h"
#import <TargetConditionals.h>
#import <CommonCrypto/CommonCrypto.h>
#import <ImageIO/ImageIO.h>

NSString * KKHttpOptionsTypeText = @"text";
NSString * KKHttpOptionsTypeJSON = @"json";
NSString * KKHttpOptionsTypeData = @"data";
NSString * KKHttpOptionsTypeURI = @"uri";
NSString * KKHttpOptionsTypeImage = @"image";

NSString * KKHttpOptionsGET = @"GET";
NSString * KKHttpOptionsPOST = @"POST";

@interface KKHttpImage : NSObject

@property(nonatomic,weak) UIImage * image;

@end

@implementation KKHttpImage

@end

@implementation UIImage(KKHttp)

+(UIImage *) kk_imageWithPath:(NSString *) path {
    
    if(path == nil) {
        return nil;
    }
    
    NSString * main = [[NSBundle mainBundle] resourcePath];
    
    if(![main hasSuffix:@"/"]) {
        main = [main stringByAppendingString:@"/"];
    }
    
    if([path hasPrefix:main]) {
        return [UIImage imageNamed:[path substringFromIndex:[main length]]];
    }
    
    static NSMutableDictionary * images = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        images = [[NSMutableDictionary alloc] initWithCapacity:4];
    });
    
    KKHttpImage * object = nil;
    
    @synchronized(images)  {
        object = [images valueForKey:path];
    }
    
    UIImage * image = object.image;
    
    if(image == nil) {
        
        image = [UIImage imageWithContentsOfFile:path];
        
        if(image == nil) {
            
            CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], nil);
            
            if(source) {
                
                CGImageRef i = CGImageSourceCreateImageAtIndex(source, 0, nil);
                
                if(i) {
                    image = [UIImage imageWithCGImage:i];
                    CFRelease(i);
                }
                
                CFRelease(source);
            }
            
        }
    }

    @synchronized(images)  {
        if(image == nil) {
            [images removeObjectForKey:path];
        } else if(object){
            object.image = image;
            images[path] = object;
        } else {
            object = [[KKHttpImage alloc] init];
            object.image = image;
            images[path] = object;
        }
    }
    
    return image;
}

@end

@implementation KKHttpOptions
    
    @synthesize key = _key;
    @synthesize absoluteUrl = _absoluteUrl;

    -(instancetype) init{
        if((self = [super init])) {
            self.method = KKHttpOptionsGET;
            self.type = KKHttpOptionsTypeText;
            self.headers = [NSMutableDictionary dictionaryWithCapacity:4];
            self.timeout = 300;
            [self.headers setValue:[KKHttp userAgent] forKey:@"User-Agent"];
        }
        return self;
    }

    -(instancetype) initWithURL:(NSString *) url {
        if((self = [self init])) {
            self.url = url;
        }
        return self;
    }
    
    +(NSString *) pathWithURI:(NSString *) uri {
        if([self respondsToSelector:@selector(KKHttpOptionsPathWithURI:)]) {
            NSString * v = [self KKHttpOptionsPathWithURI:uri];
            if(v != nil) {
                return v;
            }
        }
        if([uri hasPrefix:@"document://"]) {
            return [NSHomeDirectory() stringByAppendingPathComponent:[uri substringFromIndex:11]];
        } else if([uri hasPrefix:@"app://"]) {
            return [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:[uri substringFromIndex:6]];
        } else if([uri hasPrefix:@"cache://"]) {
            return [[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches"] stringByAppendingString:[uri substringFromIndex:8]];
        }
        return uri;
    }
    
    +(NSString *) cacheKeyWithURL:(NSString *) url {
        CC_MD5_CTX m;
        CC_MD5_Init(&m);
        CC_MD5_Update(&m, [url UTF8String], (CC_LONG) [url length]);
        unsigned char md[16];
        CC_MD5_Final(md, &m);
        return [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x"
                ,md[0],md[1],md[2],md[3],md[4],md[5],md[6],md[7]
                ,md[8],md[9],md[10],md[11],md[12],md[13],md[14],md[15]];
    }
    
    +(NSString *) cachePathWithURL:(NSString *) url {
        NSString * key = [self cacheKeyWithURL:url];
        return [self pathWithURI:[NSString stringWithFormat:@"cache:///kk/%@",key]];
    }
    
    +(NSString *) cacheTmpPathWithURL:(NSString *) url {
        NSString * key = [self cacheKeyWithURL:url];
        return [self pathWithURI:[NSString stringWithFormat:@"cache:///kk/%@.t",key]];
    }
    
    -(NSString *) key {
        if(_key == nil
           && ([self.type isEqualToString:KKHttpOptionsTypeURI] || [self.type isEqualToString:KKHttpOptionsTypeImage] )) {
            _key = [KKHttpOptions cacheKeyWithURL:self.absoluteUrl];
        }
        return _key;
    }
    
    -(NSString *) absoluteUrl {
        if(_absoluteUrl == nil) {
            if(([self.type isEqualToString:KKHttpOptionsTypeURI]
               || [self.type isEqualToString:KKHttpOptionsTypeImage]
               || [self.method isEqualToString:KKHttpOptionsGET])
               && [self.data isKindOfClass:[NSDictionary class]]) {
                NSMutableString * query = [NSMutableString stringWithCapacity:64];
                NSEnumerator * en = [self.data keyEnumerator];
                NSString * key;
                while((key = [en nextObject]) != nil) {
                    NSString * v = [KKHttp stringValue:[self.data valueForKey:key] defaultValue:@""];
                    if([query length] !=0) {
                        [query appendString:@"&"];
                    }
                    [query appendString:key];
                    [query appendString:@"="];
                    [query appendString:[KKHttpOptions encodeURL:v]];
                }
                if( [self.url hasSuffix:@"?"]) {
                    _absoluteUrl = [NSString stringWithFormat:@"%@%@",self.url,query];
                } else if([self.url containsString:@"?"]) {
                    _absoluteUrl = [NSString stringWithFormat:@"%@&%@",self.url,query];
                } else {
                    _absoluteUrl = [NSString stringWithFormat:@"%@?%@",self.url,query];
                }
            } else {
                _absoluteUrl = self.url;
            }
        }
        return _absoluteUrl;
    }
    
    -(NSURLRequest *) request {
        NSURL * u = [NSURL URLWithString:self.absoluteUrl];
        if(u == nil) {
            u = [NSURL URLWithString:[self.absoluteUrl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        }
        if(u != nil) {
            
            NSMutableURLRequest * req = [NSMutableURLRequest requestWithURL:u cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:self.timeout];
            
            req.HTTPMethod = self.method;
            
            if([self.method isEqualToString:@"POST"]) {
                
                if([self.data isKindOfClass:[NSDictionary class]]) {
                    KKHttpBody * body = [[KKHttpBody alloc] init];
                    NSFileManager * fm = [NSFileManager defaultManager];
                    
                    NSEnumerator * en = [self.data keyEnumerator];
                    NSString * key;
                    while((key = [en nextObject]) != nil) {
                        id v = [self.data valueForKey:key];
                        if([v isKindOfClass:[NSDictionary class]]) {
                            NSString * uri = [v valueForKey:@"uri"];
                            NSString * name = [v valueForKey:@"name"];
                            NSString * type = [v valueForKey:@"type"];
                            if(uri && type) {
                                NSString * path = [KKHttpOptions pathWithURI:uri];
                                if([fm fileExistsAtPath:path]) {
                                    [body add:key data:[NSData dataWithContentsOfFile:path] type:type name:name];
                                }
                            }
                        } else {
                            [body add:key value:[KKHttp stringValue:v defaultValue:@""]];
                        }
                        [req setValue:[self.headers valueForKey:key] forHTTPHeaderField:key];
                    }
                    [req setValue:[body contentType] forHTTPHeaderField:@"Content-Type"];
                    [req setHTTPBody:[body data]];
                }
                else if([self.data isKindOfClass:[NSData class]]) {
                    [req setHTTPBody:self.data];
                }
                else if([self.data isKindOfClass:[NSString class]]) {
                    [req setHTTPBody:[(NSString *) self.data dataUsingEncoding:NSUTF8StringEncoding]];
                }
                
            }
            
            {
                NSEnumerator * en = [self.headers keyEnumerator];
                NSString * key;
                while((key = [en nextObject]) != nil) {
                    [req setValue:[self.headers valueForKey:key] forHTTPHeaderField:key];
                }
            }
            
            if([self.type isEqualToString:KKHttpOptionsTypeURI]
               || [self.type isEqualToString:KKHttpOptionsTypeImage]) {
                
                if(_filePath != nil) {
                    NSFileManager * fm = [NSFileManager defaultManager];
                    if([fm fileExistsAtPath:_filePath]) {
                        NSDictionary * attrs = [fm attributesOfItemAtPath:_filePath error:nil];
                        [req setValue:[NSString stringWithFormat:@"%llu-",[attrs fileSize]] forHTTPHeaderField:@"Range"];
                    }
                }
                
            }
            
            return req;
            
        }
        
        return nil;
    }

    +(NSString *) encodeURL:(NSString *) url {
        
        if(url == nil) {
            return nil;
        }
        
        CFStringRef v = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef) url, nil, CFSTR(":/?&=;+!@#$()',*"), kCFStringEncodingUTF8);
        
        return CFBridgingRelease(v);
    }

    +(NSString *) decodeURL:(NSString *) url {
        
        if(url == nil) {
            return nil;
        }
        
        CFStringRef v = CFURLCreateStringByReplacingPercentEscapesUsingEncoding(kCFAllocatorDefault, (__bridge CFStringRef) url, CFSTR(":/?&=;+!@#$()',*"), kCFStringEncodingUTF8);
        
        return CFBridgingRelease(v);
    }

@end

@interface KKHttpBodyItem : NSObject {
    
}

@property(nonatomic,strong) NSString * key;
    
@end

@interface KKHttpBodyItemValue : KKHttpBodyItem {
    
}
    
@property(nonatomic,strong) NSString * value;

@end

@interface KKHttpBodyItemData : KKHttpBodyItem {
    
}
    
@property(nonatomic,strong) NSData * data;
@property(nonatomic,strong) NSString * type;
@property(nonatomic,strong) NSString * name;
    
@end

@implementation KKHttpBodyItem
@end

@implementation KKHttpBodyItemValue
@end

@implementation KKHttpBodyItemData
@end

@interface KKHttpBody() {
    
}
    
@property(nonatomic,strong) NSMutableArray * items;
    
@end

static NSString * KKHttpBodyToken = @"8jej23fkdxxd" ;
static NSString * KKHttpBodyTokenBegin = @"--8jej23fkdxxd";
static NSString * KKHttpBodyTokenEnd = @"--8jej23fkdxxd--";
static NSString * KKHttpBodyMutilpartType = @"multipart/form-data; boundary=8jej23fkdxxd";
static NSString * KKHttpBodyUrlencodedType = @"application/x-www-form-urlencoded";

@implementation KKHttpBody

@synthesize contentType = _contentType;
@synthesize items = _items;
@synthesize data = _data;
    
-(instancetype) init {
    if((self = [super init])) {
        _contentType = KKHttpBodyUrlencodedType;
    }
    return self;
}
    
-(NSMutableArray *) items {
    if(_items == nil) {
        _items = [NSMutableArray arrayWithCapacity:4];
    }
    return _items;
}
    
-(void) add:(NSString *)key value:(NSString *)value {
    KKHttpBodyItemValue * i = [[KKHttpBodyItemValue alloc] init];
    i.key = key;
    i.value = value;
    [self.items addObject:i];
}

-(void) add:(NSString *)key data:(NSData *)data type:(NSString *)type name:(NSString *)name {
    KKHttpBodyItemData * i = [[KKHttpBodyItemData alloc] init];
    i.key =key;
    i.data = data;
    i.type = type;
    i.name = name;
    [self.items addObject:i];
    _contentType = KKHttpBodyMutilpartType;
}
    
-(NSData *) data {
    if(_data == nil) {
        
        NSMutableData * mdata = [NSMutableData dataWithCapacity:64];
        
        if([self.contentType isEqualToString:KKHttpBodyMutilpartType]) {
            for(KKHttpBodyItem * i in _items) {
                if([i isKindOfClass:[KKHttpBodyItemValue class]]) {
                    KKHttpBodyItemValue * v = (KKHttpBodyItemValue *) i;
                    [mdata appendData:[KKHttpBodyTokenBegin dataUsingEncoding:NSUTF8StringEncoding]];
                    [mdata appendBytes:"\r\n" length:2];
                    [mdata appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"",i.key] dataUsingEncoding:NSUTF8StringEncoding]];
                    [mdata appendBytes:"\r\n\r\n" length:4];
                    [mdata appendData:[v.value dataUsingEncoding:NSUTF8StringEncoding]];
                    [mdata appendBytes:"\r\n" length:2];
                 } else if([i isKindOfClass:[KKHttpBodyItemData class]]) {
                     
                     KKHttpBodyItemData * v = (KKHttpBodyItemData *) i;
                     
                     [mdata appendData:[KKHttpBodyTokenBegin dataUsingEncoding:NSUTF8StringEncoding]];
                     [mdata appendBytes:"\r\n" length:2];
                     [mdata appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"",i.key] dataUsingEncoding:NSUTF8StringEncoding]];
                     
                     if([v.name length]) {
                         [mdata appendData:[[NSString stringWithFormat:@"; filename=\"%@\"",v.name] dataUsingEncoding:NSUTF8StringEncoding]];
                     }
                     
                     [mdata appendBytes:"\r\n" length:2];
                     [mdata appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n",v.type] dataUsingEncoding:NSUTF8StringEncoding]];
                     [mdata appendData:[@"Content-Transfer-Encoding: binary\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
                     
                     [mdata appendData:v.data];
                     [mdata appendBytes:"\r\n" length:2];
                     
                 }
            }
            [mdata appendData:[KKHttpBodyTokenEnd dataUsingEncoding:NSUTF8StringEncoding]];
        } else {
            for(KKHttpBodyItem * i in _items) {
                if([i isKindOfClass:[KKHttpBodyItemValue class]]) {
                    KKHttpBodyItemValue * v = (KKHttpBodyItemValue *) i;
                    if([mdata length] !=0 ){
                        [mdata appendBytes:"&" length:1];
                    }
                    [mdata appendData:[v.key dataUsingEncoding:NSUTF8StringEncoding]];
                    [mdata appendBytes:"=" length:1];
                    [mdata appendData:[[KKHttpOptions encodeURL:v.value] dataUsingEncoding:NSUTF8StringEncoding]];
                }
            }
        }
        
        _data = mdata;
    }
    return _data;
}
    
@end

@interface KKHttp() <NSURLSessionDelegate,NSURLSessionDataDelegate>  {
}
    
    @property(nonatomic,strong,readonly) NSMutableDictionary * identitysWithKey;
    @property(nonatomic,strong,readonly) NSMutableDictionary * tasksWithIdentity;
    @property(nonatomic,strong,readonly) NSMutableDictionary * sessionTasks;
    @property(nonatomic,strong,readonly) NSMutableDictionary * responsesWithIdentity;
    
    -(void) cancelTask:(KKHttpTask *) task;
    
@end

@interface KKHttpTask(){
    
}
    
    @property(nonatomic,weak) KKHttp * http;
    
    -(instancetype) initWithOptions:(KKHttpOptions *) options http:(KKHttp *) http weakObject:(id) weakObject identity:(NSUInteger) identity;
    
@end

@implementation KKHttpTask
    
    @synthesize options = _options;
    @synthesize http = _http;
    @synthesize weakObject = _weakObject;
    @synthesize identity = _identity;
    
    -(instancetype) initWithOptions:(KKHttpOptions *) options http:(KKHttp *) http weakObject:(id) weakObject identity:(NSUInteger) identity {
        if((self = [super init])) {
            _options = options;
            _key = options.key;
            _identity = identity;
            _http = http;
            _weakObject = weakObject;
        }
        return self;
    }
    
    -(void) cancel {
        [_http cancelTask:self];
    }
    
@end

@interface KKHttpResponse : NSObject {
    
    NSString * _path;
    NSString * _tmppath;
    NSMutableData * _data;
    unsigned long _encoding;
}

    @property(nonatomic,strong,readonly) KKHttpOptions * options;
    @property(nonatomic,strong,readonly) NSString *key;
    @property(nonatomic,assign) long long value;
    @property(nonatomic,assign,readonly) long long maxValue;
    @property(nonatomic,strong,readonly) id body;
    @property(nonatomic,strong,readonly) NSError * error;
    @property(nonatomic,assign,readonly,getter=isBackground) BOOL background;
    @property(nonatomic,strong) NSString * contentType;

    -(instancetype) initWithOptions:(KKHttpOptions *) options;
    
    -(void) onResponse:(NSHTTPURLResponse *) response;
    
    -(void) onData:(NSData *) data;
    
    -(void) onFail:(NSError *)error;
    
    -(void) onLoad;
    
@end

@implementation KKHttpResponse
  
    @synthesize options = _options;
    @synthesize key = _key;
    @synthesize value = _value;
    @synthesize maxValue = _maxValue;
    @synthesize body = _body;
    @synthesize error = _error;
    
    -(instancetype) initWithOptions:(KKHttpOptions *) options {
        if((self = [super init])) {
            _options = options;
            _key = options.key;
            _encoding = NSUTF8StringEncoding;
            
            if(_key != nil) {
                if(options.filePath != nil) {
                    _path = options.filePath;
                    _tmppath = options.filePath;
                } else {
                    _path = [KKHttpOptions cachePathWithURL:options.absoluteUrl];
                    _tmppath = [KKHttpOptions cacheTmpPathWithURL:options.absoluteUrl];
                }
            }
        }
        return self;
    }
    
    -(void) onResponse:(NSHTTPURLResponse *) response {
        _maxValue = [response expectedContentLength];
        self.contentType = [[[response allHeaderFields] valueForKey:@"Content-Type"] lowercaseString];
        if([self.contentType containsString:@"charset=gbk"] || [self.contentType containsString:@"charset=gb2312"]) {
            _encoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGBK_95);
        }
        
        if(_key != nil) {
            
            NSFileManager * fm = [NSFileManager defaultManager];
            
            if(![fm fileExistsAtPath:_tmppath]) {
                [fm createDirectoryAtPath:[_tmppath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
                FILE * fd = fopen([_tmppath UTF8String], "wb");
                if(fd != NULL){
                    fclose(fd);
                }
            } else if(response.statusCode == 200) {
                FILE * fd = fopen([_tmppath UTF8String], "wb");
                if(fd != NULL){
                    fclose(fd);
                }
            }
        } else {
            _data = [NSMutableData dataWithCapacity:64];
        }
     }
    
    -(void) onData:(NSData *) data {
        if(_key != nil) {
            
            FILE * fd = fopen([_tmppath UTF8String],"ab");
            
            if(fd != nil) {
                
                fwrite([data bytes], 1, [data length], fd);
                
                fclose(fd);
            }
        } else {
            [_data appendData:data];
        }

    }
    
    -(void) onFail:(NSError *) error {
        if(_key != nil) {
            if(_tmppath != _path) {
                NSFileManager * fm = [NSFileManager defaultManager];
                [fm removeItemAtPath:_tmppath error:nil];
            }
        }
    }
    
    -(void) onLoad {
        if(_key != nil) {
            
            NSFileManager * fm = [NSFileManager defaultManager];
            NSError * e = nil;
            
            if(_path != _tmppath) {
                [fm removeItemAtPath:_path error:nil];
                [fm moveItemAtPath:_tmppath toPath:_path error:nil];
            }
            
            _error = e;
            
            if([_options.type isEqualToString:KKHttpOptionsTypeURI]) {
                _body = _path;
            }
            else if([_options.type isEqualToString:KKHttpOptionsTypeImage]) {
                if([self.contentType containsString:@"image"]) {
                    _body = [UIImage kk_imageWithPath:_path];
                } else {
                    _body = nil;
                    _error = [NSError errorWithDomain:@"KKHttp" code:-300 userInfo:@{NSLocalizedDescriptionKey:@"错误的图片资源"}];
                    [fm removeItemAtPath:_path error:nil];
                }
            }
            
        } else if([_options.type isEqualToString:KKHttpOptionsTypeJSON]) {
            NSError * e = nil;
            _body = [NSJSONSerialization JSONObjectWithData:_data options:NSJSONReadingMutableLeaves error:&e];
            _error = e;
        } else if([_options.type isEqualToString:KKHttpOptionsTypeText]) {
            _body = [[NSString alloc] initWithData:_data encoding:_encoding];
        } else {
            _body = _data;
        }
    }
    
    -(BOOL) isBackground {
        return _key != nil || [_options.type isEqualToString:KKHttpOptionsTypeJSON];
    }
    
@end


@implementation KKHttp

    @synthesize session = _session;
    @synthesize identitysWithKey = _identitysWithKey;
    @synthesize tasksWithIdentity = _tasksWithIdentity;
    @synthesize sessionTasks = _sessionTasks;
    @synthesize responsesWithIdentity = _responsesWithIdentity;

    -(void) onInit {
        
    }
    
    -(instancetype) init {
        if((self = [super init])) {
            _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue currentQueue]];
            [self onInit];
        }
        return self;
    }
    
    -(instancetype) initWithConfiguration:(NSURLSessionConfiguration *) configuration {
        if((self = [super init])) {
            _session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:[NSOperationQueue currentQueue]];
            [self onInit];
        }
        return self;
    }
    
    -(NSMutableDictionary *) identitysWithKey {
        if(_identitysWithKey == nil) {
            _identitysWithKey = [[NSMutableDictionary alloc] initWithCapacity:4];
        }
        return _identitysWithKey;
    }
    
    -(NSMutableDictionary *) tasksWithIdentity {
        if(_tasksWithIdentity == nil) {
            _tasksWithIdentity = [[NSMutableDictionary alloc] initWithCapacity:4];
        }
        return _tasksWithIdentity;
    }
    
    -(NSMutableDictionary *) sessionTasks {
        if(_sessionTasks == nil) {
            _sessionTasks = [[NSMutableDictionary alloc] initWithCapacity:4];
        }
        return _sessionTasks;
    }
    
    -(NSMutableDictionary *) responsesWithIdentity {
        if(_responsesWithIdentity == nil) {
            _responsesWithIdentity = [[NSMutableDictionary alloc] initWithCapacity:4];
        }
        return _responsesWithIdentity;
    }
    
    -(id<KKHttpTask>) send:(KKHttpOptions *) options weakObject:(id) weakObject {
        
        NSString * key = options.key;
        
        if(key != nil) {
            NSNumber* identity = [self.identitysWithKey objectForKey:key];
            if(identity != nil) {
                NSMutableArray * tasks = [self.tasksWithIdentity objectForKey:identity];
                if(tasks != nil) {
                    KKHttpTask * v = [[KKHttpTask alloc] initWithOptions:options http:self weakObject:weakObject identity:[identity intValue]];
                    [tasks addObject:v];
                    return v;
                }
            }
        }
        
        NSURLRequest * req = [options request];
        
        if(req == nil) {
            
            NSLog(@"[KK] URL Error: %@",options.absoluteUrl);
            
            if(options.onfail) {
                
                __weak id vObject = weakObject;
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    options.onfail([NSError errorWithDomain:@"KKHttp" code:-300 userInfo:@{NSLocalizedDescriptionKey:@"错误的URL"}], vObject);
                });
            }
            
            return nil;
        }
        
        NSLog(@"[KK] %@",[[req URL] absoluteString]);
        
        if(options.data) {
            NSLog(@"[KK] %@",options.data);
        }
        
        NSURLSessionTask * sessionTask = [_session dataTaskWithRequest:req];
        
        KKHttpTask * v = [[KKHttpTask alloc] initWithOptions:options http:self weakObject:weakObject identity:sessionTask.taskIdentifier];
        
        NSNumber * identity = [NSNumber numberWithUnsignedInteger:sessionTask.taskIdentifier];
        
        if(key != nil) {
            [self.identitysWithKey setObject:identity forKey:key];
        }
        
        NSMutableArray * tasks = [self.tasksWithIdentity objectForKey:identity];
        
        if(tasks == nil) {
            tasks = [NSMutableArray arrayWithCapacity:4];
            [self.tasksWithIdentity setObject:tasks forKey:identity];
        }
        
        [tasks addObject:v];
        
        [self.sessionTasks setObject:sessionTask forKey:identity];
        [self.responsesWithIdentity setObject:[[KKHttpResponse alloc] initWithOptions:options] forKey:identity];
        
        [sessionTask resume];
        
        return v;
    }
    
    -(id<KKHttpTask>) get:(NSString *) url data:(id) data type:(NSString *) type onload:(KKHttpOnLoad) onload onfail:(KKHttpOnFail) onfail weakObject:(id) weakObject {
        KKHttpOptions * options = [[KKHttpOptions alloc] initWithURL:url];
        options.data = data;
        options.type = type;
        options.onload = onload;
        options.onfail = onfail;
        options.method = KKHttpOptionsGET;
        return [self send:options weakObject:weakObject];
    }
    
    -(id<KKHttpTask>) post:(NSString *) url data:(id) data type:(NSString *) type onload:(KKHttpOnLoad) onload onfail:(KKHttpOnFail) onfail weakObject:(id) weakObject {
        KKHttpOptions * options = [[KKHttpOptions alloc] initWithURL:url];
        options.data = data;
        options.type = type;
        options.onload = onload;
        options.onfail = onfail;
        options.method = KKHttpOptionsPOST;
        return [self send:options weakObject:weakObject];
    }
    
    -(void) cancel:(id) weakObject {
        NSMutableArray * identitys = [NSMutableArray arrayWithCapacity:4];
        
        {
            NSEnumerator * en = [self.tasksWithIdentity keyEnumerator];
            NSNumber * key;
            while((key = [en nextObject]) != nil) {
                NSMutableArray * tasks = [self.tasksWithIdentity objectForKey:key];
                int i=0;
                while(i < [tasks count]) {
                    KKHttpTask * v = [tasks objectAtIndex:i];
                    if(v.weakObject == weakObject) {
                        [tasks removeObjectAtIndex:i];
                        continue;
                    }
                    i ++;
                }
                if([tasks count] ==0) {
                    [identitys addObject:key];
                }
            }
        }
        
        for(NSNumber * identity in identitys) {
            
            NSURLSessionTask * v = [self.sessionTasks objectForKey:identity];
            
            if(v != nil) {
                [v cancel];
                [self.sessionTasks removeObjectForKey:identity];
                [self.responsesWithIdentity removeObjectForKey:identity];
            }
            
            NSMutableArray * keys = [NSMutableArray arrayWithCapacity:4];
            
            {
                NSEnumerator * en = [self.identitysWithKey keyEnumerator];
                NSString * key;
                while((key = [en nextObject]) != nil) {
                    if([identity isEqual:[self.identitysWithKey objectForKey:key]]) {
                        [keys addObject:key];
                    }
                }
            }
            
            for(NSString * key in keys) {
                [self.identitysWithKey removeObjectForKey:key];
            }
        }
    }
    
    -(void) cancelTask:(KKHttpTask *) task {
        
        NSNumber * identity = [NSNumber numberWithUnsignedInteger:task.identity];
        
        NSMutableArray * tasks = [self.tasksWithIdentity objectForKey:identity];
        
        if(tasks != nil) {
            
            [tasks removeObject:task];
            
            if([tasks count] == 0) {
                
                [self.tasksWithIdentity removeObjectForKey:identity];
                
                if(task.key != nil) {
                    [self.identitysWithKey removeObjectForKey:task.key];
                }
                
                NSURLSessionTask * v = [self.sessionTasks objectForKey:identity];
                
                if(v != nil) {
                    [v cancel];
                    [self.sessionTasks removeObjectForKey:identity];
                    [self.responsesWithIdentity removeObjectForKey:identity];
                }
            }
        }
    }
    
    - (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
            newRequest:(NSURLRequest *)request
     completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler {
        
        NSNumber * identity = [NSNumber numberWithUnsignedInteger:task.taskIdentifier];
        
        NSMutableArray * tasks = [self.tasksWithIdentity objectForKey:identity];
        
        for(KKHttpTask * task in tasks) {
            
            if(task.options.onredirect != nil) {
                if(task.options.onredirect((NSHTTPURLResponse *) response, task.weakObject) == NO) {
                    completionHandler(nil);
                    return;
                }
            }
            
        }
        
        completionHandler(request);
    }
    
    - (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveResponse:(NSURLResponse *)response
     completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
       
        NSNumber * identity = [NSNumber numberWithUnsignedInteger:dataTask.taskIdentifier];
        
        KKHttpResponse * r  = [self.responsesWithIdentity objectForKey:identity];
        
        [r onResponse:(NSHTTPURLResponse *) response];
        
        NSMutableArray * tasks = [self.tasksWithIdentity objectForKey:identity];
        
        for(KKHttpTask * task in tasks) {
      
            if(task.options.onresponse != nil) {
                task.options.onresponse((NSHTTPURLResponse *) response, task.weakObject);
            }
            
        }
        
        completionHandler(NSURLSessionResponseAllow);
        
    }
    
    - (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
        didReceiveData:(NSData *)data {
        
        NSNumber * identity = [NSNumber numberWithUnsignedInteger:dataTask.taskIdentifier];
        
        KKHttpResponse * r  = [self.responsesWithIdentity objectForKey:identity];
        
        if(r != nil) {
            
            if([r isBackground]) {
                
                dispatch_async(KKHttpIODispatchQueue(), ^{
                    [r onData:data];
                });
            } else {
                [r onData:data];
            }
            
            r.value = r.value + [data length];
            
            NSMutableArray * tasks = [self.tasksWithIdentity objectForKey:identity];
            
            for(KKHttpTask * task in tasks) {
                if(task.options.onprocess != nil) {
                    task.options.onprocess(r.value, r.maxValue, task.weakObject);
                }
            }
        }
    }
    
    - (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
       didSendBodyData:(int64_t)bytesSent
        totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
        
        NSNumber * identity = [NSNumber numberWithUnsignedInteger:task.taskIdentifier];
        
        NSMutableArray * tasks = [self.tasksWithIdentity objectForKey:identity];
        
        for(KKHttpTask * task in tasks) {
            if(task.options.onprocess != nil) {
                task.options.onprocess(totalBytesSent, totalBytesExpectedToSend, task.weakObject);
            }
        }
        
    }
    
    - (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
  didCompleteWithError:(nullable NSError *)error {
        
        NSNumber * identity = [NSNumber numberWithUnsignedInteger:task.taskIdentifier];
        
        KKHttpResponse * r  = [self.responsesWithIdentity objectForKey:identity];
        
        if(r != nil) {
            
            NSMutableArray * tasks = [self.tasksWithIdentity objectForKey:identity];
            
            void (^fn)(void) = ^(){
                
                for(KKHttpTask * task in tasks) {
                    
                    if(error == nil) {
                        if(task.options.onload != nil) {
                            task.options.onload(r.body, r.error, task.weakObject);
                        }
                    } else {
                        if(task.options.onfail != nil) {
                            task.options.onfail(error, task.weakObject);
                        }
                    }
                }
                
            };
            
            if([r isBackground]) {
                
                NSOperationQueue * q = session.delegateQueue;
                
                dispatch_async(KKHttpIODispatchQueue(), ^{
                    
                    if(error == nil) {
                        [r onLoad];
                    } else {
                        [r onFail:error];
                    }
                    
                    [q addOperationWithBlock:fn];
                    
                });
            } else {
                if(error == nil) {
                    [r onLoad];
                } else {
                    [r onFail:error];
                }
                fn();
            }
            
            [self.tasksWithIdentity removeObjectForKey:identity];
            [self.sessionTasks removeObjectForKey:identity];
            [self.responsesWithIdentity removeObjectForKey:identity];
            
            NSMutableArray * keys = [NSMutableArray arrayWithCapacity:4];
            
            {
                NSEnumerator * en = [self.identitysWithKey keyEnumerator];
                NSString * key;
                while((key = [en nextObject]) != nil) {
                    if([identity isEqual:[self.identitysWithKey objectForKey:key]]) {
                        [keys addObject:key];
                    }
                }
            }
            
            for(NSString * key in keys) {
                [self.identitysWithKey removeObjectForKey:key];
            }
            
            
        }
        
    }
    
    +(id<KKHttp>) main {
        static KKHttp * v = nil;
        if(v == nil) {
            v = [[KKHttp alloc] init];
        }
        return v;
    }

    +(UIImage *) imageWithURL:(NSString *) url {
        return [UIImage kk_imageWithPath:[KKHttpOptions cachePathWithURL:url]];
    }
    
    +(BOOL) imageWithURL:(NSString *) url callback:(KKHttpImageCallback) callback {
        NSString * path = [KKHttpOptions cachePathWithURL:url];
        if([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            if(callback) {
                dispatch_async(KKHttpIODispatchQueue(), ^{
                    UIImage * image = [UIImage kk_imageWithPath:path];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        callback(image);
                    });
                });
            }
            return YES;
        }
        return NO;
    }

    +(NSString *) stringValue:(id) value defaultValue:(NSString *) defaultValue {
        
        if(value == nil) {
            return defaultValue;
        }
        
        if([value isKindOfClass:[NSString class]]) {
            return value;
        }
        
        if([value respondsToSelector:@selector(stringValue)]) {
            return [value stringValue];
        }
        
        return defaultValue;
    }

    static NSString * gUserAgent = nil;

    +(NSString *) userAgent {
        if(gUserAgent == nil) {
            UIWebView *webView = [[UIWebView alloc] initWithFrame:CGRectZero];
            gUserAgent = [webView stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
#if TARGET_IPHONE_SIMULATOR==1
            gUserAgent = [gUserAgent stringByAppendingString:@" Simulator"];
#endif
        }
        return gUserAgent;
    }

    +(void) setUserAgent:(NSString *)userAgent {
        gUserAgent = userAgent;
    }
    
@end

dispatch_queue_t KKHttpIODispatchQueue() {
    static dispatch_queue_t v = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        v = dispatch_queue_create("kk-io", nil);
    });
    return v;
}
