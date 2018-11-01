// Oleg Andreev <oleganza@gmail.com>

#import "BTCBase58.h"
#import "BTCData.h"
#import <openssl/bn.h>

static const char* BTCBase58Alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

NSMutableData* BTCDataFromBase58(NSString* string) {
    return BTCDataFromBase58CString([string cStringUsingEncoding:NSASCIIStringEncoding]);
}

NSMutableData* BTCDataFromBase58Check(NSString* string) {
    return BTCDataFromBase58CheckCString([string cStringUsingEncoding:NSASCIIStringEncoding]);
}

NSMutableData* BTCDataFromBase58CString(const char* cstring) {
    if (cstring == NULL) return nil;
    
    // empty string -> empty data.
    if (cstring[0] == '\0') return [NSMutableData data];
    
    NSMutableData* result = nil;
    
    BN_CTX* pctx = BN_CTX_new();
    __block BIGNUM bn58;   BN_init(&bn58);   BN_set_word(&bn58, 58);
    __block BIGNUM bn;     BN_init(&bn);     BN_zero(&bn);
    __block BIGNUM bnChar; BN_init(&bnChar);
    
    void(^finish)() = ^{
        if (pctx) BN_CTX_free(pctx);
        BN_clear_free(&bn58);
        BN_clear_free(&bn);
        BN_clear_free(&bnChar);
    };
    
    while (isspace(*cstring)) cstring++;
    
    
    // Convert big endian string to bignum
    for (const char* p = cstring; *p; p++) {
        const char* p1 = strchr(BTCBase58Alphabet, *p);
        if (p1 == NULL) {
            while (isspace(*p))
                p++;
            if (*p != '\0') {
                finish();
                return nil;
            }
            break;
        }
        
        BN_set_word(&bnChar, (BN_ULONG)(p1 - BTCBase58Alphabet));
        
        if (!BN_mul(&bn, &bn, &bn58, pctx)) {
            finish();
            return nil;
        }
        
        if (!BN_add(&bn, &bn, &bnChar)) {
            finish();
            return nil;
        }
    }
    
    // Get bignum as little endian data
    
    NSMutableData* bndata = nil;
    {
        size_t bnsize = BN_bn2mpi(&bn, NULL);
        if (bnsize <= 4) {
            bndata = [NSMutableData data];
        } else {
            bndata = [NSMutableData dataWithLength:bnsize];
            BN_bn2mpi(&bn, bndata.mutableBytes);
            [bndata replaceBytesInRange:NSMakeRange(0, 4) withBytes:NULL length:0];
            BTCDataReverse(bndata);
        }
    }
    size_t bnsize = bndata.length;
    
    // Trim off sign byte if present
    if (bnsize >= 2
        && ((unsigned char*)bndata.bytes)[bnsize - 1] == 0
        && ((unsigned char*)bndata.bytes)[bnsize - 2] >= 0x80) {
        bnsize -= 1;
        [bndata setLength:bnsize];
    }
    
    // Restore leading zeros
    int nLeadingZeros = 0;
    for (const char* p = cstring; *p == BTCBase58Alphabet[0]; p++)
        nLeadingZeros++;
    
    result = [NSMutableData dataWithLength:nLeadingZeros + bnsize];
    
    // Copy the bignum to the beginning of array. We'll reverse it then and zeros will become leading zeros.
    [result replaceBytesInRange:NSMakeRange(0, bnsize) withBytes:bndata.bytes length:bnsize];
    
    // Convert little endian data to big endian
    BTCDataReverse(result);
    
    finish();
    
    return result;
}

NSMutableData* BTCDataFromBase58CheckCString(const char* cstring) {
    if (cstring == NULL) return nil;
    
    NSMutableData* result = BTCDataFromBase58CString(cstring);
    size_t length = result.length;
    if (length < 4) {
        return nil;
    }
    NSData* hash = BTCHash256([result subdataWithRange:NSMakeRange(0, length - 4)]);
    
    // Last 4 bytes should be equal first 4 bytes of the hash.
    if (memcmp(hash.bytes, result.bytes + length - 4, 4) != 0) {
        return nil;
    }
    [result setLength:length - 4];
    return result;
}


