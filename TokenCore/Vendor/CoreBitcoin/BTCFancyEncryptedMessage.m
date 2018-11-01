// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.

#import "BTCErrors.h"
#import "BTCFancyEncryptedMessage.h"
#import "BTCData.h"
#import "BTCKey.h"
#import "BTCCurvePoint.h"
#import "BTCBigNumber.h"
#import "BTCProtocolSerialization.h"
#import <CommonCrypto/CommonCrypto.h>

// First 16 bytes of the hash of a shared key and decrypted message appended to the end of the complete message.
#define BTCFancyEncryptedMessageChecksumLength 16

static uint8_t BTCEMCompactTargetForFullTarget(uint32_t fullTarget);
static uint32_t BTCEMFullTargetForCompactTarget(uint8_t compactTarget);

@implementation BTCFancyEncryptedMessage {
    
    // Decrypted message data:
    
    NSData* _decryptedData;
    
    // Encrypted message data:
    BTCKey* _nonceKey;
    NSData* _encryptedData;
    NSData* _checksum; // first 16 bytes of double SHA256 of the shared secret concatenated with the decrypted message.
}

// Instantiates unencrypted message with its content
- (id) initWithData:(NSData*)data {
    if (!data) return nil;
    
    if (self = [super init]) {
        _difficultyTarget = 0xFFFFFFFF;
        _addressLength = BTCFancyEncryptedMessageAddressLengthNone;
        _decryptedData = data;
    }
    return self;
}

