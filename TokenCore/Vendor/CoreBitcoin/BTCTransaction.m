// Oleg Andreev <oleganza@gmail.com>

#import "BTCTransaction.h"
#import "BTCTransactionInput.h"
#import "BTCOutpoint.h"
#import "BTCTransactionOutput.h"
#import "BTCProtocolSerialization.h"
#import "BTCData.h"
#import "BTCScript.h"
#import "BTCErrors.h"
#import "BTCHashID.h"

NSData* BTCTransactionHashFromID(NSString* txid) {
    return BTCHashFromID(txid);
}

NSString* BTCTransactionIDFromHash(NSData* txhash) {
    return BTCIDFromHash(txhash);
}

@interface BTCTransaction ()
@end

@implementation BTCTransaction

- (id) init {
    if (self = [super init]) {
        // init default values
        _version = BTCTransactionCurrentVersion;
        _marker = BTCTransactionCurrentMarker;
        _flag = BTCTransactionCurrentFlag;
        _lockTime = 0;
        _inputs = @[];
        _outputs = @[];
        _blockHeight = 0;
        _blockDate = nil;
        _confirmations = NSNotFound;
        _fee = -1;
        _inputsAmount = -1;
    }
    return self;
}

// Parses tx from data buffer.
- (id) initWithData:(NSData*)data {
    if (self = [self init]) {
        if (![self parseData:data]) return nil;
    }
    return self;
}

// Parses tx from hex string.
- (id) initWithHex:(NSString*)hex {
    return [self initWithData:BTCDataFromHex(hex)];
}

// Parses input stream (useful when parsing many transactions from a single source, e.g. a block).
- (id) initWithStream:(NSInputStream*)stream {
    if (self = [self init]) {
        if (![self parseStream:stream]) return nil;
    }
    return self;
}

// Constructs transaction from dictionary representation
- (id) initWithDictionary:(NSDictionary*)dictionary {
    if (self = [self init]) {
        _version = (uint32_t)[dictionary[@"ver"] unsignedIntegerValue];
        _lockTime = (uint32_t)[dictionary[@"lock_time"] unsignedIntegerValue];
        
        NSMutableArray* ins = [NSMutableArray array];
        for (id dict in dictionary[@"in"]) {
            BTCTransactionInput* txin = [[BTCTransactionInput alloc] initWithDictionary:dict];
            if (!txin) return nil;
            [ins addObject:txin];
        }
        _inputs = ins;
        
        NSMutableArray* outs = [NSMutableArray array];
        for (id dict in dictionary[@"out"]) {
            BTCTransactionOutput* txout = [[BTCTransactionOutput alloc] initWithDictionary:dict];
            if (!txout) return nil;
            [outs addObject:txout];
        }
        _outputs = outs;
    }
    return self;
}

// Returns a dictionary representation suitable for encoding in JSON or Plist.
- (NSDictionary*) dictionaryRepresentation {
    return self.dictionary;
}

- (NSDictionary*) dictionary {
    return @{
      @"hash":      self.transactionID,
      @"ver":       @(_version),
      @"vin_sz":    @(_inputs.count),
      @"vout_sz":   @(_outputs.count),
      @"lock_time": @(_lockTime),
      @"size":      @(self.data.length),
      @"in":        [_inputs valueForKey:@"dictionary"],
      @"out":       [_outputs valueForKey:@"dictionary"],
    };
}


#pragma mark - NSObject



- (BOOL) isEqual:(BTCTransaction*)object {
    if (![object isKindOfClass:[BTCTransaction class]]) return NO;
    return [object.transactionHash isEqual:self.transactionHash];
}

- (NSUInteger) hash {
    if (self.transactionHash.length >= sizeof(NSUInteger)) {
        // Interpret first bytes as a hash value
        return *((NSUInteger*)self.transactionHash.bytes);
    } else {
        return 0;
    }
}

