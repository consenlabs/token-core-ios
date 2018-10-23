// Oleg Andreev <oleganza@gmail.com>

#import "BTCCurvePoint.h"
#import "BTCKey.h"
#import "BTCData.h"
#import "BTCBigNumber.h"
#include <openssl/bn.h>
#include <openssl/ecdsa.h>
#include <openssl/evp.h>

@implementation BTCCurvePoint {
    EC_GROUP* _group;
    EC_POINT* _point;
    BN_CTX*   _bnctx;
}

- (void) dealloc {
    if (_point) EC_POINT_clear_free(_point);
    _point = NULL;
    
    if (_group) EC_GROUP_free(_group);
    _group = NULL;
    
    if (_bnctx) BN_CTX_free(_bnctx);
    _bnctx = NULL;
}

+ (instancetype) generator {
    return [[self alloc] init];
}

+ (BTCBigNumber*) curveOrder {
    static BTCBigNumber* order;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        order = [[BTCBigNumber alloc] initWithUnsignedBigEndian:BTCDataWithHexCString("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141")];
    });
    return order;
}

- (id) initEmpty {
    if (self = [super init]) {
        _group = NULL;
        _point = NULL;
        _bnctx   = NULL;
        
        _group = EC_GROUP_new_by_curve_name(NID_secp256k1);
        if (!_group) {
            NSLog(@"BTCCurvePoint: EC_GROUP_new_by_curve_name(NID_secp256k1) failed");
            goto finish;
        }
        
        _point = EC_POINT_new(_group);
        if (!_point) {
            NSLog(@"BTCCurvePoint: EC_POINT_new(_group) failed");
            goto finish;
        }
        
        _bnctx = BN_CTX_new();
        if (!_bnctx) {
            NSLog(@"BTCCurvePoint: BN_CTX_new() failed");
            goto finish;
        }
        
        return self;
        
    finish:
        if (_group) EC_GROUP_free(_group);
        if (_point) EC_POINT_clear_free(_point);
        
        return nil;
    }
    return self;
}

- (id) init {
    if (self = [self initEmpty]) {
        if (!EC_POINT_copy(_point, EC_GROUP_get0_generator(_group))) {
            return nil;
        }
    }
    return self;
}

// Initializes point with its binary representation (corresponds to -data).
- (id) initWithData:(NSData*)data {
    if (self = [self initEmpty]) {
        
        BIGNUM* bn = BN_bin2bn(data.bytes, (int)data.length, NULL);
        if (!bn) {
            return nil;
        }
        
        if (!EC_POINT_bn2point(_group, bn, _point, _bnctx)) {
            if (bn) BN_clear_free(bn);
            return nil;
        }
        
        // Point is imported, only need to cleanup an intermediate BIGNUM structure.
        if (bn) BN_clear_free(bn);
    }
    return self;
}

// Initializes point with OpenSSL
- (id) initWithEC_POINT:(const EC_POINT*)ecpoint {
    if (self = [self initEmpty]) {
        if (!EC_POINT_copy(_point, ecpoint)) {
            return nil;
        }
    }
    return self;
}

- (NSData*) data {
    NSMutableData* data = [NSMutableData dataWithLength:33];
    
    BIGNUM* bn = BN_new();
    
    if (!bn) {
        return nil;
    }
    
    if (!EC_POINT_point2bn(_group, _point, POINT_CONVERSION_COMPRESSED, bn, _bnctx)) {
        if (bn) BN_clear_free(bn);
        return nil;
    }
    
    NSAssert(BN_num_bytes(bn) == 33, @"compressed point must be 33 bytes long");
    
    BN_bn2bin(bn, data.mutableBytes);
    
    if (bn) BN_clear_free(bn);
    
    return data;
}

- (const EC_POINT*) EC_POINT {
    return _point;
}

// These modify the receiver. To create another point use -copy: [[point copy] multiply:number]
- (instancetype) multiply:(BTCBigNumber*)number {
    if (!number) return nil;
    
    if (!EC_POINT_mul(_group, _point, NULL, _point, number.BIGNUM, _bnctx)) {
        return nil;
    }
    return self;
}

- (instancetype) add:(BTCCurvePoint*)otherPoint {
    if (!otherPoint) return nil;
    
    if (!EC_POINT_add(_group, _point, _point, otherPoint.EC_POINT, _bnctx)) {
        return nil;
    }
    return self;
}

// Efficiently adds n*G to the receiver. Equivalent to [point add:[[G copy] multiply:number]]
- (instancetype) addGeneratorMultipliedBy:(BTCBigNumber*)number {
    if (!number) return nil;
    
    if (!EC_POINT_mul(_group, _point, number.BIGNUM, _point, BN_value_one(), _bnctx)) {
        return nil;
    }
    
    return self;
}

- (BOOL) isInfinity {
    return 1 == EC_POINT_is_at_infinity(_group, _point);
}

- (BTCBigNumber*) x {
    BN_CTX_start(_bnctx);
    BIGNUM* bn = BN_CTX_get(_bnctx);
    if (!EC_POINT_get_affine_coordinates_GFp(_group, _point, bn /* x */, NULL  /* y */, _bnctx)) {
        BN_CTX_end(_bnctx);
        return nil;
    }
    BTCBigNumber* result = [[BTCBigNumber alloc] initWithBIGNUM:bn];
    BN_CTX_end(_bnctx);
    return result;
}

- (BTCBigNumber*) y {
    BN_CTX_start(_bnctx);
    BIGNUM* bn = BN_CTX_get(_bnctx);
    if (!EC_POINT_get_affine_coordinates_GFp(_group, _point, NULL /* x */, bn  /* y */, _bnctx)) {
        BN_CTX_end(_bnctx);
        return nil;
    }
    BTCBigNumber* result = [[BTCBigNumber alloc] initWithBIGNUM:bn];
    BN_CTX_end(_bnctx);
    return result;
}

// Clears internal point data.
- (void) clear {
    if (_point) EC_POINT_clear_free(_point);
    _point = NULL;
}



#pragma mark - NSObject & NSCopying


// Re-declared copy to provide exact return type.
- (BTCCurvePoint*) copy {
    return [self copyWithZone:nil];
}

- (id) copyWithZone:(NSZone *)zone {
    return [[BTCCurvePoint alloc] initWithEC_POINT:_point];
}

- (BOOL) isEqual:(BTCCurvePoint*)otherPoint {
    if (![otherPoint isKindOfClass:[self class]]) return NO;
    return 0 == EC_POINT_cmp(_group, _point, otherPoint.EC_POINT, _bnctx);
}

- (NSUInteger) hash {
    return self.data.hash;
}

- (NSString*) description {
    return [NSString stringWithFormat:@"<BTCCurvePoint:0x%p %@>", self, BTCHexFromData(self.data)];
}


@end
