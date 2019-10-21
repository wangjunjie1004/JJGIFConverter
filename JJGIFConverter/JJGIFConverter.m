//
//  JJGIFConverter.m
//  JJGIFConverter
//
//  Created by wjj on 2019/10/21.
//  Copyright © 2019 wjj. All rights reserved.
//

#import "JJGIFConverter.h"
#import <ImageIO/ImageIO.h>
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>

const int32_t GifConverterFPS = 600;
const CGFloat GifConverterMaximumSide = 720.0f;

@implementation JJGIFConverter

+ (dispatch_queue_t)convertGifQueue {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("GIFConvertToMP4", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

+ (void)convertGifToMp4:(NSURL *)pathUrl completion:(void (^)(NSURL * _Nullable))handler
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:pathUrl.path]) {
        handler(nil);
        return;
    }
    
    __block BOOL cancel = NO;
    dispatch_async([self convertGifQueue], ^{
        NSData *data = [NSData dataWithContentsOfURL:pathUrl options:NSDataReadingMappedIfSafe error:nil];
        if (data) {
            CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
            unsigned char *bytes = (unsigned char *)data.bytes;
            NSError* error = nil;
            
            if (CGImageSourceGetStatus(source) != kCGImageStatusComplete) {
                CFRelease(source);
                handler(nil);
                return;
            }
            
            size_t sourceWidth = bytes[6] + (bytes[7]<<8), sourceHeight = bytes[8] + (bytes[9]<<8);
            __block size_t currentFrameNumber = 0;
            __block Float64 totalFrameDelay = 0.f;
            
            NSString *lastComponent = pathUrl.lastPathComponent;
            
            NSURL *outFilePath = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:true] URLByAppendingPathComponent:[lastComponent stringByReplacingCharactersInRange:NSMakeRange(lastComponent.length - 3, 3) withString:@"mp4"]];
            if ([[NSFileManager defaultManager] fileExistsAtPath:outFilePath.path]) {
                [[NSFileManager defaultManager] removeItemAtURL:outFilePath error:nil];
            }
            
            AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:outFilePath fileType:AVFileTypeMPEG4 error:&error];
            
            if (error || sourceWidth == 0 || sourceHeight == 0 || CGImageSourceGetCount(source) < 2) {
                CFRelease(source);
                handler(nil);
                return;
            }
            
            CGSize targetSize = [self fitSize:CGSizeMake(sourceWidth, sourceHeight) :CGSizeMake(GifConverterMaximumSide, GifConverterMaximumSide)];
            
            NSDictionary *videoCleanApertureSettings = @{
                                                         AVVideoCleanApertureWidthKey: @((NSInteger)targetSize.width),
                                                         AVVideoCleanApertureHeightKey: @((NSInteger)targetSize.height),
                                                         AVVideoCleanApertureHorizontalOffsetKey: @10,
                                                         AVVideoCleanApertureVerticalOffsetKey: @10
                                                         };
            
            NSDictionary *videoAspectRatioSettings = @{
                                                       AVVideoPixelAspectRatioHorizontalSpacingKey: @3,
                                                       AVVideoPixelAspectRatioVerticalSpacingKey: @3
                                                       };
            
            NSDictionary *codecSettings = @{
                                            AVVideoAverageBitRateKey: @(500000),
                                            AVVideoCleanApertureKey: videoCleanApertureSettings,
                                            AVVideoPixelAspectRatioKey: videoAspectRatioSettings
                                            };
            
            NSDictionary *videoSettings = @{
                                            AVVideoCodecKey : AVVideoCodecTypeH264,
                                            AVVideoCompressionPropertiesKey: codecSettings,
                                            AVVideoWidthKey : @((NSInteger)targetSize.width),
                                            AVVideoHeightKey : @((NSInteger)targetSize.height)
                                            };
            
            AVAssetWriterInput *videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
            videoWriterInput.expectsMediaDataInRealTime = true;
            
            if (![videoWriter canAddInput:videoWriterInput])
            {
                CFRelease(source);
                handler(nil);
                return;
            }
            [videoWriter addInput:videoWriterInput];
            
            NSDictionary *attributes = @{
                                         (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32ARGB),
                                         (NSString *)kCVPixelBufferWidthKey : @(sourceWidth),
                                         (NSString *)kCVPixelBufferHeightKey : @(sourceHeight),
                                         (NSString *)kCVPixelBufferCGImageCompatibilityKey : @YES,
                                         (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES
                                         };
            
            AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:videoWriterInput sourcePixelBufferAttributes:attributes];
            
            if (![videoWriter startWriting]) {
                handler(nil);
                return;
            }
            [videoWriter startSessionAtSourceTime:CMTimeMakeWithSeconds(totalFrameDelay, GifConverterFPS)];
            
            while (!cancel) {
                if (videoWriterInput.isReadyForMoreMediaData) {
                    NSDictionary *options = @{ (NSString *)kCGImageSourceTypeIdentifierHint : (id)kUTTypeGIF };
                    CGImageRef imgRef = CGImageSourceCreateImageAtIndex(source, currentFrameNumber, (__bridge CFDictionaryRef)options);
                    if (imgRef) {
                        CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(source, currentFrameNumber, NULL);
                        CFDictionaryRef gifProperties = CFDictionaryGetValue(properties, kCGImagePropertyGIFDictionary);
                        
                        if (gifProperties) {
                            CVPixelBufferRef pxBuffer = [self newBufferFrom:imgRef
                                                        withPixelBufferPool:adaptor.pixelBufferPool
                                                              andAttributes:adaptor.sourcePixelBufferAttributes];
                            if (pxBuffer) {
                                float frameDuration = 0.1f;
                                NSNumber *delayTimeUnclampedProp = (__bridge NSNumber *)CFDictionaryGetValue(gifProperties, kCGImagePropertyGIFUnclampedDelayTime);
                                if (delayTimeUnclampedProp != nil) {
                                    frameDuration = [delayTimeUnclampedProp floatValue];
                                } else {
                                    NSNumber *delayTimeProp = (__bridge NSNumber *)CFDictionaryGetValue(gifProperties, kCGImagePropertyGIFDelayTime);
                                    if (delayTimeProp != nil)
                                        frameDuration = [delayTimeProp floatValue];
                                }
                                
                                if (frameDuration < 0.011f)
                                    frameDuration = 0.100f;
                                
                                CMTime time = CMTimeMakeWithSeconds(totalFrameDelay, GifConverterFPS);
                                totalFrameDelay += frameDuration;
                                
                                if (![adaptor appendPixelBuffer:pxBuffer withPresentationTime:time]) {
                                    CFRelease(properties);
                                    CGImageRelease(imgRef);
                                    CVBufferRelease(pxBuffer);
                                    break;
                                }
                                
                                CVBufferRelease(pxBuffer);
                            }
                        }
                        
                        if (properties)
                            CFRelease(properties);
                        CGImageRelease(imgRef);
                        
                        currentFrameNumber++;
                    } else {
                        [videoWriterInput markAsFinished];
                        
                        [videoWriter finishWritingWithCompletionHandler:^{
                            handler(outFilePath);
                            cancel = YES;
                        }];
                        break;
                    }
                } else {
                    [NSThread sleepForTimeInterval:0.1];
                }
            };
            CFRelease(source);
        } else {
            handler(nil);
            return;
        }
    });
}

