// Oleg Andreev <oleganza@gmail.com>

#import "BTCScript.h"
#import "BTCAddress.h"
#import "BTCBigNumber.h"
#import "BTCErrors.h"
#import "BTCData.h"
#import "BTCKey.h"


@interface BTCScriptChunk ()

// A range of scriptData represented by this chunk.
@property(nonatomic) NSRange range;

// Reference to the whole script binary data.
@property(nonatomic) NSData* scriptData;

// Portion of scriptData defined by range.
@property(nonatomic, readonly) NSData* chunkData;

// String representation of a chunk.
// OP_1NEGATE, OP_0, OP_1..OP_16 are represented as a decimal number.
// Most compactly represented pushdata chunks >= 128 bit is encoded as <hex string>
// Smaller most compactly represented data is encoded as [<hex string>]
// Non-compact pushdata (e.g. 75-byte string with PUSHDATA1) contain a decimal prefix denoting a length size before hex data in square brackets. Ex. "1:[...]", "2:[...]" or "4:[...]"
// For both compat and non-compact pushdata chunks, if the data consists of all printable ASCII characters (0x20..0x7E), it is enclosed not in square brackets, but in single quotes as characters themselves. Non-compact string is prefixed with 1:, 2: or 4: like described above.
- (NSString*) string;

// Returns a chunk if parsed correctly or nil if it is invalid.
+ (BTCScriptChunk*) parseChunkFromData:(NSData*)data offset:(NSUInteger)offset;

// Returns encoded data with proper length prefix for a given raw pushdata.
// If preferredLengthEncoding is -1, the most compact encoding is used. Other valid values: 0, 1, 2, 4.
+ (NSData*) scriptDataForPushdata:(NSData*)data preferredLengthEncoding:(int)preferredLengthEncoding;

@end


@interface BTCScript ()
@end

@implementation BTCScript {
    // An array of NSData objects (pushing data) or NSNumber objects (containing opcodes)
    NSMutableArray* _chunks;
    
    // Cached serialized representations for -data and -string methods.
    NSData* _data;
    
    NSString* _string;
    
    // Multisignature script attributes.
    // If multisig script is not detected, both are NULL.
    NSUInteger _multisigSignaturesRequired;
    NSArray* _multisigPublicKeys;
}

- (id) init {
    if (self = [super init]) {
        _chunks = [NSMutableArray array];
    }
    return self;
}

- (id) initWithData:(NSData*)data {
    if (self = [super init]) {
        // It's important to keep around original data to correctly identify the size of the script for BTC_MAX_SCRIPT_SIZE check
        // and to correctly calculate hash for the signature because in BitcoinQT scripts are not re-serialized/canonicalized.
        _data = data ?: [NSData data];
        _chunks = [self parseData:_data];
        if (!_chunks) return nil;
    }
    return self;
}

- (id) initWithHex:(NSString*)hex {
    return [self initWithData:BTCDataFromHex(hex)];
}

- (id) initWithString:(NSString*)string {
    if (self = [super init]) {
        _chunks = [self parseString:string ?: @""];
        if (!_chunks) return nil;
    }
    return self;
}

- (id) initWithAddress:(BTCAddress*)address {
    // Make sure we use a public address (WIF privkey is converted to usual P2PKH address).
    address = [address publicAddress];

    if ([address isKindOfClass:[BTCPublicKeyAddress class]]) {
        // OP_DUP OP_HASH160 <hash> OP_EQUALVERIFY OP_CHECKSIG
        NSMutableData* resultData = [NSMutableData data];
        
        BTCOpcode prefix[] = {OP_DUP, OP_HASH160};
        [resultData appendBytes:prefix length:sizeof(prefix)];
        
        unsigned char length = address.data.length;
        [resultData appendBytes:&length length:sizeof(length)];
        
        [resultData appendData:address.data];
        
        BTCOpcode suffix[] = {OP_EQUALVERIFY, OP_CHECKSIG};
        [resultData appendBytes:suffix length:sizeof(suffix)];
        
        return [self initWithData:resultData];
    } else if ([address isKindOfClass:[BTCScriptHashAddress class]]) {
        // OP_HASH160 <hash> OP_EQUAL
        NSMutableData* resultData = [NSMutableData data];
        
        BTCOpcode prefix[] = {OP_HASH160};
        [resultData appendBytes:prefix length:sizeof(prefix)];
        
        unsigned char length = address.data.length;
        [resultData appendBytes:&length length:sizeof(length)];
        
        [resultData appendData:address.data];
        
        BTCOpcode suffix[] = {OP_EQUAL};
        [resultData appendBytes:suffix length:sizeof(suffix)];
        
        return [self initWithData:resultData];
    } else {
        return nil;
    }
}

