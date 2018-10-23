// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.

#import "BTCPaymentMethod.h"
#import "BTCProtocolBuffers.h"
#import "BTCAssetID.h"
#import "BTCAssetType.h"

//message PaymentMethod {
//    optional bytes             merchant_data = 1;
//    repeated PaymentMethodItem items         = 2;
//}
typedef NS_ENUM(NSInteger, BTCPaymentMethodKey) {
    BTCPaymentMethodKeyMerchantData = 1,
    BTCPaymentMethodKeyItem         = 2,
};


@interface BTCPaymentMethod ()
@property(nonatomic, readwrite, nonnull) NSData* data;
@end

@implementation BTCPaymentMethod

- (id) initWithData:(NSData*)data {
    if (!data) return nil;

    if (self = [super init]) {
        NSMutableArray* items = [NSMutableArray array];

        NSInteger offset = 0;
        while (offset < data.length) {
            uint64_t integer = 0;
            NSData* d = nil;

            switch ([BTCProtocolBuffers fieldAtOffset:&offset int:&integer data:&d fromData:data]) {
                case BTCPaymentMethodKeyMerchantData:
                    if (d) _merchantData = d;
                    break;

                case BTCPaymentMethodKeyItem: {
                    if (d) {
                        BTCPaymentMethodItem* item = [[BTCPaymentMethodItem alloc] initWithData:d];
                        [items addObject:item];
                    }
                    break;
                }
                default: break;
            }
        }

        _items = items;
        _data = data;
    }
    return self;
}

- (void) setMerchantData:(NSData * __nullable)merchantData {
    _merchantData = merchantData;
    _data = nil;
}

- (void) setItems:(NSArray * __nullable)items {
    _items = items;
    _data = nil;
}

- (NSData*) data {
    if (!_data) {
        NSMutableData* dst = [NSMutableData data];

        if (_merchantData) {
            [BTCProtocolBuffers writeData:_merchantData withKey:BTCPaymentMethodKeyMerchantData toData:dst];
        }
        for (BTCPaymentMethodItem* item in _items) {
            [BTCProtocolBuffers writeData:item.data withKey:BTCPaymentMethodKeyItem toData:dst];
        }
        _data = dst;
    }
    return _data;
}

@end




//message PaymentMethodItem {
//    optional string             type                = 1 [default = "default"];
//    optional bytes              item_identifier     = 2;
//    repeated PaymentMethodAsset payment_item_assets = 3;
//}
typedef NS_ENUM(NSInteger, BTCPaymentMethodItemKey) {
    BTCPaymentMethodItemKeyItemType          = 1, // default = "default"
    BTCPaymentMethodItemKeyItemIdentifier    = 2,
    BTCPaymentMethodItemKeyAssets            = 3,
};


@interface BTCPaymentMethodItem ()

@property(nonatomic, readwrite, nonnull) NSData* data;
@end

@implementation BTCPaymentMethodItem

- (id) initWithData:(NSData*)data {
    if (!data) return nil;

    if (self = [super init]) {

        NSMutableArray* assets = [NSMutableArray array];

        NSInteger offset = 0;
        while (offset < data.length) {
            uint64_t integer = 0;
            NSData* d = nil;

            switch ([BTCProtocolBuffers fieldAtOffset:&offset int:&integer data:&d fromData:data]) {
                case BTCPaymentMethodItemKeyItemType:
                    if (d) _itemType = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;
                case BTCPaymentMethodItemKeyItemIdentifier:
                    if (d) _itemIdentifier = d;
                    break;
                case BTCPaymentMethodItemKeyAssets: {
                    if (d) {
                        BTCPaymentMethodAsset* asset = [[BTCPaymentMethodAsset alloc] initWithData:d];
                        [assets addObject:asset];
                    }
                    break;
                }
                default: break;
            }
        }

        _assets = assets;
        _data = data;
    }
    return self;
}

- (void) setItemType:(NSString * __nonnull)itemType {
    _itemType = itemType;
    _data = nil;
}

- (void) setItemIdentifier:(NSData * __nullable)itemIdentifier {
    _itemIdentifier = itemIdentifier;
    _data = nil;
}

- (void) setAssets:(NSArray * __nullable)assets {
    _assets = assets;
    _data = nil;
}

