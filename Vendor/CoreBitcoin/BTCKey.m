// Oleg Andreev <oleganza@gmail.com>

#import "BTCKey.h"
#import "BTCData.h"
#import "BTCAddress.h"
#import "BTCCurvePoint.h"
#import "BTCBigNumber.h"
#import "BTCProtocolSerialization.h"
#import "BTCErrors.h"
#import "BTCScript.h"
#import "BTCOpcode.h"
#include <CommonCrypto/CommonCrypto.h>
#include <openssl/ec.h>
#include <openssl/ecdsa.h>
#include <openssl/evp.h>
#include <openssl/obj_mac.h>
#include <openssl/bn.h>
#include <openssl/rand.h>

#define CHECK_IF_CLEARED if (_cleared) { [[NSException exceptionWithName:@"BTCKey: instance was already cleared." reason:@"" userInfo:nil] raise]; }

#define BTCCompressedPubkeyLength   (33)
#define BTCUncompressedPubkeyLength (65)

static BOOL    BTCKeyCheckPrivateKeyRange(const unsigned char *secret, size_t length);
static BOOL    BTCKeyCheckSignatureElement(const unsigned char *bytes, int length, BOOL half);
static int     BTCRegenerateKey(EC_KEY *eckey, BIGNUM *priv_key);
static NSData* BTCSignatureHashForBinaryMessage(NSData* data);
static int     ECDSA_SIG_recover_key_GFp(EC_KEY *eckey, ECDSA_SIG *ecsig, const unsigned char *msg, int msglen, int recid, int check);

@interface BTCKey ()
@end

@implementation BTCKey {
    BOOL _cleared;
    EC_KEY* _key;
    NSMutableData* _publicKey;
    BOOL _publicKeyCompressed;
}

- (id) initWithNewKeyPair:(BOOL)createKeyPair {
    if (self = [super init]) {
        [self prepareKeyIfNeeded];
        if (createKeyPair) [self generateKeyPair];
    }
    return self;
}

- (id) init {
    return [self initWithNewKeyPair:YES];
}

- (id) initWithPublicKey:(NSData*)publicKey {
    if (self = [super init]) {
        if (![self isValidPubKey:publicKey]) return nil;
        [self setPublicKey:publicKey];
    }
    return self;
}

- (id) initWithCurvePoint:(BTCCurvePoint*)curvePoint {
    if (self = [super init]) {
        if (!curvePoint) return nil;
        [self prepareKeyIfNeeded];
        EC_KEY_set_public_key(_key, curvePoint.EC_POINT);
    }
    return self;
}

- (id) initWithWIF:(NSString*)wifString {
    BTCPrivateKeyAddress* addr = [BTCPrivateKeyAddress addressWithString:wifString];
    if (![addr isKindOfClass:[BTCPrivateKeyAddress class]]) {
        return nil;
    }
    return [self initWithPrivateKeyAddress:addr];
}

- (id) initWithDERPrivateKey:(NSData*)DERPrivateKey {
    if (self = [super init]) {
        [self setDERPrivateKey:DERPrivateKey];
    }
    return self;
}

- (id) initWithPrivateKey:(NSData*)privateKey {
    if (self = [super init]) {
        [self setPrivateKey:privateKey];
    }
    return self;
}

- (void) dealloc {
    [self clear];
}

- (void) clear {
    BTCDataClear(_publicKey);
    _publicKey = nil;

    // I couldn't find how to clear sensitive key data in OpenSSL,
    // so I just replace existing key with a new one.
    // Correct me if I'm doing it wrong.
    if (!_cleared) [self generateKeyPair];

    if (_key) EC_KEY_free(_key);
    _key = NULL;

    _cleared = YES;
}

// Verifies signature for a given hash with a public key.
- (BOOL) isValidSignature:(NSData*)signature hash:(NSData*)hash {
    CHECK_IF_CLEARED;

    if (hash.length == 0 || signature.length == 0) return NO;
  
    // -1 = error, 0 = bad sig, 1 = good
    if (ECDSA_verify(0, (unsigned char*)hash.bytes,      (int)hash.length,
                        (unsigned char*)signature.bytes, (int)signature.length,
                        _key) != 1)
    {
        return NO;
    }
  
    return YES;
}

// Returns a signature data for a 256-bit hash using private key.
- (NSData*)signatureForHash:(NSData*)hash {
    return [self signatureForHash:hash appendHashType:NO hashType:0];
}

// Same as above, but also appends a hash type byte to the signature.
- (NSData*)signatureForHash:(NSData*)hash hashType:(BTCSignatureHashType)hashType {
   return [self signatureForHash:hash appendHashType:YES hashType:hashType];
}

- (NSData*)signatureForHash:(NSData*)hash withHashType:(BTCSignatureHashType)hashType {
    return [self signatureForHash:hash appendHashType:YES hashType:hashType];
}

