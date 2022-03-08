
#include "SecureHTTPURLProtocol.h"


// system import
#import <UIKit/UIKit.h>

/**
 * @brief This class implements a NSURLProtocol to implement white listing and certificate pinning
 * @ingroup port
 *
 * This class implements a NSURLProtocol that captures http/https requests in order to implement
 * http/https white listing and https certificate pinning.
 */
@implementation SecureHTTPURLProtocol

@synthesize m_oURLSessionDataTask;

// Constant to set a request property to identify request being handle, in order to avoid cycle
static NSString* kPropertyFlagToBreakCycle = @"com.harmony.urlbeinghandled";

// Constant to set a request property to identify redirected requests
static NSString* kPropertyFlagForRedirectedRequests = @"com.harmony.redirected";

// The loaded certificates if any
static NSMutableArray* gCertificates = nil;

// The white listing feature indicator
static BOOL g_bWhiteListingActivated = NO;
static NSMutableArray *g_oWhiteListURLs = nil;

// workaround indicator for some issue
static BOOL m_bShouldApplyCookieRestoreOnRedirect = NO;

// error callback
static id <SecureHTTPURLProtocolErrorHandler> m_oErrorHandler = nil;

// authentication handler
static id <SecureHTTPURLProtocolAuthenticationHandler> m_oAuthenticationHandler = nil;

/**
 * @brief initializes
 *
 * Sets the error handler and registers the protocol handler
 *
 * @param the error handler
 */
+ (void)initWithErrorHandler:(id <SecureHTTPURLProtocolErrorHandler>)oErrorHandler
{
   // register handler
   m_oErrorHandler = oErrorHandler;
   
   // Register this NSURLProtocol class
   [NSURLProtocol registerClass:self];

   // compute once some stuff
   // need to apply some workaround below only for some specific 13 =< version < 13.2
   NSString *sVersion = [[UIDevice currentDevice] systemVersion];
   if (([sVersion compare:@"13.0" options:NSNumericSearch] != NSOrderedAscending) && ([sVersion compare:@"13.2" options:NSNumericSearch] == NSOrderedAscending))
   {
      m_bShouldApplyCookieRestoreOnRedirect = YES;
   }
}

/**
 * @brief set Authentication handler
 *
 * Sets the authentication handler
 *
 * @param the error handler
 */
+ (void)setAuthenticationHandler:(id <SecureHTTPURLProtocolAuthenticationHandler>)oAuthenticationHandler;
{
   //report handler
   m_oAuthenticationHandler = oAuthenticationHandler;
}

/**
 * @brief set white listing feature operation.
 *
 * Sets the certificate pinning feature for this class
 * During this initialization phase, *.der certificate files are loaded for pinning
 *
 * @param the app content path (chtoub folder path)
 */
+ (void)setCertificatePinningWithContentPath:(NSString*_Nullable)sContentPath
{
   
   // Default init
   gCertificates = [[NSMutableArray alloc] init];
   
   // Get paths of all certificates files
   NSFileManager *oFileManager = [NSFileManager defaultManager];
   NSArray *oAllDirContent = [oFileManager contentsOfDirectoryAtPath:sContentPath error:nil];
   if (nil == oAllDirContent)
   {
      return;
   }
   NSPredicate *oFilter = [NSPredicate predicateWithFormat:@"SELF ENDSWITH '.der'"];
   NSArray *oAllCertFilename = [oAllDirContent filteredArrayUsingPredicate:oFilter];
   
   // Load all certificates
   for (NSString *sFilename in oAllCertFilename)
   {
      // Read certificate file data
       
      NSString *sFilepath = [sContentPath stringByAppendingString:sFilename];
      NSData *oData = [NSData dataWithContentsOfFile:sFilepath];

      // Create the certificate object and store it
      if (nil != oData)
      {
         SecCertificateRef oCertificate = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)oData);
         if (NULL != oCertificate)
         {
            
            // Store in the certificate array, transferring ownership
            [gCertificates addObject:(__bridge id)oCertificate];
            CFRelease(oCertificate);
         }
         else
         {
         }
      }
   }
}

/**
 * @brief set white listing feature operation.
 *
 * Sets the white listing feature for this class. Does NOT register the protocol itself
 *
 * @param the white listing feature indicator for the feature ON/OFF
 * @param the white list of URLs
 */