// OP_<M> <pubkey1> ... <pubkeyN> OP_<N> OP_CHECKMULTISIG
- (id) initWithPublicKeys:(NSArray*)publicKeys signaturesRequired:(NSUInteger)signaturesRequired {
    // First make sure the arguments make sense.
    
    // We need at least one signature
    if (signaturesRequired == 0) return nil;
    
    // And we cannot have more signatures than available pubkeys.
    if (signaturesRequired > publicKeys.count) return nil;
    
    // Both M and N should map to OP_<1..16>
    BTCOpcode m_opcode = BTCOpcodeForSmallInteger(signaturesRequired);
    BTCOpcode n_opcode = BTCOpcodeForSmallInteger(publicKeys.count);
    if (m_opcode == OP_INVALIDOPCODE) return nil;
    if (n_opcode == OP_INVALIDOPCODE) return nil;
    
    // Every pubkey should be present.
    for (NSData* pkdata in publicKeys) {
        if (![pkdata isKindOfClass:[NSData class]] || pkdata.length == 0) return nil;
    }
    
    NSMutableData* data = [NSMutableData data];
    
    [data appendBytes:&m_opcode length:sizeof(m_opcode)];
    
    for (NSData* pubkey in publicKeys) {
        NSData* d = [BTCScriptChunk scriptDataForPushdata:pubkey preferredLengthEncoding:-1];
        
        if (d.length == 0) return nil; // invalid data
        
        [data appendData:d];
    }
    
    [data appendBytes:&n_opcode length:sizeof(n_opcode)];
    
    BTCOpcode checkmultisig_opcode = OP_CHECKMULTISIG;
    [data appendBytes:&checkmultisig_opcode length:sizeof(checkmultisig_opcode)];
    
    if (self = [self initWithData:data]) {
        _multisigSignaturesRequired = signaturesRequired;
        _multisigPublicKeys = publicKeys;
    }
    return self;
}

- (NSData*) data {
    if (!_data) {
        // When we calculate data from scratch, it's important to respect actual offsets in the chunks as they may have been copied or shifted in subScript* methods.
        NSMutableData* md = [NSMutableData data];
        for (BTCScriptChunk* chunk in _chunks) {
            [md appendData:chunk.chunkData];
        }
        _data = md;
    }
    return _data;
}

- (NSString*) hex {
    return BTCHexFromData(self.data);
}

- (NSString*) string {
    if (!_string) {
        NSMutableArray* buffer = [NSMutableArray array];
        
        for (BTCScriptChunk* chunk in _chunks) {
            [buffer addObject:[chunk string]];
        }
        
        _string = [buffer componentsJoinedByString:@" "];
    }
    return _string;
}

- (NSMutableArray*) parseData:(NSData*)data {
    if (data.length == 0) return [NSMutableArray array];
    
    NSMutableArray* chunks = [NSMutableArray array];
    
    int i = 0;
    int length = (int)data.length;
    
    while (i < length) {
        BTCScriptChunk* chunk = [BTCScriptChunk parseChunkFromData:data offset:i];
        
        // Exit if failed to parse
        if (!chunk) return nil;
        
        [chunks addObject:chunk];
        
        i += chunk.range.length;
    }
    return chunks;
}