- (NSData*)signatureForHash:(NSData*)hash appendHashType:(BOOL)appendHashType hashType:(BTCSignatureHashType)hashType {
    CHECK_IF_CLEARED;

    // ECDSA signature is a pair of numbers: (Kx, s)
    // Where Kx = x coordinate of k*G mod n (n is the order of secp256k1).
    // And s = (k^-1)*(h + Kx*privkey).
    // By default, k is chosen randomly on interval [0, n - 1].
    // But this makes signatures harder to test and allows faulty or backdoored RNGs to leak private keys from ECDSA signatures.
    // To avoid these issues, we'll generate k = Hash256(hash || privatekey) and make all computations by hand.
    //
    // Note: if one day you think it's a good idea to mix in some extra entropy as an option,
    //       ask yourself why Hash(message || privkey) is not unpredictable enough.
    //       IMHO, it is as predictable as privkey and making it any stronger has no point since
    //       guessing the privkey allows anyone to do the same as guessing the k: sign any
    //       other transaction with that key. Also, the same hash function is used for computing
    //       the message hash and needs to be preimage resistant. If it's weak, anyone can recover the
    //       private key from a few observed signatures. Using the same function to derive k therefore
    //       does not make the signature any less secure.
    //

    ECDSA_SIG sigValue;
    ECDSA_SIG *sig = NULL;

    /* deterministic signature with nonce derived from message and private key */
    sig = &sigValue;
  
    const BIGNUM *privkeyBIGNUM = EC_KEY_get0_private_key(_key);

    BTCMutableBigNumber* privkeyBN = [[BTCMutableBigNumber alloc] initWithBIGNUM:privkeyBIGNUM];
    BTCBigNumber* n = [BTCCurvePoint curveOrder];

    NSMutableData* kdata = [self signatureNonceForHash:hash];
    BTCMutableBigNumber* k = [[BTCMutableBigNumber alloc] initWithUnsignedBigEndian:kdata];
    [k mod:n]; // make sure k belongs to [0, n - 1]

    BTCDataClear(kdata);

    BTCCurvePoint* K = [[BTCCurvePoint generator] multiply:k];
    BTCBigNumber* Kx = K.x;

    BTCBigNumber* hashBN = [[BTCBigNumber alloc] initWithUnsignedBigEndian:hash];

    // Compute s = (k^-1)*(h + Kx*privkey)

    BTCBigNumber* signatureBN = [[[privkeyBN multiply:Kx mod:n] add:hashBN mod:n] multiply:[k inverseMod:n] mod:n];

    BIGNUM r; BN_init(&r); BN_copy(&r, Kx.BIGNUM);
    BIGNUM s; BN_init(&s); BN_copy(&s, signatureBN.BIGNUM);

    [privkeyBN clear];
    [k clear];
    [hashBN clear];
    [K clear];
    [Kx clear];
    [signatureBN clear];

    sig->r = &r;
    sig->s = &s;

    BN_CTX *ctx = BN_CTX_new();
    BN_CTX_start(ctx);

    const EC_GROUP *group = EC_KEY_get0_group(_key);
    BIGNUM *order = BN_CTX_get(ctx);
    BIGNUM *halforder = BN_CTX_get(ctx);
    EC_GROUP_get_order(group, order, ctx);
    BN_rshift1(halforder, order);
    if (BN_cmp(sig->s, halforder) > 0) {
        // enforce low S values, by negating the value (modulo the order) if above order/2.
        BN_sub(sig->s, order, sig->s);
    }
    BN_CTX_end(ctx);
    BN_CTX_free(ctx);
    unsigned int sigSize = ECDSA_size(_key);

    NSMutableData* signature = [NSMutableData dataWithLength:sigSize + 16]; // Make sure it is big enough

    unsigned char *pos = (unsigned char *)signature.mutableBytes;
    sigSize = i2d_ECDSA_SIG(sig, &pos);

    [signature setLength:sigSize];  // Shrink to fit actual size

    if (appendHashType) {
        [signature appendBytes:&hashType length:sizeof(hashType)];
    }

    return signature;
  
    // This code is simpler but it produces random signatures and does not canonicalize S as done above.
    //
    //    unsigned int sigSize = ECDSA_size(_key);
    //    NSMutableData* signature = [NSMutableData dataWithLength:sigSize];
    //
    //    if (!ECDSA_sign(0, (unsigned char*)hash.bytes, (int)hash.length, signature.mutableBytes, &sigSize, _key))
    //    {
    //        BTCDataClear(signature);
    //        return nil;
    //    }
    //    [signature setLength:sigSize];
    //
    //    return signature;
}

- (ECDSA_SIG*) eosSignForHash:(NSData*)hash{
  CHECK_IF_CLEARED;
  
  // ECDSA signature is a pair of numbers: (Kx, s)
  // Where Kx = x coordinate of k*G mod n (n is the order of secp256k1).
  // And s = (k^-1)*(h + Kx*privkey).
  // By default, k is chosen randomly on interval [0, n - 1].
  // But this makes signatures harder to test and allows faulty or backdoored RNGs to leak private keys from ECDSA signatures.
  // To avoid these issues, we'll generate k = Hash256(hash || privatekey) and make all computations by hand.
  //
  // Note: if one day you think it's a good idea to mix in some extra entropy as an option,
  //       ask yourself why Hash(message || privkey) is not unpredictable enough.
  //       IMHO, it is as predictable as privkey and making it any stronger has no point since
  //       guessing the privkey allows anyone to do the same as guessing the k: sign any
  //       other transaction with that key. Also, the same hash function is used for computing
  //       the message hash and needs to be preimage resistant. If it's weak, anyone can recover the
  //       private key from a few observed signatures. Using the same function to derive k therefore
  //       does not make the signature any less secure.
  //
  
  const BIGNUM *privkeyBIGNUM = EC_KEY_get0_private_key(_key);
  BTCBigNumber* n = [BTCCurvePoint curveOrder];
  int nonce = 1;
  BIGNUM *r = BN_new();
  BIGNUM *s = BN_new();
  ECDSA_SIG *sig = ECDSA_SIG_new();
  
  while (1) {
    NSMutableData* kdata;
    NSMutableData* kdataHash = [[NSMutableData alloc] initWithData:hash];
    BTCMutableBigNumber* privkeyBN = [[BTCMutableBigNumber alloc] initWithBIGNUM:privkeyBIGNUM];
    
    kdata = [self signatureNonceForHash:kdataHash nonce:nonce];
    
    BTCMutableBigNumber* k = [[BTCMutableBigNumber alloc] initWithUnsignedBigEndian:kdata];
    [k mod:n]; // make sure k belongs to [0, n - 1]
    
    BTCDataClear(kdata);
    
    BTCCurvePoint* K = [[BTCCurvePoint generator] multiply:k];
    BTCBigNumber* Kx = K.x;
    
    BTCBigNumber* hashBN = [[BTCBigNumber alloc] initWithUnsignedBigEndian:hash];
    
    // Compute s = (k^-1)*(h + Kx*privkey)
    
    BTCBigNumber* signatureBN = [[[privkeyBN multiply:Kx mod:n] add:hashBN mod:n] multiply:[k inverseMod:n] mod:n];
    
    BN_init(r); BN_copy(r, Kx.BIGNUM);
    BN_init(s); BN_copy(s, signatureBN.BIGNUM);
    
    sig->r = r;
    sig->s = s;
    BN_CTX *ctx = BN_CTX_new();
    BN_CTX_start(ctx);
    
    const EC_GROUP *group = EC_KEY_get0_group(_key);
    BIGNUM *order = BN_CTX_get(ctx);
    BIGNUM *halforder = BN_CTX_get(ctx);
    EC_GROUP_get_order(group, order, ctx);
    BN_rshift1(halforder, order);
    if (BN_cmp(sig->s, halforder) > 0) {
      // enforce low S values, by negating the value (modulo the order) if above order/2.
      BN_sub(sig->s, order, sig->s);
    }
    BN_CTX_end(ctx);
    BN_CTX_free(ctx);
    
    unsigned int sigSize = ECDSA_size(_key);
    
    NSMutableData* signature = [NSMutableData dataWithLength:sigSize + 16]; // Make sure it is big enough
    
    unsigned char *pos = (unsigned char *)signature.mutableBytes;
    sigSize = i2d_ECDSA_SIG(sig, &pos);
    int lenR = ((Byte *)signature.bytes)[3];
    int lenS = ((Byte*)signature.bytes)[5+ lenR];
    [k clear];
    [hashBN clear];
    [K clear];
    [Kx clear];
    [signatureBN clear];
    [privkeyBN clear];
    
    if (lenR == 32 && lenS == 32) {
      break;
    } else {
      nonce++;
    }
  }
  
  //
  //  [signature setLength:sigSize];  // Shrink to fit actual size
  
  
  //  return signature;
  
  return sig;
  // This code is simpler but it produces random signatures and does not canonicalize S as done above.
  //
  //    unsigned int sigSize = ECDSA_size(_key);
  //    NSMutableData* signature = [NSMutableData dataWithLength:sigSize];
  //
  //    if (!ECDSA_sign(0, (unsigned char*)hash.bytes, (int)hash.length, signature.mutableBytes, &sigSize, _key))
  //    {
  //        BTCDataClear(signature);
  //        return nil;
  //    }
  //    [signature setLength:sigSize];
  //
  //    return signature;
}


