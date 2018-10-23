// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.

#import "BTCEncryptedBackup.h"
#import "BTCData.h"
#import "BTCBase58.h"
#import "BTCKey.h"
#import "BTCNetwork.h"
#import "BTCMerkleTree.h"
#import "BTCProtocolSerialization.h"
#import <CommonCrypto/CommonCrypto.h>

@interface BTCEncryptedBackup ()
@property(nonatomic, readwrite) BTCEncryptedBackupVersion version;
@property(nonatomic, readwrite) NSTimeInterval timestamp;
@property(nonatomic, readwrite) NSDate* date;

@property(nonatomic, readwrite) NSData* backupKey;
@property(nonatomic, readwrite) NSData* decryptedData;
@property(nonatomic, readwrite) NSData* encryptedData;

@property(nonatomic, readwrite) NSData* iv;
@property(nonatomic, readwrite) NSData* ciphertext;
@property(nonatomic, readwrite) NSData* signature;
@end

@implementation BTCEncryptedBackup

- (id) initWithBackupKey:(NSData*)backupKey {
    if (!backupKey) return nil;
    if (self = [super init]) {
        self.version = BTCEncryptedBackupVersion1;
        self.date = [NSDate date];
        self.backupKey = backupKey;
    }
    return self;
}

- (NSTimeInterval) timestamp {
    return self.date.timeIntervalSince1970;
}

- (void) setTimestamp:(NSTimeInterval)timestamp {
    if (timestamp == 0.0) {
        self.date = nil;
    } else {
        self.date = [NSDate dateWithTimeIntervalSince1970:timestamp];
    }
}

+ (instancetype) encrypt:(NSData*)data backupKey:(NSData*)backupKey {
    return [self encrypt:data backupKey:backupKey timestamp:[NSDate date].timeIntervalSince1970];
}

+ (instancetype) encrypt:(NSData*)data backupKey:(NSData*)backupKey timestamp:(NSTimeInterval)timestamp {
    BTCEncryptedBackup* b = [[BTCEncryptedBackup alloc] initWithBackupKey:backupKey];
    b.timestamp = timestamp;
    b.decryptedData = data;
    NSData* r = [b encrypt];
    if (r) {
        b.encryptedData = r;
        return b;
    }
    return nil;
}

+ (instancetype) decrypt:(NSData*)data backupKey:(NSData*)backupKey {
    BTCEncryptedBackup* b = [[BTCEncryptedBackup alloc] initWithBackupKey:backupKey];
    b.encryptedData = data;
    NSData* r = [b decrypt];
    if (r) {
        b.decryptedData = r;
        return b;
    }
    return nil;
}

+ (NSData*) backupKeyForNetwork:(BTCNetwork*)network masterKey:(NSData*)masterKey {
    if (!network || network.isMainnet) {
        return BTCHMACSHA256(masterKey, [@"Automatic Backup Key Mainnet" dataUsingEncoding:NSASCIIStringEncoding]);
    } else {
        return BTCHMACSHA256(masterKey, [@"Automatic Backup Key Testnet" dataUsingEncoding:NSASCIIStringEncoding]);
    }
}

+ (BTCKey*) authenticationKeyWithBackupKey:(NSData*)backupKey {
    BTCKey* key = [[BTCKey alloc] initWithPrivateKey:BTCHMACSHA256(backupKey, [@"Authentication Key" dataUsingEncoding:NSUTF8StringEncoding])];
    key.publicKeyCompressed = YES;
    return key;
}

+ (NSString*) walletIDWithAuthenticationKey:(NSData*)authPubkey {
    // WalletID = Base58Check(0x49 || RIPEMD-160(SHA-256(APub)))
    NSMutableData* data = [NSMutableData data];
    uint8_t v = 0x49;
    [data appendBytes:&v length:1];
    [data appendData:BTCHash160(authPubkey)];
    return BTCBase58CheckStringWithData(data);
}


- (NSData*) encryptionKey {
    return [BTCHMACSHA256(self.backupKey, [@"Encryption Key" dataUsingEncoding:NSUTF8StringEncoding]) subdataWithRange:NSMakeRange(0, 16)];
}

- (NSData*) iv {
    if (_iv) return _iv;
    return [self ivForPlaintext:self.decryptedData ek:[self encryptionKey]];
}

- (NSData*) ciphertext {
    if (_ciphertext) return _ciphertext;
    return [self ciphertextForData:self.decryptedData iv:[self iv] ek:[self encryptionKey]];
}

