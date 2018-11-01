// Oleg Andreev <oleganza@gmail.com>

#import "BTCTransaction.h"
#import "BTCTransactionInput.h"
#import "BTCTransactionOutput.h"
#import "BTCScript.h"
#import "BTCProtocolSerialization.h"
#import "BTCData.h"
#import "BTCHashID.h"
#import "BTCOutpoint.h"

@interface BTCTransactionInput ()
@end

static const uint32_t BTCInvalidIndex = 0xFFFFFFFF; // aka "(unsigned int) -1" in BitcoinQT.
static const uint32_t BTCMaxSequence = 0xFFFFFFFF;


@implementation BTCTransactionInput

- (id) init {
    if (self = [super init]) {
        _previousHash = BTCZero256();
        _previousIndex = BTCInvalidIndex;
        _signatureScript = [[BTCScript alloc] init];
        _witnessData = NULL;
        _sequence = BTCMaxSequence; // max
        _value = -1;
    }
    return self;
}

// Parses tx input from a data buffer.
- (id) initWithData:(NSData*)data {
    if (self = [self init]) {
        if (![self parseData:data]) return nil;
    }
    return self;
}

// Read tx input from the stream.
- (id) initWithStream:(NSInputStream*)stream {
    if (self = [self init]) {
        if (![self parseStream:stream]) return nil;
    }
    return self;
}

// Constructs transaction input from a dictionary representation
- (id) initWithDictionary:(NSDictionary*)dictionary {
    if (self = [self init]) {
        NSString* prevHashString = (dictionary[@"prev_out"] ?: @{})[@"hash"];
        if (prevHashString) _previousHash = BTCReversedData(BTCDataFromHex(prevHashString));
        NSNumber* prevIndexNumber = (dictionary[@"prev_out"] ?: @{})[@"n"];
        if (prevIndexNumber) _previousIndex = prevIndexNumber.unsignedIntValue;
        
        if (dictionary[@"coinbase"]) {
            _coinbaseData = BTCDataFromHex(dictionary[@"coinbase"]);
        } else {
            // BitcoinQT RPC creates {"asm": ..., "hex": ...} dictionary for this key instead of an ASM-like string like bitcoin-ruby and bitcoinjs.
            id scriptSig = dictionary[@"scriptSig"];
            
            if ([scriptSig isKindOfClass:[NSString class]]) {
                _signatureScript = [[BTCScript alloc] initWithString:scriptSig];
            } else if ([scriptSig isKindOfClass:[NSDictionary class]]) {
                if (scriptSig[@"hex"]) {
                    _signatureScript = [[BTCScript alloc] initWithData:BTCDataFromHex(scriptSig[@"hex"])];
                } else if (scriptSig[@"asm"]) {
                    _signatureScript = [[BTCScript alloc] initWithString:scriptSig[@"asm"]];
                }
            }
        }
        
        if (!_signatureScript) {
            return nil;
        }
        
        NSNumber* seqNumber = dictionary[@"sequence"];
        if (seqNumber) _sequence = [seqNumber unsignedIntValue];
        
    }
    return self;
}

- (id) copyWithZone:(NSZone *)zone {
    BTCTransactionInput* txin = [[BTCTransactionInput alloc] init];
    txin.previousHash = [self.previousHash copy];
    txin.previousIndex = self.previousIndex;
    txin.signatureScript = [self.signatureScript copy];
    txin.sequence = self.sequence;
    txin.value = self.value;

    txin.transaction = _transaction;
    txin.transactionOutput = _transactionOutput;
    txin.userInfo = _userInfo;

    return txin;
}

- (NSData*) data {
    return [self computePayload];
}

