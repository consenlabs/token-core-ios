#import "BTCQRCode.h"
#import <AVFoundation/AVFoundation.h>

#if TARGET_OS_IPHONE
@interface BTCQRCodeScannerView : UIView <AVCaptureMetadataOutputObjectsDelegate>
@property (nonatomic, strong) void(^detectionBlock)(NSString* message);
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) dispatch_queue_t sessionQueue;
@property (nonatomic, assign) AVCaptureDevicePosition cameraPosition;
@property (nonatomic, assign) AVCaptureVideoOrientation cameraOrientation;
- (id) initWithDetectionBlock:(void(^)(NSString* message))detectionBlock;
@end
#endif

@implementation BTCQRCode

#if TARGET_OS_IPHONE
+ (UIImage*) imageForURL:(NSURL*)url size:(CGSize)size scale:(CGFloat)scale {
    return [self imageForString:url.absoluteString size:size scale:scale];
}

+ (UIImage*) imageForString:(NSString*)string size:(CGSize)size scale:(CGFloat)scale {
    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];

    [filter setValue:[string dataUsingEncoding:NSISOLatin1StringEncoding] forKey:@"inputMessage"];
    [filter setValue:@"L" forKey:@"inputCorrectionLevel"];

    UIGraphicsBeginImageContextWithOptions(size, NO, scale);

    CGContextRef context = UIGraphicsGetCurrentContext();
    CGImageRef cgimage = [[CIContext contextWithOptions:nil] createCGImage:filter.outputImage
                                                              fromRect:filter.outputImage.extent];

    UIImage* image = nil;
    if (context) {
        CGContextSetInterpolationQuality(context, kCGInterpolationNone);
        CGContextDrawImage(context, CGContextGetClipBoundingBox(context), cgimage);
        image = [UIImage imageWithCGImage:UIGraphicsGetImageFromCurrentImageContext().CGImage
                                                scale:scale
                                          orientation:UIImageOrientationDownMirrored];
    }

    UIGraphicsEndImageContext();
    CGImageRelease(cgimage);

    return image;
}

+ (UIView*) scannerViewUsingDevice:(AVCaptureDevicePosition) devicePosition
                       orientation:(AVCaptureVideoOrientation) orientation
                             block:(void(^)(NSString* message))detectionBlock {
    BTCQRCodeScannerView *view = [[BTCQRCodeScannerView alloc] initWithDetectionBlock:detectionBlock];
    view.cameraPosition = devicePosition;
    view.cameraOrientation = orientation;
    return view;
}

+ (UIView*) scannerViewWithBlock:(void(^)(NSString* message))detectionBlock {
    return [self scannerViewUsingDevice:AVCaptureDevicePositionUnspecified
                            orientation:0
                                  block:detectionBlock];
}

#endif

@end



#if TARGET_OS_IPHONE
@implementation BTCQRCodeScannerView
@synthesize cameraPosition, cameraOrientation;

- (id) initWithDetectionBlock:(void(^)(NSString* message))detection {
    if (self = [super initWithFrame:[UIScreen mainScreen].bounds]) {
        self.sessionQueue = dispatch_queue_create("BTCQRCodeScannerView", NULL);
        self.detectionBlock = detection;
        self.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.8];
    }
    return self;
}

- (void) cleanup {
    [self.session removeOutput:self.session.outputs.firstObject];
    self.sessionQueue = nil;
    self.detectionBlock = nil;
    self.session = nil;
}

- (void) didMoveToWindow {
    [super didMoveToWindow];

    if (!self.sessionQueue) return;

    if (self.window) {
        [self prepareScanner];
    } else {
        [self cleanup];
    }
}

- (AVCaptureDevice *)deviceFromPosition:(AVCaptureDevicePosition) position {
    if (position != AVCaptureDevicePositionUnspecified) {
        NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        for (AVCaptureDevice *device in devices) {
            if ([device position] == position) {
                return device;
            }
        }
    }
    return [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
}

- (void) prepareScanner {
    [self prepareScannerWithDevice:[self deviceFromPosition:self.cameraPosition]];
}

- (void) prepareScannerWithDevice:(AVCaptureDevice *)device {
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    AVCaptureMetadataOutput *output = [AVCaptureMetadataOutput new];

    if (!input) {
        NSLog(@"BTCQRCodeScannerView: Failed to instantiate a video device: %@", [error localizedDescription]);
        return;
    }

    if ([device lockForConfiguration:&error]) {
        if (device.isAutoFocusRangeRestrictionSupported) {
            device.autoFocusRangeRestriction = AVCaptureAutoFocusRangeRestrictionNear;
        }

        if ([device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
            device.focusMode = AVCaptureFocusModeContinuousAutoFocus;
        }

        [device unlockForConfiguration];
    } else {
        NSLog(@"BTCQRCodeScannerView: Failed to lock device for configuration: %@", [error localizedDescription]);
    }

    self.session = [AVCaptureSession new];

    if (input) [self.session addInput:input];

    [self.session addOutput:output];
    [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];

    if ([output.availableMetadataObjectTypes containsObject:AVMetadataObjectTypeQRCode]) {
        output.metadataObjectTypes = @[ AVMetadataObjectTypeQRCode ];
    } else {
        NSLog(@"BTCQRCodeScannerView: QRCode not found in availableMetadataObjectTypes: %@", output.availableMetadataObjectTypes);
        [self cleanup];
        return;
    }

    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.previewLayer.frame = self.layer.bounds;
    [self.layer addSublayer:self.previewLayer];

    dispatch_async(self.sessionQueue, ^{
        [self.session startRunning];
        
        if (self.cameraOrientation != 0) {
            //Get Preview Layer connection
            AVCaptureConnection *previewLayerConnection=self.previewLayer.connection;
            if ([previewLayerConnection isVideoOrientationSupported])
                [previewLayerConnection setVideoOrientation:self.cameraOrientation];
        }
    });
}

- (void) layoutSubviews
{
    [super layoutSubviews];
    self.previewLayer.frame = self.layer.bounds;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    for (AVMetadataMachineReadableCodeObject *object in metadataObjects) {
        // Take the first detected QR code.
        if ([object.type isEqual:AVMetadataObjectTypeQRCode]) {
            if (self.detectionBlock) self.detectionBlock(object.stringValue);

            // Do not cleanup - the owner of this view will remove it from window if detection succeeded.

            return;
        }
    }
}

@end
#endif