- (NSData*) merkleRoot {
    return [self merkleRootForCiphertext:[self ciphertext]];
}

- (NSData*) dataForSigning {
    return [self dataForSigning:self.version timestamp:self.timestamp iv:[self iv] merkleRoot:[self merkleRoot]];
}

- (BTCKey*) authenticationKey {
    return [[self class] authenticationKeyWithBackupKey:self.backupKey];
}

- (NSString*) walletID {
    return [[self class] walletIDWithAuthenticationKey:self.authenticationKey.publicKey];
}

- (NSData*) signature {
    if (_signature) return _signature;
    return [self signatureForData:[self dataForSigning] key:[self authenticationKey]];
}


- (NSData*) encrypt {

    NSData* plaintext = self.decryptedData;

    // Result = VersionByte || Timestamp || IV || CiphertextLength || Ciphertext || SignatureLength || Signature
    NSMutableData* result = [NSMutableData data];

    uint8_t v = (uint8_t)self.version;
    uint32_t ts = CFSwapInt32HostToLittle((uint32_t)self.timestamp);
    BTCKey* ak = [self authenticationKey];
    NSData* ek = [self encryptionKey];
    NSData* iv = [self ivForPlaintext:plaintext ek:ek];
    NSData* ciphertext = [self ciphertextForData:plaintext iv:iv ek:ek];
    NSData* mr = [self merkleRootForCiphertext:ciphertext];
    NSData* signature = [self signatureForData:[self dataForSigning:self.version timestamp:self.timestamp iv:iv merkleRoot:mr] key:ak];

    [result appendData:[NSData dataWithBytes:&v length:1]];
    [result appendData:[NSData dataWithBytes:&ts length:4]];
    [result appendData:iv];
    [result appendData:[BTCProtocolSerialization dataForVarString:ciphertext]];
    [result appendData:[BTCProtocolSerialization dataForVarString:signature]];
    return result;
}

- (NSData*) decrypt {

    // Result = VersionByte || Timestamp || IV || CiphertextLength || Ciphertext || SignatureLength || Signature

    NSData* payload = self.encryptedData;
    if (payload.length < (1 + 4 + 16 + 2 + 60)) {
        return nil;
    }
    self.version = ((uint8_t*)payload.bytes)[0];
    uint32_t ts;
    memcpy(&ts, [payload subdataWithRange:NSMakeRange(1, 4)].bytes, 4);
    self.timestamp = CFSwapInt32LittleToHost(ts);
    NSData* iv = [payload subdataWithRange:NSMakeRange(1+4, 16)];

    NSInteger fixedOffset = 1+4+16;
    NSUInteger ctlen = 0;
    NSData* ciphertext = [BTCProtocolSerialization readVarStringFromData:[payload subdataWithRange:NSMakeRange(fixedOffset, payload.length - fixedOffset)] readBytes:&ctlen];

    if (!ciphertext) {
        return nil;
    }

    NSData* signature = [BTCProtocolSerialization readVarStringFromData:
                         [payload subdataWithRange:NSMakeRange(fixedOffset + ctlen, payload.length - (fixedOffset + ctlen))]];

    if (!signature) {
        return nil;
    }

    self.iv = iv;
    self.ciphertext = ciphertext;
    self.signature = signature;

    // 1. Verify signature.
    // 2. Decrypt
    // 3. Verify plaintext integrity via IV-as-MAC.

    BTCKey* ak = [self authenticationKey];
    NSData* ek = [self encryptionKey];
    NSData* mr = [self merkleRootForCiphertext:ciphertext];
    NSData* sigData = [self dataForSigning:self.version timestamp:self.timestamp iv:iv merkleRoot:mr];
    if (![ak isValidSignature:signature hash:BTCHash256(sigData)]) {
        return nil;
    }

    NSData* plaintext = [self plaintextFromData:ciphertext iv:iv ek:ek];
    if (!plaintext) {
        return nil;
    }

    NSData* mac = [self ivForPlaintext:plaintext ek:ek];

    // IV acts as a MAC on plaintext. Here we check that ciphertext wasn't tail-mutated within Merkle Tree.
    if (![mac isEqual:iv]) {
        return nil;
    }

    return plaintext;
}



// Functional Helpers

- (NSData*) ivForPlaintext:(NSData*)plaintext ek:(NSData*)ek {
    return [BTCHMACSHA256(ek, plaintext) subdataWithRange:NSMakeRange(0, 16)];
}

