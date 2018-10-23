// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.

#import "BTCMnemonic.h"
#import "BTCData.h"
#import "BTCKeychain.h"
#import "BTCProtocolSerialization.h"
#include <CommonCrypto/CommonKeyDerivation.h>

@interface BTCMnemonic ()

@property(nonatomic, readwrite) BTCMnemonicWordListType wordListType;
@property(nonatomic, readwrite) NSData* entropy;
@property(nonatomic, readwrite) NSArray* words;
@property(nonatomic, readwrite) NSString* password;
@property(nonatomic, readwrite) NSData* seed;
@property(nonatomic, readwrite) BTCKeychain* keychain;

@end

static inline BOOL BTCMnemonicIsBitSet(uint8_t* buf, int bitIndex) {
    int val = ((int) buf[bitIndex / 8]) & 0xFF;
    val = val << (bitIndex % 8);
    val = val & 0x80;
    return val == 0x80;
}

static inline void BTCMnemonicSetBit(uint8_t* buf, int bitIndex) {
    int value = ((int) buf[bitIndex / 8]) & 0xFF;
    value = value | (1 << (7 - (bitIndex % 8)));
    buf[bitIndex / 8] = (uint8_t) value;
}

static inline void BTCMnemonicIntegerTo11Bits(uint8_t* buf, int bitIndex, int integer) {
    for (int i = 0; i < 11; i++) {
        if ((integer & 0x400) == 0x400) {
            BTCMnemonicSetBit(buf, bitIndex + i);
        }
        integer = integer << 1;
    }
}

static inline NSUInteger BTCMnemonicIntegerFrom11Bits(uint8_t* buf, int bitIndex) {
    NSUInteger value = 0;
    for (int i = 0; i < 11; i++) {
        if (BTCMnemonicIsBitSet(buf, bitIndex + i)) {
            value = (value << 1) | 0x01;
        } else {
            value = (value << 1);
        }
    }
    return value;
}



@implementation BTCMnemonic


- (id) initWithEntropy:(NSData*)entropy password:(NSString*)password wordListType:(BTCMnemonicWordListType)wordListType {
    if (!entropy) return nil;
    if (wordListType == BTCMnemonicWordListTypeUnknown) return nil;

    if (self = [super init]) {
        _entropy = entropy;
        _password = password;
        _wordListType = wordListType;
    }
    return self;
}

- (id) initWithWords:(NSArray*)words password:(NSString*)password wordListType:(BTCMnemonicWordListType)wordListType {
    if (!words) return nil;

    if (words.count != 12 &&
        words.count != 15 &&
        words.count != 18 &&
        words.count != 21 &&
        words.count != 24) {
        // Words count should be between 12 and 24 and be divisible by 13.
        return nil;
    }

    if (self = [super init]) {
        _words = words;
        _password = password ?: @"";
        _wordListType = wordListType;

        // If the list is given, get the entropy from it
        if (wordListType != BTCMnemonicWordListTypeUnknown) {
            _entropy = [self entropyFromWords:_words wordListType:wordListType];

            // If failed to read entropy it's because words are malformed and/or checksum failed.
            if (!_entropy) return nil;
        } else {
            // leave entropy being nil. This instance is still useful for BIP32 seed.
        }
    }
    return self;
}


- (id) initWithData:(NSData*)data {
    if (!data) return nil;

    if (self = [super init]) {
        NSAssert(sizeof(BTCMnemonicWordListType) == 1, @"must be 1 byte long");

        if (data.length < sizeof(BTCMnemonicWordListType)) {
            // Not enough bytes.
            return nil;
        }

        NSUInteger offset = 0;

        _wordListType = ((BTCMnemonicWordListType*)data.bytes)[offset];

        offset += sizeof(BTCMnemonicWordListType);

        if (_wordListType != BTCMnemonicWordListTypeEnglish) {
            // Not supported list.
            return nil;
        }

        NSUInteger encodedEntropyLength = 0;
        _entropy = [BTCProtocolSerialization
                    readVarStringFromData:[data subdataWithRange:NSMakeRange(offset, data.length - offset)]
                    readBytes:&encodedEntropyLength];
        offset += encodedEntropyLength;

        if (_entropy.length != 128 / 8 &&
            _entropy.length != 160 / 8 &&
            _entropy.length != 192 / 8 &&
            _entropy.length != 224 / 8 &&
            _entropy.length != 256 / 8) {
            // Not canonical size of the entropy.
            return nil;
        }

        NSUInteger encodedPasswordLength = 0;
        NSData* passwordData = [BTCProtocolSerialization
                                readVarStringFromData:[data subdataWithRange:NSMakeRange(offset, data.length - offset)]
                                readBytes:&encodedPasswordLength];
        offset += encodedPasswordLength;

        if (!passwordData) {
            // Bad mnemonic encoding
            NSLog(@"ERROR: BTCMnemonic cannot decode password (if missing, password should be empty string with 0x00 length prefix).");
            return nil;
        }

        _password = [[NSString alloc] initWithData:passwordData encoding:NSUTF8StringEncoding];

        if (!_password) {
            // Bad password encoding (not representable in UTF8, wtf?)
            NSLog(@"ERROR: BTCMnemonic cannot convert password back to UTF8 string.");
            return nil;
        }

        // If we have some more data, try to read seed from there.
        if (data.length > offset) {
            _seed = [BTCProtocolSerialization
                     readVarStringFromData:[data subdataWithRange:NSMakeRange(offset, data.length - offset)]
                     readBytes:NULL];

            if (!_seed) {
                NSLog(@"ERROR: BTCMnemonic failed to read encoded seed from mnemonic payload. Will recompute it lazily when needed.");
            }
        }
    }
    return self;
}