// [RFC6979 implementation](https://tools.ietf.org/html/rfc6979#section-3.2).
// Returns 32-byte `k` nonce generated deterministically from the `hash` and the private key.
- (NSMutableData*) signatureNonceForHash:(NSData*)hash {

    NSMutableData* privkey = [self privateKey];
    BTCBigNumber* order = [BTCCurvePoint curveOrder];

    uint8_t v[32];
    uint8_t k[32];
    uint8_t bx[2*32];
    uint8_t buf[32 + 1 + sizeof(bx)];
    uint8_t t[32];

    // Step 3.2.a. hash = H(message). Already performed by the caller.

    // Step 3.2.b. V = 0x01 0x01 0x01 ... 0x01 (32 bytes equal 0x01)
    memset(v, 1, sizeof(v));

    // Step 3.2.c. K = 0x00 0x00 0x00 ... 0x00 (32 bytes equal 0x00)
    memset(k, 0, sizeof(k));

    // Step 3.2.d. K = HMAC-SHA256(key: K, data: V || 0x00 || int2octets(privkey) || bits2octets(hash))
    memcpy(bx, privkey.bytes, 32);
    BTCMutableBigNumber* hashModOrder = [[[BTCMutableBigNumber alloc] initWithUnsignedBigEndian:hash] mod:order];
    memcpy(bx + 32, hashModOrder.unsignedBigEndian.bytes, 32);

    memcpy(buf, v, sizeof(v));
    buf[sizeof(v)] = 0x00;
    memcpy(buf + sizeof(v) + 1, bx, 64);

    CCHmac(kCCHmacAlgSHA256, k, sizeof(k), buf, sizeof(buf), k);

    // Step 3.2.e. V = HMAC-SHA256(key: K, data: V)
    CCHmac(kCCHmacAlgSHA256, k, sizeof(k), v, sizeof(v), v);

    // Step 3.2.f. K = HMAC-SHA256(key: K, data: V || 0x01 || int2octets(privkey) || bits2octets(hash))
    memcpy(buf, v, sizeof(v));
    buf[sizeof(v)] = 0x01;
    memcpy(buf + sizeof(v) + 1, bx, 64);
    CCHmac(kCCHmacAlgSHA256, k, sizeof(k), buf, sizeof(buf), k);

    // Step 3.2.g. V = HMAC-SHA256(key: K, data: V)
    CCHmac(kCCHmacAlgSHA256, k, sizeof(k), v, sizeof(v), v);

    // Step 3.2.h.
    for (int i = 0; i < 10000; i++) {
        CCHmac(kCCHmacAlgSHA256, k, sizeof(k), v, sizeof(v), t);

        BTCBigNumber* bn = [[BTCBigNumber alloc] initWithUnsignedBigEndian:[NSData dataWithBytesNoCopy:t length:sizeof(t) freeWhenDone:NO]];
        if (!bn.isZero && [bn less:order]) {
            return [NSMutableData dataWithBytes:&t length:sizeof(t)];
        }
        // Note: the probability of not succeeding at the first try is about 2^-127.
        memcpy(buf, v, sizeof(v));
        buf[sizeof(v)] = 0x00;
        CCHmac(kCCHmacAlgSHA256, k, sizeof(k), buf, sizeof(v) + 1, k);
        CCHmac(kCCHmacAlgSHA256, k, sizeof(k), v, sizeof(v), v);
    }
    // we generated 10000 numbers, none of them is good -> fail.
    return nil;
}

// [RFC6979 implementation](https://tools.ietf.org/html/rfc6979#section-3.2).
// Returns 32-byte `k` nonce generated deterministically from the `hash` and the private key.
- (NSMutableData*) signatureNonceForHash:(NSData*)hash nonce:(int)nonce {
  
  NSMutableData* privkey = [self privateKey];
  BTCBigNumber* order = [BTCCurvePoint curveOrder];
  
  uint8_t v[32];
  uint8_t k[32];
  uint8_t bx[2*32];
  uint8_t buf[32 + 1 + sizeof(bx)];
  
  // Step 3.2.a. hash = H(message). Already performed by the caller.
  
  // Step 3.2.b. V = 0x01 0x01 0x01 ... 0x01 (32 bytes equal 0x01)
  memset(v, 1, sizeof(v));
  
  // Step 3.2.c. K = 0x00 0x00 0x00 ... 0x00 (32 bytes equal 0x00)
  memset(k, 0, sizeof(k));
  
  // Step 3.2.d. K = HMAC-SHA256(key: K, data: V || 0x00 || int2octets(privkey) || bits2octets(hash))
  memcpy(bx, privkey.bytes, 32);
  BTCMutableBigNumber* hashModOrder = [[[BTCMutableBigNumber alloc] initWithUnsignedBigEndian:hash] mod:order];
  memcpy(bx + 32, hashModOrder.unsignedBigEndian.bytes, 32);
  
  memcpy(buf, v, sizeof(v));
  buf[sizeof(v)] = 0x00;
  memcpy(buf + sizeof(v) + 1, bx, 64);
  
  CCHmac(kCCHmacAlgSHA256, k, sizeof(k), buf, sizeof(buf), k);
  
  // Step 3.2.e. V = HMAC-SHA256(key: K, data: V)
  CCHmac(kCCHmacAlgSHA256, k, sizeof(k), v, sizeof(v), v);
  
  // Step 3.2.f. K = HMAC-SHA256(key: K, data: V || 0x01 || int2octets(privkey) || bits2octets(hash))
  memcpy(buf, v, sizeof(v));
  buf[sizeof(v)] = 0x01;
  memcpy(buf + sizeof(v) + 1, bx, 64);
  CCHmac(kCCHmacAlgSHA256, k, sizeof(k), buf, sizeof(buf), k);
  
  // Step 3.2.g. V = HMAC-SHA256(key: K, data: V)
  CCHmac(kCCHmacAlgSHA256, k, sizeof(k), v, sizeof(v), v);
  
  int i=0;
  do {
    if (i >0 ) {
      // Note: the probability of not succeeding at the first try is about 2^-127.
      memcpy(buf, v, sizeof(v));
      buf[sizeof(v)] = 0x00;
      CCHmac(kCCHmacAlgSHA256, k, sizeof(k), buf, sizeof(v) + 1, k);
      CCHmac(kCCHmacAlgSHA256, k, sizeof(k), v, sizeof(v), v);
    }
    // Step 3.2.h.
    CCHmac(kCCHmacAlgSHA256, k, sizeof(k), v, sizeof(v), v);
      
    i++;
  } while (i<=nonce);
  
  
  return [NSMutableData dataWithBytes:&v length:sizeof(v)];;
}