- (NSData*) ciphertextForData:(NSData*)plaintext iv:(NSData*)iv ek:(NSData*)ek {

    NSMutableData* ct = [NSMutableData dataWithLength:plaintext.length + 16];
    size_t dataOutMoved = 0;
    CCCryptorStatus cryptstatus = CCCrypt(
                                          kCCEncrypt,                  // CCOperation op,         /* kCCEncrypt, kCCDecrypt */
                                          kCCAlgorithmAES,             // CCAlgorithm alg,        /* kCCAlgorithmAES128, etc. */
                                          kCCOptionPKCS7Padding,       // CCOptions options,      /* kCCOptionPKCS7Padding, etc. */
                                          ek.bytes,                    // const void *key,
                                          ek.length,                   // size_t keyLength,
                                          iv.bytes,                    // const void *iv,         /* optional initialization vector */
                                          plaintext.bytes,             // const void *dataIn,     /* optional per op and alg */
                                          plaintext.length,            // size_t dataInLength,
                                          ct.mutableBytes,             // void *dataOut,          /* data RETURNED here */
                                          ct.length,                   // size_t dataOutAvailable,
                                          &dataOutMoved                // size_t *dataOutMoved
                                          );

    if (cryptstatus != kCCSuccess) {
        return nil;
    }
    [ct setLength:dataOutMoved];
    return ct;
}

- (NSData*) plaintextFromData:(NSData*)ciphertext iv:(NSData*)iv ek:(NSData*)ek {

    NSMutableData* pt = [NSMutableData dataWithLength:ciphertext.length];
    size_t dataOutMoved = 0;
    CCCryptorStatus cryptstatus = CCCrypt(
                                          kCCDecrypt,                  // CCOperation op,         /* kCCEncrypt, kCCDecrypt */
                                          kCCAlgorithmAES,             // CCAlgorithm alg,        /* kCCAlgorithmAES128, etc. */
                                          kCCOptionPKCS7Padding,       // CCOptions options,      /* kCCOptionPKCS7Padding, etc. */
                                          ek.bytes,                    // const void *key,
                                          ek.length,                   // size_t keyLength,
                                          iv.bytes,                    // const void *iv,         /* optional initialization vector */
                                          ciphertext.bytes,            // const void *dataIn,     /* optional per op and alg */
                                          ciphertext.length,           // size_t dataInLength,
                                          pt.mutableBytes,             // void *dataOut,          /* data RETURNED here */
                                          pt.length,                   // size_t dataOutAvailable,
                                          &dataOutMoved                // size_t *dataOutMoved
                                          );

    if (cryptstatus != kCCSuccess) {
        return nil;
    }
    [pt setLength:dataOutMoved];
    return pt;
}


- (NSData*) merkleRootForCiphertext:(NSData*)data {
    // Ciphertext = a (1024) || b (1024) || c (1024) || d (1024) || e (904 bytes)
    /*
          Merkle Root
            /     \
           p       q
          / \     / \
         f   g   h   h
        / \ / \ / \
        a b c d e e
    */
    NSMutableArray* dataItems = [NSMutableArray arrayWithCapacity:((data.length + 1023) / 1024)];
    for (int i = 0; i < data.length; i += 1024) {
        NSData* item = [data subdataWithRange:NSMakeRange(i, MIN(1024, data.length - i))];
        [dataItems addObject:item];
    }
    BTCMerkleTree* mt = [[BTCMerkleTree alloc] initWithDataItems:dataItems];
    return mt.merkleRoot;
}

- (NSData*) dataForSigning:(BTCEncryptedBackupVersion)version timestamp:(NSTimeInterval)timestamp iv:(NSData*)iv merkleRoot:(NSData*)merkleRoot {
    // VersionByte || Timestamp || IV || MerkleRoot

    NSMutableData* result = [NSMutableData data];

    uint8_t v = (uint8_t)version;
    uint32_t ts = (uint32_t)timestamp;

    [result appendData:[NSData dataWithBytes:&v length:1]];
    [result appendData:[NSData dataWithBytes:&ts length:4]];
    [result appendData:iv];
    [result appendData:merkleRoot];
    return result;
}

- (NSData*) signatureForData:(NSData*)data key:(BTCKey*)key {

    // Signature = ECDSA(private key: AK, hash: SHA-256(SHA-256(VersionByte || Timestamp || IV || MerkleRoot))))
    NSData* hash = BTCHash256(data);
    return [key signatureForHash:hash];
}


@end
