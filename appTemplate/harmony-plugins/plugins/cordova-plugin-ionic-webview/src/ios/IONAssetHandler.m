#import "IONAssetHandler.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "CDVWKWebViewEngine.h"

@implementation IONAssetHandler

-(void)setAssetPath:(NSString *)assetPath {
    self.basePath = assetPath;
}

- (instancetype)initWithBasePath:(NSString *)basePath andScheme:(NSString *)scheme andCustomEntryPoint:(NSString *) customEntryPoint {
    self = [super init];
    if (self) {
        _basePath = basePath;
        _scheme = scheme;
        _customEntryPoint = customEntryPoint;
    }
    return self;
}
- (void) updateBasePath: (NSString *) cordovaDataDirectoryUpdateDir {
    self.basePath = cordovaDataDirectoryUpdateDir;
}
- (void)webView:(WKWebView *)webView startURLSchemeTask:(id <WKURLSchemeTask>)urlSchemeTask
{
    NSString * startPath = @"";
    NSURL * url = urlSchemeTask.request.URL;
    NSString * stringToLoad = url.path;
    NSString * scheme = url.scheme;
    /* DEBUG TESTING CONTENT UPDATE
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *libPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString * cordovaDataDirectory = [libPath stringByAppendingPathComponent:@"NoCloud"];
    NSString * cordovaDataDirectorymyApp = [cordovaDataDirectory stringByAppendingPathComponent:@"myapp"];

    NSString *tempPath = cordovaDataDirectory;
    NSLog(@"path exists %@", [fileManager fileExistsAtPath:tempPath] ? @"YES" : @"NO");
    NSLog(@"path exists %@", [fileManager fileExistsAtPath:cordovaDataDirectorymyApp] ? @"YES" : @"NO");

    NSLog(@"lib path %@", cordovaDataDirectory);
    NSFileManager *oFileManager = [NSFileManager defaultManager];
    NSArray *oAllDirContent = [oFileManager contentsOfDirectoryAtPath:cordovaDataDirectorymyApp error:nil];
    if (nil == oAllDirContent)
    {
        NSLog(@"no files at path");
    }
  
    // Load all certificates
    for (NSString *sFilename in oAllDirContent)
    {
        NSLog(@"path file %@", sFilename);
    }
    DEBUG TESTING CONTENT UPDATE */
    
    
    
    if ([scheme isEqualToString:self.scheme]) {
        if ([stringToLoad hasPrefix:@"/_app_file_"]) {
            startPath = [stringToLoad stringByReplacingOccurrencesOfString:@"/_app_file_" withString:@""];
        } else {
            startPath = self.basePath ? self.basePath : @"";
             if ([stringToLoad isEqualToString:@""] || [url.pathExtension isEqualToString:@""]) {
                startPath = [startPath stringByAppendingString:@"index.html"];
            }  else {
                startPath = [startPath stringByAppendingString:stringToLoad];
            }
        }
    }
    
    NSError * fileError = nil;
    NSData * data = nil;
    if ([self isMediaExtension:url.pathExtension]) {
        data = [NSData dataWithContentsOfFile:startPath options:NSDataReadingMappedIfSafe error:&fileError];
    }
    if (!data || fileError) {
        data =  [[NSData alloc] initWithContentsOfFile:startPath];
    }
    NSInteger statusCode = 200;
    if (!data) {
        statusCode = 404;
    }
    NSURL * localUrl = [NSURL URLWithString:url.absoluteString];
    NSString * mimeType = [self getMimeType:url.pathExtension];
    id response = nil;
    if (data && [self isMediaExtension:url.pathExtension]) {
        response = [[NSURLResponse alloc] initWithURL:localUrl MIMEType:mimeType expectedContentLength:data.length textEncodingName:nil];
    } else {
        NSDictionary * headers = @{ @"Content-Type" : mimeType, @"Cache-Control": @"no-cache"};
        response = [[NSHTTPURLResponse alloc] initWithURL:localUrl statusCode:statusCode HTTPVersion:nil headerFields:headers];
    }
    
    [urlSchemeTask didReceiveResponse:response];
    [urlSchemeTask didReceiveData:data];
    [urlSchemeTask didFinish];

}

- (void)webView:(nonnull WKWebView *)webView stopURLSchemeTask:(nonnull id<WKURLSchemeTask>)urlSchemeTask
{
    NSLog(@"stop");
}

-(NSString *) getMimeType:(NSString *)fileExtension {
    if (fileExtension && ![fileExtension isEqualToString:@""]) {
        NSString *UTI = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)fileExtension, NULL);
        NSString *contentType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)UTI, kUTTagClassMIMEType);
        return contentType ? contentType : @"application/octet-stream";
    } else {
        return @"text/html";
    }
}

-(BOOL) isMediaExtension:(NSString *) pathExtension {
    NSArray * mediaExtensions = @[@"m4v", @"mov", @"mp4",
                           @"aac", @"ac3", @"aiff", @"au", @"flac", @"m4a", @"mp3", @"wav",@"html", @"css", @"js"];
    if ([mediaExtensions containsObject:pathExtension.lowercaseString]) {
        return YES;
    }
    return NO;
}


@end