- (NSData*) computePayload {
    NSMutableData* payload = [NSMutableData data];
    
    [payload appendData:_previousHash];
    [payload appendBytes:&_previousIndex length:4];

    if (self.isCoinbase) {
        [payload appendData:[BTCProtocolSerialization dataForVarInt:self.coinbaseData.length]];
        [payload appendData:self.coinbaseData];
    } else {
        NSData* scriptData = _signatureScript.data;
        [payload appendData:[BTCProtocolSerialization dataForVarInt:scriptData.length]];
        [payload appendData:scriptData];
    }
    
    [payload appendBytes:&_sequence length:4];
    
    return payload;
}

- (BTCOutpoint*) outpoint {
    return [[BTCOutpoint alloc] initWithHash:self.previousHash index:self.previousIndex];
}

- (void) setOutpoint:(BTCOutpoint *)outpoint {
    self.previousHash = outpoint.txHash;
    self.previousIndex = outpoint.index;
}

- (NSString*) previousTransactionID {
    return BTCIDFromHash(self.previousHash);
}

- (void) setPreviousTransactionID:(NSString *)previousTransactionID {
    self.previousHash = BTCHashFromID(previousTransactionID);
}

// Returns a dictionary representation suitable for encoding in JSON or Plist.
- (NSDictionary*) dictionaryRepresentation {
    return self.dictionary;
}

- (NSDictionary*) dictionary {
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    dict[@"prev_out"] = @{
                        @"hash": BTCHexFromData(BTCReversedData(_previousHash)), // transaction hashes are reversed
                        @"n": @(_previousIndex),
                        };
    
    if ([self isCoinbase]) {
        dict[@"coinbase"] = BTCHexFromData(_coinbaseData);
    } else {
        // Latest BitcoinQT does this: "scriptSig": {"asm": "assembly-style script with spaces and literal ops", "hex": "raw script in hex" }
        // Here and in bitcoin-qt we use only "asm" style script.
        // (But we support reading BitcoinQT style in initWithDictionary:)
        dict[@"scriptSig"] = _signatureScript.string;
    }
    
    if (_sequence != BTCMaxSequence) {
        dict[@"sequence"] = [NSString stringWithFormat:@"%08x", _sequence];
    }
    return dict;
}








#pragma mark - Serialization and parsing



- (BOOL) parseData:(NSData*)data {
    if (!data) return NO;
    NSInputStream* stream = [NSInputStream inputStreamWithData:data];
    [stream open];
    BOOL result = [self parseStream:stream];
    [stream close];
    return result;
}

- (BOOL) parseStream:(NSInputStream*)stream {
    if (!stream) return NO;
    if (stream.streamStatus == NSStreamStatusClosed) return NO;
    if (stream.streamStatus == NSStreamStatusNotOpen) return NO;
    
    // Read previousHash
    uint8_t hash[32] = {0};
    if ([stream read:(uint8_t*)hash maxLength:sizeof(hash)] != sizeof(hash)) return NO;
    _previousHash = [NSData dataWithBytes:hash length:sizeof(hash)];
    
    // Read previousIndex
    if ([stream read:(uint8_t*)(&_previousIndex) maxLength:sizeof(_previousIndex)] != sizeof(_previousIndex)) return NO;
    
    // Read signature script
    NSData* scriptdata = [BTCProtocolSerialization readVarStringFromStream:stream];
    if (!scriptdata) return NO;

    if ([self isCoinbase]) {
        _coinbaseData = scriptdata;
    } else {
        _signatureScript = [[BTCScript alloc] initWithData:scriptdata];
    }
    
    // Read sequence
    if ([stream read:(uint8_t*)(&_sequence) maxLength:sizeof(_sequence)] != sizeof(_sequence)) return NO;
    
    return YES;
}


- (BOOL) isCoinbase {
    return (_previousIndex == BTCInvalidIndex) &&
            _previousHash.length == 32 &&
            0 == memcmp(BTCZeroString256(), _previousHash.bytes, 32);
}



#pragma mark - Informational Properties



- (BTCAmount) value {
    if (_value != -1) {
        return _value;
    }
    if (_transactionOutput) {
        return _transactionOutput.value;
    }
    return -1;
}


@end

