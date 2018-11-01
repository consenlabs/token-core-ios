// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.

#import "BTC256.h"
#import "BTCData.h"

// 1. Structs are already defined in the .h file.

// 2. Constants

const BTC160 BTC160Zero = {0,0,0,0,0};
const BTC256 BTC256Zero = {0,0,0,0};
const BTC512 BTC512Zero = {0,0,0,0,0,0,0,0};

const BTC160 BTC160Max = {0xffffffff,0xffffffff,0xffffffff,0xffffffff,0xffffffff};
const BTC256 BTC256Max = {0xffffffffffffffffLL,0xffffffffffffffffLL,0xffffffffffffffffLL,0xffffffffffffffffLL};
const BTC512 BTC512Max = {0xffffffffffffffffLL,0xffffffffffffffffLL,0xffffffffffffffffLL,0xffffffffffffffffLL,
                          0xffffffffffffffffLL,0xffffffffffffffffLL,0xffffffffffffffffLL,0xffffffffffffffffLL};

// Using ints assuming little-endian platform. 160-bit chunk actually begins with 82963d5e. Same thing about the rest.
// Digest::SHA512.hexdigest("CoreBitcoin/BTC160Null")[0,2*20].scan(/.{8}/).map{|x| "0x" + x.scan(/../).reverse.join}.join(",")
// 82963d5edd842f1e6bd2b6bc2e9a97a40a7d8652
const BTC160 BTC160Null = {0x5e3d9682,0x1e2f84dd,0xbcb6d26b,0xa4979a2e,0x52867d0a};

// Digest::SHA512.hexdigest("CoreBitcoin/BTC256Null")[0,2*32].scan(/.{16}/).map{|x| "0x" + x.scan(/../).reverse.join}.join(",")
// d1007a1fe826e95409e21595845f44c3b9411d5285b6b5982285aabfa5999a5e
const BTC256 BTC256Null = {0x54e926e81f7a00d1LL,0xc3445f849515e209LL,0x98b5b685521d41b9LL,0x5e9a99a5bfaa8522LL};

// Digest::SHA512.hexdigest("CoreBitcoin/BTC512Null")[0,2*64].scan(/.{16}/).map{|x| "0x" + x.scan(/../).reverse.join}.join(",")
// 62ce64dd92836e6e99d83eee3f623652f6049cf8c22272f295b262861738f0363e01b5d7a53c4a2e5a76d283f3e4a04d28ab54849c6e3e874ca31128bcb759e1
const BTC512 BTC512Null = {0x6e6e8392dd64ce62LL,0x5236623fee3ed899LL,0xf27222c2f89c04f6LL,0x36f038178662b295LL,0x2e4a3ca5d7b5013eLL,0x4da0e4f383d2765aLL,0x873e6e9c8454ab28LL,0xe159b7bc2811a34cLL};


// 3. Comparison

BOOL BTC160Equal(BTC160 chunk1, BTC160 chunk2) {
// Which one is faster: memcmp or word-by-word check? The latter does not need any loop or extra checks to compare bytes.
//    return memcmp(&chunk1, &chunk2, sizeof(chunk1)) == 0;
    return chunk1.words32[0] == chunk2.words32[0]
        && chunk1.words32[1] == chunk2.words32[1]
        && chunk1.words32[2] == chunk2.words32[2]
        && chunk1.words32[3] == chunk2.words32[3]
        && chunk1.words32[4] == chunk2.words32[4];
}

BOOL BTC256Equal(BTC256 chunk1, BTC256 chunk2) {
    return chunk1.words64[0] == chunk2.words64[0]
        && chunk1.words64[1] == chunk2.words64[1]
        && chunk1.words64[2] == chunk2.words64[2]
        && chunk1.words64[3] == chunk2.words64[3];
}

BOOL BTC512Equal(BTC512 chunk1, BTC512 chunk2) {
    return chunk1.words64[0] == chunk2.words64[0]
        && chunk1.words64[1] == chunk2.words64[1]
        && chunk1.words64[2] == chunk2.words64[2]
        && chunk1.words64[3] == chunk2.words64[3]
        && chunk1.words64[4] == chunk2.words64[4]
        && chunk1.words64[5] == chunk2.words64[5]
        && chunk1.words64[6] == chunk2.words64[6]
        && chunk1.words64[7] == chunk2.words64[7];
}

