#import "BTCNumberFormatter.h"

#define NarrowNbsp @"\xE2\x80\xAF"
//#define PunctSpace @" "
//#define ThinSpace  @" "

NSString* const BTCNumberFormatterBitcoinCode    = @"XBT";

NSString* const BTCNumberFormatterSymbolBTC      = @"Ƀ" @"";
NSString* const BTCNumberFormatterSymbolMilliBTC = @"mɃ";
NSString* const BTCNumberFormatterSymbolBit      = @"ƀ";
NSString* const BTCNumberFormatterSymbolSatoshi  = @"ṡ";

BTCAmount BTCAmountFromDecimalNumber(NSNumber* num) {
    if ([num isKindOfClass:[NSDecimalNumber class]]) {
        NSDecimalNumber* dnum = (id)num;
        // Starting iOS 8.0.2, the longLongValue method returns 0 for some non rounded values.
        // Rounding the number looks like a work around.
        NSDecimalNumberHandler *roundingBehavior = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundPlain
                                                                                                          scale:0
                                                                                               raiseOnExactness:NO
                                                                                                raiseOnOverflow:YES
                                                                                               raiseOnUnderflow:NO
                                                                                            raiseOnDivideByZero:YES];
        num = [dnum decimalNumberByRoundingAccordingToBehavior:roundingBehavior];
    }
    BTCAmount sat = [num longLongValue];
    return sat;
}

@implementation BTCNumberFormatter {
    NSDecimalNumber* _myMultiplier; // because standard multiplier when below 1e-6 leads to a rounding no matter what the settings.
}

- (id) initWithBitcoinUnit:(BTCNumberFormatterUnit)unit {
    return [self initWithBitcoinUnit:unit symbolStyle:BTCNumberFormatterSymbolStyleNone];
}

- (id) initWithBitcoinUnit:(BTCNumberFormatterUnit)unit symbolStyle:(BTCNumberFormatterSymbolStyle)symbolStyle {
    if (self = [super init]) {
        _bitcoinUnit = unit;
        _symbolStyle = symbolStyle;

        [self updateFormatterProperties];
    }
    return self;
}

- (void) setBitcoinUnit:(BTCNumberFormatterUnit)bitcoinUnit {
    if (_bitcoinUnit == bitcoinUnit) return;
    _bitcoinUnit = bitcoinUnit;
    [self updateFormatterProperties];
}

- (void) setSymbolStyle:(BTCNumberFormatterSymbolStyle)suffixStyle {
    if (_symbolStyle == suffixStyle) return;
    _symbolStyle = suffixStyle;
    [self updateFormatterProperties];
}

- (void) updateFormatterProperties {
    // Reset formats so they are recomputed after we change properties.
    self.positiveFormat = nil;
    self.negativeFormat = nil;

    self.lenient = YES;
    self.generatesDecimalNumbers = YES;
    self.numberStyle = NSNumberFormatterCurrencyStyle;
    self.currencyCode = @"XBT";
    self.groupingSize = 3;

    self.currencySymbol = [self bitcoinUnitSymbol] ?: @"";

    self.internationalCurrencySymbol = self.currencySymbol;

    // On iOS 8 we have to set these *after* setting the currency symbol.
    switch (_bitcoinUnit) {
        case BTCNumberFormatterUnitSatoshi:
            _myMultiplier = [NSDecimalNumber decimalNumberWithMantissa:1 exponent:0 isNegative:NO];
            self.minimumFractionDigits = 0;
            self.maximumFractionDigits = 0;
            break;
        case BTCNumberFormatterUnitBit:
            _myMultiplier = [NSDecimalNumber decimalNumberWithMantissa:1 exponent:-2 isNegative:NO];
            self.minimumFractionDigits = 0;
            self.maximumFractionDigits = 2;
            break;
        case BTCNumberFormatterUnitMilliBTC:
            _myMultiplier = [NSDecimalNumber decimalNumberWithMantissa:1 exponent:-5 isNegative:NO];
            self.minimumFractionDigits = 2;
            self.maximumFractionDigits = 5;
            break;
        case BTCNumberFormatterUnitBTC:
            _myMultiplier = [NSDecimalNumber decimalNumberWithMantissa:1 exponent:-8 isNegative:NO];
            self.minimumFractionDigits = 2;
            self.maximumFractionDigits = 8;
            break;
        default:
            [[NSException exceptionWithName:@"BTCNumberFormatter: not supported bitcoin unit" reason:@"" userInfo:nil] raise];
    }

    switch (_symbolStyle) {
        case BTCNumberFormatterSymbolStyleNone:
            self.minimumFractionDigits = 0;
            self.positivePrefix = @"";
            self.positiveSuffix = @"";
            self.negativePrefix = @"–";
            self.negativeSuffix = @"";
            break;
        case BTCNumberFormatterSymbolStyleCode:
        case BTCNumberFormatterSymbolStyleLowercase:
            self.positivePrefix = @"";
            self.positiveSuffix = [NSString stringWithFormat:@" %@", self.currencySymbol]; // nobreaking space here.
            self.negativePrefix = @"-";
            self.negativeSuffix = self.positiveSuffix;
            break;

        case BTCNumberFormatterSymbolStyleSymbol:
            // Leave positioning of the currency symbol to locale (in English it'll be prefix, in French it'll be suffix).
            break;
    }
    self.maximum = @(BTC_MAX_MONEY);

    // Fixup prefix symbol with a no-breaking space. When it's postfix, Foundation puts nobr space already.
    self.positiveFormat = [self.positiveFormat stringByReplacingOccurrencesOfString:@"¤" withString:@"¤" NarrowNbsp "#"];

    // Fixup negative format to have the same format as positive format and a minus sign in front of the first digit.
    self.negativeFormat = [self.positiveFormat stringByReplacingCharactersInRange:[self.positiveFormat rangeOfString:@"#"] withString:@"–#"];
}