// Lazily-computed phrase of words
- (NSArray*) words {
    if (!_words) {
        _words = [self wordsForEntropy:self.entropy wordListType:self.wordListType];
    }
    return _words;
}

// Lazily-computed seed for BIP32
- (NSData*) seed {
    if (!_seed) {
        _seed = [self seedForWords:self.words password:self.password];
    }
    return _seed;
}

// Root keychain instantiated with a given seed.
- (BTCKeychain*) keychain
{
    if (!_keychain) {
        _keychain = [[BTCKeychain alloc] initWithSeed:self.seed];
    }
    return _keychain;
}

- (NSData*) data {
    return [self dataWithSeed:NO];
}

- (NSData*) dataWithSeed {
    return [self dataWithSeed:YES];
}

- (NSData*) dataWithSeed:(BOOL)withSeed {
    NSMutableData* data = [NSMutableData data];

    NSAssert(sizeof(_wordListType) == 1, @"must be 1 byte long");

    // Do not export unknown wordlist mnemonics so we don't accidentally get them back.
    if (_wordListType == BTCMnemonicWordListTypeUnknown) return nil;

    [data appendBytes:&_wordListType length:sizeof(_wordListType)];

    if (!_entropy) return nil;

    [data appendData:[BTCProtocolSerialization dataForVarString:_entropy]];

    NSData* passwordData = [_password ?: @"" dataUsingEncoding:NSUTF8StringEncoding];

    [data appendData:[BTCProtocolSerialization dataForVarString:passwordData]];

    if (withSeed) {
        NSData* seed = self.seed;

        [data appendData:[BTCProtocolSerialization dataForVarString:seed]];
    }

    return data;
}

- (NSUInteger) hash {
    return [self.seed hash];
}

- (BOOL) isEqual:(BTCMnemonic*)other {
    return [self.seed isEqual:other.seed];
}

- (void) dealloc {
    [self clear];
}

- (void) clear {
    BTCDataClear(_entropy);
    BTCDataClear(_seed);
    [_keychain clear];
    _keychain = nil;
    _entropy = nil;
    _seed = nil;
}



#pragma mark - Private Helpers


- (NSData*) seedForWords:(NSArray*)words password:(NSString*)password {
    password = password ?: @"";

    NSData* mnemonic = [[words componentsJoinedByString:@" "] dataUsingEncoding:NSUTF8StringEncoding];
    NSData* salt = [[@"mnemonic" stringByAppendingString:password] dataUsingEncoding:NSUTF8StringEncoding];

    const NSUInteger seedLength = 64;
    NSMutableData* seed = [NSMutableData dataWithLength:seedLength];

    CCKeyDerivationPBKDF(kCCPBKDF2,
                         mnemonic.bytes,
                         mnemonic.length,
                         salt.bytes,
                         salt.length,
                         kCCPRFHmacAlgSHA512,
                         2048,
                         seed.mutableBytes,
                         seedLength);

    return seed;
}

- (NSArray*) wordsForEntropy:(NSData*)entropy wordListType:(BTCMnemonicWordListType)listType {
    if (!entropy) return nil;

    NSArray* wordList = [[self class] wordListForType:listType];

    if (!wordList) return nil;

    NSUInteger bitLength = entropy.length * 8;

    if (bitLength != 128 &&
        bitLength != 160 &&
        bitLength != 192 &&
        bitLength != 224 &&
        bitLength != 256) {
        [[NSException exceptionWithName:@"Bad entropy length" reason:@"Raw entropy must be 128, 160, 192, 224, or 256 bits" userInfo:nil] raise];
    }

    // Calculate the checksum
    NSUInteger checksumLength = bitLength / 32;
    NSData* checksumHash = BTCSHA256(entropy);
    uint8_t checksumByte = (uint8_t) (((0xFF << (8 - checksumLength)) & 0xFF) & (0xFF & ((int) ((uint8_t*)checksumHash.bytes)[0] )));

    // Append the checksum to the raw entropy
    NSMutableData* buf = [entropy mutableCopy];
    [buf appendBytes:&checksumByte length:1];

    // Turn the array of bytes into a word list where each word represents 11 bits
    NSUInteger wordsCount = (bitLength + checksumLength) / 11;
    NSMutableArray* words = [[NSMutableArray alloc] initWithCapacity:wordsCount];

    for (int i = 0; i < wordsCount; i++) {
        NSUInteger wordIndex = BTCMnemonicIntegerFrom11Bits((uint8_t*)buf.bytes, i * 11);

        [words addObject:wordList[wordIndex]];
    }
    return words;
}