- (id) copyWithZone:(NSZone *)zone {
    BTCTransaction* tx = [[BTCTransaction alloc] init];
    tx->_inputs = [[NSArray alloc] initWithArray:self.inputs copyItems:YES]; // so each element is copied individually
    tx->_outputs = [[NSArray alloc] initWithArray:self.outputs copyItems:YES]; // so each element is copied individually
    for (BTCTransactionInput* txin in tx.inputs) {
        txin.transaction = self;
    }
    for (BTCTransactionOutput* txout in tx.outputs) {
        txout.transaction = self;
    }
    tx.version = self.version;
    tx.lockTime = self.lockTime;

    // Copy informational properties as is.
    tx.blockHash     = [_blockHash copy];
    tx.blockHeight   = _blockHeight;
    tx.blockDate     = _blockDate;
    tx.confirmations = _confirmations;
    tx.userInfo      = _userInfo;

    return tx;
}



#pragma mark - Properties


- (NSData*) transactionHash {
    return BTCHash256(self.data);
}

- (NSData*) witnessTransactionHash {
    return BTCHash256(self.dataWithWitness);
}

- (NSString*) transactionID {
    return BTCIDFromHash(self.transactionHash);
}

- (NSString*) witnessTransactionID {
    return BTCIDFromHash(self.witnessTransactionHash);
}

- (NSString*) blockID {
    return BTCIDFromHash(self.blockHash);
}

- (void) setBlockID:(NSString *)blockID {
    self.blockHash = BTCHashFromID(blockID);
}

- (NSData*) data {
    return [self computePayloadWithWitness:NO];
}

- (NSString*) hex {
    return BTCHexFromData(self.data);
}

- (NSData*) dataWithWitness {
    return [self computeWitnessPayload];
}

- (NSString*) hexWithWitness {
    return BTCHexFromData(self.dataWithWitness);
}

- (NSData*) computeWitnessPayload {
    return [self computePayloadWithWitness:[self isSegWit]];
}

- (NSData*) computePayloadWithWitness:(BOOL) withWitness {
    NSMutableData* payload = [NSMutableData data];
    
    // 4-byte version
    uint32_t ver = _version;
    [payload appendBytes:&ver length:4];
    
    // Adding special segwit fields to serialized transaction
    if (withWitness) {
        // 1-byte marker
        uint32_t marker = _marker;
        [payload appendBytes:&marker length:1];
        
        // 1-byte flag
        uint32_t flag = _flag;
        [payload appendBytes:&flag length:1];
    }
    
    // varint with number of inputs
    [payload appendData:[BTCProtocolSerialization dataForVarInt:_inputs.count]];
    
    // input payloads
    for (BTCTransactionInput* input in _inputs) {
        [payload appendData:input.data];
    }
    
    // varint with number of outputs
    [payload appendData:[BTCProtocolSerialization dataForVarInt:_outputs.count]];
    
    // output payloads
    for (BTCTransactionOutput* output in _outputs) {
        [payload appendData:output.data];
    }
    
    // Adding witness data to serialized transaction
    if (withWitness) {
        for (BTCTransactionInput* input in _inputs) {
            if (input.witnessData) {
                [payload appendData:[BTCProtocolSerialization dataForVarInt:input.witnessData.scriptChunks.count]];
                
                for (BTCScriptChunk* chunk in input.witnessData.scriptChunks) {
                    NSData* data;
                    
                    if (chunk.isOpcode) {
                        unsigned char opcode = chunk.opcode;
                        [payload appendBytes:&opcode length:1];
                    } else {
                        data = chunk.pushdata;
                    }
                    
                    if (data) {
                        [payload appendData:[BTCProtocolSerialization dataForVarInt:[data length]]];
                        [payload appendData:data];
                    }
                }
            } else {
                uint32_t emptyWitnessDataBytes = 0;
                [payload appendBytes:&emptyWitnessDataBytes length:1];
            }
        }
    }
    
    // 4-byte lock_time
    uint32_t lt = _lockTime;
    [payload appendBytes:&lt length:4];
    
    return payload;
}

