// Oleg Andreev <oleganza@gmail.com>

#import "BTCAddress.h"
#import "BTCAddressSubclass.h"
#import "BTCNetwork.h"
#import "BTCData.h"
#import "BTCBase58.h"
#import "BTCKey.h"
#import <objc/runtime.h>

enum
{
    BTCPublicKeyAddressVersion         = 0,
    BTCPrivateKeyAddressVersion        = 128,
    BTCScriptHashAddressVersion        = 5,
    BTCPublicKeyAddressVersionTestnet  = 111,
    BTCPrivateKeyAddressVersionTestnet = 239,
    BTCScriptHashAddressVersionTestnet = 196,
};

@implementation BTCAddress {
    char* _cstring;
    NSData* _data;
}

- (id) init {
    if (self = [super init]) {
        _data = nil;
    }
    return self;
}

- (void) setData:(NSData *)data {
    id d = [data copy];
    _data = d;
}

- (NSData*) data {
    return _data;
}

- (void) dealloc {
    // The data may be retained by someone and should not be cleared like that.
//    [self clear];
    if (_cstring) free(_cstring);
}

+ (instancetype) addressWithString:(NSString*)string {
    return [self addressWithBase58CString:[string cStringUsingEncoding:NSASCIIStringEncoding]];
}

+ (instancetype) addressWithBase58String:(NSString*)string { // DEPRECATED
    return [self addressWithString:string];
}

// Initializes address with raw data. Should only be used in subclasses, base class will raise exception.
+ (instancetype) addressWithData:(NSData*)data {
    @throw [NSException exceptionWithName:@"BTCAddress Exception"
                                   reason:@"Cannot init base class with raw data. Please use specialized subclass." userInfo:nil];
    return nil;
}

// prototype to make clang happy.
+ (instancetype) addressWithComposedData:(NSData*)data cstring:(const char*)cstring version:(uint8_t)version {
    return nil;
}

// Returns an instance of a specific subclass depending on version number.
// Returns nil for unsupported addresses.
+ (id) addressWithBase58CString:(const char*)cstring {
    NSMutableData* composedData = BTCDataFromBase58CheckCString(cstring);
    if (!composedData) return nil;
    if (composedData.length < 2) return nil;
    
    uint8_t version = ((unsigned char*)composedData.bytes)[0];

    NSDictionary* classes = [self registeredAddressClasses];
    Class cls = classes[@(version)];
    BTCAddress* address = [cls addressWithComposedData:composedData cstring:cstring version:version];
    if (!address) {
        NSLog(@"BTCAddress: unknown address version: %d", version);
    }

    // Verify that address is compatible with the class being invoked.
    // So if someone asked to parse P2PKH address with P2SH string, they will get nil instead of P2SH instance.
    if (![address isKindOfClass:self]) {
        return nil;
    }

    // Securely erase decoded address data
    BTCDataClear(composedData);
    
    return address;
}

- (void) setBase58CString:(const char*)cstring {
    if (_cstring) {
        BTCSecureClearCString(_cstring);
        free(_cstring);
        _cstring = NULL;
    }

    if (cstring) {
        size_t len = strlen(cstring) + 1; // with \0
        _cstring = malloc(len);
        memcpy(_cstring, cstring, len);
    }
}

// for subclasses
- (NSMutableData*) dataForBase58Encoding {
    return nil;
}

- (const char*) base58CString {
    if (!_cstring) {
        NSMutableData* data = [self dataForBase58Encoding];
        _cstring = BTCBase58CheckCStringWithData(data);
        BTCDataClear(data);
    }
    return _cstring;
}

// Returns representation in base58 encoding.
- (NSString*) string {
    const char* cstr = [self base58CString];
    if (!cstr) return nil;
    return [NSString stringWithCString:cstr encoding:NSASCIIStringEncoding];
}

- (NSString*) base58String { // deprecated
    return [self string];
}

- (BTCAddress*) publicAddress {
    return self;
}

- (BTCNetwork*) network {
    // TODO: use this as a primary source and replace isTestnet
    return [self isTestnet] ? [BTCNetwork testnet] : [BTCNetwork mainnet];
}

- (BOOL) isTestnet {
    // TODO: replace this method with network property exclusively.
    return NO;
}

- (uint8_t) versionByte {
    return [[self class] BTCVersionPrefix];
}

+ (uint8_t) BTCVersionPrefix {
    [NSException raise:@"BTCAddress BTCVersionPrefix must be accessed via subclasses" format:@""];
    return 0xff;
}

- (void) clear {
    BTCSecureClearCString(_cstring);
    BTCDataClear(_data);
}