- (NSString *) standaloneSymbol {
    NSString* sym = [self bitcoinUnitSymbol];
    if (!sym) {
        sym = [self bitcoinUnitSymbolForUnit:_bitcoinUnit];
    }
    return sym;
}

- (NSString*) bitcoinUnitSymbol {
    return [self bitcoinUnitSymbolForStyle:_symbolStyle unit:_bitcoinUnit];
}

- (NSString*) unitCode {
    return [self bitcoinUnitCodeForUnit:_bitcoinUnit];
}

- (NSString*) bitcoinUnitCodeForUnit:(BTCNumberFormatterUnit)unit {
    switch (unit) {
        case BTCNumberFormatterUnitSatoshi:
            return NSLocalizedStringFromTable(@"SAT", @"CoreBitcoin", @"");
        case BTCNumberFormatterUnitBit:
            return NSLocalizedStringFromTable(@"Bits", @"CoreBitcoin", @"");
        case BTCNumberFormatterUnitMilliBTC:
            return NSLocalizedStringFromTable(@"mBTC", @"CoreBitcoin", @"");
        case BTCNumberFormatterUnitBTC:
            return NSLocalizedStringFromTable(@"BTC", @"CoreBitcoin", @"");
        default:
            [[NSException exceptionWithName:@"BTCNumberFormatter: not supported bitcoin unit" reason:@"" userInfo:nil] raise];
    }
}

- (NSString*) bitcoinUnitSymbolForUnit:(BTCNumberFormatterUnit)unit {
    switch (unit) {
        case BTCNumberFormatterUnitSatoshi:
            return BTCNumberFormatterSymbolSatoshi;
        case BTCNumberFormatterUnitBit:
            return BTCNumberFormatterSymbolBit;
        case BTCNumberFormatterUnitMilliBTC:
            return BTCNumberFormatterSymbolMilliBTC;
        case BTCNumberFormatterUnitBTC:
            return BTCNumberFormatterSymbolBTC;
        default:
            [[NSException exceptionWithName:@"BTCNumberFormatter: not supported bitcoin unit" reason:@"" userInfo:nil] raise];
    }
}

- (NSString*) bitcoinUnitSymbolForStyle:(BTCNumberFormatterSymbolStyle)symbolStyle unit:(BTCNumberFormatterUnit)bitcoinUnit {
    switch (symbolStyle) {
        case BTCNumberFormatterSymbolStyleNone:
            return nil;
        case BTCNumberFormatterSymbolStyleCode:
            return [self bitcoinUnitCodeForUnit:bitcoinUnit];
        case BTCNumberFormatterSymbolStyleLowercase:
            return [[self bitcoinUnitCodeForUnit:bitcoinUnit] lowercaseString];
        case BTCNumberFormatterSymbolStyleSymbol:
            return [self bitcoinUnitSymbolForUnit:bitcoinUnit];
        default:
            [[NSException exceptionWithName:@"BTCNumberFormatter: not supported symbol style" reason:@"" userInfo:nil] raise];
    }
    return nil;
}

- (NSString *) placeholderText {
    //NSString* groupSeparator = self.currencyGroupingSeparator ?: @"";
    NSString* decimalPoint = self.currencyDecimalSeparator ?: @".";
    switch (_bitcoinUnit) {
        case BTCNumberFormatterUnitSatoshi:
            return @"0";
        case BTCNumberFormatterUnitBit:
            return [NSString stringWithFormat:@"0%@00", decimalPoint];
        case BTCNumberFormatterUnitMilliBTC:
            return [NSString stringWithFormat:@"0%@00000", decimalPoint];
        case BTCNumberFormatterUnitBTC:
            return [NSString stringWithFormat:@"0%@00000000", decimalPoint];
        default:
            [[NSException exceptionWithName:@"BTCNumberFormatter: not supported bitcoin unit" reason:@"" userInfo:nil] raise];
            return nil;
    }
}

- (NSString*) stringFromNumber:(NSNumber *)number {
    if (![number isKindOfClass:[NSDecimalNumber class]]) {
        number = [NSDecimalNumber decimalNumberWithDecimal:number.decimalValue];
    }
    return [super stringFromNumber:[(NSDecimalNumber*)number decimalNumberByMultiplyingBy:_myMultiplier]];
}

- (NSNumber*) numberFromString:(NSString *)string {
    // self.generatesDecimalNumbers guarantees NSDecimalNumber here.
    NSDecimalNumber* number = (NSDecimalNumber*)[super numberFromString:string];
    return [number decimalNumberByDividingBy:_myMultiplier];
}

- (NSString *) stringFromAmount:(BTCAmount)amount {
    return [self stringFromNumber:@(amount)];
}

- (BTCAmount) amountFromString:(NSString *)string {
    return BTCAmountFromDecimalNumber([self numberFromString:string]);
}

- (id) copyWithZone:(NSZone *)zone {
    return [[BTCNumberFormatter alloc] initWithBitcoinUnit:self.bitcoinUnit symbolStyle:self.symbolStyle];
}


@end
