// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.

#import "BTCPaymentRequest.h"
#import "BTCProtocolBuffers.h"
#import "BTCErrors.h"
#import "BTCAssetType.h"
#import "BTCAssetID.h"
#import "BTCData.h"
#import "BTCNetwork.h"
#import "BTCScript.h"
#import "BTCTransaction.h"
#import "BTCTransactionOutput.h"
#import "BTCTransactionInput.h"
#import <Security/Security.h>

NSInteger const BTCPaymentRequestVersion1 = 1;
NSInteger const BTCPaymentRequestVersionOpenAssets1 = 0x4f41;

NSString* const BTCPaymentRequestPKITypeNone = @"none";
NSString* const BTCPaymentRequestPKITypeX509SHA1 = @"x509+sha1";
NSString* const BTCPaymentRequestPKITypeX509SHA256 = @"x509+sha256";

BTCAmount const BTCUnspecifiedPaymentAmount = -1;

typedef NS_ENUM(NSInteger, BTCOutputKey) {
    BTCOutputKeyAmount = 1,
    BTCOutputKeyScript = 2,
    BTCOutputKeyAssetID = 4001, // only for Open Assets PRs.
    BTCOutputKeyAssetAmount = 4002 // only for Open Assets PRs.
};

typedef NS_ENUM(NSInteger, BTCInputKey) {
    BTCInputKeyTxhash = 1,
    BTCInputKeyIndex = 2
};

typedef NS_ENUM(NSInteger, BTCRequestKey) {
    BTCRequestKeyVersion        = 1,
    BTCRequestKeyPkiType        = 2,
    BTCRequestKeyPkiData        = 3,
    BTCRequestKeyPaymentDetails = 4,
    BTCRequestKeySignature      = 5
};

typedef NS_ENUM(NSInteger, BTCDetailsKey) {
    BTCDetailsKeyNetwork      = 1,
    BTCDetailsKeyOutputs      = 2,
    BTCDetailsKeyTime         = 3,
    BTCDetailsKeyExpires      = 4,
    BTCDetailsKeyMemo         = 5,
    BTCDetailsKeyPaymentURL   = 6,
    BTCDetailsKeyMerchantData = 7,
    BTCDetailsKeyInputs       = 8
};

typedef NS_ENUM(NSInteger, BTCCertificatesKey) {
    BTCCertificatesKeyCertificate = 1
};

typedef NS_ENUM(NSInteger, BTCPaymentKey) {
    BTCPaymentKeyMerchantData = 1,
    BTCPaymentKeyTransactions = 2,
    BTCPaymentKeyRefundTo     = 3,
    BTCPaymentKeyMemo         = 4
};

typedef NS_ENUM(NSInteger, BTCPaymentAckKey) {
    BTCPaymentAckKeyPayment = 1,
    BTCPaymentAckKeyMemo    = 2
};


@interface BTCPaymentRequest ()
// If you make these publicly writable, make sure to set _data to nil and _isValidated to NO.
@property(nonatomic, readwrite) NSInteger version;
@property(nonatomic, readwrite) NSString* pkiType;
@property(nonatomic, readwrite) NSData* pkiData;
@property(nonatomic, readwrite) BTCPaymentDetails* details;
@property(nonatomic, readwrite) NSData* signature;
@property(nonatomic, readwrite) NSArray* certificates;
@property(nonatomic, readwrite) NSData* data;

@property(nonatomic) BOOL isValidated;
@property(nonatomic, readwrite) BOOL isValid;
@property(nonatomic, readwrite) NSString* signerName;
@property(nonatomic, readwrite) BTCPaymentRequestStatus status;
@end


@interface BTCPaymentDetails ()
@property(nonatomic, readwrite) BTCNetwork* network;
@property(nonatomic, readwrite) NSArray* /*[BTCTransactionOutput]*/ outputs;
@property(nonatomic, readwrite) NSArray* /*[BTCTransactionInput]*/ inputs;
@property(nonatomic, readwrite) NSDate* date;
@property(nonatomic, readwrite) NSDate* expirationDate;
@property(nonatomic, readwrite) NSString* memo;
@property(nonatomic, readwrite) NSURL* paymentURL;
@property(nonatomic, readwrite) NSData* merchantData;
@property(nonatomic, readwrite) NSData* data;
@end


