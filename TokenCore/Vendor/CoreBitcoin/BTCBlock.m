// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.

#import "BTCBlock.h"
#import "BTCBlockHeader.h"
#import "BTCHashID.h"

@interface BTCBlock ()
@property(nonatomic, readwrite) BTCBlockHeader* header;
@end

@implementation BTCBlock

- (id) init {
    if (self = [super init]) {
        self.header = [[BTCBlockHeader alloc] init];
    }
    return self;
}

- (id) initWithHeader:(BTCBlockHeader*)header {
    if (self = [super init]) {
        self.header = header;
    }
    return self;
}

- (id) initWithData:(NSData*)data {
    if (self = [super init])
    {
        if (![self parseData:data]) return nil;
    }
    return self;
}

- (id) initWithStream:(NSInputStream*)stream {
    if (self = [super init]) {
        if (![self parseStream:stream]) return nil;
    }
    return self;
}

- (BOOL) parseData:(NSData*)data {

    // TODO

    return YES;
}

- (BOOL) parseStream:(NSStream*)stream {
    // TODO

    return YES;
}

- (NSData*) blockHash {
    return self.header.blockHash;
}

- (NSString*) blockID {
    return self.header.blockID;
}

- (NSData*) data {
    return [self computePayload];
}

- (NSData*) computePayload {
    NSMutableData* data = [NSMutableData data];

    [data appendData:self.header.data];

    // TODO: add transactions.

    return data;
}



#pragma mark - Informational Properties


- (NSInteger) height {
    return self.header.height;
}

- (void) setHeight:(NSInteger)height {
    self.header.height = height;
}

- (NSUInteger) confirmations {
    return self.header.confirmations;
}

- (void) setConfirmations:(NSUInteger)confirmations {
    self.header.confirmations = confirmations;
}

- (NSDictionary*) userInfo {
    return self.header.userInfo;
}

- (void) setUserInfo:(NSDictionary *)userInfo {
    self.header.userInfo = userInfo;
}


#pragma mark - Merkle Tree


// Computes merkle root hash from the current transaction array.
- (NSData*) computeMerkleRootHash {
    // TODO
    return nil;
}

- (void) updateMerkleTree {
    self.header.merkleRootHash = [self computeMerkleRootHash];
}

- (id) copyWithZone:(NSZone *)zone {
    BTCBlock* b = [[BTCBlock alloc] init];
    b.header = [self->_header copy];
    b.transactions = [[NSArray alloc] initWithArray:self.transactions copyItems:YES]; // so each element is copied individually
    return b;
}

@end
