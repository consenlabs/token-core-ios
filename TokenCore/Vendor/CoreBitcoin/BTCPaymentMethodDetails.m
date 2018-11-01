// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.

#import "BTCPaymentMethodDetails.h"
#import "BTCPaymentProtocol.h"
#import "BTCProtocolBuffers.h"
#import "BTCNetwork.h"
#import "BTCAssetType.h"
#import "BTCAssetID.h"

//message PaymentMethodDetails {
//    optional string        network            = 1 [default = "main"];
//    required string        payment_method_url = 2;
//    repeated PaymentItem   items              = 3;
//    required uint64        time               = 4;
//    optional uint64        expires            = 5;
//    optional string        memo               = 6;
//    optional bytes         merchant_data      = 7;
//}
typedef NS_ENUM(NSInteger, BTCPMDetailsKey) {
    BTCPMDetailsKeyNetwork            = 1,
    BTCPMDetailsKeyPaymentMethodURL   = 2,
    BTCPMDetailsKeyItems              = 3,
    BTCPMDetailsKeyTime               = 4,
    BTCPMDetailsKeyExpires            = 5,
    BTCPMDetailsKeyMemo               = 6,
    BTCPMDetailsKeyMerchantData       = 7,
};

@interface BTCPaymentMethodDetails ()
@property(nonatomic, readwrite) BTCNetwork* network;
@property(nonatomic, readwrite) NSArray* /* [BTCPaymentMethodRequestItem] */ items;
@property(nonatomic, readwrite) NSURL* paymentMethodURL;
@property(nonatomic, readwrite) NSDate* date;
@property(nonatomic, readwrite) NSDate* expirationDate;
@property(nonatomic, readwrite) NSString* memo;
@property(nonatomic, readwrite) NSData* merchantData;
@property(nonatomic, readwrite) NSData* data;
@end

@implementation BTCPaymentMethodDetails