- (NSMutableData*) publicKey {
    CHECK_IF_CLEARED;
    return [NSMutableData dataWithData:[self publicKeyCached]];
}

- (NSMutableData*) publicKeyCached {
    CHECK_IF_CLEARED;
    if (!_publicKey) {
        _publicKey = [self publicKeyWithCompression:_publicKeyCompressed];
    }
    return _publicKey;
}

- (NSMutableData*) compressedPublicKey {
    return [self publicKeyWithCompression:YES];
}

- (NSMutableData*) uncompressedPublicKey {
    return [self publicKeyWithCompression:NO];
}


- (NSMutableData*) publicKeyWithCompression:(BOOL)compression {
    CHECK_IF_CLEARED;
    if (!_key) return nil;
    EC_KEY_set_conv_form(_key, compression ? POINT_CONVERSION_COMPRESSED : POINT_CONVERSION_UNCOMPRESSED);
    int length = i2o_ECPublicKey(_key, NULL);
    if (!length) return nil;
    NSAssert(length <= 65, @"Pubkey length must be up to 65 bytes.");
    NSMutableData* data = [[NSMutableData alloc] initWithLength:length];
    unsigned char* bytes = [data mutableBytes];
    if (i2o_ECPublicKey(_key, &bytes) != length) return nil;
    return data;
}

- (BTCCurvePoint*) curvePoint {
    CHECK_IF_CLEARED;
    const EC_POINT* ecpoint = EC_KEY_get0_public_key(_key);
    BTCCurvePoint* cp = [[BTCCurvePoint alloc] initWithEC_POINT:ecpoint];
    return cp;
}

- (NSMutableData*) DERPrivateKey {
    CHECK_IF_CLEARED;
    if (!_key) return nil;
    int length = i2d_ECPrivateKey(_key, NULL);
    if (!length) return nil;
    NSMutableData* data = [[NSMutableData alloc] initWithLength:length];
    unsigned char* bytes = [data mutableBytes];
    if (i2d_ECPrivateKey(_key, &bytes) != length) return nil;
    return data;
}

- (NSMutableData*) privateKey {
    CHECK_IF_CLEARED;
    if (!_key) return nil;
    const BIGNUM *bignum = EC_KEY_get0_private_key(_key);
    if (!bignum) return nil;
    int num_bytes = BN_num_bytes(bignum);
    NSMutableData* data = [[NSMutableData alloc] initWithLength:32];
    int copied_bytes = BN_bn2bin(bignum, &data.mutableBytes[32 - num_bytes]);
    if (copied_bytes != num_bytes) return nil;
    return data;
}

- (NSString*) WIF {
    if (!self.privateKey) return nil;
    return [self privateKeyAddress].string;
}

- (NSString*) WIFTestnet {
    if (!self.privateKey) return nil;
    return [self privateKeyAddressTestnet].string;
}

- (void) setPublicKey:(NSData *)publicKey {
    CHECK_IF_CLEARED;
    if (publicKey.length == 0) return;
    _publicKey = [NSMutableData dataWithData:publicKey];
  
    _publicKeyCompressed = ([self lengthOfPubKey:_publicKey] == BTCCompressedPubkeyLength);
  
    [self prepareKeyIfNeeded];
  
    const unsigned char* bytes = publicKey.bytes;
    if (!o2i_ECPublicKey(&_key, &bytes, publicKey.length)) {
        _publicKey = nil;
        _publicKeyCompressed = NO;
    }
}

- (void) setDERPrivateKey:(NSData *)DERPrivateKey {
    CHECK_IF_CLEARED;
    if (!DERPrivateKey) return;
  
    BTCDataClear(_publicKey); _publicKey = nil;
    [self prepareKeyIfNeeded];
  
    const unsigned char* bytes = DERPrivateKey.bytes;
    if (!d2i_ECPrivateKey(&_key, &bytes, DERPrivateKey.length)) {
        // OpenSSL failed for some weird reason. I have no idea what we should do.
    }
}

- (void) setPrivateKey:(NSData *)privateKey {
    CHECK_IF_CLEARED;
    if (!privateKey) return;
  
    BTCDataClear(_publicKey); _publicKey = nil;
    [self prepareKeyIfNeeded];

    if (!_key) return;
  
    BIGNUM *bignum = BN_bin2bn(privateKey.bytes, (int)privateKey.length, BN_new());
  
    if (!bignum) return;
  
    BTCRegenerateKey(_key, bignum);
    BN_clear_free(bignum);
}

- (BOOL) isPublicKeyCompressed {
    CHECK_IF_CLEARED;
    return _publicKeyCompressed;
}

- (void) setPublicKeyCompressed:(BOOL)flag {
    CHECK_IF_CLEARED;
    _publicKey = nil;
    _publicKeyCompressed = flag;
}

- (void) generateKeyPair {
    CHECK_IF_CLEARED;
    [self prepareKeyIfNeeded];
    NSMutableData* secret = [NSMutableData dataWithLength:32];
    unsigned char* bytes = secret.mutableBytes;
    do {
        RAND_bytes(bytes, 32);
    } while (!BTCKeyCheckPrivateKeyRange(bytes, 32));
    [self setPrivateKey:secret];
    BTCDataClear(secret);
}

- (void) prepareKeyIfNeeded {
    CHECK_IF_CLEARED;
    if (_key) return;
    _key = EC_KEY_new_by_curve_name(NID_secp256k1);
    if (!_key) {
        // This should not generally happen.
    }
}




#pragma mark - NSObject



- (id) copy {
    CHECK_IF_CLEARED;
    BTCKey* newKey = [[BTCKey alloc] initWithNewKeyPair:NO];
    if (_key) newKey->_key = EC_KEY_dup(_key);
    return newKey;
}

- (BOOL) isEqual:(BTCKey*)otherKey {
    CHECK_IF_CLEARED;
    if (![otherKey isKindOfClass:[self class]]) return NO;
    return [self.publicKeyCached isEqual:otherKey.publicKeyCached];
}

- (NSUInteger) hash {
    CHECK_IF_CLEARED;
    return [self.publicKeyCached hash];
}

- (NSString*) description {
    return [NSString stringWithFormat:@"<BTCKey:0x%p %@>", self, BTCHexFromData(self.publicKeyCached)];
}

- (NSString*) debugDescription
{
    return [NSString stringWithFormat:@"<BTCKey:0x%p pubkey:%@ privkey:%@>", self, BTCHexFromData(self.publicKeyCached), BTCHexFromData(self.privateKey)];
}



