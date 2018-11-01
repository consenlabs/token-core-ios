// Oleg Andreev <oleganza@gmail.com>

#import "NS+BTCBase58.h"

// TODO.

@implementation NSString (BTCBase58)

- (NSMutableData*) dataFromBase58 { return BTCDataFromBase58(self); }
- (NSMutableData*) dataFromBase58Check { return BTCDataFromBase58Check(self); }
@end


@implementation NSMutableData (BTCBase58)

+ (NSMutableData*) dataFromBase58CString:(const char*)cstring {
    return BTCDataFromBase58CString(cstring);
}

+ (NSMutableData*) dataFromBase58CheckCString:(const char*)cstring {
    return BTCDataFromBase58CheckCString(cstring);
}

@end


@implementation NSData (BTCBase58)

- (char*) base58CString {
    return BTCBase58CStringWithData(self);
}

- (char*) base58CheckCString {
    return BTCBase58CheckCStringWithData(self);
}

- (NSString*) base58String {
    return BTCBase58StringWithData(self);
}

- (NSString*) base58CheckString {
    return BTCBase58CheckStringWithData(self);
}


@end