@interface BTCPayment ()
@property(nonatomic, readwrite) NSData* merchantData;
@property(nonatomic, readwrite) NSArray* /*[BTCTransaction]*/ transactions;
@property(nonatomic, readwrite) NSArray* /*[BTCTransactionOutput]*/ refundOutputs;
@property(nonatomic, readwrite) NSString* memo;
@property(nonatomic, readwrite) NSData* data;
@end


@interface BTCPaymentACK ()
@property(nonatomic, readwrite) BTCPayment* payment;
@property(nonatomic, readwrite) NSString* memo;
@property(nonatomic, readwrite) NSData* data;
@end







@implementation BTCPaymentRequest

- (id) initWithData:(NSData*)data {
    if (!data) return nil;

    if (self = [super init]) {

        // Note: we are not assigning default values here because we need to
        // reconstruct exact data (without the signature) for signature verification.

        NSInteger offset = 0;
        while (offset < data.length) {
            uint64_t i = 0;
            NSData* d = nil;

            switch ([BTCProtocolBuffers fieldAtOffset:&offset int:&i data:&d fromData:data]) {
                case BTCRequestKeyVersion:
                    if (i) _version = (uint32_t)i;
                    break;
                case BTCRequestKeyPkiType:
                    if (d) _pkiType = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;
                case BTCRequestKeyPkiData:
                    if (d) _pkiData = d;
                    break;
                case BTCRequestKeyPaymentDetails:
                    if (d) _details = [[BTCPaymentDetails alloc] initWithData:d];
                    break;
                case BTCRequestKeySignature:
                    if (d) _signature = d;
                    break;
                default: break;
            }
        }

        // Payment details are required.
        if (!_details) return nil;
    }
    return self;
}

- (NSData*) data {
    if (!_data) {
        _data = [self dataWithSignature:_signature];
    }
    return _data;
}

- (NSData*) dataForSigning {
    return [self dataWithSignature:[NSData data]];
}

- (NSData*) dataWithSignature:(NSData*)signature {
    NSMutableData* data = [NSMutableData data];

    // Note: we should reconstruct the data exactly as it was on the input.
    if (_version > 0) {
        [BTCProtocolBuffers writeInt:_version withKey:BTCRequestKeyVersion toData:data];
    }
    if (_pkiType) {
        [BTCProtocolBuffers writeString:_pkiType withKey:BTCRequestKeyPkiType toData:data];
    }
    if (_pkiData) {
        [BTCProtocolBuffers writeData:_pkiData withKey:BTCRequestKeyPkiData toData:data];
    }

    [BTCProtocolBuffers writeData:self.details.data withKey:BTCRequestKeyPaymentDetails toData:data];

    if (signature) {
        [BTCProtocolBuffers writeData:signature withKey:BTCRequestKeySignature toData:data];
    }
    return data;
}

- (NSInteger) version
{
    return (_version > 0) ? _version : BTCPaymentRequestVersion1;
}

- (NSString*) pkiType
{
    return _pkiType ?: BTCPaymentRequestPKITypeNone;
}

- (NSArray*) certificates {
    if (!_certificates) {
        _certificates = BTCParseCertificatesFromPaymentRequestPKIData(self.pkiData);
    }
    return _certificates;
}

- (BOOL) isValid {
    if (!_isValidated) [self validatePaymentRequest];
    return _isValid;
}

- (NSString*) signerName {
    if (!_isValidated) [self validatePaymentRequest];
    return _signerName;
}

- (BTCPaymentRequestStatus) status {
    if (!_isValidated) [self validatePaymentRequest];
    return _status;
}

- (void) validatePaymentRequest {
    _isValidated = YES;
    _isValid = NO;

    // Make sure we do not accidentally send funds to a payment request that we do not support.
    if (self.version != BTCPaymentRequestVersion1 &&
        self.version != BTCPaymentRequestVersionOpenAssets1) {
        _status = BTCPaymentRequestStatusNotCompatible;
        return;
    }

    __typeof(_status) status = _status;
    __typeof(_signerName) signer = _signerName;
    _isValid = BTCPaymentRequestVerifySignature(self.pkiType,
                                                [self dataForSigning],
                                                self.certificates,
                                                _signature,
                                                &status,
                                                &signer);
    _status = status;
    _signerName = signer;
    if (!_isValid) {
        return;
    }

    // Signatures are valid, but PR has expired.
    if (self.details.expirationDate && [self.currentDate ?: [NSDate date] timeIntervalSinceDate:self.details.expirationDate] > 0.0) {
        _status = BTCPaymentRequestStatusExpired;
        _isValid = NO;
        return;
    }
}