- (BOOL) isSegWit {
    for (BTCTransactionInput* input in _inputs) {
        if (input.witnessData) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Methods


// Adds input script
- (void) addInput:(BTCTransactionInput*)input {
    if (!input) return;
    [self linkInput:input];
    _inputs = [_inputs arrayByAddingObject:input];
}

- (void) linkInput:(BTCTransactionInput*)input {
    if (!(input.transaction == nil || input.transaction == self)) {
        @throw [NSException exceptionWithName:@"BTCTransaction consistency error!" reason:@"Can't add an input to a transaction when it references another transaction." userInfo:nil];
        return;
    }
    input.transaction = self;
}

// Adds output script
- (void) addOutput:(BTCTransactionOutput*)output {
    if (!output) return;
    [self linkOutput:output];
    _outputs = [_outputs arrayByAddingObject:output];
}

- (void) linkOutput:(BTCTransactionOutput*)output {
    if (!(output.transaction == nil || output.transaction == self)) {
        @throw [NSException exceptionWithName:@"BTCTransaction consistency error!" reason:@"Can't add an output to a transaction when it references another transaction." userInfo:nil];
        return;
    }
    output.index = BTCTransactionOutputIndexUnknown; // reset to be recomputed lazily later
    output.transactionHash = nil; // can't be reliably set here because transaction may get updated.
    output.transaction = self;
}

- (void) setInputs:(NSArray *)inputs {
    [self removeAllInputs];
    for (BTCTransactionInput* txin in inputs) {
        [self addInput:txin];
    }
}

- (void) setOutputs:(NSArray *)outputs {
    [self removeAllOutputs];
    for (BTCTransactionOutput* txout in outputs) {
        [self addOutput:txout];
    }
}

- (void) removeAllInputs {
    for (BTCTransactionInput* txin in _inputs) {
        txin.transaction = nil;
    }
    _inputs = @[];
}

- (void) removeAllOutputs {
    for (BTCTransactionOutput* txout in _outputs) {
        txout.transaction = nil;
    }
    _outputs = @[];
}

- (BOOL) isCoinbase {
    // Coinbase transaction has one input and it must be coinbase.
    return (_inputs.count == 1 && [(BTCTransactionInput*)_inputs[0] isCoinbase]);
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
    
    if ([stream read:(uint8_t*)&_version maxLength:sizeof(_version)] != sizeof(_version)) return NO;
    
    {
        uint64_t inputsCount = 0;
        if ([BTCProtocolSerialization readVarInt:&inputsCount fromStream:stream] == 0) return NO;
        
        NSMutableArray* ins = [NSMutableArray array];
        for (uint64_t i = 0; i < inputsCount; i++)
        {
            BTCTransactionInput* input = [[BTCTransactionInput alloc] initWithStream:stream];
            if (!input) return NO;
            [self linkInput:input];
            [ins addObject:input];
        }
        _inputs = ins;
    }

    {
        uint64_t outputsCount = 0;
        if ([BTCProtocolSerialization readVarInt:&outputsCount fromStream:stream] == 0) return NO;
            
        NSMutableArray* outs = [NSMutableArray array];
        for (uint64_t i = 0; i < outputsCount; i++)
        {
            BTCTransactionOutput* output = [[BTCTransactionOutput alloc] initWithStream:stream];
            if (!output) return NO;
            [self linkOutput:output];
            [outs addObject:output];
        }
        _outputs = outs;
    }
    
    if ([stream read:(uint8_t*)&_lockTime maxLength:sizeof(_lockTime)] != sizeof(_lockTime)) return NO;
    
    return YES;
}


#pragma mark - Signing a transaction



// Hash for signing a transaction.
// You should supply the output script of the previous transaction, desired hash type and input index in this transaction.
- (NSData*) signatureHashForScript:(BTCScript*)subscript forSegWit:(BOOL) isSegWit inputIndex:(uint32_t)inputIndex hashType:(BTCSignatureHashType)hashType error:(NSError**)errorOut {
    // Create a temporary copy of the transaction to apply modifications to it.
    BTCTransaction* tx = [self copy];
    
    // We may have a scriptmachine instantiated without a transaction (for testing),
    // but it should not use signature checks then.
    if (!tx || inputIndex == 0xFFFFFFFF) {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain
                                                      code:BTCErrorScriptError
                                                  userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Transaction and valid input index must be provided for signature verification.", @"")}];
        return nil;
    }
    
    // Note: BitcoinQT returns a 256-bit little-endian number 1 in such case, but it does not matter
    // because it would crash before that in CScriptCheck::operator()(). We normally won't enter this condition
    // if script machine is instantiated with initWithTransaction:inputIndex:, but if it was just -init-ed, it's better to check.
    if (inputIndex >= tx.inputs.count) {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCErrorDomain
                                                      code:BTCErrorScriptError
                                                  userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:
                                                     NSLocalizedString(@"Input index is out of bounds for transaction: %d >= %d.", @""),
                                                                                        (int)inputIndex, (int)tx.inputs.count]}];
        return nil;
    }
    
    // In case concatenating two scripts ends up with two codeseparators,
    // or an extra one at the end, this prevents all those possible incompatibilities.
    // Note: this normally never happens because there is no use for OP_CODESEPARATOR.
    // But we have to do that cleanup anyway to not break on rare transaction that use that for lulz.
    // Also: we modify the same subscript which is used several times for multisig check, but that's what BitcoinQT does as well.
    [subscript deleteOccurrencesOfOpcode:OP_CODESEPARATOR];
    
    // Blank out other inputs' signature scripts
    // and replace our input script with a subscript (which is typically a full output script from the previous transaction).
    for (BTCTransactionInput* txin in tx.inputs) {
        txin.signatureScript = [[BTCScript alloc] init];
    }
    ((BTCTransactionInput*)tx.inputs[inputIndex]).signatureScript = subscript;
    
    // Blank out some of the outputs depending on BTCSignatureHashType
    // Default is SIGHASH_ALL - all inputs and outputs are signed.
    if ((hashType & SIGHASH_OUTPUT_MASK) == SIGHASH_NONE) {
        // Wildcard payee - we can pay anywhere.
        [tx removeAllOutputs];
        
        // Blank out others' input sequence numbers to let others update transaction at will.
        for (NSUInteger i = 0; i < tx.inputs.count; i++) {
            if (i != inputIndex) {
                ((BTCTransactionInput*)tx.inputs[i]).sequence = 0;
            }
        }
    } else if ((hashType & SIGHASH_OUTPUT_MASK) == SIGHASH_SINGLE) {
        // Single mode assumes we sign an output at the same index as an input.
        // Outputs before the one we need are blanked out. All outputs after are simply removed.
        // Only lock-in the txout payee at same index as txin.
        uint32_t outputIndex = inputIndex;
        
        // If outputIndex is out of bounds, BitcoinQT is returning a 256-bit little-endian 0x01 instead of failing with error.
        // We should do the same to stay compatible.
        if (outputIndex >= tx.outputs.count) {
            static unsigned char littleEndianOne[32] = {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
            return [NSData dataWithBytes:littleEndianOne length:32];
        }
        
        // All outputs before the one we need are blanked out. All outputs after are simply removed.
        // This is equivalent to replacing outputs with (i-1) empty outputs and a i-th original one.
        BTCTransactionOutput* myOutput = tx.outputs[outputIndex];
        [tx removeAllOutputs];
        for (int i = 0; i < outputIndex; i++) {
            [tx addOutput:[[BTCTransactionOutput alloc] init]];
        }
        [tx addOutput:myOutput];
        
        // Blank out others' input sequence numbers to let others update transaction at will.
        for (NSUInteger i = 0; i < tx.inputs.count; i++) {
            if (i != inputIndex) {
                ((BTCTransactionInput*)tx.inputs[i]).sequence = 0;
            }
        }
    }
    
    // Blank out other inputs completely. This is not recommended for open transactions.
    if (hashType & SIGHASH_ANYONECANPAY) {
        BTCTransactionInput* input = tx.inputs[inputIndex];
        [tx removeAllInputs];
        [tx addInput:input];
    }
    
    // Important: we have to hash transaction together with its hash type.
    // Hash type is appended as little endian uint32 unlike 1-byte suffix of the signature.
    NSMutableData* fulldata;
    
    if (isSegWit) {
        fulldata = [[tx computeSignatureHashForWitnessWithHashType:hashType inputIndex:inputIndex] mutableCopy];
    } else {
        fulldata = [tx.data mutableCopy];
    }
    
    uint32_t hashType32 = OSSwapHostToLittleInt32((uint32_t)hashType);
    [fulldata appendBytes:&hashType32 length:sizeof(hashType32)];
    
    NSData* hash = BTCHash256(fulldata);
    
//    NSLog(@"\n----------------------\n");
//    NSLog(@"TX: %@", BTCHexFromData(fulldata));
//    NSLog(@"TX SUBSCRIPT: %@ (%@)", BTCHexFromData(subscript.data), subscript);
//    NSLog(@"TX HASH: %@", BTCHexFromData(hash));
//    NSLog(@"TX PLIST: %@", tx.dictionary);
    
    return hash;
}