+ (CGSize)fitSize:(CGSize)size1 :(CGSize)size2
{
    if (size1.width >= size1.height) {
        if (size1.width > size2.width) {
            return CGSizeMake(size2.width, size2.width * size1.height / size1.width);
        }else{
            return size1;
        }
    }else{
        if (size1.height > size2.height) {
            return CGSizeMake(size2.height * size1.width / size1.height, size2.height);
        }else{
            return size1;
        }
    }
}

+ (CVPixelBufferRef)newBufferFrom:(CGImageRef)frame withPixelBufferPool:(CVPixelBufferPoolRef)pixelBufferPool andAttributes:(NSDictionary *)attributes
{
    NSParameterAssert(frame);
    
    size_t width = CGImageGetWidth(frame);
    size_t height = CGImageGetHeight(frame);
    size_t bpc = 8;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CVPixelBufferRef pxBuffer = NULL;
    CVReturn status;
    
    if (pixelBufferPool)
        status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pxBuffer);
    else
        status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef)attributes, &pxBuffer);
    
    NSAssert(status == kCVReturnSuccess, @"Could not create a pixel buffer");
    
    CVPixelBufferLockBaseAddress(pxBuffer, 0);
    void *pxData = CVPixelBufferGetBaseAddress(pxBuffer);
    
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pxBuffer);
    
    CGContextRef context = CGBitmapContextCreate(pxData, width, height, bpc, bytesPerRow, colorSpace, kCGImageAlphaNoneSkipFirst);
    NSAssert(context, @"Could not create a context");
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), frame);
    
    CVPixelBufferUnlockBaseAddress(pxBuffer, 0);
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    return pxBuffer;
}

@end