- (NSData*) data {
    if (!_data) {
        NSMutableData* dst = [NSMutableData data];

        if (_itemType) {
            [BTCProtocolBuffers writeString:_itemType withKey:BTCPaymentMethodItemKeyItemType toData:dst];
        }
        if (_itemIdentifier) {
            [BTCProtocolBuffers writeData:_itemIdentifier withKey:BTCPaymentMethodItemKeyItemIdentifier toData:dst];
        }
        for (BTCPaymentMethodItem* item in _assets) {
            [BTCProtocolBuffers writeData:item.data withKey:BTCPaymentMethodItemKeyAssets toData:dst];
        }
        _data = dst;
    }
    return _data;
}

@end






//message PaymentMethodAsset {
//    optional string            asset_id = 1 [default = "default"];
//    optional uint64            amount = 2;
//}
typedef NS_ENUM(NSInteger, BTCPaymentMethodAssetKey) {
    BTCPaymentMethodAssetKeyAssetID = 1,
    BTCPaymentMethodAssetKeyAmount  = 2,
};


@interface BTCPaymentMethodAsset ()

@property(nonatomic, readwrite, nonnull) NSData* data;
@end

@implementation BTCPaymentMethodAsset

- (id) initWithData:(NSData*)data {
    if (!data) return nil;

    if (self = [super init]) {

        NSString* assetIDString = nil;

        NSInteger offset = 0;
        while (offset < data.length) {
            uint64_t integer = 0;
            NSData* d = nil;

            switch ([BTCProtocolBuffers fieldAtOffset:&offset int:&integer data:&d fromData:data]) {
                case BTCPaymentMethodAssetKeyAssetID:
                    if (d) assetIDString = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;
                case BTCPaymentMethodAssetKeyAmount: {
                    _amount = integer;
                    break;
                }
                default: break;
            }
        }
        if (!assetIDString || [assetIDString isEqual:@"default"]) {
            _assetType = BTCAssetTypeBitcoin;
            _assetID = nil;
        } else {
            _assetID = [BTCAssetID assetIDWithString:assetIDString];
            if (_assetID) {
                _assetType = BTCAssetTypeOpenAssets;
            }
        }
        _data = data;
    }
    return self;
}

- (void) setAssetType:(NSString * __nullable)assetType {
    _assetType = assetType;
    _data = nil;
}

- (void) setAssetID:(BTCAssetID * __nullable)assetID {
    _assetID = assetID;
    _data = nil;
}

- (void) setAmount:(BTCAmount)amount {
    _amount = amount;
    _data = nil;
}

- (NSData*) data {
    if (!_data) {
        NSMutableData* dst = [NSMutableData data];

        if ([_assetType isEqual:BTCAssetTypeBitcoin]) {
            [BTCProtocolBuffers writeString:@"default" withKey:BTCPaymentMethodAssetKeyAssetID toData:dst];
        } else if ([_assetType isEqual:BTCAssetTypeOpenAssets] && _assetID) {
            [BTCProtocolBuffers writeString:_assetID.string withKey:BTCPaymentMethodAssetKeyAssetID toData:dst];
        }

        [BTCProtocolBuffers writeInt:(uint64_t)_amount withKey:BTCPaymentMethodAssetKeyAmount toData:dst];
        _data = dst;
    }
    return _data;
}

@end




//message PaymentMethodRejection {
//    optional string memo = 1;
//    repeated PaymentMethodRejectedAsset rejected_assets = 2;
//}
typedef NS_ENUM(NSInteger, BTCPaymentMethodRejectionKey) {
    BTCPaymentMethodRejectionKeyMemo   = 1,
    BTCPaymentMethodRejectionKeyCode   = 2,
    BTCPaymentMethodRejectionKeyAssets = 3,
};


@interface BTCPaymentMethodRejection ()

@property(nonatomic, readwrite, nonnull) NSData* data;
@end

@implementation BTCPaymentMethodRejection

- (id) initWithData:(NSData*)data {
    if (!data) return nil;

    if (self = [super init]) {

        NSMutableArray* rejectedAssets = [NSMutableArray array];

        NSInteger offset = 0;
        while (offset < data.length) {
            uint64_t integer = 0;
            NSData* d = nil;

            switch ([BTCProtocolBuffers fieldAtOffset:&offset int:&integer data:&d fromData:data]) {
                case BTCPaymentMethodRejectionKeyMemo:
                    if (d) _memo = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;
                case BTCPaymentMethodRejectionKeyCode:
                    _code = integer;
                    break;
                case BTCPaymentMethodRejectionKeyAssets: {
                    if (d) {
                        BTCPaymentMethodRejectedAsset* rejasset = [[BTCPaymentMethodRejectedAsset alloc] initWithData:d];
                        [rejectedAssets addObject:rejasset];
                    }
                    break;
                }
                default: break;
            }
        }

        _rejectedAssets = rejectedAssets;
        _data = data;
    }
    return self;
}