- (BTCPayment*) paymentWithTransaction:(BTCTransaction*)tx {
    NSParameterAssert(tx);
    return [self paymentWithTransactions:@[ tx ] memo:nil];
}

- (BTCPayment*) paymentWithTransactions:(NSArray*)txs memo:(NSString*)memo {
    if (!txs || txs.count == 0) return nil;
    BTCPayment* payment = [[BTCPayment alloc] init];
    payment.merchantData = self.details.merchantData;
    payment.transactions = txs;
    payment.memo = memo;
    return payment;
}

@end


NSArray* __nullable BTCParseCertificatesFromPaymentRequestPKIData(NSData* __nullable pkiData) {
    if (!pkiData) return nil;
    NSMutableArray* certs = [NSMutableArray array];
    NSInteger offset = 0;
    while (offset < pkiData.length) {
        NSData* d = nil;
        NSInteger key = [BTCProtocolBuffers fieldAtOffset:&offset int:NULL data:&d fromData:pkiData];
        if (key == BTCCertificatesKeyCertificate && d) {
            [certs addObject:d];
        }
    }
    return certs;
}


BOOL BTCPaymentRequestVerifySignature(NSString* __nullable pkiType,
                                      NSData* __nullable dataToVerify,
                                      NSArray* __nullable certificates,
                                      NSData* __nullable signature,
                                      BTCPaymentRequestStatus* __nullable statusOut,
                                      NSString* __autoreleasing __nullable *  __nullable signerOut) {

    if ([pkiType isEqual:BTCPaymentRequestPKITypeX509SHA1] ||
        [pkiType isEqual:BTCPaymentRequestPKITypeX509SHA256]) {

        if (!signature || !certificates || certificates.count == 0 || !dataToVerify) {
            if (statusOut) *statusOut = BTCPaymentRequestStatusInvalidSignature;
            return NO;
        }

        // 1. Verify chain of trust

        NSMutableArray *certs = [NSMutableArray array];
        NSArray *policies = @[CFBridgingRelease(SecPolicyCreateBasicX509())];
        SecTrustRef trust = NULL;
        SecTrustResultType trustResult = kSecTrustResultInvalid;

        for (NSData *certData in certificates) {
            SecCertificateRef cert = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certData);
            if (cert) [certs addObject:CFBridgingRelease(cert)];
        }

        if (certs.count > 0) {
            if (signerOut) *signerOut = CFBridgingRelease(SecCertificateCopySubjectSummary((__bridge SecCertificateRef)certs[0]));
        }

        SecTrustCreateWithCertificates((__bridge CFArrayRef)certs, (__bridge CFArrayRef)policies, &trust);
        SecTrustEvaluate(trust, &trustResult); // verify certificate chain

        // kSecTrustResultUnspecified indicates the evaluation succeeded
        // and the certificate is implicitly trusted, but user intent was not
        // explicitly specified.
        if (trustResult != kSecTrustResultUnspecified && trustResult != kSecTrustResultProceed) {
            if (certs.count > 0) {
                if (statusOut) *statusOut = BTCPaymentRequestStatusUntrustedCertificate;
            } else {
                if (statusOut) *statusOut = BTCPaymentRequestStatusMissingCertificate;
            }
            return NO;
        }

        // 2. Verify signature

    #if TARGET_OS_IPHONE
        SecKeyRef pubKey = SecTrustCopyPublicKey(trust);
        SecPadding padding = kSecPaddingPKCS1;
        NSData* hash = nil;

        if ([pkiType isEqual:BTCPaymentRequestPKITypeX509SHA256]) {
            hash = BTCSHA256(dataToVerify);
            padding = kSecPaddingPKCS1SHA256;
        }
        else if ([pkiType isEqual:BTCPaymentRequestPKITypeX509SHA1]) {
            hash = BTCSHA1(dataToVerify);
            padding = kSecPaddingPKCS1SHA1;
        }

        OSStatus status = SecKeyRawVerify(pubKey, padding, hash.bytes, hash.length, signature.bytes, signature.length);

        CFRelease(pubKey);

        if (status != errSecSuccess) {
            if (statusOut) *statusOut = BTCPaymentRequestStatusInvalidSignature;
            return NO;
        }

        if (statusOut) *statusOut = BTCPaymentRequestStatusValid;
        return YES;

    #else
        // On OS X 10.10 we don't have kSecPaddingPKCS1SHA256 and SecKeyRawVerify.
        // So we have to verify the signature using Security Transforms API.

        //  Here's a draft of what needs to be done here.
        /*
         CFErrorRef* error = NULL;
         verifier = SecVerifyTransformCreate(publickey, signature, &error);
         if (!verifier) { CFShow(error); exit(-1); }
         if (!SecTransformSetAttribute(verifier, kSecTransformInputAttributeName, dataForSigning, &error) {
         CFShow(error);
         exit(-1);
         }
         // if it's sha256, then set SHA2 digest type and 32 bytes length.
         if (!SecTransformSetAttribute(verifier, kSecDigestTypeAttribute, kSecDigestSHA2, &error) {
         CFShow(error);
         exit(-1);
         }
         // Not sure if the length is in bytes or bits. Quinn The Eskimo says it's in bits:
         // https://devforums.apple.com/message/1119092#1119092
         if (!SecTransformSetAttribute(verifier, kSecDigestLengthAttribute, @(256), &error) {
         CFShow(error);
         exit(-1);
         }

         result = SecTransformExecute(verifier, &error);
         if (error) {
         CFShow(error);
         exit(-1);
         }
         if (result == kCFBooleanTrue) {
         // signature is valid
         if (statusOut) *statusOut = BTCPaymentRequestStatusValid;
         _isValid = YES;
         } else {
         // signature is invalid.
         if (statusOut) *statusOut = BTCPaymentRequestStatusInvalidSignature;
         _isValid = NO;
         return NO;
         }

         // -----------------------------------------------------------------------

         // From CryptoCompatibility sample code (QCCRSASHA1VerifyT.m):

         BOOL                success;
         SecTransformRef     transform;
         CFBooleanRef        result;
         CFErrorRef          errorCF;

         result = NULL;
         errorCF = NULL;

         // Set up the transform.

         transform = SecVerifyTransformCreate(self.publicKey, (__bridge CFDataRef) self.signatureData, &errorCF);
         success = (transform != NULL);

         // Note: kSecInputIsAttributeName defaults to kSecInputIsPlainText, which is what we want.

         if (success) {
         success = SecTransformSetAttribute(transform, kSecDigestTypeAttribute, kSecDigestSHA1, &errorCF) != false;
         }

         if (success) {
         success = SecTransformSetAttribute(transform, kSecTransformInputAttributeName, (__bridge CFDataRef) self.inputData, &errorCF) != false;
         }

         // Run it.

         if (success) {
         result = SecTransformExecute(transform, &errorCF);
         success = (result != NULL);
         }

         // Process the results.

         if (success) {
         assert(CFGetTypeID(result) == CFBooleanGetTypeID());
         self.verified = (CFBooleanGetValue(result) != false);
         } else {
         assert(errorCF != NULL);
         self.error = (__bridge NSError *) errorCF;
         }

         // Clean up.

         if (result != NULL) {
         CFRelease(result);
         }
         if (errorCF != NULL) {
         CFRelease(errorCF);
         }
         if (transform != NULL) {
         CFRelease(transform);
         }
         */

        if (statusOut) *statusOut = BTCPaymentRequestStatusUnknown;
        return NO;
    #endif

    } else {
        // Either "none" PKI type or some new and unsupported PKI.

        if (certificates.count > 0) {
            // Non-standard extension to include a signer's name without actually signing request.
            if (signerOut) *signerOut = [[NSString alloc] initWithData:certificates[0] encoding:NSUTF8StringEncoding];
        }

        if ([pkiType isEqual:BTCPaymentRequestPKITypeNone]) {
            if (statusOut) *statusOut = BTCPaymentRequestStatusUnsigned;
            return YES;
        } else {
            if (statusOut) *statusOut = BTCPaymentRequestStatusUnknown;
            return NO;
        }
    }
    return NO;
}



