- (NSData*) encryptedDataWithKey:(BTCKey*)recipientKey seed:(NSData*)seed0 {
    // These will be used for various purposes.
    unsigned char digest256[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_CTX ctx256;
    
    NSMutableData* recipientPubKey = [recipientKey compressedPublicKey];
    
    self.address = BTCHash160(recipientPubKey);
    self.addressLength = MIN(self.address.length * 8, self.addressLength);
    
    self.timestamp = (uint32_t)[[NSDate date] timeIntervalSince1970];
    
    // Transform seed into a unique per-message seed.
    // TODO: perform raw SHA computation to be able to erase digests from memory.
    CC_SHA256_Init(&ctx256);
    if (seed0) {
        CC_SHA256_Update(&ctx256, seed0.bytes, (CC_LONG)seed0.length);
    } else {
        // If no seed given, use random bytes.
        void* randomBytes = BTCCreateRandomBytesOfLength(32);
        CC_SHA256_Update(&ctx256, randomBytes, 32);
        BTCSecureMemset(randomBytes, 0, 32);
        free(randomBytes);
    }
    CC_SHA256_Update(&ctx256, _decryptedData.bytes, (CC_LONG)_decryptedData.length);
    CC_SHA256_Update(&ctx256, recipientPubKey.bytes, (CC_LONG)recipientPubKey.length);
    CC_SHA256_Final(digest256, &ctx256);

    NSMutableData* seed = [NSMutableData dataWithBytes:digest256 length:CC_SHA256_DIGEST_LENGTH];
    
    BTCSecureMemset(digest256, 0, CC_SHA256_DIGEST_LENGTH);
    BTCDataClear(recipientPubKey);
    
    if (self.timestampVariance > 0) {
        NSData* varianceHash = BTCSHA256(seed); // extra hashing to not leak our seed that we'll use for private key nonce.
        uint32_t rand = *((uint32_t*)varianceHash.bytes);
        self.timestamp -= (rand % self.timestampVariance);
    }
    
    uint8_t compactTarget = BTCEMCompactTargetForFullTarget(_difficultyTarget);
    
    NSMutableData* messageData = [[NSMutableData alloc] initWithCapacity:100 + _decryptedData.length];
    
    // NOTE: this code could be greately optimized to avoid re-creating message prefix.
    // Also, if time variance is > 0 we can try some random values there to avoid recomputing the private key.
    uint64_t nonce = 0;
    do {
        
        BTCDataClear(messageData); // clear previous trial
        
        [messageData setLength:0];
        
        [messageData appendBytes:BTCFancyEncryptedMessageVersion length:4];
        
        [messageData appendBytes:&compactTarget length:1];
        
        uint8_t noncePlaceholder = 0;
        [messageData appendBytes:&noncePlaceholder length:1];
        
        NSUInteger offsetForNonce = messageData.length;
        
        uint32_t ts = OSSwapHostToBigInt32(self.timestamp);
        [messageData appendBytes:&ts length:sizeof(ts)];
        
        [messageData appendBytes:&_addressLength length:1];
        
        uint8_t partialByte = _addressLength % 8;
        
        [messageData appendBytes:self.address.bytes length:_addressLength / 8];
        
        if (partialByte > 0) {
            // Add one more byte, but mask lower bits with zeros. (We treat address as a big endian number.)
            
            uint8_t lastByte = ((uint8_t*)self.address.bytes)[_addressLength/8] & (0xFF << (8 - partialByte));
            [messageData appendBytes:&lastByte length:1];
        }
        
        // Compute the private key
        
        CC_SHA256_Init(&ctx256);
        CC_SHA256_Update(&ctx256, [seed bytes], (CC_LONG)[seed length]);
        CC_SHA256_Update(&ctx256, &nonce, sizeof(nonce));
        CC_SHA256_Final(digest256, &ctx256);
        
        nonce++;
        
        NSData* privkey = [NSData dataWithBytesNoCopy:digest256 length:CC_SHA256_DIGEST_LENGTH freeWhenDone:NO]; // not copying data as it'll be copied into bignum right away anyway.

        BTCKey* nonceKey = [[BTCKey alloc] initWithPrivateKey:privkey];
        
        NSData* pubkey = [nonceKey compressedPublicKey];
        
        uint8_t pubkeyLength = pubkey.length;
        
        [messageData appendBytes:&pubkeyLength length:1];
        
        [messageData appendData:pubkey];
        
        
        // Create a shared secret
        
        BTCBigNumber* pk = [[BTCBigNumber alloc] initWithUnsignedBigEndian:privkey];
        
        BTCCurvePoint* curvePoint = recipientKey.curvePoint;
        
        // D-H happens here. We multiply our private key (bignum) by a recipient's key (curve point).
        // Recipient will multiply his private key (bignum) by our pubkey that we attach in the previous step.
        [curvePoint multiply:pk];
        
        NSData* pointX = curvePoint.x.unsignedBigEndian;
        
        // Hash the x-coordinate for better diffusion.
        CC_SHA256_Init(&ctx256);
        CC_SHA256_Update(&ctx256, [pointX bytes], (CC_LONG)[pointX length]);
        CC_SHA256_Final(digest256, &ctx256);

        int blockSize = kCCBlockSizeAES128;
        int encryptedDataCapacity = (int)(_decryptedData.length / blockSize + 1) * blockSize;
        NSMutableData* encryptedData = [[NSMutableData alloc] initWithLength:encryptedDataCapacity];
        
        size_t dataOutMoved = 0;
                
        CCCryptorStatus cryptstatus = CCCrypt(
                                              kCCEncrypt,                  // CCOperation op,         /* kCCEncrypt, kCCDecrypt */
                                              kCCAlgorithmAES,             // CCAlgorithm alg,        /* kCCAlgorithmAES128, etc. */
                                              kCCOptionPKCS7Padding,       // CCOptions options,      /* kCCOptionPKCS7Padding, etc. */
                                              digest256,                   // const void *key,
                                              CC_SHA256_DIGEST_LENGTH,     // size_t keyLength,
                                              NULL,                        // const void *iv,         /* optional initialization vector */
                                              [_decryptedData bytes],      // const void *dataIn,     /* optional per op and alg */
                                              [_decryptedData length],     // size_t dataInLength,
                                              encryptedData.mutableBytes,  // void *dataOut,          /* data RETURNED here */
                                              encryptedDataCapacity,       // size_t dataOutAvailable,
                                              &dataOutMoved                // size_t *dataOutMoved
                                              );
        
        if (cryptstatus != kCCSuccess) {
            BTCDataClear(encryptedData);
            BTCSecureMemset(&ctx256, 0, sizeof(ctx256));
            encryptedData = nil;
        } else {
            // Resize the result key to the correct size.
            encryptedData.length = dataOutMoved;
        }
        
        // Clear sensitive info from memory.
        
        if ([pointX isKindOfClass:[NSMutableData class]]) {
            BTCDataClear((NSMutableData*)pointX);
        }
        [pk clear];
        [curvePoint clear];
        BTCSecureMemset(&ctx256, 0, sizeof(ctx256));
        
        if (!encryptedData) {
            BTCDataClear(seed);
            return nil;
        }
        
        // Raw encrypted data + variable-length data length prefix.
        [messageData appendData:[BTCProtocolSerialization dataForVarString:encryptedData]];

        // Add 16-byte checksum which is SHA256^2 of the shared secret + decrypted message
        CC_SHA256_Init(&ctx256);
        CC_SHA256_Update(&ctx256, digest256, CC_SHA256_DIGEST_LENGTH);
        CC_SHA256_Update(&ctx256, _decryptedData.bytes, (CC_LONG)_decryptedData.length);
        CC_SHA256_Final(digest256, &ctx256);
        CC_SHA256_Init(&ctx256);
        CC_SHA256_Update(&ctx256, digest256, CC_SHA256_DIGEST_LENGTH);
        CC_SHA256_Final(digest256, &ctx256);

        [messageData appendBytes:digest256 length:BTCFancyEncryptedMessageChecksumLength];
        
        BTCSecureMemset(&ctx256, 0, sizeof(ctx256));
        
        // Do not even compute the full hash if we don't need PoW.
        if (_difficultyTarget == 0xFFFFFFFF) {
            BTCDataClear(seed);
            return messageData;
        }
        
        // Compute full hash for PoW.
        unsigned char digest512[CC_SHA512_DIGEST_LENGTH];
        CC_SHA512_CTX ctx512;
        
        // Iterate 256 nonces
        
        uint8_t nonce2 = 0;
        uint8_t* msgbytes = (uint8_t*)messageData.mutableBytes;
        do {
            
            msgbytes[offsetForNonce] = nonce2; // skip prefix and difficulty target.
            
            // Compute proof-of-work hash.
            CC_SHA512_Init(&ctx512);
            CC_SHA512_Update(&ctx512, msgbytes, (CC_LONG)messageData.length);
            CC_SHA512_Final(digest512, &ctx512);
            CC_SHA512_Init(&ctx512);
            CC_SHA512_Update(&ctx512, digest512, CC_SHA512_DIGEST_LENGTH);
            CC_SHA512_Final(digest512, &ctx512);
            
            // To avoid bignum math, we only check 32-bit prefixes for PoW.
            uint32_t prefix = OSSwapBigToHostConstInt32(*((uint32_t*)digest512));
            
            if (prefix <= _difficultyTarget) {
                BTCDataClear(seed);
                return messageData;
            }
            
            if (nonce2 == 255) {
                break; // go back to main loop and try another pubkey.
            }
            
            nonce2++;
            
        } while (1);
    } while (1);
}



// Instantiates encrypted message with its binary representation. Checks that difficulty matches the actual proof of work.
// To decrypt the message, use -decryptedDataWithKey:
- (id) initWithEncryptedData:(NSData*)data {
    if (self = [super init]) {
        // Check for minimum length.
        uint32_t datalength = (uint32_t)data.length;
        
        if (datalength < (4 + 1 + 1 + 4 + 1 + 1 + 32 + 1 + BTCFancyEncryptedMessageChecksumLength)) return nil;
        
        // Compute full hash for PoW.
        unsigned char digest512[CC_SHA512_DIGEST_LENGTH];
        CC_SHA512_CTX ctx512;
        
        // Iterate 256 nonces
        
        uint8_t nonce = 0;
        uint8_t* msgbytes = (uint8_t*)data.bytes;
        
        // Check the magic prefix.
        if (memcmp(BTCFancyEncryptedMessageVersion, msgbytes, sizeof(BTCFancyEncryptedMessageVersion)) != 0) {
            return nil;
        }
        
        nonce = msgbytes[4+1]; // skip prefix and difficulty target.
        
        // Proof-of-work check.
        CC_SHA512_Init(&ctx512);
        CC_SHA512_Update(&ctx512, data.bytes, (CC_LONG)data.length);
        CC_SHA512_Final(digest512, &ctx512);
        CC_SHA512_Init(&ctx512);
        CC_SHA512_Update(&ctx512, digest512, CC_SHA512_DIGEST_LENGTH);
        CC_SHA512_Final(digest512, &ctx512);
        
        // To avoid bignum math, we only check 32-bit prefixes for PoW.
        uint32_t prefix = OSSwapBigToHostConstInt32(*((uint32_t*)digest512));
        
        uint32_t target = BTCEMFullTargetForCompactTarget(msgbytes[4]);
        
        if (prefix > target) {
            return nil;
        }
        
        // Fill in the properties.
            
        _difficultyTarget = target;
        
        _timestamp = OSSwapBigToHostConstInt32(*(uint32_t*)(msgbytes + 6));
        
        _addressLength = msgbytes[10];
        
        uint8_t realAddrLength = _addressLength/8 + (_addressLength % 8 == 0 ? 0 : 1);
        if (_addressLength > 0) {
            _address = [data subdataWithRange:NSMakeRange(11, realAddrLength)];
        } else {
            _address = [NSData data];
        }
        
        uint32_t offset = 11 + realAddrLength;
        
        if (datalength <= offset) return nil;
        
        uint8_t pubkeyLength = msgbytes[offset];
        
        offset++;
        
        if (datalength <= (offset + pubkeyLength)) return nil;
        
        NSData* pubkeyNonceData = [NSData dataWithBytes:msgbytes + offset length:pubkeyLength];
        
        offset += pubkeyLength;
        
        if (datalength <= offset) return nil;

        BTCKey* nonceKey = [[BTCKey alloc] initWithPublicKey:pubkeyNonceData];
        
        _nonceKey = nonceKey;
        
        // To reconstruct the shared secret, this nonceKey should be multiplied by our private key.
        // This will happen in -decryptedDataWithKey

        NSUInteger encodedMessageLength = 0; // contains both the encrypted message length and the length of its length prefix.
        _encryptedData = [BTCProtocolSerialization readVarStringFromData:[data subdataWithRange:NSMakeRange(offset, datalength - offset)] readBytes:&encodedMessageLength];
        
        if (_encryptedData == nil) return nil;
        
        offset += encodedMessageLength;
        
        if (datalength < offset + BTCFancyEncryptedMessageChecksumLength) return nil;
        
        _checksum = [data subdataWithRange:NSMakeRange(offset, BTCFancyEncryptedMessageChecksumLength)];
        
        // Now the user must call decryptedDataWithKey: with some of his keys to see if this message is for him or not.
    }
    return self;
}

// Attempts to decrypt the message with a given private key and returns result.
- (NSData*) decryptedDataWithKey:(BTCKey*)key error:(NSError**)errorOut {
    // 1. Reconstruct a shared secret from key and _nonceKey.
    // 2. Decrypt message.
    // 3. Verify the checksum.
    // 4. If valid, return the message. Otherwise, set error and return nil.
    
    
    // 1. Reconstruct a shared secret from key and _nonceKey.
    
    BTCBigNumber* pk = [[BTCBigNumber alloc] initWithUnsignedBigEndian:key.privateKey];
    
    BTCCurvePoint* curvePoint = _nonceKey.curvePoint;
    
    // D-H happens here. We multiply our private key (bignum) by a sender's nonce key (curve point).
    // Sender did multiply his nonce private key (bignum) by recipient's pubkey to encrypt the message.
    [curvePoint multiply:pk];
    
    NSData* pointX = curvePoint.x.unsignedBigEndian;
    
    // These will be used for various purposes.
    unsigned char digest256[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_CTX ctx256;
    
    // Hash the x-coordinate for better diffusion.
    CC_SHA256_Init(&ctx256);
    CC_SHA256_Update(&ctx256, [pointX bytes], (CC_LONG)[pointX length]);
    CC_SHA256_Final(digest256, &ctx256);

    // 2. Decrypt message.
    
    int blockSize = kCCBlockSizeAES128;
    int decryptedDataCapacity = (int)(_encryptedData.length / blockSize + 1) * blockSize;
    NSMutableData* decryptedData = [[NSMutableData alloc] initWithLength:decryptedDataCapacity];
    
    size_t dataOutMoved = 0;
    CCCryptorStatus cryptstatus = CCCrypt(
                                          kCCDecrypt,                  // CCOperation op,         /* kCCEncrypt, kCCDecrypt */
                                          kCCAlgorithmAES,             // CCAlgorithm alg,        /* kCCAlgorithmAES128, etc. */
                                          kCCOptionPKCS7Padding,       // CCOptions options,      /* kCCOptionPKCS7Padding, etc. */
                                          digest256,                   // const void *key,
                                          CC_SHA256_DIGEST_LENGTH,     // size_t keyLength,
                                          NULL,                        // const void *iv,         /* optional initialization vector */
                                          [_encryptedData bytes],      // const void *dataIn,     /* optional per op and alg */
                                          [_encryptedData length],     // size_t dataInLength,
                                          decryptedData.mutableBytes,  // void *dataOut,          /* data RETURNED here */
                                          decryptedDataCapacity,       // size_t dataOutAvailable,
                                          &dataOutMoved                // size_t *dataOutMoved
                                          );
    
    if (cryptstatus != kCCSuccess) {
        BTCDataClear(decryptedData);
        BTCSecureMemset(&ctx256, 0, sizeof(ctx256));
        decryptedData = nil;
    } else {
        // Resize the result key to the correct size.
        decryptedData.length = dataOutMoved;
    }
    
    // Clear sensitive info from memory.
    
    if ([pointX isKindOfClass:[NSMutableData class]]) {
        BTCDataClear((NSMutableData*)pointX);
    }
    [pk clear];
    [curvePoint clear];
    BTCSecureMemset(&ctx256, 0, sizeof(ctx256));
    
    if (!decryptedData) {
        BTCSecureMemset(digest256, 0, CC_SHA256_DIGEST_LENGTH);
        return nil;
    }

    // 3. Verify the checksum.
    
    CC_SHA256_Init(&ctx256);
    CC_SHA256_Update(&ctx256, digest256, CC_SHA256_DIGEST_LENGTH);
    CC_SHA256_Update(&ctx256, decryptedData.bytes, (CC_LONG)decryptedData.length);
    CC_SHA256_Final(digest256, &ctx256);
    CC_SHA256_Init(&ctx256);
    CC_SHA256_Update(&ctx256, digest256, CC_SHA256_DIGEST_LENGTH);
    CC_SHA256_Final(digest256, &ctx256);
    
    if (_checksum.length != BTCFancyEncryptedMessageChecksumLength) {
        BTCSecureMemset(digest256, 0, CC_SHA256_DIGEST_LENGTH);
        return nil;
    }
    
    if (memcmp(digest256, _checksum.bytes, BTCFancyEncryptedMessageChecksumLength) != 0) {
        BTCSecureMemset(digest256, 0, CC_SHA256_DIGEST_LENGTH);
        return nil;
    }
    
    BTCSecureMemset(digest256, 0, CC_SHA256_DIGEST_LENGTH);
    
    return decryptedData;
}



// Returns 1-byte representation of a target not higher than a given one.
// Maximum difficulty is the minimum target and vice versa.
+ (uint8_t) compactTargetForTarget:(uint32_t)target {
    return BTCEMCompactTargetForFullTarget(target);
}


// Returns a full 32-bit target from its compact representation.
+ (uint32_t) targetForCompactTarget:(uint8_t)compactTarget {
    return BTCEMFullTargetForCompactTarget(compactTarget);
}



@end


static uint8_t BTCEMCompactTargetForFullTarget(uint32_t fullTarget) {
    // Simply find the highest target that is not greater than a given one.
    for (uint8_t ct = 0xFF; ct >= 0; --ct) {
        if (BTCEMFullTargetForCompactTarget(ct) <= fullTarget) {
            uint32_t order = ct >> 3;
            if (order == 0) return ct >> 2;
            if (order == 1) return ct & (0xff - 1 - 2);
            if (order == 2) return ct & (0xff - 1);
            return ct;
        }
    }
    return 0;
}

static uint32_t BTCEMFullTargetForCompactTarget(uint8_t compactTarget) {
    // 8 bits: a b c d e f g h
    // a,b,c,d,e (higher bits) are used to determine the order (2^(0..31))
    // f,g,h are following the order bit. The rest are 1's till the lowest bit.
    
    uint32_t order = compactTarget >> 3;
    uint32_t tail = compactTarget & (1 + 2 + 4);
    
    if (order == 0) return (tail >> 2);
    
    // Compose a full tail where highest 3 bits are tail and the rest is ones.
    // Then shift it where the order says.
    
    // [8 bits] [8 bits] [8 bits] [5 bits] [3 tail bits]
    tail <<= 8 + 8 + 8 + 5;
    tail += ((1 << (8 + 8 + 8 + 5)) - 1); // trailing 1's
    
    tail >>= 32 - order;
    
    uint32_t fullTarget = (1 << order) + tail;
    
    return fullTarget;
}



