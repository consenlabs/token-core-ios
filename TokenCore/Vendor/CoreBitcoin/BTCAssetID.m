// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.

#import "BTCAssetID.h"
#import "BTCAddressSubclass.h"

static const uint8_t BTCAssetIDVersionMainnet = 23; // "A" prefix
static const uint8_t BTCAssetIDVersionTestnet = 115;

@implementation BTCAssetID

+ (void) load {
    [BTCAddress registerAddressClass:self version:BTCAssetIDVersionMainnet];
    [BTCAddress registerAddressClass:self version:BTCAssetIDVersionTestnet];
}

#define BTCAssetIDLength 20

+ (instancetype) assetIDWithString:(NSString*)string {
    return [self addressWithString:string];
}

+ (instancetype) assetIDWithHash:(NSData*)data {
    if (!data) return nil;
    if (data.length != BTCAssetIDLength) {
        NSLog(@"+[BTCAssetID addressWithData] cannot init with hash %d bytes long", (int)data.length);
        return nil;
    }
    BTCAssetID* addr = [[self alloc] init];
    addr.data = [NSMutableData dataWithData:data];
    return addr;
}

+ (instancetype) addressWithComposedData:(NSData*)composedData cstring:(const char*)cstring version:(uint8_t)version {
    if (composedData.length != (1 + BTCAssetIDLength)) {
        NSLog(@"BTCAssetID: cannot init with %d bytes (need 20+1 bytes)", (int)composedData.length);
        return nil;
    }
    BTCAssetID* addr = [[self alloc] init];
    addr.data = [[NSMutableData alloc] initWithBytes:((const char*)composedData.bytes) + 1 length:composedData.length - 1];
    return addr;
}

- (NSMutableData*) dataForBase58Encoding {
    NSMutableData* data = [NSMutableData dataWithLength:1 + BTCAssetIDLength];
    char* buf = data.mutableBytes;
    buf[0] = [self versionByte];
    memcpy(buf + 1, self.data.bytes, BTCAssetIDLength);
    return data;
}

- (uint8_t) versionByte {
// TODO: support testnet
    return BTCAssetIDVersionMainnet;
}


@end