NSComparisonResult BTC160Compare(BTC160 chunk1, BTC160 chunk2) {
    int r = memcmp(&chunk1, &chunk2, sizeof(chunk1));
    
         if (r > 0) return NSOrderedDescending;
    else if (r < 0) return NSOrderedAscending;
    return NSOrderedSame;
}

NSComparisonResult BTC256Compare(BTC256 chunk1, BTC256 chunk2) {
    int r = memcmp(&chunk1, &chunk2, sizeof(chunk1));
    
         if (r > 0) return NSOrderedDescending;
    else if (r < 0) return NSOrderedAscending;
    return NSOrderedSame;
}

NSComparisonResult BTC512Compare(BTC512 chunk1, BTC512 chunk2) {
    int r = memcmp(&chunk1, &chunk2, sizeof(chunk1));
    
         if (r > 0) return NSOrderedDescending;
    else if (r < 0) return NSOrderedAscending;
    return NSOrderedSame;
}



// 4. Operations


// Inverse (b = ~a)
BTC160 BTC160Inverse(BTC160 chunk) {
    chunk.words32[0] = ~chunk.words32[0];
    chunk.words32[1] = ~chunk.words32[1];
    chunk.words32[2] = ~chunk.words32[2];
    chunk.words32[3] = ~chunk.words32[3];
    chunk.words32[4] = ~chunk.words32[4];
    return chunk;
}

BTC256 BTC256Inverse(BTC256 chunk) {
    chunk.words64[0] = ~chunk.words64[0];
    chunk.words64[1] = ~chunk.words64[1];
    chunk.words64[2] = ~chunk.words64[2];
    chunk.words64[3] = ~chunk.words64[3];
    return chunk;
}

BTC512 BTC512Inverse(BTC512 chunk) {
    chunk.words64[0] = ~chunk.words64[0];
    chunk.words64[1] = ~chunk.words64[1];
    chunk.words64[2] = ~chunk.words64[2];
    chunk.words64[3] = ~chunk.words64[3];
    chunk.words64[4] = ~chunk.words64[4];
    chunk.words64[5] = ~chunk.words64[5];
    chunk.words64[6] = ~chunk.words64[6];
    chunk.words64[7] = ~chunk.words64[7];
    return chunk;
}

// Swap byte order
BTC160 BTC160Swap(BTC160 chunk) {
    BTC160 chunk2;
    chunk2.words32[4] = OSSwapConstInt32(chunk.words32[0]);
    chunk2.words32[3] = OSSwapConstInt32(chunk.words32[1]);
    chunk2.words32[2] = OSSwapConstInt32(chunk.words32[2]);
    chunk2.words32[1] = OSSwapConstInt32(chunk.words32[3]);
    chunk2.words32[0] = OSSwapConstInt32(chunk.words32[4]);
    return chunk2;
}

BTC256 BTC256Swap(BTC256 chunk) {
    BTC256 chunk2;
    chunk2.words64[3] = OSSwapConstInt64(chunk.words64[0]);
    chunk2.words64[2] = OSSwapConstInt64(chunk.words64[1]);
    chunk2.words64[1] = OSSwapConstInt64(chunk.words64[2]);
    chunk2.words64[0] = OSSwapConstInt64(chunk.words64[3]);
    return chunk2;
}

BTC512 BTC512Swap(BTC512 chunk) {
    BTC512 chunk2;
    chunk2.words64[7] = OSSwapConstInt64(chunk.words64[0]);
    chunk2.words64[6] = OSSwapConstInt64(chunk.words64[1]);
    chunk2.words64[5] = OSSwapConstInt64(chunk.words64[2]);
    chunk2.words64[4] = OSSwapConstInt64(chunk.words64[3]);
    chunk2.words64[3] = OSSwapConstInt64(chunk.words64[4]);
    chunk2.words64[2] = OSSwapConstInt64(chunk.words64[5]);
    chunk2.words64[1] = OSSwapConstInt64(chunk.words64[6]);
    chunk2.words64[0] = OSSwapConstInt64(chunk.words64[7]);
    return chunk2;
}