- (NSUInteger) lengthOfPubKey:(NSData*)data {
    if (data.length == 0) return 0;
  
    unsigned char header = ((const unsigned char*)data.bytes)[0];
    if (header == 2 || header == 3)
        return BTCCompressedPubkeyLength;
    if (header == 4 || header == 6 || header == 7)
        return BTCUncompressedPubkeyLength;
    return 0;
}

- (BOOL) isValidPubKey:(NSData*)data {
    CHECK_IF_CLEARED;
    NSUInteger length = data.length;
    return length > 0 && [self lengthOfPubKey:data] == length;
}





#pragma mark - BTCAddress Import/Export




- (id) initWithPrivateKeyAddress:(BTCPrivateKeyAddress*)privateKeyAddress {
    if (self = [self initWithNewKeyPair:NO]) {
        [self setPrivateKey:privateKeyAddress.data];
        [self setPublicKeyCompressed:privateKeyAddress.publicKeyCompressed];
    }
    return self;
}

- (BTCPublicKeyAddress*) publicKeyAddress {
    CHECK_IF_CLEARED;
    NSData* pubkey = [self publicKeyCached];
    if (pubkey.length == 0) return nil;
    return [BTCPublicKeyAddress addressWithData:BTCHash160(pubkey)];
}

- (BTCPublicKeyAddress*) address {
    CHECK_IF_CLEARED;
    NSData* pubkey = [self publicKeyCached];
    if (pubkey.length == 0) return nil;
    return [BTCPublicKeyAddress addressWithData:BTCHash160(pubkey)];
}

- (BTCPublicKeyAddressTestnet*) addressTestnet {
    CHECK_IF_CLEARED;
    NSData* pubkey = [self publicKeyCached];
    if (pubkey.length == 0) return nil;
    return [BTCPublicKeyAddressTestnet addressWithData:BTCHash160(pubkey)];
}

- (BTCPublicKeyAddress*) compressedPublicKeyAddress {
    CHECK_IF_CLEARED;
    NSData* pubkey = [self compressedPublicKey];
    if (pubkey.length == 0) return nil;
    return [BTCPublicKeyAddress addressWithData:BTCHash160(pubkey)];
}

- (BTCPublicKeyAddressTestnet*) compressedPublicKeyAddressTestnet {
    CHECK_IF_CLEARED;
    NSData* pubkey = [self compressedPublicKey];
    if (pubkey.length == 0) return nil;
    return [BTCPublicKeyAddressTestnet addressWithData:BTCHash160(pubkey)];
}

- (BTCScriptHashAddressTestnet*) witnessAddressTestnet {
    BTCScript* redeemScript = [self witnessRedeemScript];
    return [redeemScript scriptHashAddressTestnet];
}

- (BTCScriptHashAddress*) witnessAddress {
    BTCScript* redeemScript = [self witnessRedeemScript];
    return [redeemScript scriptHashAddress];
}

- (BTCScript*) witnessRedeemScript {
    CHECK_IF_CLEARED;
    NSData* pubkey = [self compressedPublicKey];
    if (pubkey.length == 0) return nil;
    NSData* pubKeyHash = BTCHash160(pubkey);
    BTCScript* redeemScript = [[BTCScript alloc] init];
    [redeemScript appendOpcode:OP_0];
    [redeemScript appendData:pubKeyHash];
    // The P2SH redeemScript is always 22 bytes.
    // It starts with a OP_0, followed by a canonical push of the keyhash (i.e. 0x0014{20-byte keyhash})
    if (redeemScript.data.length != 22) return nil;
    return redeemScript;
}

- (BTCPublicKeyAddress*) uncompressedPublicKeyAddress {
    CHECK_IF_CLEARED;
    NSData* pubkey = [self uncompressedPublicKey];
    if (pubkey.length == 0) return nil;
    return [BTCPublicKeyAddress addressWithData:BTCHash160(pubkey)];
}

- (BTCPublicKeyAddressTestnet*) uncompressedPublicKeyAddressTestnet {
    CHECK_IF_CLEARED;
    NSData* pubkey = [self uncompressedPublicKey];
    if (pubkey.length == 0) return nil;
    return [BTCPublicKeyAddressTestnet addressWithData:BTCHash160(pubkey)];
}

- (BTCPrivateKeyAddress*) privateKeyAddress {
    CHECK_IF_CLEARED;
    NSMutableData* privkey = self.privateKey;
    if (privkey.length == 0) return nil;
  
    BTCPrivateKeyAddress* result = [BTCPrivateKeyAddress addressWithData:privkey publicKeyCompressed:self.isPublicKeyCompressed];
    BTCDataClear(privkey);
    return result;
}


- (BTCPrivateKeyAddressTestnet*) privateKeyAddressTestnet {
    CHECK_IF_CLEARED;
    NSMutableData* privkey = self.privateKey;
    if (privkey.length == 0) return nil;

    BTCPrivateKeyAddressTestnet* result = [BTCPrivateKeyAddressTestnet addressWithData:privkey publicKeyCompressed:self.isPublicKeyCompressed];
    BTCDataClear(privkey);
    return result;
}







#pragma mark - Compact Signature






// Returns a compact signature for 256-bit hash. Aka "CKey::SignCompact" in BitcoinQT.
// Initially used for signing text messages.
//
// The format is one header byte, followed by two times 32 bytes for the serialized r and s values.
// The header byte: 0x1B = first key with even y, 0x1C = first key with odd y,
//                  0x1D = second key with even y, 0x1E = second key with odd y,
//                  add 0x04 for compressed keys.
- (NSData*) compactSignatureForHash:(NSData*)hash {
    CHECK_IF_CLEARED;
    NSMutableData* sigdata = [NSMutableData dataWithLength:65];
    unsigned char* sigbytes = sigdata.mutableBytes;
    const unsigned char* hashbytes = hash.bytes;
    int hashlength = (int)hash.length;
  
    int rec = -1;
  
    unsigned char *p64 = (sigbytes + 1); // first byte is reserved for header.
  
    ECDSA_SIG *sig = ECDSA_do_sign(hashbytes, hashlength, _key);
  
    if (sig==NULL) {
        return nil;
    }
    memset(p64, 0, 64);
    int nBitsR = BN_num_bits(sig->r);
    int nBitsS = BN_num_bits(sig->s);
    if (nBitsR <= 256 && nBitsS <= 256) {
        NSData* pubkey = [self compressedPublicKey];
        BOOL foundMatchingPubkey = NO;
        for (int i=0; i < 4; i++) {
            // It will be updated via direct access to _key ivar.
            BTCKey* key2 = [[BTCKey alloc] initWithNewKeyPair:NO];
            if (ECDSA_SIG_recover_key_GFp(key2->_key, sig, hashbytes, hashlength, i, 1) == 1) {
                NSData* pubkey2 = [key2 compressedPublicKey];
                if ([pubkey isEqual:pubkey2]) {
                    rec = i;
                    foundMatchingPubkey = YES;
                    break;
                }
            }
        }
        NSAssert(foundMatchingPubkey, @"At least one signature must work.");
        BN_bn2bin(sig->r,&p64[32-(nBitsR+7)/8]);
        BN_bn2bin(sig->s,&p64[64-(nBitsS+7)/8]);
    }
    ECDSA_SIG_free(sig);
  
    // First byte is a header
    sigbytes[0] = 0x1b + rec + (self.isPublicKeyCompressed ? 4 : 0);
    return sigdata;
}

