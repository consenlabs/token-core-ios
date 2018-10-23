// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.

#import "BTCMerkleTree.h"
#import "BTCData.h"

@interface BTCMerkleTree ()
@property(nonatomic, readwrite) NSData* merkleRoot;
@property(nonatomic, readwrite) BOOL hasTailDuplicates;
@property(nonatomic) NSArray* hashes;
@end

@implementation BTCMerkleTree

- (id) initWithHashes:(NSArray*)hashes {
    if (hashes.count == 0) return nil;
    if (self = [super init]) {
        self.hashes = hashes;
    }
    return self;
}

- (id) initWithTransactions:(NSArray*)transactions {
    if (transactions.count == 0) return nil;
    return [self initWithHashes:[transactions valueForKey:@"transactionHash"]];
}

- (id) initWithDataItems:(NSArray* /* [NSData] */)dataItems {
    if (dataItems.count == 0) return nil;
    NSMutableArray* hashes = [NSMutableArray arrayWithCapacity:dataItems.count];
    for (NSData* data in dataItems) {
        [hashes addObject:BTCHash256(data)];
    }
    return [self initWithHashes:hashes];
}

- (NSData*) merkleRoot {
    if (!_merkleRoot) {
        _merkleRoot = [self computeMerkleRoot];
    }
    return _merkleRoot;
}

- (BOOL) hasTailDuplicates {
    if (!_merkleRoot) {
        _merkleRoot = [self computeMerkleRoot];
    }
    return _hasTailDuplicates;
}

- (NSData*) computeMerkleRoot {
    // Based on original Satoshi implementation + vulnerability detection API:
    /* WARNING! If you're reading this because you're learning about crypto
       and/or designing a new system that will use merkle trees, keep in mind
       that the following merkle tree algorithm has a serious flaw related to
       duplicate txids, resulting in a vulnerability (CVE-2012-2459).

       The reason is that if the number of hashes in the list at a given time
       is odd, the last one is duplicated before computing the next level (which
       is unusual in Merkle trees). This results in certain sequences of
       transactions leading to the same merkle root. For example, these two
       trees:

                    A               A
                  /  \            /   \
                B     C         B       C
               / \    |        / \     / \
              D   E   F       D   E   F   F
             / \ / \ / \     / \ / \ / \ / \
             1 2 3 4 5 6     1 2 3 4 5 6 5 6

       for transaction lists [1,2,3,4,5,6] and [1,2,3,4,5,6,5,6] (where 5 and
       6 are repeated) result in the same root hash A (because the hash of both
       of (F) and (F,F) is C).

       The vulnerability results from being able to send a block with such a
       transaction list, with the same merkle root, and the same block hash as
       the original without duplication, resulting in failed validation. If the
       receiving node proceeds to mark that block as permanently invalid
       however, it will fail to accept further unmodified (and thus potentially
       valid) versions of the same block. We defend against this by detecting
       the case where we would hash two identical hashes at the end of the list
       together, and treating that identically to the block having an invalid
       merkle root. Assuming no double-SHA256 collisions, this will detect all
       known ways of changing the transactions without affecting the merkle
       root.
    */
    NSMutableArray* tree = [self.hashes mutableCopy];
    _hasTailDuplicates = NO;
    NSInteger j = 0;
    for (NSInteger size = (NSInteger)tree.count; size > 1; size = (size + 1) / 2) {
        for (NSInteger i = 0; i < size; i += 2) {
            NSInteger i2 = MIN(i + 1, size - 1);
            if (i2 == i + 1 && i2 + 1 == size && [tree[j+i] isEqual:tree[j+i2]]) {
                // Two identical hashes at the end of the list at a particular level.
                _hasTailDuplicates = YES;
            }
            NSData* hash = BTCHash256Concat(tree[j+i], tree[j+i2]);
            [tree addObject:hash];
        }
        j += size;
    }
    return tree.lastObject;
}

@end