- (NSMutableArray*) parseString:(NSString*)string {
    if (string.length == 0) return [NSMutableArray array];
    
    // Accumulated data to which chunks are referring to.
    NSMutableData* scriptData = [NSMutableData data];
    
    NSScanner* scanner = [NSScanner scannerWithString:string];
    NSCharacterSet* whitespaceSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    while (![scanner isAtEnd]) {
        [scanner scanCharactersFromSet:whitespaceSet intoString:NULL];
        
        if ([scanner isAtEnd]) break;
        
        // First detect 1:, 2: and 4: prefixes before pushdata (quoted, hex or in square brackets)
        // encoding = 0 - most compact encoding for the given data
        // encoding = 1 - 1-byte length prefix
        // encoding = 2 - 2-byte length prefix
        // encoding = 4 - 4-byte length prefix
        int lengthEncoding = -1; // -1 means "use the most compact one".
        BOOL mustBePushdata = NO;
        
        if ([scanner scanString:@"0:" intoString:NULL]) { // just for extra consistency, detect 0: as well (although, it's pointless to use it for real)
            lengthEncoding = 0;
            mustBePushdata = YES;
        } else if ([scanner scanString:@"1:" intoString:NULL]) {
            lengthEncoding = 1;
            mustBePushdata = YES;
        } else if ([scanner scanString:@"2:" intoString:NULL]) {
            lengthEncoding = 2;
            mustBePushdata = YES;
        } else if ([scanner scanString:@"4:" intoString:NULL]) {
            lengthEncoding = 4;
            mustBePushdata = YES;
        }
        
        // The text could be:
        // 1. Single-quoted UTF8 string. (BitcoinQT unit tests style)
        // 2. Arbitrary pushdata in square brackets (bitcoinj style)
        // 3. Raw binary in hex (starts with 0x) (BitcoinQT unit tests style)
        // 4. Opcode with and without OP_ prefix
        // 5. Small integer
        // 6. Big pushdata in hex
        
        
        NSData* pushdata = nil;
        NSString* word = nil;
        
        // 1. Detect an ASCII string in single quotes.
        if ([scanner scanString:@"'" intoString:NULL]) {
            NSMutableString* buffer = [NSMutableString string];
            
            while (1) {
                NSString* portion = @"";
                if ([scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\\'"] intoString:&portion]) {
                    [buffer appendString:portion];
                }
                
                if ([scanner isAtEnd]) return nil; // if finished it means the string is not terminated properly
                
                // For simplicity, we do not support all imaginable escape sequences like in C or JavaScript (especially unicode ones).
                // This parser will be happy to read UTF8 characters, but we do not support writing UTF8 characters in a form of single-quoted string.
                // For unsupported characters use hex notation, not ASCII one.
                // Backslash not in front of another backslash or single quote is a syntax error.
                if ([scanner scanString:@"\\" intoString:NULL]) {
                    // Escape sequence before either quote «'» or backslash «\\»
                    if ([scanner scanString:@"\\" intoString:NULL]) { // escaped backslash
                        [buffer appendString:@"\\"];
                        continue;
                    } else if ([scanner scanString:@"'" intoString:NULL]) {
                        [buffer appendString:@"'"];
                        continue;
                    }
                    // Something unsupported is escaped - fail.
                    return nil;
                } else if ([scanner scanString:@"'" intoString:NULL]) {
                    // String finished.
                    break;
                }
                // Syntax failed.
                return nil;
            }
            
            pushdata = [buffer dataUsingEncoding:NSUTF8StringEncoding];
        } else if ([scanner scanString:@"[" intoString:NULL]) {
        // 2. Arbitrary hex pushdata in square brackets (bitcoinj style)
            NSString* hexstring = nil;
            if ([scanner scanUpToString:@"]" intoString:&hexstring]) {
                // Check if hex string is valid.
                NSData* data = BTCDataFromHex(hexstring);
                
                if (!data) return nil; // hex string is invalid
                
                if (![scanner scanString:@"]" intoString:NULL])
                {
                    return nil;
                }
                
                pushdata = data;
            } else {
                return nil;
            }
        } else if ([scanner scanString:@"0x" intoString:NULL]) {
            // 3. Raw binary in hex (starts with 0x) (BitcoinQT unit tests style)
            if (mustBePushdata) return nil; // Should not prepend 0x... with pushdata length prefix.
            
            NSString* hexstring = nil;
            if ([scanner scanUpToCharactersFromSet:whitespaceSet intoString:&hexstring]) {
                NSData* data = BTCDataFromHex(hexstring);
                
                if (!data || data.length == 0) return nil; // hex string is invalid
                
                [scriptData appendData:data];
                
                // Move back to the beginning of the loop to scan another piece of script.
                continue;
            } else {
                // Should have some data after 0x
                return nil;
            }
        } else if ([scanner scanUpToCharactersFromSet:whitespaceSet intoString:&word]) {
        // Find one of these:
        // 4. Opcode with and without OP_ prefix
        // 5. Small integer
        // 6. Big pushdata in hex
            // Attempt to find an opcode name or small integer only if we don't have pushdata prefix (1:, 2:, 4:)
            // E.g. "12" is a small integer OP_12, but "1:12" is OP_PUSHDATA1 with data 0x12
            if (!mustBePushdata) {
                BTCOpcode opcode = BTCOpcodeForName(word);
                
                // Opcode may be used without OP_ prefix.
                if (opcode == OP_INVALIDOPCODE) opcode = BTCOpcodeForName([@"OP_" stringByAppendingString:word]);

                // 4. Opcode with and without OP_ prefix
                if (opcode != OP_INVALIDOPCODE) {
                    [scriptData appendBytes:&opcode length:sizeof(opcode)];
                    continue;
                } else {
                    long long decimalInteger = [word longLongValue];
                    
                    if ([[NSString stringWithFormat:@"%lld", decimalInteger] isEqualToString:word]) {
                        // 5.1. Small Integer
                        if (decimalInteger >= -1 && decimalInteger <= 16) {
                            opcode = BTCOpcodeForSmallInteger((NSUInteger)decimalInteger);
                            
                            if (opcode == OP_INVALIDOPCODE) {
                                @throw [NSException exceptionWithName:@"BTCScript parser inconsistency"
                                                               reason:@"Tried to parse small integer into opcode, but the opcode comes out invalid." userInfo:nil];
                            }
                            
                            [scriptData appendBytes:&opcode length:sizeof(opcode)];
                            continue;
                        } else {
                            BTCBigNumber* bn = [[BTCBigNumber alloc] initWithInt64:decimalInteger];
                            [scriptData appendData:[BTCScriptChunk scriptDataForPushdata:bn.signedLittleEndian preferredLengthEncoding:-1]];
                            continue;
                        }
                    }
                    
                } // opcode or small integer
            } // if (!mustBePushdata)
            
            
            
            // 6. Big pushdata in hex
            
            NSData* data = BTCDataFromHex(word);
            
            if (!data || data.length == 0) return nil; // hex string is invalid
            
            pushdata = data;
            
        } else {
            // Why this should ever happen?
            @throw [NSException exceptionWithName:@"BTCScript parser inconsistency"
                                           reason:@"Unhandled code path. Should figure out why this happens." userInfo:nil];

        }
        
        
        // If we need pushdata because 1:, 2:, 4: prefix was used, fail if we don't have it.
        if (mustBePushdata && !pushdata) {
            return nil;
        }
        
        // If it was a pushdata, encode it.
        if (pushdata) {
            NSData* addedScriptData = [BTCScriptChunk scriptDataForPushdata:pushdata preferredLengthEncoding:lengthEncoding];
            
            if (!addedScriptData) {
                // Invalid length prefix or data is too small or too big.
                return nil;
            }
                        
            [scriptData appendData:addedScriptData];
        } else {
            // Why this should ever happen?
            @throw [NSException exceptionWithName:@"BTCScript parser inconsistency"
                                           reason:@"Unhandled code path. Should figure out why this happens." userInfo:nil];

        }
    } // loop over chunks
    
    
    return [self parseData:scriptData];
}


- (BOOL) isStandard {
    return [self isPayToPublicKeyHashScript]
        || [self isPayToScriptHashScript]
        || [self isPublicKeyScript]
        || [self isStandardMultisignatureScript];
}

- (BOOL) isPublicKeyScript {
    if (_chunks.count != 2) return NO;
    return [self pushdataAtIndex:0].length > 1
        && [self opcodeAtIndex:1] == OP_CHECKSIG;
}

- (BOOL) isHash160Script {
    return [self isPayToPublicKeyHashScript];
}

- (BOOL) isPayToPublicKeyHashScript {
    if (_chunks.count != 5) return NO;
    
    BTCScriptChunk* dataChunk = [self chunkAtIndex:2];
    
    return [self opcodeAtIndex:0] == OP_DUP
        && [self opcodeAtIndex:1] == OP_HASH160
        && !dataChunk.isOpcode
        && dataChunk.range.length == 21
        && [self opcodeAtIndex:3] == OP_EQUALVERIFY
        && [self opcodeAtIndex:4] == OP_CHECKSIG;
}

- (BOOL) isPayToScriptHashScript {
    // TODO: check against the original serialized form instead of parsed chunks because BIP16 defines
    // P2SH script as an exact byte template. Scripts using OP_PUSHDATA1/2/4 are not valid P2SH scripts.
    // To do that we have to maintain original script binary data and each chunk should keep a range in that data.
    
    if (_chunks.count != 3) return NO;
    
    BTCScriptChunk* dataChunk = [self chunkAtIndex:1];
    
    return [self opcodeAtIndex:0] == OP_HASH160
        && !dataChunk.isOpcode
        && dataChunk.range.length == 21          // this is enough to match the exact byte template, any other encoding will be larger.
        && [self opcodeAtIndex:2] == OP_EQUAL;
}

// Returns YES if the script ends with P2SH check.
// Not used in CoreBitcoin. Similar code is used in bitcoin-ruby. I don't know if we'll ever need it.
- (BOOL) endsWithPayToScriptHash {
    if (_chunks.count < 3) return NO;
    
    return [self opcodeAtIndex:-3] == OP_HASH160
        && [self pushdataAtIndex:-2].length == 20
        && [self opcodeAtIndex:-1] == OP_EQUAL;
}

- (BOOL) isStandardMultisignatureScript {
    if (![self isMultisignatureScript]) return NO;
    return _multisigPublicKeys.count <= 3;
}

- (BOOL) isMultisignatureScript {
    if (_multisigSignaturesRequired == 0) {
         [self detectMultisigScript];
    }
    return _multisigSignaturesRequired > 0;
}

// If typical multisig tx is detected, sets two ivars:
// _multisigSignaturesRequired, _multisigPublicKeys.
- (void) detectMultisigScript {
    // multisig script must have at least 4 ops ("OP_1 <pubkey> OP_1 OP_CHECKMULTISIG")
    if (_chunks.count < 4) return;
    
    // The last op is multisig check.
    if ([self opcodeAtIndex:-1] != OP_CHECKMULTISIG) return;
    
    BTCOpcode m_opcode = [self opcodeAtIndex:0];
    BTCOpcode n_opcode = [self opcodeAtIndex:-2];
    
    NSInteger m = BTCSmallIntegerFromOpcode(m_opcode);
    NSInteger n = BTCSmallIntegerFromOpcode(n_opcode);
    if (m <= 0 || m == NSIntegerMax) return;
    if (n <= 0 || n == NSIntegerMax || n < m) return;
    
    // We must have correct number of pubkeys in the script. 3 extra ops: OP_<M>, OP_<N> and OP_CHECKMULTISIG
    if (_chunks.count != (3 + n)) return;
    
    NSMutableArray* list = [NSMutableArray array];
    for (int i = 1; i <= n; i++) {
        NSData* data = [self pushdataAtIndex:i];
        if (!data) return;
        [list addObject:data];
    }
    
    // Now we extracted all pubkeys and verified the numbers.
    _multisigSignaturesRequired = m;
    _multisigPublicKeys = list;
}

- (BOOL) isDataOnly {
    // Include both PUSHDATA ops and OP_0..OP_16 literals.
    for (BTCScriptChunk* chunk in _chunks) {
        if (chunk.opcode > OP_16) {
            return NO;
        }
    }
    return YES;
}

- (NSArray*) scriptChunks {
    return [_chunks copy];
}

- (void) enumerateOperations:(void(^)(NSUInteger opIndex, BTCOpcode opcode, NSData* pushdata, BOOL* stop))block {
    if (!block) return;
    
    NSUInteger opIndex = 0;
    for (BTCScriptChunk* chunk in _chunks) {
        if (chunk.isOpcode) {
            BTCOpcode opcode = chunk.opcode;
            BOOL stop = NO;
            block(opIndex, opcode, nil, &stop);
            if (stop) return;
        } else {
            NSData* data = chunk.pushdata;
            BOOL stop = NO;
            block(opIndex, OP_INVALIDOPCODE, data, &stop);
            if (stop) return;
        }
        opIndex++;
    }
}


- (BTCAddress*) standardAddress {
    if ([self isPayToPublicKeyHashScript]) {
        if (_chunks.count != 5) return nil;
        
        BTCScriptChunk* dataChunk = [self chunkAtIndex:2];
        
        if (!dataChunk.isOpcode && dataChunk.range.length == 21) {
            return [BTCPublicKeyAddress addressWithData:dataChunk.pushdata];
        }
    } else if ([self isPayToScriptHashScript]) {
        if (_chunks.count != 3) return nil;
        
        BTCScriptChunk* dataChunk = [self chunkAtIndex:1];
        
        if (!dataChunk.isOpcode && dataChunk.range.length == 21) {
            return [BTCScriptHashAddress addressWithData:dataChunk.pushdata];
        }
    }
    return nil;
}


// Wraps the recipient into an output P2SH script (OP_HASH160 <20-byte hash of the recipient> OP_EQUAL).
- (BTCScript*) scriptHashScript {
    return [[BTCScript alloc] initWithAddress:[self scriptHashAddress]];
}

// Returns BTCScriptHashAddress that hashes this script.
// Equivalent to [[script scriptHashScript] standardAddress] or [BTCScriptHashAddress addressWithData:BTCHash160(script.data)]
- (BTCScriptHashAddress*) scriptHashAddress {
    return [BTCScriptHashAddress addressWithData:BTCHash160(self.data)];
}

- (BTCScriptHashAddressTestnet*) scriptHashAddressTestnet {
    return [BTCScriptHashAddressTestnet addressWithData:BTCHash160(self.data)];
}




#pragma mark - Simulation



- (BTCScript*) simulatedSignatureScriptWithOptions:(BTCScriptSimulationOptions)opts {
    if ([self isPayToPublicKeyHashScript]) {
        BTCScript* script = [BTCScript new];
        [script appendData:[BTCScript simulatedSignatureWithHashType:SIGHASH_ALL]];
        [script appendData:(opts & BTCScriptSimulationCompressedPublicKeys) ? [BTCScript simulatedCompressedPubkey] : [BTCScript simulatedUncompressedPubkey]];
        return script;
    } else if ([self isPublicKeyScript]) {
        return [[BTCScript new] appendData:[BTCScript simulatedSignatureWithHashType:SIGHASH_ALL]];
    } else if ([self isPayToScriptHashScript]) {
        // Check if allowed to simulate input for P2SH as 2-of-3 multisig.
        if (opts & BTCScriptSimulationMultisigP2SH) {
            // This is a wild approximation, but works well if most p2sh scripts are 2-of-3 multisig scripts.
            BTCScript* script = [BTCScript new];
            [script appendOpcode:OP_0];
            [script appendData:[BTCScript simulatedSignatureWithHashType:SIGHASH_ALL]];
            [script appendData:[BTCScript simulatedSignatureWithHashType:SIGHASH_ALL]];
            [script appendData:[BTCScript simulatedMultisigScriptWithSignaturesCount:2 pubkeysCount:3
                                          compressedPubkeys:(opts & BTCScriptSimulationCompressedPublicKeys)].data];
            return script;
        } else {
            // Can't figure how to simulate signature script for P2SH as it can be anything.
            return nil;
        }
    } else if ([self isMultisignatureScript]) {
        BTCScript* script = [BTCScript new];
        [script appendOpcode:OP_0];
        for (NSInteger i = 0; i < _multisigSignaturesRequired; i++) {
            [script appendData:[BTCScript simulatedSignatureWithHashType:SIGHASH_ALL]];
        }
        return script;
    }

    // Any other type of script is not supported yet.
    // However, it'd be fun to simulate those based on reverse-playback of the script opcodes.
    return nil;
}

// Returns a simulated signature without a hashtype byte.
+ (NSData*) simulatedSignature {
    // "\x30" + "\xff"*71
    NSMutableData* sig = [NSMutableData dataWithLength:1 + 71];
    memset(sig.mutableBytes, 0x30, 1);
    memset(sig.mutableBytes + 1, 0xFF, 71);
    return sig;
}

// Returns a simulated signature with a hashtype byte attached.
+ (NSData*) simulatedSignatureWithHashType:(BTCSignatureHashType)hashtype {
    // "\x30" + "\xff"*71 + encode_uint8(hashtype)
    NSMutableData* sig = [NSMutableData dataWithLength:1 + 71 + 1];
    memset(sig.mutableBytes, 0x30, 1);
    memset(sig.mutableBytes + 1, 0xFF, 71);
    memset(sig.mutableBytes + 1 + 71, hashtype, 1);
    return sig;
}

// Returns a dummy uncompressed pubkey (65 bytes).
+ (NSData*) simulatedUncompressedPubkey {
    // "\x04" + "\xff"*64
    NSMutableData* sig = [NSMutableData dataWithLength:1 + 64];
    memset(sig.mutableBytes, 0x04, 1);
    memset(sig.mutableBytes + 1, 0xFF, 64);
    return sig;
}

// Returns a dummy compressed pubkey (33 bytes).
+ (NSData*) simulatedCompressedPubkey {
    // "\x02" + "\xff"*32
    NSMutableData* sig = [NSMutableData dataWithLength:1 + 32];
    memset(sig.mutableBytes, 0x02, 1);
    memset(sig.mutableBytes + 1, 0xFF, 32);
    return sig;
}

// Returns a dummy script that simulates m-of-n multisig script
+ (BTCScript*) simulatedMultisigScriptWithSignaturesCount:(NSInteger)m pubkeysCount:(NSInteger)n compressedPubkeys:(BOOL)compressedPubkeys {
    /*
     Script.new <<
     Opcode.opcode_for_small_integer(m) <<
     [simulated_uncompressed_pubkey]*n  << # assuming non-compressed pubkeys to be conservative
     Opcode.opcode_for_small_integer(n) <<
     OP_CHECKMULTISIG
     */
    BTCScript* multisig = [BTCScript new];
    [multisig appendOpcode:BTCOpcodeForSmallInteger(m)];
    NSData* pubkey = compressedPubkeys ? [BTCScript simulatedCompressedPubkey] : [BTCScript simulatedUncompressedPubkey];
    for (NSInteger i = 0; i < n; i++) {
        [multisig appendData:pubkey];
    }
    [multisig appendOpcode:BTCOpcodeForSmallInteger(n)];
    return multisig;
}






#pragma mark - Modification



- (void) invalidateSerialization {
    _data = nil;
    _string = nil;
    _multisigSignaturesRequired = 0;
    _multisigPublicKeys = nil;
}

- (BTCScript*) appendOpcode:(BTCOpcode)opcode {
    NSMutableData* scriptData = [self.data mutableCopy] ?: [NSMutableData data];
    
    [scriptData appendBytes:&opcode length:sizeof(opcode)];
    
    BTCScriptChunk* chunk = [[BTCScriptChunk alloc] init];
    chunk.scriptData = scriptData;
    chunk.range = NSMakeRange(scriptData.length - sizeof(opcode), sizeof(opcode));
    [_chunks addObject:chunk];
    
    // Update reference to a new data for all chunks.
    for (BTCScriptChunk* chunk in _chunks) chunk.scriptData = scriptData;
    
    [self invalidateSerialization];

    return self;
}

- (BTCScript*) appendData:(NSData*)data {
    if (data.length == 0) return self;
    
    NSMutableData* scriptData = [self.data mutableCopy] ?: [NSMutableData data];
    
    NSData* addedScriptData = [BTCScriptChunk scriptDataForPushdata:data preferredLengthEncoding:-1];
    [scriptData appendData:addedScriptData];
    
    BTCScriptChunk* chunk = [[BTCScriptChunk alloc] init];
    chunk.scriptData = scriptData;
    chunk.range = NSMakeRange(scriptData.length - addedScriptData.length, addedScriptData.length);
    [_chunks addObject:chunk];
    
    // Update reference to a new data for all chunks.
    for (BTCScriptChunk* chunk in _chunks) chunk.scriptData = scriptData;
    
    [self invalidateSerialization];

    return self;
}

- (BTCScript*) appendScript:(BTCScript*)otherScript {
    if (!otherScript) return self;
    
    NSMutableData* scriptData = [self.data mutableCopy] ?: [NSMutableData data];
    
    NSInteger offset = scriptData.length;
    
    [scriptData appendData:otherScript.data];
    
    for (BTCScriptChunk* chunk in otherScript->_chunks) {
        BTCScriptChunk* chunk2 = [[BTCScriptChunk alloc] init];
        chunk2.range = NSMakeRange(chunk.range.location + offset, chunk.range.length);
        chunk2.scriptData = scriptData;
        [_chunks addObject:chunk2];
    }

    // Update reference to a new data for all chunks.
    for (BTCScriptChunk* chunk in _chunks) chunk.scriptData = scriptData;

    [self invalidateSerialization];

    return self;
}

- (BTCScript*) deleteOccurrencesOfData:(NSData*)data {
    if (data.length == 0) return self;
    
    NSMutableData* md = [NSMutableData data];
    
    for (BTCScriptChunk* chunk in _chunks) {
        if (![chunk.pushdata isEqual:data]) {
            [md appendData:chunk.chunkData];
        }
    }
    
    _chunks = [self parseData:md];

    return self;
}

- (BTCScript*) deleteOccurrencesOfOpcode:(BTCOpcode)opcode {
    NSMutableData* md = [NSMutableData data];
    
    for (BTCScriptChunk* chunk in _chunks) {
        if (chunk.opcode != opcode) {
            [md appendData:chunk.chunkData];
        }
    }
    
    _chunks = [self parseData:md];

    return self;
}



- (BTCScript*) subScriptFromIndex:(NSUInteger)index {
    NSMutableData* md = [NSMutableData data];
    for (BTCScriptChunk* chunk in [_chunks subarrayWithRange:NSMakeRange(index, _chunks.count - index)]) {
        [md appendData:chunk.chunkData];
    }
    return [[BTCScript alloc] initWithData:md];
}

- (BTCScript*) subScriptToIndex:(NSUInteger)index {
    NSMutableData* md = [NSMutableData data];
    for (BTCScriptChunk* chunk in [_chunks subarrayWithRange:NSMakeRange(0, index)]) {
        [md appendData:chunk.chunkData];
    }
    return [[BTCScript alloc] initWithData:md];
}



- (id) copyWithZone:(NSZone *)zone {
    return [[BTCScript alloc] initWithData:self.data];
}

- (NSString*) description {
    return [NSString stringWithFormat:@"<%@:0x%p \"%@\">", [self class], self, self.string];
}



#pragma mark - Utility methods


- (BTCScriptChunk*) chunkAtIndex:(NSInteger)index {
    BTCScriptChunk* chunk = _chunks[index < 0 ? (_chunks.count + index) : index];
    return chunk;
}

// Returns an opcode in a chunk.
// If the chunk is data, not an opcode, returns OP_INVALIDOPCODE
// Raises exception if index is out of bounds.
- (BTCOpcode) opcodeAtIndex:(NSInteger)index {
    BTCScriptChunk* chunk = _chunks[index < 0 ? (_chunks.count + index) : index];
    
    if (chunk.isOpcode) return chunk.opcode;
    
    // If the chunk is not actually an opcode, return invalid opcode.
    return OP_INVALIDOPCODE;
}

// Returns NSData in a chunk.
// If chunk is actually an opcode, returns nil.
// Raises exception if index is out of bounds.
- (NSData*) pushdataAtIndex:(NSInteger)index {
    BTCScriptChunk* chunk = _chunks[index < 0 ? (_chunks.count + index) : index];
    
    if (chunk.isOpcode) return nil;
    
    return chunk.pushdata;
}

// Returns bignum from pushdata or nil.
- (BTCBigNumber*) bignumberAtIndex:(NSInteger)index {
    NSData* data = [self pushdataAtIndex:index];
    if (!data) return nil;
    BTCBigNumber* bn = [[BTCBigNumber alloc] initWithSignedLittleEndian:data];
    return bn;
}






#pragma mark - Canonical checks (Deprecated methods - use BTCKey API)


+ (BOOL) isCanonicalPublicKey:(NSData*)data error:(NSError**)errorOut {
    return [BTCKey isCanonicalPublicKey:data error:errorOut];
}

+ (BOOL) isCanonicalSignature:(NSData*)data verifyEvenS:(BOOL)verifyEvenS error:(NSError**)errorOut {
    return [BTCKey isCanonicalSignatureWithHashType:data verifyEvenS:verifyEvenS error:errorOut];
}


@end










@implementation BTCScriptChunk {
}

- (BTCOpcode) opcode {
    return (BTCOpcode)((const unsigned char*)_scriptData.bytes)[_range.location];
}

- (BOOL) isOpcode {
    BTCOpcode opcode = [self opcode];
    // Pushdata opcodes are not considered a single "opcode".
    // Attention: OP_0 is also "pushdata" code that pushes empty data.
    if (opcode <= OP_PUSHDATA4) return NO;
    return YES;
}

- (NSData*) chunkData {
    return [_scriptData subdataWithRange:_range];
}

// Data being pushed. Returns nil if the opcode is not OP_PUSHDATA*.
- (NSData*) pushdata {
    if (self.isOpcode) return nil;
    BTCOpcode opcode = [self opcode];
    NSUInteger loc = 1;
    if (opcode == OP_PUSHDATA1) {
        loc += 1;
    } else if (opcode == OP_PUSHDATA2) {
        loc += 2;
    } else if (opcode == OP_PUSHDATA4) {
        loc += 4;
    }
    return [_scriptData subdataWithRange:NSMakeRange(_range.location + loc, _range.length - loc)];
}

// Returns YES if the data is represented with the most compact opcode.
- (BOOL) isDataCompact {
    if (self.isOpcode) return NO;
    BTCOpcode opcode = [self opcode];
    NSData* data = [self pushdata];
    if (opcode < OP_PUSHDATA1) return YES; // length fits in one byte under OP_PUSHDATA1.
    if (opcode == OP_PUSHDATA1) return data.length >= OP_PUSHDATA1; // length should be less than OP_PUSHDATA1
    if (opcode == OP_PUSHDATA2) return data.length > 0xff; // length should not fit in one byte
    if (opcode == OP_PUSHDATA4) return data.length > 0xffff; // length should not fit in two bytes
    return NO;
}

// String representation of a chunk.
// OP_1NEGATE, OP_0, OP_1..OP_16 are represented as a decimal number.
// Most compactly represented pushdata chunks >=128 bit are encoded as <hex string>
// Smaller most compactly represented data is encoded as [<hex string>]
// Non-compact pushdata (e.g. 75-byte string with PUSHDATA1) contains a decimal prefix denoting a length size before hex data in square brackets. Ex. "1:[...]", "2:[...]" or "4:[...]"
// For both compat and non-compact pushdata chunks, if the data consists of all printable characters (0x20..0x7E), it is enclosed not in square brackets, but in single quotes as characters themselves. Non-compact string is prefixed with 1:, 2: or 4: like described above.

// Some other guys (BitcoinQT, bitcoin-ruby) encode "small enough" integers in decimal numbers and do that differently.
// BitcoinQT encodes any data less than 4 bytes as a decimal number.
// bitcoin-ruby encodes 2..16 as decimals, 0 and -1 as opcode names and the rest is in hex.
// Now no matter which encoding you use, it can be parsed incorrectly.
// Also: pushdata operations are typically encoded in a raw data which can be encoded in binary differently.
// This means, you'll never be able to parse a sane-looking script into only one binary.
// So forget about relying on parsing this thing exactly. Typically, we either have very small numbers (0..16),
// or very big numbers (hashes and pubkeys).

- (NSString*) string {
    BTCOpcode opcode = [self opcode];
    
    if (self.isOpcode) {
        if (opcode == OP_0) return @"OP_0";
        if (opcode == OP_1NEGATE) return @"OP_1NEGATE";
        if (opcode >= OP_1 && opcode <= OP_16) {
            return [NSString stringWithFormat:@"OP_%u", ((int)opcode + 1 - (int)OP_1)];
        } else {
            return BTCNameForOpcode(opcode);
        }
    } else {
        NSData* data = [self pushdata];
        
        NSString* string = nil;
        // Empty data is encoded as OP_0.
        if (data.length == 0) {
            string = @"OP_0";
        } else if ([self isASCIIData:data]) {
            string = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            
            // Escape escapes & single quote characters.
            string = [string stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
            string = [string stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
            
            // Wrap in single quotes. Why not double? Because they are already used in JSON and we don't want to multiply the mess.
            string = [NSString stringWithFormat:@"'%@'", string];
        } else {
            string = BTCHexFromData(data);
            
            // Shorter than 128-bit chunks are wrapped in square brackets to avoid ambiguity with big all-decimal numbers.
            if (data.length < 16) {
                string = [NSString stringWithFormat:@"[%@]", string];
            }
        }
        
        // Non-compact data is prefixed with an appropriate length prefix.
        if (![self isDataCompact]) {
            int prefix = 1;
            if (opcode == OP_PUSHDATA2) prefix = 2;
            if (opcode == OP_PUSHDATA4) prefix = 4;
            string = [NSString stringWithFormat:@"%d:%@", prefix, string];
        }
        return string;
    }
    
    return nil;
}

- (BOOL) isASCIIData:(NSData*)data {
    BOOL isASCII = YES;
    for (int i = 0; i < data.length; i++) {
        char ch = ((const char*)data.bytes)[i];
        if (!(ch >= 0x20 && ch <= 0x7E)) {
            isASCII = NO;
            break;
        }
    }
    return isASCII;
}

// If encoding is -1, then the most compact will be chosen.
// Valid values: -1, 0, 1, 2, 4.
// Returns nil if preferredLengthEncoding can't be used for data, or data is nil or too big.

+ (NSData*) scriptDataForPushdata:(NSData*)data preferredLengthEncoding:(int)preferredLengthEncoding {
    if (!data) return nil;
    
    NSMutableData* scriptData = [NSMutableData data];
    
    if (data.length < OP_PUSHDATA1 && preferredLengthEncoding <= 0) {
        uint8_t len = data.length;
        [scriptData appendBytes:&len length:sizeof(len)];
        [scriptData appendData:data];
    } else if (data.length <= 0xff && (preferredLengthEncoding == -1 || preferredLengthEncoding == 1)) {
        uint8_t op = OP_PUSHDATA1;
        uint8_t len = data.length;
        [scriptData appendBytes:&op length:sizeof(op)];
        [scriptData appendBytes:&len length:sizeof(len)];
        [scriptData appendData:data];
    } else if (data.length <= 0xffff && (preferredLengthEncoding == -1 || preferredLengthEncoding == 2)) {
        uint8_t op = OP_PUSHDATA2;
        uint16_t len = CFSwapInt16HostToLittle((uint16_t)data.length);
        [scriptData appendBytes:&op length:sizeof(op)];
        [scriptData appendBytes:&len length:sizeof(len)];
        [scriptData appendData:data];
    } else if ((unsigned long long)data.length <= 0xffffffffull && (preferredLengthEncoding == -1 || preferredLengthEncoding == 4)) {
        uint8_t op = OP_PUSHDATA4;
        uint32_t len = CFSwapInt32HostToLittle((uint32_t)data.length);
        [scriptData appendBytes:&op length:sizeof(op)];
        [scriptData appendBytes:&len length:sizeof(len)];
        [scriptData appendData:data];
    } else {
        // Invalid preferredLength encoding or data size is too big.
        return nil;
    }
    
    return scriptData;
}

+ (BTCScriptChunk*) parseChunkFromData:(NSData*)scriptData offset:(NSUInteger)offset {
    // Data should fit at least one opcode.
    if (scriptData.length < (offset + 1)) return nil;
    
    const uint8_t* bytes = ((const uint8_t*)[scriptData bytes]);
    BTCOpcode opcode = bytes[offset];
    
    if (opcode <= OP_PUSHDATA4) {
        // push data opcode
        int length = (int)scriptData.length;

        BTCScriptChunk* chunk = [[BTCScriptChunk alloc] init];
        chunk.scriptData = scriptData;
        
        if (opcode < OP_PUSHDATA1) {
            uint8_t dataLength = opcode;
            NSUInteger chunkLength = sizeof(opcode) + dataLength;
            
            if (offset + chunkLength > length) return nil;
            
            chunk.range = NSMakeRange(offset, chunkLength);
        } else if (opcode == OP_PUSHDATA1) {
            uint8_t dataLength;
            
            if (offset + sizeof(dataLength) > length) return nil;
            
            memcpy(&dataLength, bytes + offset + sizeof(opcode), sizeof(dataLength));

            NSUInteger chunkLength = sizeof(opcode) + sizeof(dataLength) + dataLength;
            
            if (offset + chunkLength > length) return nil;
            
            chunk.range = NSMakeRange(offset, chunkLength);
        } else if (opcode == OP_PUSHDATA2) {
            uint16_t dataLength;
            
            if (offset + sizeof(dataLength) > length) return nil;
            
            memcpy(&dataLength, bytes + offset + sizeof(opcode), sizeof(dataLength));
            dataLength = CFSwapInt16LittleToHost(dataLength);
            
            NSUInteger chunkLength = sizeof(opcode) + sizeof(dataLength) + dataLength;
            
            if (offset + chunkLength > length) return nil;
            
            chunk.range = NSMakeRange(offset, chunkLength);
        } else if (opcode == OP_PUSHDATA4) {
            uint32_t dataLength;
            
            if (offset + sizeof(dataLength) > length) return nil;
            
            memcpy(&dataLength, bytes + offset + sizeof(opcode), sizeof(dataLength));
            dataLength = CFSwapInt16LittleToHost(dataLength);
            
            NSUInteger chunkLength = sizeof(opcode) + sizeof(dataLength) + dataLength;
            
            if (offset + chunkLength > length) return nil;
            
            chunk.range = NSMakeRange(offset, chunkLength);
        }
        
        return chunk;
    } else {
        // simple opcode
        BTCScriptChunk* chunk = [[BTCScriptChunk alloc] init];
        chunk.scriptData = scriptData;
        chunk.range = NSMakeRange(offset, sizeof(opcode));
        return chunk;
    }
    return nil;
}


@end