- (NSData*) eosCompactSignatureForHash:(NSData*)hash {
  CHECK_IF_CLEARED;
  NSMutableData* sigdata = [NSMutableData dataWithLength:65];
  unsigned char* sigbytes = sigdata.mutableBytes;
  const unsigned char* hashbytes = hash.bytes;
  int hashlength = (int)hash.length;
  
  int rec = -1;
  
  unsigned char *p64 = (sigbytes + 1); // first byte is reserved for header.
  ECDSA_SIG *sig = [self eosSignForHash:hash];
  
  
  if (sig==NULL) {
    return nil;
  }
  memset(p64, 0, 64);
  int nBitsR = BN_num_bits(sig->r);
  int nBitsS = BN_num_bits(sig->s);
  if (nBitsR <= 256 && nBitsS <= 256) {
    NSData* pubkey = [self compressedPublicKey];
    BOOL foundMatchingPubkey = NO;
    for (int i=0; i < 4; i++) {
      // It will be updated via direct access to _key ivar.
      BTCKey* key2 = [[BTCKey alloc] initWithNewKeyPair:NO];
      if (ECDSA_SIG_recover_key_GFp(key2->_key, sig, hashbytes, hashlength, i, 1) == 1) {
        NSData* pubkey2 = [key2 compressedPublicKey];
        if ([pubkey isEqual:pubkey2]) {
          rec = i;
          foundMatchingPubkey = YES;
          break;
        }
      }
    }
    NSAssert(foundMatchingPubkey, @"At least one signature must work.");
    BN_bn2bin(sig->r,&p64[32-(nBitsR+7)/8]);
    BN_bn2bin(sig->s,&p64[64-(nBitsS+7)/8]);
  }
  ECDSA_SIG_free(sig);
  
  // First byte is a header
  sigbytes[0] = 0x1b + rec + 4;
  return sigdata;
}

+ (instancetype) eosEcRecover:(NSData *)signature forHash:(NSData *)hash {
  BTCKey *key = [[BTCKey alloc] initWithNewKeyPair:NO];
  ECDSA_SIG *sig = ECDSA_SIG_new();
  int recId = (int)[signature subdataWithRange:NSMakeRange(0, 1)];
  BTCBigNumber *r = [[BTCMutableBigNumber alloc] initWithUnsignedBigEndian:[signature subdataWithRange:NSMakeRange(1, 32)]];
  BTCBigNumber *s = [[BTCMutableBigNumber alloc] initWithUnsignedBigEndian:[signature subdataWithRange:NSMakeRange(33, 32)]];
  
  sig->r = r.BIGNUM;
  sig->s = s.BIGNUM;
  recId = (recId - 27) & 3;
  for (int i=0; i< recId; i++) {
    if (ECDSA_SIG_recover_key_GFp(key->_key, sig, hash.bytes, (int)hash.length, i, 1)) {
      return key;
    }
  }
  return nil;
}

// Verifies digest against given compact signature. On success returns a public key.
// Reconstruct public key from a compact signature
// This is only slightly more CPU intensive than just verifying it.
// If this function succeeds, the recovered public key is guaranteed to be valid
// (the signature is a valid signature of the given data for that key).
+ (BTCKey*) verifyCompactSignature:(NSData*)compactSignature forHash:(NSData*)hash {
    if (compactSignature.length != 65) return nil;
  
    const unsigned char* sigbytes = compactSignature.bytes;
    BOOL compressedPubKey = (sigbytes[0] - 0x1b) & 4;
    int rec = (sigbytes[0] - 0x1b) & ~4;
    const unsigned char* p64 = sigbytes + 1;
  
    // It will be updated via direct access to _key ivar.
    BTCKey* key = [[BTCKey alloc] initWithNewKeyPair:NO];
    key.publicKeyCompressed = compressedPubKey;
  
    if (rec<0 || rec>=3) {
        // Invalid variant of a pubkey.
        return nil;
    }
    ECDSA_SIG *sig = ECDSA_SIG_new();
    BN_bin2bn(&p64[0],  32, sig->r);
    BN_bin2bn(&p64[32], 32, sig->s);
    BOOL result = (1 == ECDSA_SIG_recover_key_GFp(key->_key, sig, (unsigned char*)hash.bytes, (int)hash.length, rec, 0));
    ECDSA_SIG_free(sig);
  
    // Failed to recover a pubkey.
    if (!result) return nil;
  
    return key;
}

// Verifies signature of the hash with its public key.
- (BOOL) isValidCompactSignature:(NSData*)signature forHash:(NSData*)hash {
    CHECK_IF_CLEARED;
    BTCKey* key = [[self class] verifyCompactSignature:signature forHash:hash];
    return [key isEqual:self];
}


// Multiplies a public key of the receiver with a given private key and returns resulting curve point as BTCKey object (pubkey only).
// Pubkey compression flag is the same as on receiver.
- (BTCKey*) diffieHellmanWithPrivateKey:(BTCKey*)privkey {

    BTCCurvePoint* curvePoint = self.curvePoint;
    BTCBigNumber* pk = [[BTCBigNumber alloc] initWithUnsignedBigEndian:privkey.privateKey];

    NSAssert(curvePoint, @"sanity check");
    NSAssert(pk, @"sanity check");

    // D-H happens here.
    [curvePoint multiply:pk];

    BTCKey* dhKey = [[BTCKey alloc] initWithCurvePoint:curvePoint];
    dhKey.publicKeyCompressed = self.publicKeyCompressed;

    return dhKey;
}













#pragma mark - Bitcoin Signed Message





// Returns a signature for a message prepended with "Bitcoin Signed Message:\n" line.
- (NSData*) signatureForMessage:(NSString*)message {
    return [self signatureForBinaryMessage:[message dataUsingEncoding:NSASCIIStringEncoding]];
}

- (NSData*) signatureForBinaryMessage:(NSData*)data {
    if (!data) return nil;
    return [self compactSignatureForHash:BTCSignatureHashForBinaryMessage(data)];
}

// Verifies message against given signature. On success returns a public key.
+ (BTCKey*) verifySignature:(NSData*)signature forMessage:(NSString*)message {
    return [self verifySignature:signature forBinaryMessage:[message dataUsingEncoding:NSASCIIStringEncoding]];
}

