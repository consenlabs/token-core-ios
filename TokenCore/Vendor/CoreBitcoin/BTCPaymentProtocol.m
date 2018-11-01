// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.

#import "BTCPaymentProtocol.h"
#import "BTCPaymentRequest.h"
#import "BTCErrors.h"
#import "BTCAssetType.h"
#import <Security/Security.h>

static NSString* const BTCBitcoinPaymentRequestMimeType = @"application/bitcoin-paymentrequest";
static NSString* const BTCOpenAssetsPaymentRequestMimeType = @"application/oa-paymentrequest";
static NSString* const BTCOpenAssetsPaymentMethodRequestMimeType = @"application/oa-paymentmethodrequest";

@interface BTCPaymentProtocol ()
@property(nonnull, nonatomic, readwrite) NSArray* assetTypes;
@property(nonnull, nonatomic) NSArray* paymentRequestMediaTypes;
@end

@implementation BTCPaymentProtocol

// Instantiates default BIP70 protocol that supports only Bitcoin.
- (nonnull id) init {
    return [self initWithAssetTypes:@[ BTCAssetTypeBitcoin ]];
}

// Instantiates protocol instance with accepted asset types.
- (nonnull id) initWithAssetTypes:(nonnull NSArray*)assetTypes {
    NSParameterAssert(assetTypes);
    NSParameterAssert(assetTypes.count > 0);
    if (self = [super init]) {
        self.assetTypes = assetTypes;
    }
    return self;
}

- (NSArray*) paymentRequestMediaTypes {
    if (!_paymentRequestMediaTypes && self.assetTypes) {
        NSMutableArray* arr = [NSMutableArray array];
        for (NSString* assetType in self.assetTypes) {
            if ([assetType isEqual:BTCAssetTypeBitcoin]) {
                [arr addObject:BTCBitcoinPaymentRequestMimeType];
            } else if ([assetType isEqual:BTCAssetTypeOpenAssets]) {
                [arr addObject:BTCOpenAssetsPaymentRequestMimeType];
            }
        }
        _paymentRequestMediaTypes = arr;
    }
    return _paymentRequestMediaTypes;
}

- (NSInteger) maxDataLength {
    return 50000;
}


// Convenience API


- (void) loadPaymentMethodRequestFromURL:(nonnull NSURL*)paymentMethodRequestURL
                       completionHandler:(nonnull void(^)(BTCPaymentMethodRequest* __nullable pmr, BTCPaymentRequest* __nullable pr, NSError* __nullable error))completionHandler {

    NSParameterAssert(paymentMethodRequestURL);
    NSParameterAssert(completionHandler);

    NSURLRequest* request = [self requestForPaymentMethodRequestWithURL:paymentMethodRequestURL];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        NSURLResponse* response = nil;
        NSError* error = nil;
        NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        if (!data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(nil, nil, error);
            });
            return;
        }
        id prOrPmr = [self polymorphicPaymentRequestFromData:data response:response error:&error];
        BTCPaymentRequest* pr = ([prOrPmr isKindOfClass:[BTCPaymentRequest class]] ? prOrPmr : nil);
        BTCPaymentMethodRequest* pmr = ([prOrPmr isKindOfClass:[BTCPaymentMethodRequest class]] ? prOrPmr : nil);
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(pmr, pr, prOrPmr ? nil : error);
        });
    });
}


- (void) loadPaymentRequestFromURL:(nonnull NSURL*)paymentRequestURL completionHandler:(nonnull void(^)(BTCPaymentRequest* __nullable pr, NSError* __nullable error))completionHandler {
    NSParameterAssert(paymentRequestURL);
    NSParameterAssert(completionHandler);

    NSURLRequest* request = [self requestForPaymentRequestWithURL:paymentRequestURL];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        NSURLResponse* response = nil;
        NSError* error = nil;
        NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        if (!data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(nil, error);
            });
            return;
        }
        BTCPaymentRequest* pr = [self paymentRequestFromData:data response:response error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(pr, pr ? nil : error);
        });
    });
}