+ (void)setWhiteListingWithIndicator:(const BOOL)bActivated URLs:(const NSArray*)sURL
{
   // VARs
   NSError *oError = nil;

   // create tool regexpr
   NSRegularExpression* oRegex80 = [NSRegularExpression regularExpressionWithPattern:@"^http:\\\\/\\\\/.*:80$" options:0 error:&oError];
   NSRegularExpression* oRegex443 = [NSRegularExpression regularExpressionWithPattern:@"^https:\\\\/\\\\/.*:443$" options:0 error:&oError];
   NSRegularExpression* oRegexPort = [NSRegularExpression regularExpressionWithPattern:@".*:\\d+$" options:0 error:&oError];
   
   // initialize white listing attributes
   g_bWhiteListingActivated = bActivated;
   g_oWhiteListURLs = [[NSMutableArray alloc] init];
   
   // create regular expressions
   for (NSUInteger nI = 0; nI < [sURL count]; nI++)
   {
      // convert to string
      NSString *sExpr = [sURL objectAtIndex:nI];
      
      // escape all character except * for regular expression : ? + [ ( ) { } ^ $ | \ . /
      // starting with escape character \ itself of course
      sExpr = [sExpr stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
      sExpr = [sExpr stringByReplacingOccurrencesOfString:@"?" withString:@"\\?"];
      sExpr = [sExpr stringByReplacingOccurrencesOfString:@"+" withString:@"\\+"];
      sExpr = [sExpr stringByReplacingOccurrencesOfString:@"[" withString:@"\\["];
      sExpr = [sExpr stringByReplacingOccurrencesOfString:@"(" withString:@"\\("];
      sExpr = [sExpr stringByReplacingOccurrencesOfString:@")" withString:@"\\)"];
      sExpr = [sExpr stringByReplacingOccurrencesOfString:@"{" withString:@"\\{"];
      sExpr = [sExpr stringByReplacingOccurrencesOfString:@"}" withString:@"\\}"];
      sExpr = [sExpr stringByReplacingOccurrencesOfString:@"^" withString:@"\\^"];
      sExpr = [sExpr stringByReplacingOccurrencesOfString:@"$" withString:@"\\$"];
      sExpr = [sExpr stringByReplacingOccurrencesOfString:@"|" withString:@"\\|"];
      sExpr = [sExpr stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
      sExpr = [sExpr stringByReplacingOccurrencesOfString:@"/" withString:@"\\/"];
      
      // * becomes a .+
      sExpr = [sExpr stringByReplacingOccurrencesOfString:@"*" withString:@".+"];
      
      // handle default port numbers
      NSString *sPort = @"";
      NSRange oSearchedRange = NSMakeRange(0, [sExpr length]);
      if (nil != [oRegex80 firstMatchInString:sExpr options:0 range: oSearchedRange])
      {
         sExpr = [sExpr stringByReplacingOccurrencesOfString:@":80" withString:@"80"];
         sPort = @"(:80)?";
      }
      else if (nil != [oRegex443 firstMatchInString:sExpr options:0 range: oSearchedRange])
      {
         sExpr = [sExpr stringByReplacingOccurrencesOfString:@":443" withString:@"443"];
         sPort = @"(:443)?";
      }
      // accept any port if not specified
      else if (nil == [oRegexPort firstMatchInString:sExpr options:0 range: oSearchedRange])
      {
         // Any port
         sPort = @"(:\\d+)?";
      }
      // else: let the specified port in the developer spec
      
      // complete rule
      sExpr = [@"^" stringByAppendingString:sExpr];
      sExpr = [sExpr stringByAppendingString:sPort];
      sExpr = [sExpr stringByAppendingString:@"(\\/.*)?"];
      
      // add the regular expression to the list
      NSRegularExpression* oRegExp = [NSRegularExpression regularExpressionWithPattern:sExpr options:0 error:&oError];
      [g_oWhiteListURLs addObject:oRegExp];
   }
}

/**
 * @brief dispose static operation.
 *
 * Releases resources associated to this class.
 */
+ (void)dispose
{
   // Release stored certificates
   if (nil != gCertificates)
   {
      [gCertificates removeAllObjects];
      gCertificates = nil;
   }
   // Release while list URLs
   if (nil != g_oWhiteListURLs)
   {
      [g_oWhiteListURLs removeAllObjects];
      g_oWhiteListURLs = nil;
   }
}

/**
 * @brief NSURLProtocol implementation
 */
+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
   // Sanity check
   NSURL* oURL = [request URL];
   if ((nil == oURL) || (nil == [oURL absoluteString]))
   {
      return NO;
   }
   
   // Break cycle, because our NSURLConnection goes there as well
   if (nil != [self propertyForKey:kPropertyFlagToBreakCycle inRequest:request])
   {
      return NO;
   }
   
   // handle http and https for white listing and certificate pinning
   NSString* sScheme = [[oURL scheme] lowercaseString];
   if (nil == sScheme)
   {
      return NO;
   }
   
   // handle https and http transaction to implement certificate pinning and white listing
   // and, anyway, at least to catch ATS errors
   if (([sScheme isEqual:@"https"]) || ([sScheme isEqual:@"http"]))
   {
      return YES;
   }
   return NO;
}

/**
 * @brief NSURLProtocol implementation
 */
+ (NSURLRequest*)canonicalRequestForRequest:(NSURLRequest *)request
{
   // Maybe we should refine this... But it is very complex...
   // 2 request that are effectively the same should have the same resquest string so as to target the same cached content
   // So lot of transformation must be applied on the passed-in request
   return request;
}

/**
 * @brief NSURLProtocol implementation
 */
- (void)startLoading
{
   // Create a mutable copy of the request
   NSMutableURLRequest *oActualRequest = [[self request] mutableCopy];

   // Force no cache to disable sending of the previously received ETag in order to avoid response code 412
   if ([[oActualRequest HTTPMethod] isEqualToString:@"POST"])
   {
      // Check if the request header specify 'no-cache'
      NSString *sCacheControl = [oActualRequest valueForHTTPHeaderField:@"Cache-Control"];
      if ((sCacheControl != nil) && ([sCacheControl rangeOfString:@"no-cache"].location != NSNotFound))
      {
         [oActualRequest setCachePolicy:NSURLRequestReloadIgnoringCacheData];
      }
   }
   
   // Set custom property in the request to be able to detect cycle
   [[self class] setProperty:@YES forKey:kPropertyFlagToBreakCycle inRequest:oActualRequest];
   
   // create the URL session
   NSURLSession *oURLSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:nil];
   
   
  // verify if URL matches white listing
  if ([[self class] URLMatchesWithListing:[[oActualRequest URL] absoluteString]])
  {
     // Start the request
     self.m_oURLSessionDataTask = [oURLSession dataTaskWithRequest:oActualRequest];
     [self.m_oURLSessionDataTask resume];
   
  }
  else
  {
     // stop transaction and raise error (will produce a dual log in safari console)
     NSError* oError = [NSError errorWithDomain:@"com.harmony" code:403 userInfo:@{ NSLocalizedDescriptionKey:@"[Whitelisting] Content Blocked"}];
     [[self client] URLProtocol:self didFailWithError:oError];
     [m_oErrorHandler handleWhiteListingError:[[oActualRequest URL] absoluteString]];
  }
  

}