- (NSData*) computeSignatureHashForWitnessWithHashType:(BTCSignatureHashType)hashType inputIndex:(NSUInteger) index {
    
    NSMutableData* payload = [NSMutableData data];
    
    BOOL anyoneCanPay = hashType & SIGHASH_ANYONECANPAY;
    BOOL sighashSingle = (hashType & SIGHASH_OUTPUT_MASK) == SIGHASH_SINGLE;
    BOOL sighashNone = (hashType & SIGHASH_OUTPUT_MASK) == SIGHASH_NONE;
    
    // 4-byte version (nVersion)
    uint32_t ver = _version;
    [payload appendBytes:&ver length:4];
    
    // hashPrevouts
    if (anyoneCanPay) {
        [payload appendData:BTCZero256()];
    } else {
        // Double SHA256 of the serialization of all input outpoints
        NSMutableData* prevouts = [[NSMutableData alloc] init];
        for (BTCTransactionInput* input in _inputs) {
            [prevouts appendData:input.outpoint.outpointData];
        }
        [payload appendData:BTCHash256(prevouts)];
    }
    
    // hashSequence
    if (!anyoneCanPay && !sighashSingle && !sighashNone) {
        // Double SHA256 of the serialization of all input nSequence
        NSMutableData* sequence = [[NSMutableData alloc] init];
        for (BTCTransactionInput* input in _inputs) {
            uint32_t seq = input.sequence;
            [sequence appendBytes:&seq length:sizeof(seq)];
        }
        [payload appendData:BTCHash256(sequence)];
    } else {
        [payload appendData:BTCZero256()];
    }
    
    BTCTransactionInput* input = _inputs[index];
    // outpoint
    [payload appendData:input.outpoint.outpointData];
    
    // scriptCode
    NSData* scriptData = input.signatureScript.data;
    /// Comment out for imToken: witness data should NOT include scriptCode length!
    // [payload appendData:[BTCProtocolSerialization dataForVarInt:scriptData.length]];
    [payload appendData:scriptData];
    
    // amount
    BTCAmount amount = input.value;
    [payload appendBytes:&amount length:sizeof(amount)];
    
    // nSequence
    uint32_t sequence = input.sequence;
    [payload appendBytes:&sequence length:sizeof(sequence)];
    
    // hashOutputs
    if (!sighashSingle && !sighashNone) {
        NSMutableData* outputs = [[NSMutableData alloc] init];
        for (BTCTransactionOutput* output in _outputs) {
            [outputs appendData:output.data];
        }
        [payload appendData:BTCHash256(outputs)];
    } else if (sighashSingle && index < _outputs.count) {
        BTCTransactionOutput* output = _outputs[index];
        [payload appendData:BTCHash256(output.data)];
    } else {
        [payload appendData:BTCZero256()];
    }
    
    // nLockTime
    uint32_t lt = _lockTime;
    [payload appendBytes:&lt length:4];
    
    return payload;
}