// Bitwise AND operation (a & b)
BTC160 BTC160AND(BTC160 chunk1, BTC160 chunk2) {
    chunk1.words32[0] = chunk1.words32[0] & chunk2.words32[0];
    chunk1.words32[1] = chunk1.words32[1] & chunk2.words32[1];
    chunk1.words32[2] = chunk1.words32[2] & chunk2.words32[2];
    chunk1.words32[3] = chunk1.words32[3] & chunk2.words32[3];
    chunk1.words32[4] = chunk1.words32[4] & chunk2.words32[4];
    return chunk1;
}

BTC256 BTC256AND(BTC256 chunk1, BTC256 chunk2) {
    chunk1.words64[0] = chunk1.words64[0] & chunk2.words64[0];
    chunk1.words64[1] = chunk1.words64[1] & chunk2.words64[1];
    chunk1.words64[2] = chunk1.words64[2] & chunk2.words64[2];
    chunk1.words64[3] = chunk1.words64[3] & chunk2.words64[3];
    return chunk1;
}

BTC512 BTC512AND(BTC512 chunk1, BTC512 chunk2) {
    chunk1.words64[0] = chunk1.words64[0] & chunk2.words64[0];
    chunk1.words64[1] = chunk1.words64[1] & chunk2.words64[1];
    chunk1.words64[2] = chunk1.words64[2] & chunk2.words64[2];
    chunk1.words64[3] = chunk1.words64[3] & chunk2.words64[3];
    chunk1.words64[4] = chunk1.words64[4] & chunk2.words64[4];
    chunk1.words64[5] = chunk1.words64[5] & chunk2.words64[5];
    chunk1.words64[6] = chunk1.words64[6] & chunk2.words64[6];
    chunk1.words64[7] = chunk1.words64[7] & chunk2.words64[7];
    return chunk1;
}

// Bitwise OR operation (a | b)
BTC160 BTC160OR(BTC160 chunk1, BTC160 chunk2) {
    chunk1.words32[0] = chunk1.words32[0] | chunk2.words32[0];
    chunk1.words32[1] = chunk1.words32[1] | chunk2.words32[1];
    chunk1.words32[2] = chunk1.words32[2] | chunk2.words32[2];
    chunk1.words32[3] = chunk1.words32[3] | chunk2.words32[3];
    chunk1.words32[4] = chunk1.words32[4] | chunk2.words32[4];
    return chunk1;
}

BTC256 BTC256OR(BTC256 chunk1, BTC256 chunk2) {
    chunk1.words64[0] = chunk1.words64[0] | chunk2.words64[0];
    chunk1.words64[1] = chunk1.words64[1] | chunk2.words64[1];
    chunk1.words64[2] = chunk1.words64[2] | chunk2.words64[2];
    chunk1.words64[3] = chunk1.words64[3] | chunk2.words64[3];
    return chunk1;
}

BTC512 BTC512OR(BTC512 chunk1, BTC512 chunk2) {
    chunk1.words64[0] = chunk1.words64[0] | chunk2.words64[0];
    chunk1.words64[1] = chunk1.words64[1] | chunk2.words64[1];
    chunk1.words64[2] = chunk1.words64[2] | chunk2.words64[2];
    chunk1.words64[3] = chunk1.words64[3] | chunk2.words64[3];
    chunk1.words64[4] = chunk1.words64[4] | chunk2.words64[4];
    chunk1.words64[5] = chunk1.words64[5] | chunk2.words64[5];
    chunk1.words64[6] = chunk1.words64[6] | chunk2.words64[6];
    chunk1.words64[7] = chunk1.words64[7] | chunk2.words64[7];
    return chunk1;
}

// Bitwise exclusive-OR operation (a ^ b)
BTC160 BTC160XOR(BTC160 chunk1, BTC160 chunk2) {
    chunk1.words32[0] = chunk1.words32[0] ^ chunk2.words32[0];
    chunk1.words32[1] = chunk1.words32[1] ^ chunk2.words32[1];
    chunk1.words32[2] = chunk1.words32[2] ^ chunk2.words32[2];
    chunk1.words32[3] = chunk1.words32[3] ^ chunk2.words32[3];
    chunk1.words32[4] = chunk1.words32[4] ^ chunk2.words32[4];
    return chunk1;
}

BTC256 BTC256XOR(BTC256 chunk1, BTC256 chunk2) {
    chunk1.words64[0] = chunk1.words64[0] ^ chunk2.words64[0];
    chunk1.words64[1] = chunk1.words64[1] ^ chunk2.words64[1];
    chunk1.words64[2] = chunk1.words64[2] ^ chunk2.words64[2];
    chunk1.words64[3] = chunk1.words64[3] ^ chunk2.words64[3];
    return chunk1;
}