- (NSData*) entropyFromWords:(NSArray*)words wordListType:(BTCMnemonicWordListType)listType {
    if (listType == BTCMnemonicWordListTypeUnknown) return nil;
    if (!words) return nil;

    if (words.count != 12 &&
        words.count != 15 &&
        words.count != 18 &&
        words.count != 21 &&
        words.count != 24) {
        // Words count should be between 12 and 24 and be divisible by 13.
        return nil;
    }

    NSArray* wordList = [[self class] wordListForType:listType];

    int bitLength = (int)words.count * 11;

    NSMutableData* buf = [NSMutableData dataWithLength:bitLength / 8 + ((bitLength % 8) > 0 ? 1 : 0)];

    for (int i = 0; i < words.count; i++) {
        NSString* word = words[i];
        NSUInteger wordIndex = [wordList indexOfObject:word];

        if (wordIndex == NSNotFound) {
            return nil;
        }

        BTCMnemonicIntegerTo11Bits((uint8_t*)buf.mutableBytes, i * 11, (int)wordIndex);
    }

    NSData* entropy = [buf subdataWithRange:NSMakeRange(0, buf.length - 1)];

    // Calculate the checksum
    NSUInteger checksumLength = bitLength / 32;
    NSData* checksumHash = BTCSHA256(entropy);
    uint8_t checksumByte = (uint8_t) (((0xFF << (8 - checksumLength)) & 0xFF) & (0xFF & ((int) ((uint8_t*)checksumHash.bytes)[0] )));

    uint8_t lastByte = ((uint8_t*)buf.bytes)[buf.length - 1];

    // Verify the checksum
    if (lastByte != checksumByte) {
        return nil;
    }

    return entropy;
}







#pragma mark - Supported Word Lists





+ (NSArray*) wordListForType:(BTCMnemonicWordListType)type {
    if (type == BTCMnemonicWordListTypeEnglish) {
        return [self englishWordList];
    }

    return nil;
}