#pragma mark - Amounts and fee



@synthesize fee=_fee;
@synthesize inputsAmount=_inputsAmount;

- (void) setFee:(BTCAmount)fee {
    _fee = fee;
    _inputsAmount = -1; // will be computed from fee or inputs.map(&:value)
}

- (BTCAmount) fee {
    if (_fee != -1) {
        return _fee;
    }

    BTCAmount ia = self.inputsAmount;
    if (ia != -1) {
        return ia - self.outputsAmount;
    }

    return -1;
}

- (void) setInputsAmount:(BTCAmount)inputsAmount {
    _inputsAmount = inputsAmount;
    _fee = -1; // will be computed from inputs and outputs amount on the fly.
}

- (BTCAmount) inputsAmount {
    if (_inputsAmount != -1) {
        return _inputsAmount;
    }

    if (_fee != -1) {
        return _fee + self.outputsAmount;
    }

    // Try to figure the total amount from amounts on inputs.
    // If all of them are non-nil, we have a valid amount.

    BTCAmount total = 0;
    for (BTCTransactionInput* txin in self.inputs) {
        BTCAmount v = txin.value;
        if (v == -1) {
            return -1;
        }
        total += v;
    }
    return total;
}

- (BTCAmount) outputsAmount {
    BTCAmount a = 0;
    for (BTCTransactionOutput* txout in self.outputs) {
        a += txout.value;
    }
    return a;
}






#pragma mark - Fees