/**
 * @brief NSURLProtocol implementation
 */
- (void)stopLoading
{

   // Stop
   [m_oURLSessionDataTask cancel];
   
   // Release
   self.m_oURLSessionDataTask = nil;
}

/**
 * @brief NSURLSessionDataDelegate implementation
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
   // By default UIWebView only use in memory cache, so do the same here so as to not change the default behavior
   [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowedInMemoryOnly];

   // Task continues normally
   completionHandler(NSURLSessionResponseAllow);
}

/**
 * @brief NSURLSessionDataDelegate implementation
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
   [[self client] URLProtocol:self didLoadData:data];
}

/**
 * @brief NSURLSessionTaskDelegate implementation
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
   if (nil != error)
   {
      
      // include here something to warn application about ATS/SSL failing when it is one internal request
      
      [[self client] URLProtocol:self didFailWithError:error];
   }
   else
   {
      [[self client] URLProtocolDidFinishLoading:self];
   }
}

/**
 * @brief NSURLSessionTaskDelegate implementation
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler
{
   if (response)
   {

      // Create a mutable copy of the request
      NSMutableURLRequest *newRequest = [request mutableCopy];

      // insert manually the cookies in redirections as, for some reason, they are dropped (eaten?)
      // between iOS13 and iOS13.2
      if (m_bShouldApplyCookieRestoreOnRedirect)
      {
         NSArray *oResponseCookies = [NSHTTPCookie cookiesWithResponseHeaderFields:[response allHeaderFields] forURL:[[self request] URL]];
         [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookies:oResponseCookies forURL:[[self request] URL] mainDocumentURL:nil];
      }

      // Remove the custom property since it is a new request
      [[self class] removePropertyForKey:kPropertyFlagToBreakCycle inRequest:newRequest];
      
      // Indicate it is a redirect from one (implicitely) accepted request
      [[self class] setProperty:@YES forKey:kPropertyFlagForRedirectedRequests inRequest:newRequest];
      
      // Forward redirect info to the protocol client
      [[self client] URLProtocol:self wasRedirectedToRequest:newRequest redirectResponse:response];
      
      // Cancel current connection
      [m_oURLSessionDataTask cancel];
      
      // Release request copy object
      //[newRequest release];
   }
}

/**
 * @brief NSURLSessionTaskDelegate implementation
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler
{
   // We only want to handle server trust challenge. Let the default behavior apply to other type of challenge.
   // Default behavior will also be used if any error occurs
   // Same if there is no embedded certificates
   // would be nice to move this in plugins so as to disable the whole code at prod
   if ( ([[[challenge protectionSpace] authenticationMethod] isEqual:NSURLAuthenticationMethodServerTrust]) && (nil != gCertificates) && (0 != [gCertificates count]) )
   {
      
      // Get server SSL transaction states and check against loaded certificates
      SecTrustRef oTrust = [[challenge protectionSpace] serverTrust];
      if (nil != oTrust)
      {
         // Set the anchor certificates to use when evaluating the trust management object
         OSStatus nError = SecTrustSetAnchorCertificates(oTrust, (__bridge CFArrayRef)gCertificates);
         if (errSecSuccess == nError)
         {
            // Enable trusting built-in anchor certificates
            nError = SecTrustSetAnchorCertificatesOnly(oTrust, false);
            if (errSecSuccess == nError)
            {
               // Validate
               /*
               SecTrustResultType nTrustResult;
               nError = SecTrustEvaluate(oTrust, &nTrustResult);
               if (errSecSuccess == nError)
               {
                  // Check result
                  if ( (kSecTrustResultProceed == nTrustResult) || (kSecTrustResultUnspecified == nTrustResult) )
                  {
                     // OK, continue challenge with this credential
                     completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:oTrust]);
                     return;
                  }
               }
               */
                nError = SecTrustEvaluateWithError(oTrust, nil);
                if (errSecSuccess == nError)
                {
                   
                      // OK, continue challenge with this credential
                      completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:oTrust]);
                      return;
                  
                }
            }
         }
      }
   }

   // check if external authentication handler is able to handle, this call will end up in plugins
   if (nil != m_oAuthenticationHandler)
   {
      if (YES == [m_oAuthenticationHandler canHandleAuthentication:challenge])
      {
         if (YES == [m_oAuthenticationHandler handleAuthentication:challenge])
         {
            return;
         }
      }
   }
   
   // finally, trigger default behavior
   completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