char* BTCBase58CStringWithData(NSData* data) {
    if (!data) return NULL;
    
    BN_CTX* pctx = BN_CTX_new();
    __block BIGNUM bn58; BN_init(&bn58); BN_set_word(&bn58, 58);
    __block BIGNUM bn0;  BN_init(&bn0);  BN_zero(&bn0);
    __block BIGNUM bn; BN_init(&bn); BN_zero(&bn);
    __block BIGNUM dv; BN_init(&dv); BN_zero(&dv);
    __block BIGNUM rem; BN_init(&rem); BN_zero(&rem);
    
    void(^finish)() = ^{
        if (pctx) BN_CTX_free(pctx);
        BN_clear_free(&bn58);
        BN_clear_free(&bn0);
        BN_clear_free(&bn);
        BN_clear_free(&dv);
        BN_clear_free(&rem);
    };
    
    // Convert big endian data to little endian.
    // Extra zero at the end make sure bignum will interpret as a positive number.
    NSMutableData* tmp = BTCReversedMutableData(data);
    tmp.length += 1;
    
    // Convert little endian data to bignum
    {
        NSUInteger size = tmp.length;
        NSMutableData* mdata = [tmp mutableCopy];
        
        // Reverse to convert to OpenSSL bignum endianess
        BTCDataReverse(mdata);
        
        // BIGNUM's byte stream format expects 4 bytes of
        // big endian size data info at the front
        [mdata replaceBytesInRange:NSMakeRange(0, 0) withBytes:"\0\0\0\0" length:4];
        unsigned char* bytes = mdata.mutableBytes;
        bytes[0] = (size >> 24) & 0xff;
        bytes[1] = (size >> 16) & 0xff;
        bytes[2] = (size >> 8) & 0xff;
        bytes[3] = (size >> 0) & 0xff;
        
        BN_mpi2bn(bytes, (int)mdata.length, &bn);
    }
    
    // Expected size increase from base58 conversion is approximately 137%
    // use 138% to be safe
    NSMutableData* stringData = [NSMutableData dataWithCapacity:data.length*138/100 + 1];
    
    while (BN_cmp(&bn, &bn0) > 0) {
        if (!BN_div(&dv, &rem, &bn, &bn58, pctx)) {
            finish();
            return nil;
        }
        BN_copy(&bn, &dv);
        unsigned long c = BN_get_word(&rem);
        [stringData appendBytes:BTCBase58Alphabet + c length:1];
    }
    finish();
    
    // Leading zeroes encoded as base58 ones ("1")
    const unsigned char* pbegin = data.bytes;
    const unsigned char* pend = data.bytes + data.length;
    for (const unsigned char* p = pbegin; p < pend && *p == 0; p++) {
        [stringData appendBytes:BTCBase58Alphabet + 0 length:1];
    }
    
    // Convert little endian std::string to big endian
    BTCDataReverse(stringData);
    
    [stringData appendBytes:"" length:1];
    
    char* r = malloc(stringData.length);
    memcpy(r, stringData.bytes, stringData.length);
    BTCDataClear(stringData);
    return r;
}

// String in Base58 with checksum
char* BTCBase58CheckCStringWithData(NSData* immutabledata) {
    if (!immutabledata) return NULL;
    // add 4-byte hash check to the end
    NSMutableData* data = [immutabledata mutableCopy];
    NSData* checksum = BTCHash256(data);
    [data appendBytes:checksum.bytes length:4];
    char* result = BTCBase58CStringWithData(data);
    BTCDataClear(data);
    return result;
}

NSString* BTCBase58StringWithData(NSData* data) {
    if (!data) return nil;
    char* s = BTCBase58CStringWithData(data);
    id r = [NSString stringWithCString:s encoding:NSASCIIStringEncoding];
    BTCSecureClearCString(s);
    free(s);
    return r;
}


NSString* BTCBase58CheckStringWithData(NSData* data) {
    if (!data) return nil;
    char* s = BTCBase58CheckCStringWithData(data);
    id r = [NSString stringWithCString:s encoding:NSASCIIStringEncoding];
    BTCSecureClearCString(s);
    free(s);
    return r;
}






