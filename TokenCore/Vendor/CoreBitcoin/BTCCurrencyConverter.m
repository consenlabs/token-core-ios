#import "BTCCurrencyConverter.h"
#import "BTCNumberFormatter.h"

@implementation BTCCurrencyConverter

- (id) init {
    if (self = [super init]) {
        _mode = BTCCurrencyConverterModeAverage;
    }
    return self;
}

- (id) initWithDictionary:(NSDictionary *)dict {
    if (!dict) return nil;

    if (self = [self init]) {
        if (dict[@"mode"])     _mode = [dict[@"mode"] unsignedIntegerValue];
        if (dict[@"currency"]) _currencyCode = dict[@"currency"];
        if (dict[@"mkt"])      _sourceName = dict[@"mkt"];
        if (dict[@"t"])        _date = [NSDate dateWithTimeIntervalSince1970:[dict[@"t"] doubleValue]];
        if (dict[@"avg"])      _averageRate = [NSDecimalNumber decimalNumberWithString:dict[@"avg"]];
        if (dict[@"buy"])      _buyRate = [NSDecimalNumber decimalNumberWithString:dict[@"buy"]];
        if (dict[@"sell"])     _buyRate = [NSDecimalNumber decimalNumberWithString:dict[@"sell"]];

        // TODO: parse asks and bids.
    }
    return self;
}

- (NSDictionary*) dictionary {
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];

    if (_mode)         dict[@"mode"] = @(_mode);
    if (_currencyCode) dict[@"currency"] = _currencyCode;
    if (_sourceName)   dict[@"mkt"] = _sourceName;
    if (_date)         dict[@"t"] = @(_date.timeIntervalSince1970);
    if (_averageRate)  dict[@"avg"] = _averageRate.stringValue;
    if (_buyRate)      dict[@"buy"] = _buyRate.stringValue;
    if (_sellRate)     dict[@"sell"] = _sellRate.stringValue;
    if (_asks)         dict[@"asks"] = [self encodeTuples:_asks];
    if (_bids)         dict[@"bids"] = [self encodeTuples:_bids];
    return dict;
}

- (NSArray*) encodeTuples:(NSArray*)tuples {
    NSMutableArray* arr = [NSMutableArray array];

    for (NSArray* tuple in tuples) {
        [arr addObject:@[ [tuple[0] stringValue], [tuple[1] stringValue] ]];
    }

    return arr;
}

- (void) setMarketName:(NSString *)marketName {
    self.sourceName = marketName;
}

- (NSString*) marketName {
    return self.sourceName;
}

- (void) setAverageRate:(NSDecimalNumber *)averageRate {
    _averageRate = averageRate;
    _buyRate = averageRate;
    _sellRate = averageRate;
    _bids = nil;
    _asks = nil;
    _date = [NSDate date];
}

- (void) setBuyRate:(NSDecimalNumber *)buyRate {
    _buyRate = buyRate;
    _sellRate = _sellRate ?: buyRate;
    _averageRate = [[_sellRate decimalNumberByAdding:_buyRate] decimalNumberByMultiplyingBy:[NSDecimalNumber decimalNumberWithMantissa:5 exponent:-1 isNegative:NO]];
    _bids = nil;
    _asks = nil;
    _date = [NSDate date];
}

- (void) setSellRate:(NSDecimalNumber *)sellRate {
    _buyRate = _buyRate ?: sellRate;
    _sellRate = sellRate;
    _averageRate = [[_sellRate decimalNumberByAdding:_buyRate] decimalNumberByMultiplyingBy:[NSDecimalNumber decimalNumberWithMantissa:5 exponent:-1 isNegative:NO]];
    _bids = nil;
    _asks = nil;
    _date = [NSDate date];
}

- (void) setAsks:(NSArray *)asks {
    if (!asks || asks.count == 0) {
        _asks = nil;
        return;
    }

    // TODO: sort in ascending order
    // TODO: get the lowest value as a buy rate.

    _asks = asks;
}

- (void) setBids:(NSArray *)bids {
    if (!bids || bids.count == 0) {
        _bids = nil;
        return;
    }
    // TODO: sort in descending order
    // TODO: get the highest value as a sell rate.

    _bids = bids;
}


- (BTCAmount) bitcoinFromFiat:(NSDecimalNumber*)fiatAmount {
    switch (_mode) {
        case BTCCurrencyConverterModeAverage:
            if ([self isZero:_averageRate]) return 0;
            return BTCAmountFromDecimalNumber([[fiatAmount decimalNumberByDividingBy:_averageRate] decimalNumberByMultiplyingByPowerOf10:8]);

        case BTCCurrencyConverterModeBuy:
            if ([self isZero:_buyRate]) return 0;
            return BTCAmountFromDecimalNumber([[fiatAmount decimalNumberByDividingBy:_buyRate] decimalNumberByMultiplyingByPowerOf10:8]);

        case BTCCurrencyConverterModeSell:
            if ([self isZero:_sellRate]) return 0;
            return BTCAmountFromDecimalNumber([[fiatAmount decimalNumberByDividingBy:_sellRate] decimalNumberByMultiplyingByPowerOf10:8]);

            // TODO: add order book modes

        default:
            [[NSException exceptionWithName:@"BTCCurrencyConverter Not supported Mode" reason:@"This mode is not supported yet" userInfo:nil] raise];
            break;
    }

    return 0;
}

- (NSDecimalNumber*) fiatFromBitcoin:(BTCAmount)satoshis {
    switch (_mode) {
        case BTCCurrencyConverterModeAverage:
            if ([self isZero:_averageRate]) return nil;
            return [[NSDecimalNumber decimalNumberWithMantissa:ABS(satoshis) exponent:-8 isNegative:satoshis < 0] decimalNumberByMultiplyingBy:_averageRate];

        case BTCCurrencyConverterModeBuy:
            if ([self isZero:_buyRate]) return nil;
            return [[NSDecimalNumber decimalNumberWithMantissa:ABS(satoshis) exponent:-8 isNegative:satoshis < 0] decimalNumberByMultiplyingBy:_buyRate];

        case BTCCurrencyConverterModeSell:
            if ([self isZero:_sellRate]) return nil;
            return [[NSDecimalNumber decimalNumberWithMantissa:ABS(satoshis) exponent:-8 isNegative:satoshis < 0] decimalNumberByMultiplyingBy:_sellRate];

            // TODO: add order book modes

        default:
            [[NSException exceptionWithName:@"BTCCurrencyConverter Not supported Mode" reason:@"This mode is not supported yet" userInfo:nil] raise];
    }

    return nil;
}

- (BOOL) isZero:(NSDecimalNumber*)dn {
    if (!dn) return YES;
    if ([dn isEqual:[NSDecimalNumber zero]]) return YES;
    return NO;
}

- (id) copyWithZone:(NSZone *)zone {
    return [[BTCCurrencyConverter alloc] initWithDictionary:self.dictionary];
}


@end