+ (NSArray*) englishWordList {
    static NSArray* list;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        list = @[@"abandon", @"ability", @"able", @"about", @"above",
                 @"absent", @"absorb", @"abstract", @"absurd", @"abuse", @"access", @"accident", @"account", @"accuse", @"achieve",
                 @"acid", @"acoustic", @"acquire", @"across", @"act", @"action", @"actor", @"actress", @"actual", @"adapt", @"add",
                 @"addict", @"address", @"adjust", @"admit", @"adult", @"advance", @"advice", @"aerobic", @"affair", @"afford", @"afraid",
                 @"again", @"age", @"agent", @"agree", @"ahead", @"aim", @"air", @"airport", @"aisle", @"alarm", @"album", @"alcohol",
                 @"alert", @"alien", @"all", @"alley", @"allow", @"almost", @"alone", @"alpha", @"already", @"also", @"alter", @"always",
                 @"amateur", @"amazing", @"among", @"amount", @"amused", @"analyst", @"anchor", @"ancient", @"anger", @"angle", @"angry",
                 @"animal", @"ankle", @"announce", @"annual", @"another", @"answer", @"antenna", @"antique", @"anxiety", @"any", @"apart",
                 @"apology", @"appear", @"apple", @"approve", @"april", @"arch", @"arctic", @"area", @"arena", @"argue", @"arm", @"armed",
                 @"armor", @"army", @"around", @"arrange", @"arrest", @"arrive", @"arrow", @"art", @"artefact", @"artist", @"artwork",
                 @"ask", @"aspect", @"assault", @"asset", @"assist", @"assume", @"asthma", @"athlete", @"atom", @"attack", @"attend",
                 @"attitude", @"attract", @"auction", @"audit", @"august", @"aunt", @"author", @"auto", @"autumn", @"average", @"avocado",
                 @"avoid", @"awake", @"aware", @"away", @"awesome", @"awful", @"awkward", @"axis", @"baby", @"bachelor", @"bacon",
                 @"badge", @"bag", @"balance", @"balcony", @"ball", @"bamboo", @"banana", @"banner", @"bar", @"barely", @"bargain",
                 @"barrel", @"base", @"basic", @"basket", @"battle", @"beach", @"bean", @"beauty", @"because", @"become", @"beef",
                 @"before", @"begin", @"behave", @"behind", @"believe", @"below", @"belt", @"bench", @"benefit", @"best", @"betray",
                 @"better", @"between", @"beyond", @"bicycle", @"bid", @"bike", @"bind", @"biology", @"bird", @"birth", @"bitter",
                 @"black", @"blade", @"blame", @"blanket", @"blast", @"bleak", @"bless", @"blind", @"blood", @"blossom", @"blouse",
                 @"blue", @"blur", @"blush", @"board", @"boat", @"body", @"boil", @"bomb", @"bone", @"bonus", @"book", @"boost", @"border",
                 @"boring", @"borrow", @"boss", @"bottom", @"bounce", @"box", @"boy", @"bracket", @"brain", @"brand", @"brass", @"brave",
                 @"bread", @"breeze", @"brick", @"bridge", @"brief", @"bright", @"bring", @"brisk", @"broccoli", @"broken", @"bronze",
                 @"broom", @"brother", @"brown", @"brush", @"bubble", @"buddy", @"budget", @"buffalo", @"build", @"bulb", @"bulk",
                 @"bullet", @"bundle", @"bunker", @"burden", @"burger", @"burst", @"bus", @"business", @"busy", @"butter", @"buyer",
                 @"buzz", @"cabbage", @"cabin", @"cable", @"cactus", @"cage", @"cake", @"call", @"calm", @"camera", @"camp", @"can",
                 @"canal", @"cancel", @"candy", @"cannon", @"canoe", @"canvas", @"canyon", @"capable", @"capital", @"captain", @"car",
                 @"carbon", @"card", @"cargo", @"carpet", @"carry", @"cart", @"case", @"cash", @"casino", @"castle", @"casual", @"cat",
                 @"catalog", @"catch", @"category", @"cattle", @"caught", @"cause", @"caution", @"cave", @"ceiling", @"celery", @"cement",
                 @"census", @"century", @"cereal", @"certain", @"chair", @"chalk", @"champion", @"change", @"chaos", @"chapter",
                 @"charge", @"chase", @"chat", @"cheap", @"check", @"cheese", @"chef", @"cherry", @"chest", @"chicken", @"chief", @"child",
                 @"chimney", @"choice", @"choose", @"chronic", @"chuckle", @"chunk", @"churn", @"cigar", @"cinnamon", @"circle",
                 @"citizen", @"city", @"civil", @"claim", @"clap", @"clarify", @"claw", @"clay", @"clean", @"clerk", @"clever", @"click",
                 @"client", @"cliff", @"climb", @"clinic", @"clip", @"clock", @"clog", @"close", @"cloth", @"cloud", @"clown", @"club",
                 @"clump", @"cluster", @"clutch", @"coach", @"coast", @"coconut", @"code", @"coffee", @"coil", @"coin", @"collect",
                 @"color", @"column", @"combine", @"come", @"comfort", @"comic", @"common", @"company", @"concert", @"conduct",
                 @"confirm", @"congress", @"connect", @"consider", @"control", @"convince", @"cook", @"cool", @"copper", @"copy",
                 @"coral", @"core", @"corn", @"correct", @"cost", @"cotton", @"couch", @"country", @"couple", @"course", @"cousin",
                 @"cover", @"coyote", @"crack", @"cradle", @"craft", @"cram", @"crane", @"crash", @"crater", @"crawl", @"crazy", @"cream",
                 @"credit", @"creek", @"crew", @"cricket", @"crime", @"crisp", @"critic", @"crop", @"cross", @"crouch", @"crowd",
                 @"crucial", @"cruel", @"cruise", @"crumble", @"crunch", @"crush", @"cry", @"crystal", @"cube", @"culture", @"cup",
                 @"cupboard", @"curious", @"current", @"curtain", @"curve", @"cushion", @"custom", @"cute", @"cycle", @"dad", @"damage",
                 @"damp", @"dance", @"danger", @"daring", @"dash", @"daughter", @"dawn", @"day", @"deal", @"debate", @"debris", @"decade",
                 @"december", @"decide", @"decline", @"decorate", @"decrease", @"deer", @"defense", @"define", @"defy", @"degree",
                 @"delay", @"deliver", @"demand", @"demise", @"denial", @"dentist", @"deny", @"depart", @"depend", @"deposit", @"depth",
                 @"deputy", @"derive", @"describe", @"desert", @"design", @"desk", @"despair", @"destroy", @"detail", @"detect",
                 @"develop", @"device", @"devote", @"diagram", @"dial", @"diamond", @"diary", @"dice", @"diesel", @"diet", @"differ",
                 @"digital", @"dignity", @"dilemma", @"dinner", @"dinosaur", @"direct", @"dirt", @"disagree", @"discover", @"disease",
                 @"dish", @"dismiss", @"disorder", @"display", @"distance", @"divert", @"divide", @"divorce", @"dizzy", @"doctor",
                 @"document", @"dog", @"doll", @"dolphin", @"domain", @"donate", @"donkey", @"donor", @"door", @"dose", @"double", @"dove",
                 @"draft", @"dragon", @"drama", @"drastic", @"draw", @"dream", @"dress", @"drift", @"drill", @"drink", @"drip", @"drive",
                 @"drop", @"drum", @"dry", @"duck", @"dumb", @"dune", @"during", @"dust", @"dutch", @"duty", @"dwarf", @"dynamic", @"eager",
                 @"eagle", @"early", @"earn", @"earth", @"easily", @"east", @"easy", @"echo", @"ecology", @"economy", @"edge", @"edit",
                 @"educate", @"effort", @"egg", @"eight", @"either", @"elbow", @"elder", @"electric", @"elegant", @"element", @"elephant",
                 @"elevator", @"elite", @"else", @"embark", @"embody", @"embrace", @"emerge", @"emotion", @"employ", @"empower", @"empty",
                 @"enable", @"enact", @"end", @"endless", @"endorse", @"enemy", @"energy", @"enforce", @"engage", @"engine", @"enhance",
                 @"enjoy", @"enlist", @"enough", @"enrich", @"enroll", @"ensure", @"enter", @"entire", @"entry", @"envelope", @"episode",
                 @"equal", @"equip", @"era", @"erase", @"erode", @"erosion", @"error", @"erupt", @"escape", @"essay", @"essence",
                 @"estate", @"eternal", @"ethics", @"evidence", @"evil", @"evoke", @"evolve", @"exact", @"example", @"excess",
                 @"exchange", @"excite", @"exclude", @"excuse", @"execute", @"exercise", @"exhaust", @"exhibit", @"exile", @"exist",
                 @"exit", @"exotic", @"expand", @"expect", @"expire", @"explain", @"expose", @"express", @"extend", @"extra", @"eye",
                 @"eyebrow", @"fabric", @"face", @"faculty", @"fade", @"faint", @"faith", @"fall", @"false", @"fame", @"family", @"famous",
                 @"fan", @"fancy", @"fantasy", @"farm", @"fashion", @"fat", @"fatal", @"father", @"fatigue", @"fault", @"favorite",
                 @"feature", @"february", @"federal", @"fee", @"feed", @"feel", @"female", @"fence", @"festival", @"fetch", @"fever",
                 @"few", @"fiber", @"fiction", @"field", @"figure", @"file", @"film", @"filter", @"final", @"find", @"fine", @"finger",
                 @"finish", @"fire", @"firm", @"first", @"fiscal", @"fish", @"fit", @"fitness", @"fix", @"flag", @"flame", @"flash",
                 @"flat", @"flavor", @"flee", @"flight", @"flip", @"float", @"flock", @"floor", @"flower", @"fluid", @"flush", @"fly",
                 @"foam", @"focus", @"fog", @"foil", @"fold", @"follow", @"food", @"foot", @"force", @"forest", @"forget", @"fork",
                 @"fortune", @"forum", @"forward", @"fossil", @"foster", @"found", @"fox", @"fragile", @"frame", @"frequent", @"fresh",
                 @"friend", @"fringe", @"frog", @"front", @"frost", @"frown", @"frozen", @"fruit", @"fuel", @"fun", @"funny", @"furnace",
                 @"fury", @"future", @"gadget", @"gain", @"galaxy", @"gallery", @"game", @"gap", @"garage", @"garbage", @"garden",
                 @"garlic", @"garment", @"gas", @"gasp", @"gate", @"gather", @"gauge", @"gaze", @"general", @"genius", @"genre", @"gentle",
                 @"genuine", @"gesture", @"ghost", @"giant", @"gift", @"giggle", @"ginger", @"giraffe", @"girl", @"give", @"glad",
                 @"glance", @"glare", @"glass", @"glide", @"glimpse", @"globe", @"gloom", @"glory", @"glove", @"glow", @"glue", @"goat",
                 @"goddess", @"gold", @"good", @"goose", @"gorilla", @"gospel", @"gossip", @"govern", @"gown", @"grab", @"grace", @"grain",
                 @"grant", @"grape", @"grass", @"gravity", @"great", @"green", @"grid", @"grief", @"grit", @"grocery", @"group", @"grow",
                 @"grunt", @"guard", @"guess", @"guide", @"guilt", @"guitar", @"gun", @"gym", @"habit", @"hair", @"half", @"hammer",
                 @"hamster", @"hand", @"happy", @"harbor", @"hard", @"harsh", @"harvest", @"hat", @"have", @"hawk", @"hazard", @"head",
                 @"health", @"heart", @"heavy", @"hedgehog", @"height", @"hello", @"helmet", @"help", @"hen", @"hero", @"hidden", @"high",
                 @"hill", @"hint", @"hip", @"hire", @"history", @"hobby", @"hockey", @"hold", @"hole", @"holiday", @"hollow", @"home",
                 @"honey", @"hood", @"hope", @"horn", @"horror", @"horse", @"hospital", @"host", @"hotel", @"hour", @"hover", @"hub",
                 @"huge", @"human", @"humble", @"humor", @"hundred", @"hungry", @"hunt", @"hurdle", @"hurry", @"hurt", @"husband",
                 @"hybrid", @"ice", @"icon", @"idea", @"identify", @"idle", @"ignore", @"ill", @"illegal", @"illness", @"image",
                 @"imitate", @"immense", @"immune", @"impact", @"impose", @"improve", @"impulse", @"inch", @"include", @"income",
                 @"increase", @"index", @"indicate", @"indoor", @"industry", @"infant", @"inflict", @"inform", @"inhale", @"inherit",
                 @"initial", @"inject", @"injury", @"inmate", @"inner", @"innocent", @"input", @"inquiry", @"insane", @"insect",
                 @"inside", @"inspire", @"install", @"intact", @"interest", @"into", @"invest", @"invite", @"involve", @"iron", @"island",
                 @"isolate", @"issue", @"item", @"ivory", @"jacket", @"jaguar", @"jar", @"jazz", @"jealous", @"jeans", @"jelly", @"jewel",
                 @"job", @"join", @"joke", @"journey", @"joy", @"judge", @"juice", @"jump", @"jungle", @"junior", @"junk", @"just",
                 @"kangaroo", @"keen", @"keep", @"ketchup", @"key", @"kick", @"kid", @"kidney", @"kind", @"kingdom", @"kiss", @"kit",
                 @"kitchen", @"kite", @"kitten", @"kiwi", @"knee", @"knife", @"knock", @"know", @"lab", @"label", @"labor", @"ladder",
                 @"lady", @"lake", @"lamp", @"language", @"laptop", @"large", @"later", @"latin", @"laugh", @"laundry", @"lava", @"law",
                 @"lawn", @"lawsuit", @"layer", @"lazy", @"leader", @"leaf", @"learn", @"leave", @"lecture", @"left", @"leg", @"legal",
                 @"legend", @"leisure", @"lemon", @"lend", @"length", @"lens", @"leopard", @"lesson", @"letter", @"level", @"liar",
                 @"liberty", @"library", @"license", @"life", @"lift", @"light", @"like", @"limb", @"limit", @"link", @"lion", @"liquid",
                 @"list", @"little", @"live", @"lizard", @"load", @"loan", @"lobster", @"local", @"lock", @"logic", @"lonely", @"long",
                 @"loop", @"lottery", @"loud", @"lounge", @"love", @"loyal", @"lucky", @"luggage", @"lumber", @"lunar", @"lunch",
                 @"luxury", @"lyrics", @"machine", @"mad", @"magic", @"magnet", @"maid", @"mail", @"main", @"major", @"make", @"mammal",
                 @"man", @"manage", @"mandate", @"mango", @"mansion", @"manual", @"maple", @"marble", @"march", @"margin", @"marine",
                 @"market", @"marriage", @"mask", @"mass", @"master", @"match", @"material", @"math", @"matrix", @"matter", @"maximum",
                 @"maze", @"meadow", @"mean", @"measure", @"meat", @"mechanic", @"medal", @"media", @"melody", @"melt", @"member",
                 @"memory", @"mention", @"menu", @"mercy", @"merge", @"merit", @"merry", @"mesh", @"message", @"metal", @"method",
                 @"middle", @"midnight", @"milk", @"million", @"mimic", @"mind", @"minimum", @"minor", @"minute", @"miracle", @"mirror",
                 @"misery", @"miss", @"mistake", @"mix", @"mixed", @"mixture", @"mobile", @"model", @"modify", @"mom", @"moment",
                 @"monitor", @"monkey", @"monster", @"month", @"moon", @"moral", @"more", @"morning", @"mosquito", @"mother", @"motion",
                 @"motor", @"mountain", @"mouse", @"move", @"movie", @"much", @"muffin", @"mule", @"multiply", @"muscle", @"museum",
                 @"mushroom", @"music", @"must", @"mutual", @"myself", @"mystery", @"myth", @"naive", @"name", @"napkin", @"narrow",
                 @"nasty", @"nation", @"nature", @"near", @"neck", @"need", @"negative", @"neglect", @"neither", @"nephew", @"nerve",
                 @"nest", @"net", @"network", @"neutral", @"never", @"news", @"next", @"nice", @"night", @"noble", @"noise", @"nominee",
                 @"noodle", @"normal", @"north", @"nose", @"notable", @"note", @"nothing", @"notice", @"novel", @"now", @"nuclear",
                 @"number", @"nurse", @"nut", @"oak", @"obey", @"object", @"oblige", @"obscure", @"observe", @"obtain", @"obvious",
                 @"occur", @"ocean", @"october", @"odor", @"off", @"offer", @"office", @"often", @"oil", @"okay", @"old", @"olive",
                 @"olympic", @"omit", @"once", @"one", @"onion", @"online", @"only", @"open", @"opera", @"opinion", @"oppose", @"option",
                 @"orange", @"orbit", @"orchard", @"order", @"ordinary", @"organ", @"orient", @"original", @"orphan", @"ostrich",
                 @"other", @"outdoor", @"outer", @"output", @"outside", @"oval", @"oven", @"over", @"own", @"owner", @"oxygen", @"oyster",
                 @"ozone", @"pact", @"paddle", @"page", @"pair", @"palace", @"palm", @"panda", @"panel", @"panic", @"panther", @"paper",
                 @"parade", @"parent", @"park", @"parrot", @"party", @"pass", @"patch", @"path", @"patient", @"patrol", @"pattern",
                 @"pause", @"pave", @"payment", @"peace", @"peanut", @"pear", @"peasant", @"pelican", @"pen", @"penalty", @"pencil",
                 @"people", @"pepper", @"perfect", @"permit", @"person", @"pet", @"phone", @"photo", @"phrase", @"physical", @"piano",
                 @"picnic", @"picture", @"piece", @"pig", @"pigeon", @"pill", @"pilot", @"pink", @"pioneer", @"pipe", @"pistol", @"pitch",
                 @"pizza", @"place", @"planet", @"plastic", @"plate", @"play", @"please", @"pledge", @"pluck", @"plug", @"plunge", @"poem",
                 @"poet", @"point", @"polar", @"pole", @"police", @"pond", @"pony", @"pool", @"popular", @"portion", @"position",
                 @"possible", @"post", @"potato", @"pottery", @"poverty", @"powder", @"power", @"practice", @"praise", @"predict",
                 @"prefer", @"prepare", @"present", @"pretty", @"prevent", @"price", @"pride", @"primary", @"print", @"priority",
                 @"prison", @"private", @"prize", @"problem", @"process", @"produce", @"profit", @"program", @"project", @"promote",
                 @"proof", @"property", @"prosper", @"protect", @"proud", @"provide", @"public", @"pudding", @"pull", @"pulp", @"pulse",
                 @"pumpkin", @"punch", @"pupil", @"puppy", @"purchase", @"purity", @"purpose", @"purse", @"push", @"put", @"puzzle",
                 @"pyramid", @"quality", @"quantum", @"quarter", @"question", @"quick", @"quit", @"quiz", @"quote", @"rabbit", @"raccoon",
                 @"race", @"rack", @"radar", @"radio", @"rail", @"rain", @"raise", @"rally", @"ramp", @"ranch", @"random", @"range",
                 @"rapid", @"rare", @"rate", @"rather", @"raven", @"raw", @"razor", @"ready", @"real", @"reason", @"rebel", @"rebuild",
                 @"recall", @"receive", @"recipe", @"record", @"recycle", @"reduce", @"reflect", @"reform", @"refuse", @"region",
                 @"regret", @"regular", @"reject", @"relax", @"release", @"relief", @"rely", @"remain", @"remember", @"remind", @"remove",
                 @"render", @"renew", @"rent", @"reopen", @"repair", @"repeat", @"replace", @"report", @"require", @"rescue", @"resemble",
                 @"resist", @"resource", @"response", @"result", @"retire", @"retreat", @"return", @"reunion", @"reveal", @"review",
                 @"reward", @"rhythm", @"rib", @"ribbon", @"rice", @"rich", @"ride", @"ridge", @"rifle", @"right", @"rigid", @"ring",
                 @"riot", @"ripple", @"risk", @"ritual", @"rival", @"river", @"road", @"roast", @"robot", @"robust", @"rocket", @"romance",
                 @"roof", @"rookie", @"room", @"rose", @"rotate", @"rough", @"round", @"route", @"royal", @"rubber", @"rude", @"rug",
                 @"rule", @"run", @"runway", @"rural", @"sad", @"saddle", @"sadness", @"safe", @"sail", @"salad", @"salmon", @"salon",
                 @"salt", @"salute", @"same", @"sample", @"sand", @"satisfy", @"satoshi", @"sauce", @"sausage", @"save", @"say", @"scale",
                 @"scan", @"scare", @"scatter", @"scene", @"scheme", @"school", @"science", @"scissors", @"scorpion", @"scout", @"scrap",
                 @"screen", @"script", @"scrub", @"sea", @"search", @"season", @"seat", @"second", @"secret", @"section", @"security",
                 @"seed", @"seek", @"segment", @"select", @"sell", @"seminar", @"senior", @"sense", @"sentence", @"series", @"service",
                 @"session", @"settle", @"setup", @"seven", @"shadow", @"shaft", @"shallow", @"share", @"shed", @"shell", @"sheriff",
                 @"shield", @"shift", @"shine", @"ship", @"shiver", @"shock", @"shoe", @"shoot", @"shop", @"short", @"shoulder", @"shove",
                 @"shrimp", @"shrug", @"shuffle", @"shy", @"sibling", @"sick", @"side", @"siege", @"sight", @"sign", @"silent", @"silk",
                 @"silly", @"silver", @"similar", @"simple", @"since", @"sing", @"siren", @"sister", @"situate", @"six", @"size", @"skate",
                 @"sketch", @"ski", @"skill", @"skin", @"skirt", @"skull", @"slab", @"slam", @"sleep", @"slender", @"slice", @"slide",
                 @"slight", @"slim", @"slogan", @"slot", @"slow", @"slush", @"small", @"smart", @"smile", @"smoke", @"smooth", @"snack",
                 @"snake", @"snap", @"sniff", @"snow", @"soap", @"soccer", @"social", @"sock", @"soda", @"soft", @"solar", @"soldier",
                 @"solid", @"solution", @"solve", @"someone", @"song", @"soon", @"sorry", @"sort", @"soul", @"sound", @"soup", @"source",
                 @"south", @"space", @"spare", @"spatial", @"spawn", @"speak", @"special", @"speed", @"spell", @"spend", @"sphere",
                 @"spice", @"spider", @"spike", @"spin", @"spirit", @"split", @"spoil", @"sponsor", @"spoon", @"sport", @"spot", @"spray",
                 @"spread", @"spring", @"spy", @"square", @"squeeze", @"squirrel", @"stable", @"stadium", @"staff", @"stage", @"stairs",
                 @"stamp", @"stand", @"start", @"state", @"stay", @"steak", @"steel", @"stem", @"step", @"stereo", @"stick", @"still",
                 @"sting", @"stock", @"stomach", @"stone", @"stool", @"story", @"stove", @"strategy", @"street", @"strike", @"strong",
                 @"struggle", @"student", @"stuff", @"stumble", @"style", @"subject", @"submit", @"subway", @"success", @"such",
                 @"sudden", @"suffer", @"sugar", @"suggest", @"suit", @"summer", @"sun", @"sunny", @"sunset", @"super", @"supply",
                 @"supreme", @"sure", @"surface", @"surge", @"surprise", @"surround", @"survey", @"suspect", @"sustain", @"swallow",
                 @"swamp", @"swap", @"swarm", @"swear", @"sweet", @"swift", @"swim", @"swing", @"switch", @"sword", @"symbol", @"symptom",
                 @"syrup", @"system", @"table", @"tackle", @"tag", @"tail", @"talent", @"talk", @"tank", @"tape", @"target", @"task",
                 @"taste", @"tattoo", @"taxi", @"teach", @"team", @"tell", @"ten", @"tenant", @"tennis", @"tent", @"term", @"test", @"text",
                 @"thank", @"that", @"theme", @"then", @"theory", @"there", @"they", @"thing", @"this", @"thought", @"three", @"thrive",
                 @"throw", @"thumb", @"thunder", @"ticket", @"tide", @"tiger", @"tilt", @"timber", @"time", @"tiny", @"tip", @"tired",
                 @"tissue", @"title", @"toast", @"tobacco", @"today", @"toddler", @"toe", @"together", @"toilet", @"token", @"tomato",
                 @"tomorrow", @"tone", @"tongue", @"tonight", @"tool", @"tooth", @"top", @"topic", @"topple", @"torch", @"tornado",
                 @"tortoise", @"toss", @"total", @"tourist", @"toward", @"tower", @"town", @"toy", @"track", @"trade", @"traffic",
                 @"tragic", @"train", @"transfer", @"trap", @"trash", @"travel", @"tray", @"treat", @"tree", @"trend", @"trial", @"tribe",
                 @"trick", @"trigger", @"trim", @"trip", @"trophy", @"trouble", @"truck", @"true", @"truly", @"trumpet", @"trust",
                 @"truth", @"try", @"tube", @"tuition", @"tumble", @"tuna", @"tunnel", @"turkey", @"turn", @"turtle", @"twelve", @"twenty",
                 @"twice", @"twin", @"twist", @"two", @"type", @"typical", @"ugly", @"umbrella", @"unable", @"unaware", @"uncle",
                 @"uncover", @"under", @"undo", @"unfair", @"unfold", @"unhappy", @"uniform", @"unique", @"unit", @"universe", @"unknown",
                 @"unlock", @"until", @"unusual", @"unveil", @"update", @"upgrade", @"uphold", @"upon", @"upper", @"upset", @"urban",
                 @"urge", @"usage", @"use", @"used", @"useful", @"useless", @"usual", @"utility", @"vacant", @"vacuum", @"vague", @"valid",
                 @"valley", @"valve", @"van", @"vanish", @"vapor", @"various", @"vast", @"vault", @"vehicle", @"velvet", @"vendor",
                 @"venture", @"venue", @"verb", @"verify", @"version", @"very", @"vessel", @"veteran", @"viable", @"vibrant", @"vicious",
                 @"victory", @"video", @"view", @"village", @"vintage", @"violin", @"virtual", @"virus", @"visa", @"visit", @"visual",
                 @"vital", @"vivid", @"vocal", @"voice", @"void", @"volcano", @"volume", @"vote", @"voyage", @"wage", @"wagon", @"wait",
                 @"walk", @"wall", @"walnut", @"want", @"warfare", @"warm", @"warrior", @"wash", @"wasp", @"waste", @"water", @"wave",
                 @"way", @"wealth", @"weapon", @"wear", @"weasel", @"weather", @"web", @"wedding", @"weekend", @"weird", @"welcome",
                 @"west", @"wet", @"whale", @"what", @"wheat", @"wheel", @"when", @"where", @"whip", @"whisper", @"wide", @"width", @"wife",
                 @"wild", @"will", @"win", @"window", @"wine", @"wing", @"wink", @"winner", @"winter", @"wire", @"wisdom", @"wise", @"wish",
                 @"witness", @"wolf", @"woman", @"wonder", @"wood", @"wool", @"word", @"work", @"world", @"worry", @"worth", @"wrap",
                 @"wreck", @"wrestle", @"wrist", @"write", @"wrong", @"yard", @"year", @"yellow", @"you", @"young", @"youth", @"zebra",
                 @"zero", @"zone", @"zoo"];
    });
    return list;
}


@end
