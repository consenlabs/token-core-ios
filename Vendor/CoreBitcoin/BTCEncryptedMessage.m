// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.

#import "BTCKey.h"
#import "BTCData.h"
#import "BTCCurvePoint.h"
#import "BTCBigNumber.h"
#import "BTCEncryptedMessage.h"
#import <CommonCrypto/CommonCrypto.h>

@implementation BTCEncryptedMessage

- (NSData*) encrypt:(NSData*)plaintext {

    NSData* privkey = self.senderKey.privateKey;
    NSData* iv = [BTCHMACSHA256(privkey, plaintext) subdataWithRange:NSMakeRange(0, 16)];

    BTCBigNumber* r = [[BTCBigNumber alloc] initWithUnsignedBigEndian:privkey];
    NSData* Rbuf = self.senderKey.compressedPublicKey;
    BTCCurvePoint* cp = self.recipientKey.curvePoint;
    BTCCurvePoint* P = [cp multiply:r];
    BTCBigNumber* S = P.x;
    NSData* Sbuf = S.unsignedBigEndian; // ensures padding to 32 bytes
    NSData* kEkM = BTCSHA512(Sbuf);
    NSData* kE = [kEkM subdataWithRange:NSMakeRange(0, 32)];
    NSData* kM = [kEkM subdataWithRange:NSMakeRange(32, 32)];

    size_t dataOutMoved = 0;
    NSMutableData* ivct = [NSMutableData dataWithLength:16 + plaintext.length + 16]; // IV + cipher text
    memcpy(ivct.mutableBytes, iv.bytes, iv.length); // put IV in front, to match Bitcore-ECIES
    CCCryptorStatus cryptstatus = CCCrypt(
                                          kCCEncrypt,                  // CCOperation op,         /* kCCEncrypt, kCCDecrypt */
                                          kCCAlgorithmAES,             // CCAlgorithm alg,        /* kCCAlgorithmAES128, etc. */
                                          kCCOptionPKCS7Padding,       // CCOptions options,      /* kCCOptionPKCS7Padding, etc. */
                                          kE.bytes,                    // const void *key,
                                          kE.length,                   // size_t keyLength,
                                          iv.bytes,                    // const void *iv,         /* optional initialization vector */
                                          plaintext.bytes,             // const void *dataIn,     /* optional per op and alg */
                                          plaintext.length,            // size_t dataInLength,
                                          ivct.mutableBytes + iv.length,     // void *dataOut,          /* data RETURNED here */
                                          ivct.length - iv.length,           // size_t dataOutAvailable,
                                          &dataOutMoved                // size_t *dataOutMoved
                                          );

    if (cryptstatus != kCCSuccess) {
        return nil;
    }

    [ivct setLength:dataOutMoved + iv.length];

    NSData* d = BTCHMACSHA256(kM, ivct);

    NSMutableData* result = [NSMutableData dataWithData:Rbuf];
    [result appendData:ivct];
    [result appendData:d];
    return result;

//    Based on Bitcore JS implementation:
//    var r = this._privateKey.bn;
//    var Rpubkey = this._privateKey.publicKey;
//    var Rbuf = Rpubkey.toDER(true);
//    var KB = this._publicKey.point;
//    var P = KB.mul(r);
//    var S = P.getX();
//    var Sbuf = S.toBuffer({size: 32});
//    var kEkM = Hash.sha512(Sbuf);
//    var kE = kEkM.slice(0, 32);
//    var kM = kEkM.slice(32, 64);
//    var c = AESCBC.encryptCipherkey(message, kE, ivbuf);
//    var d = Hash.sha256hmac(c, kM);
//    var encbuf = Buffer.concat([Rbuf, c, d]);
//    return encbuf;
}

- (NSData*) decrypt:(NSData*)ciphertext {

    if (ciphertext.length < (33 + 16 + 16 + 32)) {
        return nil;
    }

    NSData* privkey = self.recipientKey.privateKey;
    BTCBigNumber* kB = [[BTCBigNumber alloc] initWithUnsignedBigEndian:privkey];

    self.senderKey = [[BTCKey alloc] initWithPublicKey:[ciphertext subdataWithRange:NSMakeRange(0, 33)]];
    BTCCurvePoint* R = self.senderKey.curvePoint;
    BTCCurvePoint* P = [R multiply:kB];
    BTCBigNumber* S = P.x;
    NSData* Sbuf = S.unsignedBigEndian; // ensures padding to 32 bytes
    NSData* kEkM = BTCSHA512(Sbuf);
    NSData* kE = [kEkM subdataWithRange:NSMakeRange(0, 32)];
    NSData* kM = [kEkM subdataWithRange:NSMakeRange(32, 32)];

    NSData* ivct = [ciphertext subdataWithRange:NSMakeRange(33, ciphertext.length - 32 - 33)];
    NSData* d = [ciphertext subdataWithRange:NSMakeRange(ciphertext.length - 32, 32)];

    NSData* d2 = BTCHMACSHA256(kM, ivct);

    if (![d isEqual:d2]) {
        // Invalid checksum.
        return nil;
    }

    size_t dataOutMoved = 0;
    NSMutableData* plaintext = [NSMutableData dataWithLength:ivct.length];
    CCCryptorStatus cryptstatus = CCCrypt(
                                          kCCDecrypt,                  // CCOperation op,         /* kCCEncrypt, kCCDecrypt */
                                          kCCAlgorithmAES,             // CCAlgorithm alg,        /* kCCAlgorithmAES128, etc. */
                                          kCCOptionPKCS7Padding,       // CCOptions options,      /* kCCOptionPKCS7Padding, etc. */
                                          kE.bytes,                    // const void *key,
                                          kE.length,                   // size_t keyLength,
                                          ivct.bytes,                  // const void *iv,         /* optional initialization vector */
                                          ivct.bytes + 16,             // const void *dataIn,     /* optional per op and alg */
                                          ivct.length - 16,            // size_t dataInLength,
                                          plaintext.mutableBytes,      // void *dataOut,          /* data RETURNED here */
                                          plaintext.length,            // size_t dataOutAvailable,
                                          &dataOutMoved                // size_t *dataOutMoved
                                          );

    if (cryptstatus != kCCSuccess) {
        return nil;
    }

    [plaintext setLength:dataOutMoved];
    return plaintext;

//    var kB = this._privateKey.bn;
//    this._publicKey = PublicKey.fromDER(encbuf.slice(0, 33));
//    var R = this._publicKey.point;
//    var P = R.mul(kB);
//    var S = P.getX();
//
//    var Sbuf = S.toBuffer({
//    size: 32
//    });
//    var kEkM = Hash.sha512(Sbuf);
//
//    var kE = kEkM.slice(0, 32);
//    var kM = kEkM.slice(32, 64);
//
//    var c = encbuf.slice(33, encbuf.length - 32);
//    var d = encbuf.slice(encbuf.length - 32, encbuf.length);
//
//    var d2 = Hash.sha256hmac(c, kM);
//    if (d.toString('hex') !== d2.toString('hex')) throw new Error('Invalid checksum');
//    var messagebuf = AESCBC.decryptCipherkey(c, kE);


}


@end