+ (BTCKey*) verifySignature:(NSData*)signature forBinaryMessage:(NSData *)data {
    if (!signature || !data) return nil;
    return [self verifyCompactSignature:signature forHash:BTCSignatureHashForBinaryMessage(data)];
}

- (BOOL) isValidSignature:(NSData*)signature forMessage:(NSString*)message {
    return [self isValidSignature:signature forBinaryMessage:[message dataUsingEncoding:NSASCIIStringEncoding]];
}

- (BOOL) isValidSignature:(NSData*)signature forBinaryMessage:(NSData *)data {
    BTCKey* key = [[self class] verifySignature:signature forBinaryMessage:data];
    return [key isEqual:self];
}







#pragma mark - Canonical Checks



// Note: non-canonical pubkey could still be valid for EC internals of OpenSSL and thus accepted by Bitcoin nodes.
+ (BOOL) isCanonicalPublicKey:(NSData*)data error:(NSError**)errorOut {
    NSUInteger length = data.length;
    const char* bytes = [data bytes];
  
    // Non-canonical public key: too short
    if (length < 33) {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorNonCanonicalPublicKey userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Non-canonical public key: too short.", @"")}];
        return NO;
    }
  
    if (bytes[0] == 0x04) {
        // Length of uncompressed key must be 65 bytes.
        if (length == 65) return YES;
      
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorNonCanonicalPublicKey userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Non-canonical public key: length of uncompressed key must be 65 bytes.", @"")}];
      
        return NO;
    } else if (bytes[0] == 0x02 || bytes[0] == 0x03) {
        // Length of compressed key must be 33 bytes.
        if (length == 33) return YES;
      
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorNonCanonicalPublicKey userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Non-canonical public key: length of compressed key must be 33 bytes.", @"")}];
      
        return NO;
    }
  
    // Unknown public key format.
    if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorNonCanonicalPublicKey userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Unknown non-canonical public key.", @"")}];
  
    return NO;
}



+ (BOOL) isCanonicalSignatureWithHashType:(NSData*)data verifyEvenS:(BOOL)verifyLowerS error:(NSError**)errorOut { // deprecated
    return [self isCanonicalSignatureWithHashType:data verifyLowerS:verifyLowerS error:errorOut];
}

+ (BOOL) isCanonicalSignatureWithHashType:(NSData*)data verifyLowerS:(BOOL)verifyLowerS error:(NSError**)errorOut {
    // See https://bitcointalk.org/index.php?topic=8392.msg127623#msg127623
    // A canonical signature exists of: <30> <total len> <02> <len R> <R> <02> <len S> <S> <hashtype>
    // Where R and S are not negative (their first byte has its highest bit not set), and not
    // excessively padded (do not start with a 0 byte, unless an otherwise negative number follows,
    // in which case a single 0 byte is necessary and even required).
  
    NSInteger length = data.length;
    const unsigned char* bytes = data.bytes;
  
    // Non-canonical signature: too short
    if (length < 9) {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorNonCanonicalScriptSignature userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Non-canonical signature: too short.", @"")}];
        return NO;
    }
  
    // Non-canonical signature: too long
    if (length > 73) {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorNonCanonicalScriptSignature userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Non-canonical signature: too long.", @"")}];
        return NO;
    }
  
    unsigned char nHashType = bytes[length - 1] & (~(SIGHASH_ANYONECANPAY));
  
    if (nHashType < SIGHASH_ALL || nHashType > SIGHASH_SINGLE) {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorNonCanonicalScriptSignature userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Non-canonical signature: unknown hashtype byte.", @"")}];
        return NO;
    }
  
    if (bytes[0] != 0x30) {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorNonCanonicalScriptSignature userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Non-canonical signature: wrong type.", @"")}];
        return NO;
    }
  
    if (bytes[1] != length-3) {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorNonCanonicalScriptSignature userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Non-canonical signature: wrong length marker.", @"")}];
        return NO;
    }
  
    unsigned int lenR = bytes[3];
  
    if (5 + lenR >= length) {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorNonCanonicalScriptSignature userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Non-canonical signature: S length misplaced.", @"")}];
        return NO;
    }
  
    unsigned int lenS = bytes[5+lenR];
  
    if ((unsigned long)(lenR+lenS+7) != length) {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorNonCanonicalScriptSignature userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Non-canonical signature: R+S length mismatch", @"")}];
        return NO;
    }
  
    const unsigned char *R = &bytes[4];
    if (R[-2] != 0x02) {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorNonCanonicalScriptSignature userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Non-canonical signature: R value type mismatch", @"")}];
        return NO;
    }
    if (lenR == 0) {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorNonCanonicalScriptSignature userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Non-canonical signature: R length is zero", @"")}];
        return NO;
    }
  
    if (R[0] & 0x80) {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorNonCanonicalScriptSignature userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Non-canonical signature: R value negative", @"")}];
        return NO;
    }
  
    if (lenR > 1 && (R[0] == 0x00) && !(R[1] & 0x80)) {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorNonCanonicalScriptSignature userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Non-canonical signature: R value excessively padded", @"")}];
        return NO;
    }
  
    const unsigned char *S = &bytes[6+lenR];
    if (S[-2] != 0x02) {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorNonCanonicalScriptSignature userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Non-canonical signature: S value type mismatch", @"")}];
        return NO;
    }
  
    if (lenS == 0) {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorNonCanonicalScriptSignature userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Non-canonical signature: S length is zero", @"")}];
        return NO;
    }
  
    if (S[0] & 0x80) {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorNonCanonicalScriptSignature userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Non-canonical signature: S value is negative", @"")}];
        return NO;
    }
  
    if (lenS > 1 && (S[0] == 0x00) && !(S[1] & 0x80)) {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain code:BTCErrorNonCanonicalScriptSignature userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Non-canonical signature: S value excessively padded", @"")}];
        return NO;
    }
  
    if (verifyLowerS) {
        if (!BTCKeyCheckSignatureElement(S, lenS, YES)) {
            if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain
                                                          code:BTCErrorNonCanonicalScriptSignature
                                                      userInfo:@{NSLocalizedDescriptionKey:
                                                                     NSLocalizedString(@"Non-canonical signature: S value is unnecessarily high", @"")}];
            return NO;
        }
    }
  
    return YES;
}

@end



// Order of secp256k1's generator minus 1.
static const unsigned char BTCKeyMaxModOrder[32] = {
    0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
    0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFE,
    0xBA,0xAE,0xDC,0xE6,0xAF,0x48,0xA0,0x3B,
    0xBF,0xD2,0x5E,0x8C,0xD0,0x36,0x41,0x40
};