- (void) postPayment:(nonnull BTCPayment*)payment URL:(nonnull NSURL*)paymentURL completionHandler:(nonnull void(^)(BTCPaymentACK* __nullable ack, NSError* __nullable error))completionHandler {
    NSParameterAssert(payment);
    NSParameterAssert(paymentURL);
    NSParameterAssert(completionHandler);

    NSURLRequest* request = [self requestForPayment:payment url:paymentURL];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        NSURLResponse* response = nil;
        NSError* error = nil;
        NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        if (!data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(nil, error);
            });
            return;
        }
        BTCPaymentACK* ack = [self paymentACKFromData:data response:response error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(ack, ack ? nil : error);
        });
    });
}


// Low-level API
// (use this if you have your own connection queue).

- (nullable NSURLRequest*) requestForPaymentMethodRequestWithURL:(nonnull NSURL*)url {
    return [self requestForPaymentMethodRequestWithURL:url timeout:10];
}

- (nullable NSURLRequest*) requestForPaymentMethodRequestWithURL:(nonnull NSURL*)url timeout:(NSTimeInterval)timeout {
    if (!url) return nil;
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:timeout];
    [request addValue:BTCBitcoinPaymentRequestMimeType forHTTPHeaderField:@"Accept"];
    [request addValue:BTCOpenAssetsPaymentRequestMimeType forHTTPHeaderField:@"Accept"];
    [request addValue:BTCOpenAssetsPaymentMethodRequestMimeType forHTTPHeaderField:@"Accept"];
    return request;
}

- (nullable id) polymorphicPaymentRequestFromData:(nonnull NSData*)data response:(nonnull NSURLResponse*)response error:(NSError* __nullable * __nullable)errorOut {
    NSString* mime = response.MIMEType.lowercaseString;
    BOOL isPaymentRequest = [mime isEqual:BTCBitcoinPaymentRequestMimeType] ||
                            [mime isEqual:BTCOpenAssetsPaymentRequestMimeType];
    BOOL isPaymentMethodRequest = [mime isEqual:BTCOpenAssetsPaymentMethodRequestMimeType];

    if (!isPaymentRequest && !isPaymentMethodRequest) {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorPaymentRequestInvalidResponse userInfo:@{}];
        return nil;
    }
    if (data.length > [self maxDataLength]) {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorPaymentRequestTooBig userInfo:@{}];
        return nil;
    }
    if (isPaymentRequest) {
        BTCPaymentRequest* pr = [[BTCPaymentRequest alloc] initWithData:data];
        if (!pr) {
            if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorPaymentRequestInvalidResponse userInfo:@{}];
            return nil;
        }
        return pr;
    } else if (isPaymentMethodRequest) {
        BTCPaymentMethodRequest* pmr = [[BTCPaymentMethodRequest alloc] initWithData:data];
        if (!pmr) {
            if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorPaymentRequestInvalidResponse userInfo:@{}];
            return nil;
        }
        return pmr;
    }
    return nil;

}

- (NSURLRequest*) requestForPaymentRequestWithURL:(NSURL*)paymentRequestURL {
    return [self requestForPaymentRequestWithURL:paymentRequestURL timeout:10];
}

- (NSURLRequest*) requestForPaymentRequestWithURL:(NSURL*)paymentRequestURL timeout:(NSTimeInterval)timeout {
    if (!paymentRequestURL) return nil;
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:paymentRequestURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:timeout];
    for (NSString* mimeType in self.paymentRequestMediaTypes) {
        [request addValue:mimeType forHTTPHeaderField:@"Accept"];
    }
    return request;
}