- (void) setMemo:(NSString * __nullable)memo {
    _memo = [memo copy];
    _data = nil;
}

- (void) setCode:(uint64_t)code {
    _code = code;
    _data = nil;
}

- (void) setRejectedAssets:(NSArray * __nullable)rejectedAssets {
    _rejectedAssets = rejectedAssets;
    _data = nil;
}

- (NSData*) data {
    if (!_data) {
        NSMutableData* dst = [NSMutableData data];

        if (_memo) {
            [BTCProtocolBuffers writeString:_memo withKey:BTCPaymentMethodRejectionKeyMemo toData:dst];
        }

        [BTCProtocolBuffers writeInt:_code withKey:BTCPaymentMethodRejectionKeyCode toData:dst];

        for (BTCPaymentMethodRejectedAsset* rejectedAsset in _rejectedAssets) {
            [BTCProtocolBuffers writeData:rejectedAsset.data withKey:BTCPaymentMethodRejectionKeyAssets toData:dst];
        }

        _data = dst;
    }
    return _data;
}

@end


//message PaymentMethodRejectedAsset {
//    required string asset_id = 1;
//    optional uint64 code     = 2;
//    optional string reason   = 3;
//}
typedef NS_ENUM(NSInteger, BTCPaymentMethodRejectedAssetKey) {
    BTCPaymentMethodRejectedAssetKeyAssetID = 1,
    BTCPaymentMethodRejectedAssetKeyCode    = 2,
    BTCPaymentMethodRejectedAssetKeyReason  = 3,
};


@interface BTCPaymentMethodRejectedAsset ()

@property(nonatomic, readwrite, nonnull) NSData* data;
@end

@implementation BTCPaymentMethodRejectedAsset

- (id) initWithData:(NSData*)data {
    if (!data) return nil;

    if (self = [super init]) {

        NSString* assetIDString = nil;

        NSInteger offset = 0;
        while (offset < data.length) {
            uint64_t integer = 0;
            NSData* d = nil;

            switch ([BTCProtocolBuffers fieldAtOffset:&offset int:&integer data:&d fromData:data]) {
                case BTCPaymentMethodRejectedAssetKeyAssetID:
                    if (d) assetIDString = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;
                case BTCPaymentMethodRejectionKeyCode:
                    _code = integer;
                    break;
                case BTCPaymentMethodRejectedAssetKeyReason: {
                    if (d) _reason = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;
                }
                default: break;
            }
        }
        if (!assetIDString || [assetIDString isEqual:@"default"]) {
            _assetType = BTCAssetTypeBitcoin;
            _assetID = nil;
        } else {
            _assetID = [BTCAssetID assetIDWithString:assetIDString];
            if (_assetID) {
                _assetType = BTCAssetTypeOpenAssets;
            }
        }
        _data = data;
    }
    return self;
}

- (void) setAssetType:(NSString * __nonnull)assetType {
    _assetType = assetType;
    _data = nil;
}

- (void) setAssetID:(BTCAssetID * __nullable)assetID {
    _assetID = assetID;
    _data = nil;
}

- (void) setCode:(uint64_t)code {
    _code = code;
    _data = nil;
}

- (void) setReason:(NSString * __nullable)reason {
    _reason = reason;
    _data = nil;
}

- (NSData*) data {
    if (!_data) {
        NSMutableData* dst = [NSMutableData data];

        if ([_assetType isEqual:BTCAssetTypeBitcoin]) {
            [BTCProtocolBuffers writeString:@"default" withKey:BTCPaymentMethodRejectedAssetKeyAssetID toData:dst];
        } else if ([_assetType isEqual:BTCAssetTypeOpenAssets] && _assetID) {
            [BTCProtocolBuffers writeString:_assetID.string withKey:BTCPaymentMethodRejectedAssetKeyAssetID toData:dst];
        }

        [BTCProtocolBuffers writeInt:_code withKey:BTCPaymentMethodRejectedAssetKeyCode toData:dst];

        if (_reason) {
            [BTCProtocolBuffers writeString:_reason withKey:BTCPaymentMethodRejectedAssetKeyReason toData:dst];
        }

        _data = dst;
    }
    return _data;
}

@end
