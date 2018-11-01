// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.

#import "BTCAssetAddress.h"
#import "BTCData.h"
#import "BTCBase58.h"

@interface BTCAssetAddress ()
@property(nonatomic, readwrite) BTCAddress* bitcoinAddress;
@end

// OpenAssets Address, e.g. akB4NBW9UuCmHuepksob6yfZs6naHtRCPNy (corresponds to 16UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM)
@implementation BTCAssetAddress

#define BTCAssetAddressNamespace 0x13

+ (void) load {
    [BTCAddress registerAddressClass:self version:BTCAssetAddressNamespace];
}

+ (instancetype) addressWithBitcoinAddress:(BTCAddress*)btcAddress {
    if (!btcAddress) return nil;
    BTCAssetAddress* addr = [[self alloc] init];
    addr.bitcoinAddress = btcAddress;
    return addr;
}

+ (instancetype) addressWithString:(NSString*)string {
    NSMutableData* composedData = BTCDataFromBase58Check(string);
    uint8_t version = ((unsigned char*)composedData.bytes)[0];
    return [self addressWithComposedData:composedData cstring:[string cStringUsingEncoding:NSUTF8StringEncoding] version:version];
}

+ (instancetype) addressWithComposedData:(NSData*)composedData cstring:(const char*)cstring version:(uint8_t)version {
    if (!composedData) return nil;
    if (composedData.length < 2) return nil;

    if (version == BTCAssetAddressNamespace) { // same for testnet and mainnet
        BTCAddress* btcAddr = [BTCAddress addressWithString:BTCBase58CheckStringWithData([composedData subdataWithRange:NSMakeRange(1, composedData.length - 1)])];
        return [self addressWithBitcoinAddress:btcAddr];
    } else {
        return nil;
    }
}

- (NSMutableData*) dataForBase58Encoding {
    NSMutableData* data = [NSMutableData dataWithLength:1];
    char* buf = data.mutableBytes;
    buf[0] = BTCAssetAddressNamespace;
    [data appendData:[(BTCAssetAddress* /* cast only to expose the method that is defined in BTCAddress anyway */)self.bitcoinAddress dataForBase58Encoding]];
    return data;
}

- (unsigned char) versionByte {
    return BTCAssetAddressNamespace;
}

- (BOOL) isTestnet {
    return self.bitcoinAddress.isTestnet;
}

@end