- (NSString*) description {
    return [NSString stringWithFormat:@"<%@: %@>", [self class], self.string];
}

- (BOOL) isEqual:(BTCAddress*)other {
    if (![other isKindOfClass:[BTCAddress class]]) return NO;
    return [self.string isEqualToString:other.string];
}


// Known Addresses


+ (NSMutableDictionary*) registeredAddressClasses {
    static dispatch_once_t onceToken;
    static NSMutableDictionary* registeredAddressClasses;
    dispatch_once(&onceToken, ^{
        registeredAddressClasses = [NSMutableDictionary dictionary];
    });
    return registeredAddressClasses;
}

// Registers a price source with a given name.
+ (void) registerAddressClass:(Class)addressClass version:(uint8_t)version {
    if (!addressClass) return;
    [self registeredAddressClasses][@(version)] = addressClass;
}


@end


@implementation BTCPublicKeyAddress

+ (void) load {
    [BTCAddress registerAddressClass:self version:[self BTCVersionPrefix]];
}

+ (uint8_t) BTCVersionPrefix {
    return BTCPublicKeyAddressVersion;
}

#define BTCPublicKeyAddressLength 20

+ (instancetype) addressWithData:(NSData*)data {
    if (!data) return nil;
    if (data.length != BTCPublicKeyAddressLength) {
        NSLog(@"+[BTCPublicKeyAddress addressWithData] cannot init with hash %d bytes long", (int)data.length);
        return nil;
    }
    BTCPublicKeyAddress* addr = [[self alloc] init];
    addr.data = [NSMutableData dataWithData:data];
    return addr;
}

+ (instancetype) addressWithComposedData:(NSData*)composedData cstring:(const char*)cstring version:(uint8_t)version {
    if (composedData.length != (1 + BTCPublicKeyAddressLength)) {
        NSLog(@"BTCPublicKeyAddress: cannot init with %d bytes (need 20+1 bytes)", (int)composedData.length);
        return nil;
    }
    BTCPublicKeyAddress* addr = [[self alloc] init];
    addr.data = [[NSMutableData alloc] initWithBytes:((const char*)composedData.bytes) + 1 length:composedData.length - 1];
    addr.base58CString = cstring;
    return addr;
}

- (NSMutableData*) dataForBase58Encoding {
    NSMutableData* data = [NSMutableData dataWithLength:1 + BTCPublicKeyAddressLength];
    char* buf = data.mutableBytes;
    buf[0] = [self versionByte];
    memcpy(buf + 1, self.data.bytes, BTCPublicKeyAddressLength);
    return data;
}

@end

@implementation BTCPublicKeyAddressTestnet

+ (void) load {
    [BTCAddress registerAddressClass:self version:[self BTCVersionPrefix]];
}

+ (uint8_t) BTCVersionPrefix {
    return BTCPublicKeyAddressVersionTestnet;
}

- (BOOL) isTestnet {
    return YES;
}

@end






// Private key in Base58 format (5KQntKuhYWSRXNq... or L3p8oAcQTtuokSC...)
@implementation BTCPrivateKeyAddress {
    BOOL _publicKeyCompressed;
}

+ (void) load {
    [BTCAddress registerAddressClass:self version:[self BTCVersionPrefix]];
}

+ (uint8_t) BTCVersionPrefix {
    return BTCPrivateKeyAddressVersion;
}

#define BTCPrivateKeyAddressLength 32

+ (instancetype) addressWithData:(NSData*)data {
    return [self addressWithData:data publicKeyCompressed:NO];
}

+ (instancetype) addressWithData:(NSData*)data publicKeyCompressed:(BOOL)compressedPubkey {
    if (!data) return nil;
    if (data.length != BTCPrivateKeyAddressLength) {
        NSLog(@"+[BTCPrivateKeyAddress addressWithData] cannot init with secret of %d bytes long", (int)data.length);
        return nil;
    }
    BTCPrivateKeyAddress* addr = [[self alloc] init];
    addr.data = [NSMutableData dataWithData:data];
    addr.publicKeyCompressed = compressedPubkey;
    return addr;
}