@implementation BTCPaymentDetails

- (id) initWithData:(NSData*)data {
    if (!data) return nil;

    if (self = [super init]) {
        NSMutableArray* outputs = [NSMutableArray array];
        NSMutableArray* inputs = [NSMutableArray array];

        NSInteger offset = 0;
        while (offset < data.length) {
            uint64_t integer = 0;
            NSData* d = nil;

            switch ([BTCProtocolBuffers fieldAtOffset:&offset int:&integer data:&d fromData:data]) {
                case BTCDetailsKeyNetwork:
                    if (d) {
                        NSString* networkName = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                        if ([networkName isEqual:@"main"]) {
                            _network = [BTCNetwork mainnet];
                        } else if ([networkName isEqual:@"test"]) {
                            _network = [BTCNetwork testnet];
                        } else {
                            _network = [[BTCNetwork alloc] initWithName:networkName];
                        }
                    }
                    break;
                case BTCDetailsKeyOutputs: {
                    NSInteger offset2 = 0;
                    BTCAmount amount = BTCUnspecifiedPaymentAmount;
                    NSData* scriptData = nil;
                    BTCAssetID* assetID = nil;
                    BTCAmount assetAmount = BTCUnspecifiedPaymentAmount;

                    uint64_t integer2 = 0;
                    NSData* d2 = nil;
                    while (offset2 < d.length) {
                        switch ([BTCProtocolBuffers fieldAtOffset:&offset2 int:&integer2 data:&d2 fromData:d]) {
                            case BTCOutputKeyAmount:
                                amount = integer2;
                                break;
                            case BTCOutputKeyScript:
                                scriptData = d2;
                                break;
                            case BTCOutputKeyAssetID:
                                if (d2.length != 20) {
                                    NSLog(@"CoreBitcoin ERROR: Received invalid asset id in Payment Request Details (must be 20 bytes long): %@", d2);
                                    return nil;
                                }
                                assetID = [BTCAssetID assetIDWithHash:d2];
                                break;
                            case BTCOutputKeyAssetAmount:
                                assetAmount = integer2;
                                break;
                            default:
                                break;
                        }
                    }
                    if (scriptData) {
                        BTCScript* script = [[BTCScript alloc] initWithData:scriptData];
                        if (!script) {
                            NSLog(@"CoreBitcoin ERROR: Received invalid script data in Payment Request Details: %@", scriptData);
                            return nil;
                        }
                        if (assetID) {
                            if (amount != BTCUnspecifiedPaymentAmount) {
                                NSLog(@"CoreBitcoin ERROR: Received invalid amount specification in Payment Request Details: amount must not be specified.");
                                return nil;
                            }
                        } else {
                            if (assetAmount != BTCUnspecifiedPaymentAmount) {
                                NSLog(@"CoreBitcoin ERROR: Received invalid amount specification in Payment Request Details: asset_amount must not specified without asset_id.");
                                return nil;
                            }
                        }
                        BTCTransactionOutput* txout = [[BTCTransactionOutput alloc] initWithValue:amount script:script];
                        NSMutableDictionary* userInfo = [NSMutableDictionary dictionary];

                        if (assetID) {
                            userInfo[@"assetID"] = assetID;
                        }
                        if (assetAmount != BTCUnspecifiedPaymentAmount) {
                            userInfo[@"assetAmount"] = @(assetAmount);
                        }
                        txout.userInfo = userInfo;
                        txout.index = (uint32_t)outputs.count;
                        [outputs addObject:txout];
                    }
                    break;
                }
                case BTCDetailsKeyInputs: {
                    NSInteger offset2 = 0;
                    uint64_t index = BTCUnspecifiedPaymentAmount;
                    NSData* txhash = nil;
                    // both amount and scriptData are optional, so we try to read any of them
                    while (offset2 < d.length) {
                        [BTCProtocolBuffers fieldAtOffset:&offset2 int:(uint64_t*)&index data:&txhash fromData:d];
                    }
                    if (txhash) {
                        if (txhash.length != 32) {
                            NSLog(@"CoreBitcoin ERROR: Received invalid txhash in Payment Request Input: %@", txhash);
                            return nil;
                        }
                        if (index > 0xffffffffLL) {
                            NSLog(@"CoreBitcoin ERROR: Received invalid prev index in Payment Request Input: %@", @(index));
                            return nil;
                        }
                        BTCTransactionInput* txin = [[BTCTransactionInput alloc] init];
                        txin.previousHash = txhash;
                        txin.previousIndex = (uint32_t)index;
                        [inputs addObject:txin];
                    }
                    break;
                }
                case BTCDetailsKeyTime:
                    if (integer) _date = [NSDate dateWithTimeIntervalSince1970:integer];
                    break;
                case BTCDetailsKeyExpires:
                    if (integer) _expirationDate = [NSDate dateWithTimeIntervalSince1970:integer];
                    break;
                case BTCDetailsKeyMemo:
                    if (d) _memo = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;
                case BTCDetailsKeyPaymentURL:
                    if (d) _paymentURL = [NSURL URLWithString:[[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding]];
                    break;
                case BTCDetailsKeyMerchantData:
                    if (d) _merchantData = d;
                    break;
                default: break;
            }
        }

        // PR must have at least one output
        if (outputs.count == 0) return nil;

        // PR requires a creation time.
        if (!_date) return nil;

        _outputs = outputs;
        _inputs = inputs;
        _data = data;
    }
    return self;
}

- (BTCNetwork*) network {
    return _network ?: [BTCNetwork mainnet];
}

- (NSData*) data {
    if (!_data) {
        NSMutableData* dst = [NSMutableData data];

        // Note: we should reconstruct the data exactly as it was on the input.

        if (_network) {
            [BTCProtocolBuffers writeString:_network.paymentProtocolName withKey:BTCDetailsKeyNetwork toData:dst];
        }

        for (BTCTransactionOutput* txout in _outputs) {
            NSMutableData* outputData = [NSMutableData data];

            if (txout.value != BTCUnspecifiedPaymentAmount) {
                [BTCProtocolBuffers writeInt:txout.value withKey:BTCOutputKeyAmount toData:outputData];
            }
            [BTCProtocolBuffers writeData:txout.script.data withKey:BTCOutputKeyScript toData:outputData];

            if (txout.userInfo[@"assetID"]) {
                BTCAssetID* aid = txout.userInfo[@"assetID"];
                [BTCProtocolBuffers writeData:aid.data withKey:BTCOutputKeyAssetID toData:outputData];
            }
            if (txout.userInfo[@"assetAmount"]) {
                BTCAmount assetAmount = [txout.userInfo[@"assetAmount"] longLongValue];
                [BTCProtocolBuffers writeInt:assetAmount withKey:BTCOutputKeyAssetAmount toData:outputData];
            }
            [BTCProtocolBuffers writeData:outputData withKey:BTCDetailsKeyOutputs toData:dst];
        }

        for (BTCTransactionInput* txin in _inputs) {
            NSMutableData* inputsData = [NSMutableData data];

            [BTCProtocolBuffers writeData:txin.previousHash withKey:BTCInputKeyTxhash toData:inputsData];
            [BTCProtocolBuffers writeInt:txin.previousIndex withKey:BTCInputKeyIndex toData:inputsData];
            [BTCProtocolBuffers writeData:inputsData withKey:BTCDetailsKeyInputs toData:dst];
        }

        if (_date) {
            [BTCProtocolBuffers writeInt:(uint64_t)[_date timeIntervalSince1970] withKey:BTCDetailsKeyTime toData:dst];
        }
        if (_expirationDate) {
            [BTCProtocolBuffers writeInt:(uint64_t)[_expirationDate timeIntervalSince1970] withKey:BTCDetailsKeyExpires toData:dst];
        }
        if (_memo) {
            [BTCProtocolBuffers writeString:_memo withKey:BTCDetailsKeyMemo toData:dst];
        }
        if (_paymentURL) {
            [BTCProtocolBuffers writeString:_paymentURL.absoluteString withKey:BTCDetailsKeyPaymentURL toData:dst];
        }
        if (_merchantData) {
            [BTCProtocolBuffers writeData:_merchantData withKey:BTCDetailsKeyMerchantData toData:dst];
        }
        _data = dst;
    }
    return _data;
}

@end




















@implementation BTCPayment

- (id) initWithData:(NSData*)data {
    if (!data) return nil;

    if (self = [super init]) {

        NSInteger offset = 0;
        NSMutableArray* txs = [NSMutableArray array];
        NSMutableArray* outputs = [NSMutableArray array];

        while (offset < data.length) {
            uint64_t integer = 0;
            NSData* d = nil;
            BTCTransaction* tx = nil;

            switch ([BTCProtocolBuffers fieldAtOffset:&offset int:&integer data:&d fromData:data]) {
                case BTCPaymentKeyMerchantData:
                    if (d) _merchantData = d;
                    break;
                case BTCPaymentKeyTransactions:
                    if (d) tx = [[BTCTransaction alloc] initWithData:d];
                    if (tx) [txs addObject:tx];
                    break;
                case BTCPaymentKeyRefundTo: {
                    NSInteger offset2 = 0;
                    BTCAmount amount = BTCUnspecifiedPaymentAmount;
                    NSData* scriptData = nil;
                    // both amount and scriptData are optional, so we try to read any of them
                    while (offset2 < d.length) {
                        [BTCProtocolBuffers fieldAtOffset:&offset2 int:(uint64_t*)&amount data:&scriptData fromData:d];
                    }
                    if (scriptData) {
                        BTCScript* script = [[BTCScript alloc] initWithData:scriptData];
                        if (!script) {
                            NSLog(@"CoreBitcoin ERROR: Received invalid script data in Payment Request Details: %@", scriptData);
                            return nil;
                        }
                        BTCTransactionOutput* txout = [[BTCTransactionOutput alloc] initWithValue:amount script:script];
                        [outputs addObject:txout];
                    }
                    break;
                }
                case BTCPaymentKeyMemo:
                    if (d) _memo = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;
                default: break;
            }

        }

        _transactions = txs;
        _refundOutputs = outputs;
    }
    return self;
}

- (NSData*) data {

    if (!_data) {
        NSMutableData* dst = [NSMutableData data];

        if (_merchantData) {
            [BTCProtocolBuffers writeData:_merchantData withKey:BTCPaymentKeyMerchantData toData:dst];
        }

        for (BTCTransaction* tx in _transactions) {
            [BTCProtocolBuffers writeData:tx.data withKey:BTCPaymentKeyTransactions toData:dst];
        }

        for (BTCTransactionOutput* txout in _refundOutputs) {
            NSMutableData* outputData = [NSMutableData data];

            if (txout.value != BTCUnspecifiedPaymentAmount) {
                [BTCProtocolBuffers writeInt:txout.value withKey:BTCOutputKeyAmount toData:outputData];
            }
            [BTCProtocolBuffers writeData:txout.script.data withKey:BTCOutputKeyScript toData:outputData];
            [BTCProtocolBuffers writeData:outputData withKey:BTCPaymentKeyRefundTo toData:dst];
        }

        if (_memo) {
            [BTCProtocolBuffers writeString:_memo withKey:BTCPaymentKeyMemo toData:dst];
        }

        _data = dst;
    }
    return _data;
}

@end






















@implementation BTCPaymentACK

- (id) initWithData:(NSData*)data {
    if (!data) return nil;

    if (self = [super init]) {
        NSInteger offset = 0;
        while (offset < data.length) {
            uint64_t integer = 0;
            NSData* d = nil;

            switch ([BTCProtocolBuffers fieldAtOffset:&offset int:&integer data:&d fromData:data]) {
                case BTCPaymentAckKeyPayment:
                    if (d) _payment = [[BTCPayment alloc] initWithData:d];
                    break;
                case BTCPaymentAckKeyMemo:
                    if (d) _memo = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;
                default: break;
            }
        }
        
        // payment object is required.
        if (! _payment) return nil;
    }
    return self;
}


- (NSData*) data {
    
    if (!_data) {
        NSMutableData* dst = [NSMutableData data];
        
        [BTCProtocolBuffers writeData:_payment.data withKey:BTCPaymentAckKeyPayment toData:dst];
        
        if (_memo) {
            [BTCProtocolBuffers writeString:_memo withKey:BTCPaymentAckKeyMemo toData:dst];
        }
        
        _data = dst;
    }
    return _data;
}


@end