// Computes estimated fee for this tx size using default fee rate.
// @see BTCTransactionDefaultFeeRate.
- (BTCAmount) estimatedFee {
    return [self estimatedFeeWithRate:BTCTransactionDefaultFeeRate];
}

// Computes estimated fee for this tx size using specified fee rate (satoshis per 1000 bytes).
- (BTCAmount) estimatedFeeWithRate:(BTCAmount)feePerK {
    return [BTCTransaction estimateFeeForSize:self.data.length feeRate:feePerK];
}

// Computes estimated fee for the given tx size using specified fee rate (satoshis per 1000 bytes).
+ (BTCAmount) estimateFeeForSize:(NSInteger)txsize feeRate:(BTCAmount)feePerK {
    if (feePerK <= 0) return 0;
    BTCAmount fee = 0;
    while (txsize > 0) { // add fee rate for each (even incomplete) 1K byte chunk
        txsize -= 1000;
        fee += feePerK;
    }
    return fee;
}




// TO BE REVIEWED:



// Minimum base fee to send a transaction.
+ (BTCAmount) minimumFee {
    NSNumber* n = [[NSUserDefaults standardUserDefaults] objectForKey:@"BTCTransactionMinimumFee"];
    if (!n) return 10000;
    return (BTCAmount)[n longLongValue];
}

+ (void) setMinimumFee:(BTCAmount)fee {
    fee = MIN(fee, BTC_MAX_MONEY);
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithLongLong:fee] forKey:@"BTCTransactionMinimumFee"];
}

// Minimum base fee to relay a transaction.
+ (BTCAmount) minimumRelayFee {
    NSNumber* n = [[NSUserDefaults standardUserDefaults] objectForKey:@"BTCTransactionMinimumRelayFee"];
    if (!n) return 10000;
    return (BTCAmount)[n longLongValue];
}

+ (void) setMinimumRelayFee:(BTCAmount)fee {
    fee = MIN(fee, BTC_MAX_MONEY);
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithLongLong:fee] forKey:@"BTCTransactionMinimumRelayFee"];
}


// Minimum fee to relay the transaction
- (BTCAmount) minimumRelayFee {
    return [self minimumFeeForSending:NO];
}

// Minimum fee to send the transaction
- (BTCAmount) minimumSendFee {
    return [self minimumFeeForSending:YES];
}

- (BTCAmount) minimumFeeForSending:(BOOL)sending {
    // See also CTransaction::GetMinFee in BitcoinQT and calculate_minimum_fee in bitcoin-ruby
    
    // BitcoinQT calculates min fee based on current block size, but it's unused and constant value is used today instead.
    NSUInteger baseBlockSize = 1000;
    // BitcoinQT has some complex formulas to determine when we shouldn't allow free txs. To be done later.
    BOOL allowFree = YES;
    
    BTCAmount baseFee = sending ? [BTCTransaction minimumFee] : [BTCTransaction minimumRelayFee];
    NSUInteger txSize = self.data.length;
    NSUInteger newBlockSize = baseBlockSize + txSize;
    BTCAmount minFee = (1 + txSize / 1000) * baseFee;
    
    if (allowFree) {
        if (newBlockSize == 1) {
            // Transactions under 10K are free
            // (about 4500 BTC if made of 50 BTC inputs)
            if (txSize < 10000)
                minFee = 0;
        } else {
            // Free transaction area
            if (newBlockSize < 27000)
                minFee = 0;
        }
    }
    
    // To limit dust spam, require base fee if any output is less than 0.01
    if (minFee < baseFee) {
        for (BTCTransactionOutput* txout in _outputs) {
            if (txout.value < BTCCent) {
                minFee = baseFee;
                break;
            }
        }
    }
    
    // Raise the price as the block approaches full
    if (baseBlockSize != 1 && newBlockSize >= BTC_MAX_BLOCK_SIZE_GEN/2) {
        if (newBlockSize >= BTC_MAX_BLOCK_SIZE_GEN)
            return BTC_MAX_MONEY;
        minFee *= BTC_MAX_BLOCK_SIZE_GEN / (BTC_MAX_BLOCK_SIZE_GEN - newBlockSize);
    }
    
    if (minFee < 0 || minFee > BTC_MAX_MONEY) minFee = BTC_MAX_MONEY;
    
    return minFee;
}



@end