// Half of the order of secp256k1's generator minus 1.
static const unsigned char BTCKeyMaxModHalfOrder[32] = {
    0x7F,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
    0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
    0x5D,0x57,0x6E,0x73,0x57,0xA4,0x50,0x1D,
    0xDF,0xE9,0x2F,0x46,0x68,0x1B,0x20,0xA0
};

static const unsigned char BTCKeyZero[0] = {};

NSComparisonResult BTCKeyCompareBigEndian(const unsigned char *c1, size_t c1len,
                                          const unsigned char *c2, size_t c2len) {
    while (c1len > c2len) {
        if (*c1 > 0) return NSOrderedDescending;
        c1++;
        c1len--;
    }
    while (c2len > c1len) {
        if (*c2 > 0) return NSOrderedAscending;
        c2++;
        c2len--;
    }
    while (c1len > 0) {
        if (*c1 > *c2) return NSOrderedDescending;
        if (*c2 > *c1) return NSOrderedAscending;
        c1++;
        c2++;
        c1len--;
    }
    return NSOrderedSame;
}

static BOOL BTCKeyCheckPrivateKeyRange(const unsigned char *secret, size_t length) {
    return BTCKeyCompareBigEndian(secret, length, BTCKeyZero, 0) > 0 &&
           BTCKeyCompareBigEndian(secret, length, BTCKeyMaxModOrder, 32) <= 0;
}

static BOOL BTCKeyCheckSignatureElement(const unsigned char *bytes, int length, BOOL half) {
    return BTCKeyCompareBigEndian(bytes, length, BTCKeyZero, 0) > 0 &&
           BTCKeyCompareBigEndian(bytes, length, half ? BTCKeyMaxModHalfOrder : BTCKeyMaxModOrder, 32) <= 0;
}

static NSData* BTCSignatureHashForBinaryMessage(NSData* msg) {
    NSMutableData* data = [NSMutableData data];
    [data appendData:[BTCProtocolSerialization dataForVarString:[@"Bitcoin Signed Message:\n" dataUsingEncoding:NSASCIIStringEncoding]]];
    [data appendData:[BTCProtocolSerialization dataForVarString:msg ?: [NSData data]]];
    return BTCHash256(data);
}



static int BTCRegenerateKey(EC_KEY *eckey, BIGNUM *priv_key) {
    BN_CTX *ctx = NULL;
    EC_POINT *pub_key = NULL;
  
    if (!eckey) return 0;
  
    const EC_GROUP *group = EC_KEY_get0_group(eckey);
  
    BOOL success = NO;
    if ((ctx = BN_CTX_new())) {
        if ((pub_key = EC_POINT_new(group))) {
            if (EC_POINT_mul(group, pub_key, priv_key, NULL, NULL, ctx)) {
                EC_KEY_set_private_key(eckey, priv_key);
                EC_KEY_set_public_key(eckey, pub_key);
                success = YES;
            }
        }
    }
  
    if (pub_key) EC_POINT_free(pub_key);
    if (ctx) BN_CTX_free(ctx);
  
    return success;
}





// Perform ECDSA key recovery (see SEC1 4.1.6) for curves over (mod p)-fields
// recid selects which key is recovered
// if check is non-zero, additional checks are performed
static int ECDSA_SIG_recover_key_GFp(EC_KEY *eckey, ECDSA_SIG *ecsig, const unsigned char *msg, int msglen, int recid, int check) {
    if (!eckey) return 0;
  
    int ret = 0;
    BN_CTX *ctx = NULL;
  
    BIGNUM *x = NULL;
    BIGNUM *e = NULL;
    BIGNUM *order = NULL;
    BIGNUM *sor = NULL;
    BIGNUM *eor = NULL;
    BIGNUM *field = NULL;
    EC_POINT *R = NULL;
    EC_POINT *O = NULL;
    EC_POINT *Q = NULL;
    BIGNUM *rr = NULL;
    BIGNUM *zero = NULL;
    int n = 0;
    int i = recid / 2;
  
    const EC_GROUP *group = EC_KEY_get0_group(eckey);
    if ((ctx = BN_CTX_new()) == NULL) { ret = -1; goto err; }
    BN_CTX_start(ctx);
    order = BN_CTX_get(ctx);
    if (!EC_GROUP_get_order(group, order, ctx)) { ret = -2; goto err; }
    x = BN_CTX_get(ctx);
    if (!BN_copy(x, order)) { ret=-1; goto err; }
    if (!BN_mul_word(x, i)) { ret=-1; goto err; }
    if (!BN_add(x, x, ecsig->r)) { ret=-1; goto err; }
    field = BN_CTX_get(ctx);
    if (!EC_GROUP_get_curve_GFp(group, field, NULL, NULL, ctx)) { ret=-2; goto err; }
    if (BN_cmp(x, field) >= 0) { ret=0; goto err; }
    if ((R = EC_POINT_new(group)) == NULL) { ret = -2; goto err; }
    if (!EC_POINT_set_compressed_coordinates_GFp(group, R, x, recid % 2, ctx)) { ret=0; goto err; }
    if (check) {
        if ((O = EC_POINT_new(group)) == NULL) { ret = -2; goto err; }
        if (!EC_POINT_mul(group, O, NULL, R, order, ctx)) { ret=-2; goto err; }
        if (!EC_POINT_is_at_infinity(group, O)) { ret = 0; goto err; }
    }
    if ((Q = EC_POINT_new(group)) == NULL) { ret = -2; goto err; }
    n = EC_GROUP_get_degree(group);
    e = BN_CTX_get(ctx);
    if (!BN_bin2bn(msg, msglen, e)) { ret=-1; goto err; }
    if (8*msglen > n) BN_rshift(e, e, 8-(n & 7));
    zero = BN_CTX_get(ctx);
    if (!BN_zero(zero)) { ret=-1; goto err; }
    if (!BN_mod_sub(e, zero, e, order, ctx)) { ret=-1; goto err; }
    rr = BN_CTX_get(ctx);
    if (!BN_mod_inverse(rr, ecsig->r, order, ctx)) { ret=-1; goto err; }
    sor = BN_CTX_get(ctx);
    if (!BN_mod_mul(sor, ecsig->s, rr, order, ctx)) { ret=-1; goto err; }
    eor = BN_CTX_get(ctx);
    if (!BN_mod_mul(eor, e, rr, order, ctx)) { ret=-1; goto err; }
    if (!EC_POINT_mul(group, Q, eor, R, sor, ctx)) { ret=-2; goto err; }
    if (!EC_KEY_set_public_key(eckey, Q)) { ret=-2; goto err; }
  
    ret = 1;
  
err:
    if (ctx) {
        BN_CTX_end(ctx);
        BN_CTX_free(ctx);
    }
    if (R != NULL) EC_POINT_free(R);
    if (O != NULL) EC_POINT_free(O);
    if (Q != NULL) EC_POINT_free(Q);
    return ret;
}


