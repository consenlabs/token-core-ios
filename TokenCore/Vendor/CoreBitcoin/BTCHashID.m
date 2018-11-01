// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.

#import "BTCHashID.h"
#import "BTCData.h"

NSData* BTCHashFromID(NSString* identifier) {
    return BTCReversedData(BTCDataFromHex(identifier));
}

NSString* BTCIDFromHash(NSData* hash) {
    return BTCHexFromData(BTCReversedData(hash));
}