/**
 * @brief didReceiveAuthenticationChallenge operation
 *
 * triggers security check with certificate pinning and device' certificates
 */
+ (void)didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler
{
   // We only want to handle server trust challenge. Let the default behavior apply to other type of challenge.
   // Default behavior will also be used if any error occurs
   // Same if there is no embedded certificates
   // would be nice to move this in plugins so as to disable the whole code at prod
    NSString *appFolderPath = [[NSBundle mainBundle] resourcePath];
    NSString *imagePath = [appFolderPath stringByAppendingString:@"/www/certificates/"];
[self setCertificatePinningWithContentPath:imagePath];
   if (([[[challenge protectionSpace] authenticationMethod] isEqual:NSURLAuthenticationMethodServerTrust]) && (nil != gCertificates) && (0 != [gCertificates count]) )
   {
       NSLog(@"host: %s",[[[challenge protectionSpace] host] UTF8String]);
      
      // Get server SSL transaction states and check against loaded certificates
      SecTrustRef oTrust = [[challenge protectionSpace] serverTrust];
      if (nil != oTrust)
      {
         // Set the anchor certificates to use when evaluating the trust management object
         OSStatus nError = SecTrustSetAnchorCertificates(oTrust, (__bridge CFArrayRef)gCertificates);
         if (errSecSuccess == nError)
         {
            // Enable trusting built-in anchor certificates
            nError = SecTrustSetAnchorCertificatesOnly(oTrust, false);
            if (errSecSuccess == nError)
            {
               // Validate
                nError = SecTrustEvaluateWithError(oTrust, nil);
                if (nError)
                {
                   
                      // OK, continue challenge with this credential
                      completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:oTrust]);
                      return;
                  
                }
            }
         }
      }
   }
   
   // no external approver (MDM) as for willSendRequestForAuthenticationChallenge

   // finally, trigger default behavior
   completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

/**
 * @brief URLMatchesWithListing operation
 *
 * Indicates whether one URL matches positively with whitelisting
 */
+ (BOOL)URLMatchesWithListing:(NSString *)oURL
{
   // check if white listing is activated
   if (NO == g_bWhiteListingActivated)
   {
      // allow
      return YES;
   }
   
   // loop in the array of built expressions
   for (NSUInteger nI = 0; nI < [g_oWhiteListURLs count]; nI++)
   {
      NSRegularExpression *oRegex = [g_oWhiteListURLs objectAtIndex:nI];
      NSRange oSearchedRange = NSMakeRange(0, [oURL length]);
      if (nil != [oRegex firstMatchInString:oURL options:0 range: oSearchedRange])
      {
         return YES;
      }
   }
   
   return NO;
}

@end
