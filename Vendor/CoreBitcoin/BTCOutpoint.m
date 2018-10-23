// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.

#import "BTCOutpoint.h"
#import "BTCTransaction.h"
#import "BTCHashID.h"

@implementation BTCOutpoint

- (id) initWithHash:(NSData*)hash index:(uint32_t)index {
    if (hash.length != 32) return nil;
    if (self = [super init]) {
        _txHash = hash;
        _index = index;
    }
    return self;
}

- (id) initWithTxID:(NSString*)txid index:(uint32_t)index {
    NSData* hash = BTCHashFromID(txid);
    return [self initWithHash:hash index:index];
}

- (NSData*) outpointData {
    NSMutableData* result = [_txHash mutableCopy];
    [result appendBytes:&_index length:4];
    return result;
}

- (NSString*) txID {
    return BTCIDFromHash(self.txHash);
}

- (void) setTxID:(NSString *)txID {
    self.txHash = BTCHashFromID(txID);
}

- (NSUInteger) hash {
    const NSUInteger* words = _txHash.bytes;
    return words[0] + self.index;
}

- (BOOL) isEqual:(BTCOutpoint*)object {
    return [self.txHash isEqual:object.txHash] && self.index == object.index;
}

- (id) copyWithZone:(NSZone *)zone {
    return [[BTCOutpoint alloc] initWithHash:_txHash index:_index];
}

@end