+ (id) addressWithComposedData:(NSData*)data cstring:(const char*)cstring version:(uint8_t)version {
    if (data.length != (1 + BTCPrivateKeyAddressLength + 1) &&  data.length != (1 + BTCPrivateKeyAddressLength)) {
        NSLog(@"BTCPrivateKeyAddress: cannot init with %d bytes (need 1+32(+1) bytes)", (int)data.length);
        return nil;
    }
    
    // The life is not always easy. Somehow some people added one extra byte to a private key in Base58 to
    // let us know that the resulting public key must be compressed.
    // Private key itself is always 32 bytes.
    BOOL compressed = (data.length == (1+BTCPrivateKeyAddressLength+1));
    
    BTCPrivateKeyAddress* addr = [[self alloc] init];
    addr.data = [NSMutableData dataWithBytes:((const char*)data.bytes) + 1 length:32];
    addr.base58CString = cstring;
    addr->_publicKeyCompressed = compressed;
    return addr;
}

- (BTCKey*) key {
    BTCKey* key = [[BTCKey alloc] initWithPrivateKey:self.data];
    key.publicKeyCompressed = self.isPublicKeyCompressed;
    return key;
}

- (BTCAddress*) publicAddress {
    return [BTCPublicKeyAddress addressWithData:BTCHash160(self.key.publicKey)];
}

// Private key itself is not compressed, but it has extra 0x01 byte to indicate
// that derived pubkey must be compressed (as this affects the pubkey address).
- (BOOL) isPublicKeyCompressed {
    return _publicKeyCompressed;
}

- (void) setPublicKeyCompressed:(BOOL)compressed {
    if (_publicKeyCompressed != compressed) {
        _publicKeyCompressed = compressed;
        self.base58CString = NULL;
    }
}

- (NSMutableData*) dataForBase58Encoding {
    NSMutableData* data = [NSMutableData dataWithLength:1 + BTCPrivateKeyAddressLength + (_publicKeyCompressed ? 1 : 0)];
    char* buf = data.mutableBytes;
    buf[0] = [self versionByte];
    memcpy(buf + 1, self.data.bytes, BTCPrivateKeyAddressLength);
    if (_publicKeyCompressed) {
        // Add extra byte 0x01 in the end.
        buf[1 + BTCPrivateKeyAddressLength] = (unsigned char)1;
    }
    return data;
}

@end

@implementation BTCPrivateKeyAddressTestnet

+ (void) load {
    [BTCAddress registerAddressClass:self version:[self BTCVersionPrefix]];
}

+ (uint8_t) BTCVersionPrefix {
    return BTCPrivateKeyAddressVersionTestnet;
}

- (BTCAddress*) publicAddress {
    return [BTCPublicKeyAddressTestnet addressWithData:BTCHash160(self.key.publicKey)];
}

- (BOOL) isTestnet {
    return YES;
}

@end








// P2SH address (e.g. 3NukJ6fYZJ5Kk8bPjycAnruZkE5Q7UW7i8)
@implementation BTCScriptHashAddress

+ (void) load {
    [BTCAddress registerAddressClass:self version:[self BTCVersionPrefix]];
}

+ (uint8_t) BTCVersionPrefix {
    return BTCScriptHashAddressVersion;
}


#define BTCScriptHashAddressLength 20

+ (instancetype) addressWithData:(NSData*)data {
    if (!data) return nil;
    if (data.length != BTCScriptHashAddressLength) {
        NSLog(@"+[BTCScriptHashAddress addressWithData] cannot init with hash %d bytes long", (int)data.length);
        return nil;
    }
    BTCScriptHashAddress* addr = [[self alloc] init];
    addr.data = [NSMutableData dataWithData:data];
    return addr;
}

+ (id) addressWithComposedData:(NSData*)data cstring:(const char*)cstring version:(uint8_t)version {
    if (data.length != (1 + BTCScriptHashAddressLength)) {
        NSLog(@"BTCPublicKeyAddress: cannot init with %d bytes (need 20+1 bytes)", (int)data.length);
        return nil;
    }
    BTCScriptHashAddress* addr = [[self alloc] init];
    addr.data = [[NSMutableData dataWithBytes:((const char*)data.bytes) + 1 length:data.length - 1] copy];
    NSLog(@"Created P2SH data: %p (%@)", addr.data, addr.data);
    addr.base58CString = cstring;
    return addr;
}

- (NSMutableData*) dataForBase58Encoding {
    NSMutableData* data = [NSMutableData dataWithLength:1 + BTCScriptHashAddressLength];
    char* buf = data.mutableBytes;
    buf[0] = [self versionByte];
    memcpy(buf + 1, self.data.bytes, BTCScriptHashAddressLength);
    return data;
}

@end

@implementation BTCScriptHashAddressTestnet

+ (void) load {
    [BTCAddress registerAddressClass:self version:[self BTCVersionPrefix]];
}

+ (uint8_t) BTCVersionPrefix {
    return BTCScriptHashAddressVersionTestnet;
}

- (BOOL) isTestnet {
    return YES;
}

@end