BTC512 BTC512XOR(BTC512 chunk1, BTC512 chunk2) {
    chunk1.words64[0] = chunk1.words64[0] ^ chunk2.words64[0];
    chunk1.words64[1] = chunk1.words64[1] ^ chunk2.words64[1];
    chunk1.words64[2] = chunk1.words64[2] ^ chunk2.words64[2];
    chunk1.words64[3] = chunk1.words64[3] ^ chunk2.words64[3];
    chunk1.words64[4] = chunk1.words64[4] ^ chunk2.words64[4];
    chunk1.words64[5] = chunk1.words64[5] ^ chunk2.words64[5];
    chunk1.words64[6] = chunk1.words64[6] ^ chunk2.words64[6];
    chunk1.words64[7] = chunk1.words64[7] ^ chunk2.words64[7];
    return chunk1;
}

BTC512 BTC512Concat(BTC256 chunk1, BTC256 chunk2) {
    BTC512 result;
    *((BTC256*)(&result)) = chunk1;
    *((BTC256*)(((unsigned char*)&result) + sizeof(chunk2))) = chunk2;
    return result;
}


// 5. Conversion functions


// Conversion to NSData
NSData* NSDataFromBTC160(BTC160 chunk) {
    return [[NSData alloc] initWithBytes:&chunk length:sizeof(chunk)];
}

NSData* NSDataFromBTC256(BTC256 chunk) {
    return [[NSData alloc] initWithBytes:&chunk length:sizeof(chunk)];
}

NSData* NSDataFromBTC512(BTC512 chunk) {
    return [[NSData alloc] initWithBytes:&chunk length:sizeof(chunk)];
}

// Conversion from NSData.
// If NSData is not big enough, returns BTCHash{160,256,512}Null.
BTC160 BTC160FromNSData(NSData* data) {
    if (data.length < 160/8) return BTC160Null;
    BTC160 chunk = *((BTC160*)data.bytes);
    return chunk;
}

BTC256 BTC256FromNSData(NSData* data) {
    if (data.length < 256/8) return BTC256Null;
    BTC256 chunk = *((BTC256*)data.bytes);
    return chunk;
}

BTC512 BTC512FromNSData(NSData* data) {
    if (data.length < 512/8) return BTC512Null;
    BTC512 chunk = *((BTC512*)data.bytes);
    return chunk;
}


// Returns lowercase hex representation of the chunk

NSString* NSStringFromBTC160(BTC160 chunk) {
    const int length = 20;
    char dest[2*length + 1];
    const unsigned char *src = (unsigned char *)&chunk;
    for (int i = 0; i < length; ++i) {
        sprintf(dest + i*2, "%02x", (unsigned int)(src[i]));
    }
    return [[NSString alloc] initWithBytes:dest length:2*length encoding:NSASCIIStringEncoding];
}

NSString* NSStringFromBTC256(BTC256 chunk) {
    const int length = 32;
    char dest[2*length + 1];
    const unsigned char *src = (unsigned char *)&chunk;
    for (int i = 0; i < length; ++i) {
        sprintf(dest + i*2, "%02x", (unsigned int)(src[i]));
    }
    return [[NSString alloc] initWithBytes:dest length:2*length encoding:NSASCIIStringEncoding];
}

NSString* NSStringFromBTC512(BTC512 chunk) {
    const int length = 64;
    char dest[2*length + 1];
    const unsigned char *src = (unsigned char *)&chunk;
    for (int i = 0; i < length; ++i) {
        sprintf(dest + i*2, "%02x", (unsigned int)(src[i]));
    }
    return [[NSString alloc] initWithBytes:dest length:2*length encoding:NSASCIIStringEncoding];
}

// Conversion from hex NSString (lower- or uppercase).
// If string is invalid or data is too short, returns BTCHash{160,256,512}Null.
BTC160 BTC160FromNSString(NSString* string) {
    return BTC160FromNSData(BTCDataFromHex(string));
}

BTC256 BTC256FromNSString(NSString* string) {
    return BTC256FromNSData(BTCDataFromHex(string));
}

BTC512 BTC512FromNSString(NSString* string) {
    return BTC512FromNSData(BTCDataFromHex(string));
}



