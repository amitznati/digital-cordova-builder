

#ifndef SECUREHTTPURLPROTOCOL_H
#define SECUREHTTPURLPROTOCOL_H


#include <Foundation/Foundation.h>

/**
 * @brief This class implements a NSURLProtocol to implement white listing and certificate pinning
 * @ingroup port
 *
 * This class implements a NSURLProtocol that captures http/https requests in order to implement
 * http/https white listing and https certificate pinning.
 */
@protocol SecureHTTPURLProtocolErrorHandler
// class methods
- (void)handleWhiteListingError:(NSString*_Nullable)sFaultyURL;
- (void)handleUnmanagedError:(NSString*_Nullable)sErrorCode;
@end

@protocol SecureHTTPURLProtocolAuthenticationHandler
// class methods
- (BOOL)canHandleAuthentication:(NSURLAuthenticationChallenge*_Nullable)challenge;
- (BOOL)handleAuthentication:(NSURLAuthenticationChallenge*_Nullable)challenge;
@end

@interface SecureHTTPURLProtocol : NSURLProtocol<NSURLSessionDelegate, NSURLSessionDataDelegate>

/**
 * @brief initializes
 *
 * Sets the error handler and registers the protocol handler
 *
 * @param the error handler
 */
+ (void)initWithErrorHandler:(id <SecureHTTPURLProtocolErrorHandler>_Nullable)oErrorHandler;

/**
 * @brief set Authentication handler
 *
 * Sets the authentication handler
 *
 * @param the error handler
 */
+ (void)setAuthenticationHandler:(id <SecureHTTPURLProtocolAuthenticationHandler>_Nullable)oAuthenticationHandler;

/**
 * @brief set white listing feature operation.
 *
 * Sets the certificate pinning feature for this class
 * During this initialization phase, *.der certificate files are loaded for pinning
 *
 * @param the app content path (chtoub folder path)
 */
+ (void)setCertificatePinningWithContentPath:(NSString*_Nullable)sContentPath;

/**
 * @brief set white listing feature operation.
 *
 * Sets the white listing feature for this class.
 *
 * @param the white listing feature indicator for the feature ON/OFF
 * @param the white list of URLs
 */
+ (void)setWhiteListingWithIndicator:(const BOOL)bActivated URLs:(const NSArray*_Nullable)sURL;

/**
 * @brief URLMatchesWithListing operation
 *
 * Indicates whether one URL matches positively with whitelisting
 */
+ (BOOL)URLMatchesWithListing:(NSString *_Nullable)oURL;

/**
 * @brief didReceiveAuthenticationChallenge operation
 *
 * triggers security check with certificate pinning and device' certificates
 */
+ (void)didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *_Nullable)challenge completionHandler:(void (^_Nullable)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler;

/**
 * @brief dispose static operation.
 *
 * Releases resources associated to this class.
 */
+ (void)dispose;

//! The connection related to an URLProtocol instance
@property (nonatomic, retain) NSURLSessionDataTask * _Nullable m_oURLSessionDataTask;

@end

#endif // SECUREHTTPURLPROTOCOL_H
