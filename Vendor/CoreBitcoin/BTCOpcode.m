// Oleg Andreev <oleganza@gmail.com>

#import "BTCOpcode.h"

NSDictionary* BTCOpcodeForNameDictionary() {
    static NSDictionary* dict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dict = @{
                 @"OP_0":                   @(OP_0),
                 @"OP_FALSE":               @(OP_FALSE),
                 @"OP_PUSHDATA1":           @(OP_PUSHDATA1),
                 @"OP_PUSHDATA2":           @(OP_PUSHDATA2),
                 @"OP_PUSHDATA4":           @(OP_PUSHDATA4),
                 @"OP_1NEGATE":             @(OP_1NEGATE),
                 @"OP_RESERVED":            @(OP_RESERVED),
                 @"OP_1":                   @(OP_1),
                 @"OP_TRUE":                @(OP_TRUE),
                 @"OP_2":                   @(OP_2),
                 @"OP_3":                   @(OP_3),
                 @"OP_4":                   @(OP_4),
                 @"OP_5":                   @(OP_5),
                 @"OP_6":                   @(OP_6),
                 @"OP_7":                   @(OP_7),
                 @"OP_8":                   @(OP_8),
                 @"OP_9":                   @(OP_9),
                 @"OP_10":                  @(OP_10),
                 @"OP_11":                  @(OP_11),
                 @"OP_12":                  @(OP_12),
                 @"OP_13":                  @(OP_13),
                 @"OP_14":                  @(OP_14),
                 @"OP_15":                  @(OP_15),
                 @"OP_16":                  @(OP_16),
                 @"OP_NOP":                 @(OP_NOP),
                 @"OP_VER":                 @(OP_VER),
                 @"OP_IF":                  @(OP_IF),
                 @"OP_NOTIF":               @(OP_NOTIF),
                 @"OP_VERIF":               @(OP_VERIF),
                 @"OP_VERNOTIF":            @(OP_VERNOTIF),
                 @"OP_ELSE":                @(OP_ELSE),
                 @"OP_ENDIF":               @(OP_ENDIF),
                 @"OP_VERIFY":              @(OP_VERIFY),
                 @"OP_RETURN":              @(OP_RETURN),
                 @"OP_TOALTSTACK":          @(OP_TOALTSTACK),
                 @"OP_FROMALTSTACK":        @(OP_FROMALTSTACK),
                 @"OP_2DROP":               @(OP_2DROP),
                 @"OP_2DUP":                @(OP_2DUP),
                 @"OP_3DUP":                @(OP_3DUP),
                 @"OP_2OVER":               @(OP_2OVER),
                 @"OP_2ROT":                @(OP_2ROT),
                 @"OP_2SWAP":               @(OP_2SWAP),
                 @"OP_IFDUP":               @(OP_IFDUP),
                 @"OP_DEPTH":               @(OP_DEPTH),
                 @"OP_DROP":                @(OP_DROP),
                 @"OP_DUP":                 @(OP_DUP),
                 @"OP_NIP":                 @(OP_NIP),
                 @"OP_OVER":                @(OP_OVER),
                 @"OP_PICK":                @(OP_PICK),
                 @"OP_ROLL":                @(OP_ROLL),
                 @"OP_ROT":                 @(OP_ROT),
                 @"OP_SWAP":                @(OP_SWAP),
                 @"OP_TUCK":                @(OP_TUCK),
                 @"OP_CAT":                 @(OP_CAT),
                 @"OP_SUBSTR":              @(OP_SUBSTR),
                 @"OP_LEFT":                @(OP_LEFT),
                 @"OP_RIGHT":               @(OP_RIGHT),
                 @"OP_SIZE":                @(OP_SIZE),
                 @"OP_INVERT":              @(OP_INVERT),
                 @"OP_AND":                 @(OP_AND),
                 @"OP_OR":                  @(OP_OR),
                 @"OP_XOR":                 @(OP_XOR),
                 @"OP_EQUAL":               @(OP_EQUAL),
                 @"OP_EQUALVERIFY":         @(OP_EQUALVERIFY),
                 @"OP_RESERVED1":           @(OP_RESERVED1),
                 @"OP_RESERVED2":           @(OP_RESERVED2),
                 @"OP_1ADD":                @(OP_1ADD),
                 @"OP_1SUB":                @(OP_1SUB),
                 @"OP_2MUL":                @(OP_2MUL),
                 @"OP_2DIV":                @(OP_2DIV),
                 @"OP_NEGATE":              @(OP_NEGATE),
                 @"OP_ABS":                 @(OP_ABS),
                 @"OP_NOT":                 @(OP_NOT),
                 @"OP_0NOTEQUAL":           @(OP_0NOTEQUAL),
                 @"OP_ADD":                 @(OP_ADD),
                 @"OP_SUB":                 @(OP_SUB),
                 @"OP_MUL":                 @(OP_MUL),
                 @"OP_DIV":                 @(OP_DIV),
                 @"OP_MOD":                 @(OP_MOD),
                 @"OP_LSHIFT":              @(OP_LSHIFT),
                 @"OP_RSHIFT":              @(OP_RSHIFT),
                 @"OP_BOOLAND":             @(OP_BOOLAND),
                 @"OP_BOOLOR":              @(OP_BOOLOR),
                 @"OP_NUMEQUAL":            @(OP_NUMEQUAL),
                 @"OP_NUMEQUALVERIFY":      @(OP_NUMEQUALVERIFY),
                 @"OP_NUMNOTEQUAL":         @(OP_NUMNOTEQUAL),
                 @"OP_LESSTHAN":            @(OP_LESSTHAN),
                 @"OP_GREATERTHAN":         @(OP_GREATERTHAN),
                 @"OP_LESSTHANOREQUAL":     @(OP_LESSTHANOREQUAL),
                 @"OP_GREATERTHANOREQUAL":  @(OP_GREATERTHANOREQUAL),
                 @"OP_MIN":                 @(OP_MIN),
                 @"OP_MAX":                 @(OP_MAX),
                 @"OP_WITHIN":              @(OP_WITHIN),
                 @"OP_RIPEMD160":           @(OP_RIPEMD160),
                 @"OP_SHA1":                @(OP_SHA1),
                 @"OP_SHA256":              @(OP_SHA256),
                 @"OP_HASH160":             @(OP_HASH160),
                 @"OP_HASH256":             @(OP_HASH256),
                 @"OP_CODESEPARATOR":       @(OP_CODESEPARATOR),
                 @"OP_CHECKSIG":            @(OP_CHECKSIG),
                 @"OP_CHECKSIGVERIFY":      @(OP_CHECKSIGVERIFY),
                 @"OP_CHECKMULTISIG":       @(OP_CHECKMULTISIG),
                 @"OP_CHECKMULTISIGVERIFY": @(OP_CHECKMULTISIGVERIFY),
                 @"OP_NOP1":                @(OP_NOP1),
                 @"OP_NOP2":                @(OP_NOP2),
                 @"OP_NOP3":                @(OP_NOP3),
                 @"OP_NOP4":                @(OP_NOP4),
                 @"OP_NOP5":                @(OP_NOP5),
                 @"OP_NOP6":                @(OP_NOP6),
                 @"OP_NOP7":                @(OP_NOP7),
                 @"OP_NOP8":                @(OP_NOP8),
                 @"OP_NOP9":                @(OP_NOP9),
                 @"OP_NOP10":               @(OP_NOP10),
                 @"OP_INVALIDOPCODE":       @(OP_INVALIDOPCODE),
                 };
    });
    return dict;
}