- (BTCPaymentRequest*) paymentRequestFromData:(NSData*)data response:(NSURLResponse*)response error:(NSError**)errorOut {

    NSArray* mimes = self.paymentRequestMediaTypes;
    NSString* mime = response.MIMEType.lowercaseString;
    if (![mimes containsObject:mime]) {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorPaymentRequestInvalidResponse userInfo:@{}];
        return nil;
    }
    if (data.length > [self maxDataLength]) {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorPaymentRequestTooBig userInfo:@{}];
        return nil;
    }
    BTCPaymentRequest* pr = [[BTCPaymentRequest alloc] initWithData:data];
    if (!pr) {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorPaymentRequestInvalidResponse userInfo:@{}];
        return nil;
    }
    if (pr.version == BTCPaymentRequestVersion1 && ![self.assetTypes containsObject:BTCAssetTypeBitcoin]) {
        // Client did not want bitcoin, but received bitcoin.
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorPaymentRequestInvalidResponse userInfo:@{}];
        return nil;
    }
    if (pr.version == BTCPaymentRequestVersionOpenAssets1 && ![self.assetTypes containsObject:BTCAssetTypeOpenAssets]) {
        // Client did not want open assets, but received open assets.
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorPaymentRequestInvalidResponse userInfo:@{}];
        return nil;
    }
    return pr;
}

- (NSURLRequest*) requestForPayment:(BTCPayment*)payment url:(NSURL*)paymentURL {
    return [self requestForPayment:payment url:paymentURL timeout:10];
}

- (NSURLRequest*) requestForPayment:(BTCPayment*)payment url:(NSURL*)paymentURL timeout:(NSTimeInterval)timeout {
    if (!payment) return nil;
    if (!paymentURL) return nil;

    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:paymentURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:timeout];

    [request addValue:@"application/bitcoin-payment" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/bitcoin-paymentack" forHTTPHeaderField:@"Accept"];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:payment.data];
    return request;
}

- (BTCPaymentACK*) paymentACKFromData:(NSData*)data response:(NSURLResponse*)response error:(NSError**)errorOut {

    if (![response.MIMEType.lowercaseString isEqual:@"application/bitcoin-paymentack"]) {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorPaymentRequestInvalidResponse userInfo:@{}];
        return nil;
    }
    if (data.length > [self maxDataLength]) {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorPaymentRequestTooBig userInfo:@{}];
        return nil;
    }

    BTCPaymentACK* ack = [[BTCPaymentACK alloc] initWithData:data];

    if (!ack) {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorPaymentRequestInvalidResponse userInfo:@{}];
        return nil;
    }
    
    return ack;
}




// DEPRECATED METHODS

+ (void) loadPaymentRequestFromURL:(NSURL*)paymentRequestURL completionHandler:(void(^)(BTCPaymentRequest* pr, NSError* error))completionHandler {
    [[[self alloc] init] loadPaymentRequestFromURL:paymentRequestURL completionHandler:completionHandler];
}
+ (void) postPayment:(BTCPayment*)payment URL:(NSURL*)paymentURL completionHandler:(void(^)(BTCPaymentACK* ack, NSError* error))completionHandler {
    [[[self alloc] init] postPayment:payment URL:paymentURL completionHandler:completionHandler];
}

+ (NSURLRequest*) requestForPaymentRequestWithURL:(NSURL*)paymentRequestURL {
    return [self requestForPaymentRequestWithURL:paymentRequestURL timeout:10];
}

+ (NSURLRequest*) requestForPaymentRequestWithURL:(NSURL*)paymentRequestURL timeout:(NSTimeInterval)timeout {
    return [[[self alloc] init] requestForPaymentRequestWithURL:paymentRequestURL timeout:timeout];
}

+ (BTCPaymentRequest*) paymentRequestFromData:(NSData*)data response:(NSURLResponse*)response error:(NSError**)errorOut {
    return [[[self alloc] init] paymentRequestFromData:data response:response error:errorOut];
}

+ (NSURLRequest*) requestForPayment:(BTCPayment*)payment url:(NSURL*)paymentURL {
    return [self requestForPayment:payment url:paymentURL timeout:10];
}

+ (NSURLRequest*) requestForPayment:(BTCPayment*)payment url:(NSURL*)paymentURL timeout:(NSTimeInterval)timeout {
    return [[[self alloc] init] requestForPayment:payment url:paymentURL timeout:timeout];
}

+ (BTCPaymentACK*) paymentACKFromData:(NSData*)data response:(NSURLResponse*)response error:(NSError**)errorOut {
    return [[[self alloc] init] paymentACKFromData:data response:response error:errorOut];
}

@end