- (id) initWithData:(NSData*)data {
    if (!data) return nil;

    if (self = [super init]) {
        NSMutableArray* items = [NSMutableArray array];

        NSInteger offset = 0;
        while (offset < data.length) {
            uint64_t integer = 0;
            NSData* d = nil;

            switch ([BTCProtocolBuffers fieldAtOffset:&offset int:&integer data:&d fromData:data]) {
                case BTCPMDetailsKeyNetwork:
                    if (d) {
                        NSString* networkName = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                        if ([networkName isEqual:@"main"]) {
                            _network = [BTCNetwork mainnet];
                        } else if ([networkName isEqual:@"test"]) {
                            _network = [BTCNetwork testnet];
                        } else {
                            _network = [[BTCNetwork alloc] initWithName:networkName];
                        }
                    }
                    break;
                case BTCPMDetailsKeyPaymentMethodURL:
                    if (d) _paymentMethodURL = [NSURL URLWithString:[[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding]];
                    break;
                case BTCPMDetailsKeyItems: {
                    if (d) {
                        BTCPaymentMethodDetailsItem* item = [[BTCPaymentMethodDetailsItem alloc] initWithData:d];
                        [items addObject:item];
                    }
                    break;
                }
                case BTCPMDetailsKeyTime:
                    if (integer) _date = [NSDate dateWithTimeIntervalSince1970:integer];
                    break;
                case BTCPMDetailsKeyExpires:
                    if (integer) _expirationDate = [NSDate dateWithTimeIntervalSince1970:integer];
                    break;
                case BTCPMDetailsKeyMemo:
                    if (d) _memo = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;
                case BTCPMDetailsKeyMerchantData:
                    if (d) _merchantData = d;
                    break;
                default: break;
            }
        }

        // PMR must have at least one item
        if (items.count == 0) return nil;

        // PMR requires a creation time.
        if (!_date) return nil;

        _items = items;
        _data = data;
    }
    return self;
}

- (BTCNetwork*) network {
    return _network ?: [BTCNetwork mainnet];
}

- (NSData*) data {
    if (!_data) {
        NSMutableData* dst = [NSMutableData data];

        if (_network) {
            [BTCProtocolBuffers writeString:_network.paymentProtocolName withKey:BTCPMDetailsKeyNetwork toData:dst];
        }
        if (_paymentMethodURL) {
            [BTCProtocolBuffers writeString:_paymentMethodURL.absoluteString withKey:BTCPMDetailsKeyPaymentMethodURL toData:dst];
        }
        for (BTCPaymentMethodDetailsItem* item in _items) {
            [BTCProtocolBuffers writeData:item.data withKey:BTCPMDetailsKeyItems toData:dst];
        }
        if (_date) {
            [BTCProtocolBuffers writeInt:(uint64_t)[_date timeIntervalSince1970] withKey:BTCPMDetailsKeyTime toData:dst];
        }
        if (_expirationDate) {
            [BTCProtocolBuffers writeInt:(uint64_t)[_expirationDate timeIntervalSince1970] withKey:BTCPMDetailsKeyExpires toData:dst];
        }
        if (_memo) {
            [BTCProtocolBuffers writeString:_memo withKey:BTCPMDetailsKeyMemo toData:dst];
        }
        if (_merchantData) {
            [BTCProtocolBuffers writeData:_merchantData withKey:BTCPMDetailsKeyMerchantData toData:dst];
        }
        _data = dst;
    }
    return _data;
}

@end





//message PaymentItem {
//    optional string type                   = 1 [default = "default"];
//    optional bool   optional               = 2 [default = false];
//    optional bytes  item_identifier        = 3;
//    optional uint64 amount                 = 4 [default = 0];
//    repeated AcceptedAsset accepted_assets = 5;
//    optional string memo                   = 6;
//}
typedef NS_ENUM(NSInteger, BTCPMItemKey) {
    BTCPMRItemKeyItemType           = 1,
    BTCPMRItemKeyItemOptional       = 2,
    BTCPMRItemKeyItemIdentifier     = 3,
    BTCPMRItemKeyAmount             = 4,
    BTCPMRItemKeyAcceptedAssets     = 5,
    BTCPMRItemKeyMemo               = 6,
};

@interface BTCPaymentMethodDetailsItem ()
@property(nonatomic, readwrite, nullable) NSString* itemType;
@property(nonatomic, readwrite) BOOL optional;
@property(nonatomic, readwrite, nullable) NSData* itemIdentifier;
@property(nonatomic, readwrite) BTCAmount amount;
@property(nonatomic, readwrite, nonnull) NSArray* /* [BTCPaymentMethodAcceptedAsset] */ acceptedAssets;
@property(nonatomic, readwrite, nullable) NSString* memo;
@property(nonatomic, readwrite, nonnull) NSData* data;
@end

@implementation BTCPaymentMethodDetailsItem

- (id) initWithData:(NSData*)data {
    if (!data) return nil;

    if (self = [super init]) {
        NSMutableArray* assets = [NSMutableArray array];

        NSInteger offset = 0;
        while (offset < data.length) {
            uint64_t integer = 0;
            NSData* d = nil;

            switch ([BTCProtocolBuffers fieldAtOffset:&offset int:&integer data:&d fromData:data]) {
                case BTCPMRItemKeyItemType:
                    if (d) _itemType = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;
                case BTCPMRItemKeyItemOptional:
                    _optional = (integer != 0);
                    break;
                case BTCPMRItemKeyItemIdentifier:
                    if (d) _itemIdentifier = d;
                    break;

                case BTCPMRItemKeyAmount: {
                    _amount = integer;
                    break;
                }
                case BTCPMRItemKeyAcceptedAssets: {
                    if (d) {
                        BTCPaymentMethodAcceptedAsset* asset = [[BTCPaymentMethodAcceptedAsset alloc] initWithData:d];
                        [assets addObject:asset];
                    }
                    break;
                }
                case BTCPMRItemKeyMemo:
                    if (d) _memo = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;
                default: break;
            }
        }
        _acceptedAssets = assets;
        _data = data;
    }
    return self;
}


- (NSData*) data {
    if (!_data) {
        NSMutableData* dst = [NSMutableData data];

        if (_itemType) {
            [BTCProtocolBuffers writeString:_itemType withKey:BTCPMRItemKeyItemType toData:dst];
        }
        [BTCProtocolBuffers writeInt:_optional ? 1 : 0 withKey:BTCPMRItemKeyItemOptional toData:dst];
        if (_itemIdentifier) {
            [BTCProtocolBuffers writeData:_itemIdentifier withKey:BTCPMRItemKeyItemIdentifier toData:dst];
        }
        if (_amount > 0) {
             [BTCProtocolBuffers writeInt:(uint64_t)_amount withKey:BTCPMRItemKeyAmount toData:dst];
        }
        for (BTCPaymentMethodAcceptedAsset* asset in _acceptedAssets) {
            [BTCProtocolBuffers writeData:asset.data withKey:BTCPMRItemKeyAcceptedAssets toData:dst];
        }
        if (_memo) {
            [BTCProtocolBuffers writeString:_memo withKey:BTCPMRItemKeyMemo toData:dst];
        }
        _data = dst;
    }
    return _data;
}

@end





//message AcceptedAsset {
//    optional string asset_id = 1 [default = "default"];
//    optional string asset_group = 2;
//    optional double multiplier = 3 [default = 1.0];
//    optional uint64 min_amount = 4 [default = 0];
//    optional uint64 max_amount = 5;
//}
typedef NS_ENUM(NSInteger, BTCPMAcceptedAssetKey) {
    BTCPMRAcceptedAssetKeyAssetID    = 1,
    BTCPMRAcceptedAssetKeyAssetGroup = 2,
    BTCPMRAcceptedAssetKeyMultiplier = 3,
    BTCPMRAcceptedAssetKeyMinAmount  = 4,
    BTCPMRAcceptedAssetKeyMaxAmount  = 5,
};


@interface BTCPaymentMethodAcceptedAsset ()
@property(nonatomic, readwrite, nullable) NSString* assetType; // BTCAssetTypeBitcoin or BTCAssetTypeOpenAssets
@property(nonatomic, readwrite, nullable) BTCAssetID* assetID;
@property(nonatomic, readwrite, nullable) NSString* assetGroup;
@property(nonatomic, readwrite) double multiplier; // to use as a multiplier need to multiply by that amount and divide by 1e8.
@property(nonatomic, readwrite) BTCAmount minAmount;
@property(nonatomic, readwrite) BTCAmount maxAmount;
@property(nonatomic, readwrite, nonnull) NSData* data;
@end

@implementation BTCPaymentMethodAcceptedAsset


- (id) initWithData:(NSData*)data {
    if (!data) return nil;

    if (self = [super init]) {

        NSString* assetIDString = nil;

        _multiplier = 1.0;

        NSInteger offset = 0;
        while (offset < data.length) {
            uint64_t integer = 0;
            uint64_t fixed64 = 0;
            NSData* d = nil;
            switch ([BTCProtocolBuffers fieldAtOffset:&offset int:&integer fixed32:NULL fixed64:&fixed64 data:&d fromData:data]) {
                case BTCPMRAcceptedAssetKeyAssetID:
                    if (d) assetIDString = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;

                case BTCPMRAcceptedAssetKeyAssetGroup: {
                    if (d) _assetGroup = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;
                }
                case BTCPMRAcceptedAssetKeyMultiplier: {
                    _multiplier = (double)fixed64;
                    break;
                }
                case BTCPMRAcceptedAssetKeyMinAmount: {
                    _minAmount = integer;
                    break;
                }
                case BTCPMRAcceptedAssetKeyMaxAmount: {
                    _maxAmount = integer;
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

- (NSData*) data {
    if (!_data) {
        NSMutableData* dst = [NSMutableData data];

        if ([_assetType isEqual:BTCAssetTypeBitcoin]) {
            [BTCProtocolBuffers writeString:@"default" withKey:BTCPMRAcceptedAssetKeyAssetID toData:dst];
        } else if ([_assetType isEqual:BTCAssetTypeOpenAssets] && _assetID) {
            [BTCProtocolBuffers writeString:_assetID.string withKey:BTCPMRAcceptedAssetKeyAssetID toData:dst];
        }
        if (_assetGroup) {
            [BTCProtocolBuffers writeString:_assetGroup withKey:BTCPMRAcceptedAssetKeyAssetGroup toData:dst];
        }

        [BTCProtocolBuffers writeFixed64:(uint64_t)_multiplier withKey:BTCPMRAcceptedAssetKeyMultiplier toData:dst];
        [BTCProtocolBuffers writeInt:(uint64_t)_minAmount withKey:BTCPMRAcceptedAssetKeyMinAmount toData:dst];
        [BTCProtocolBuffers writeInt:(uint64_t)_maxAmount withKey:BTCPMRAcceptedAssetKeyMaxAmount toData:dst];
        _data = dst;
    }
    return _data;
}

@end