NSString* BTCNameForOpcode(BTCOpcode opcode) {
    NSDictionary* dict = BTCOpcodeForNameDictionary();
    for (NSString* name in dict) {
        if ([dict[name] unsignedCharValue] == opcode) return name;
    }
    return @"OP_UNKNOWN";
}

BTCOpcode BTCOpcodeForName(NSString* opcodeName) {
    NSNumber* number = opcodeName ? BTCOpcodeForNameDictionary()[opcodeName] : nil;
    if (!number) return OP_INVALIDOPCODE;
    return [number unsignedCharValue];
}

// Returns OP_1NEGATE, OP_0 .. OP_16 for ints from -1 to 16.
// Returns OP_INVALIDOPCODE for other ints.
BTCOpcode BTCOpcodeForSmallInteger(NSInteger smallInteger) {
    if (smallInteger == 0) return OP_0;
    if (smallInteger == -1) return OP_1NEGATE;
    if (smallInteger >= 1 && smallInteger <= 16) return (OP_1 + (smallInteger - 1));
    return OP_INVALIDOPCODE;
}

// Converts opcode OP_<N> or OP_1NEGATE to an integer value.
// If incorrect opcode is given, NSIntegerMax is returned.
NSInteger BTCSmallIntegerFromOpcode(BTCOpcode opcode) {
    if (opcode == OP_0) return 0;
    if (opcode == OP_1NEGATE) return -1;
    if (opcode >= OP_1 && opcode <= OP_16) return (int)opcode - (int)(OP_1 - 1);
    return NSIntegerMax;
}

