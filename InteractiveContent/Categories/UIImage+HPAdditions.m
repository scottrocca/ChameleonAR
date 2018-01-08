//
//  UIImage+HPAdditions.m
//  InteractiveContent
//
//  Created by Scott Rocca on 1/2/18.
//  Copyright © 2018 Scott Rocca. All rights reserved.
//

#import "UIImage+HPAdditions.h"

@implementation UIImage (HPAdditions)
- (NSDictionary <NSString *, NSNumber *>*)averageColor {
    CGImageRef cgImage = [self CGImage];
    CIFilter *averageFilter = [CIFilter filterWithName:@"CIAreaAverage"];
    
    if(nil != cgImage  && nil != averageFilter){
        CIImage *ciImage = [CIImage imageWithCGImage:cgImage];
        CGRect extent = ciImage.extent;
        CIVector *ciExtent = [CIVector vectorWithX:extent.origin.x Y:extent.origin.y Z:extent.size.width W:extent.size.height];
        [averageFilter setValue:ciImage forKey:kCIInputImageKey];
        [averageFilter setValue:ciExtent forKey:kCIInputExtentKey];
        
        CIImage *outputImage = averageFilter.outputImage;
        
        if(nil != outputImage){
            CIContext *context =  [CIContext contextWithOptions:nil];
            //NSArray *bitmap = @[[NSNumber numberWithUnsignedChar:0], [NSNumber numberWithUnsignedChar:0], [NSNumber numberWithUnsignedChar:0], [NSNumber numberWithUnsignedChar:0]];
            unsigned char bitmap[4];
            
            [context render:outputImage toBitmap:bitmap rowBytes:4 bounds:CGRectMake(0, 0, 1, 1) format:kCIFormatARGB8 colorSpace:CGColorSpaceCreateDeviceRGB()];

            //return @{@"red" : [NSNumber numberWithFloat:([bitmap[0] floatValue] / 255.0)], @"green" :  [NSNumber numberWithFloat:([bitmap[1] floatValue] / 255.0)], @"blue" : [NSNumber numberWithFloat:([bitmap[2] floatValue] / 255.0)],};
            
           // return @{@"red" : bitmap[0] , @"green" :  bitmap[1], @"blue" : bitmap[2]};
            return @{@"red" : [NSNumber numberWithFloat:(((CGFloat)bitmap[0]) / 255.0)], @"green" :  [NSNumber numberWithFloat:(((CGFloat)bitmap[1]) / 255.0)], @"blue" : [NSNumber numberWithFloat:(((CGFloat)bitmap[2]) / 255.0)],};
            
        }
        
        
    }
    
    return nil;
}

@end
