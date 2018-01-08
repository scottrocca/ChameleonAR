//
//  ARSCNView+HPAdditions.m
//  InteractiveContent
//
//  Created by Scott Rocca on 1/2/18.
//  Copyright © 2018 Scott Rocca. All rights reserved.
//

#import "ARSCNView+HPAdditions.h"
#import "UIImage+HPAdditions.h"

@implementation ARSCNView (HPAdditions)

- (SCNVector3)averageColorFromEnvironment:(SCNVector3) screenPos {
    // Take screenshot of the scene, without the content
    SCNVector3 colorVector = SCNVector3Zero;
    self.scene.rootNode.hidden = YES;
    UIImage *screenshot = [self snapshot];
    self.scene.rootNode.hidden = NO;
    
    // Use a patch from the specified screen position
    CGFloat scale = UIScreen.mainScreen.scale;
    CGFloat patchSize = 100 * scale;
    CGPoint screenPoint = CGPointMake(((CGFloat)screenPos.x - patchSize / 2) * scale, ((CGFloat)screenPos.y - patchSize / 2) * scale);
    
    CGRect cropRect = CGRectMake(screenPoint.x, screenPoint.y, patchSize, patchSize);
    if(screenshot != nil){
        CGImageRef croppedCGImage = CGImageCreateWithImageInRect(screenshot.CGImage, cropRect);
        UIImage *image = [UIImage imageWithCGImage:croppedCGImage];
        NSDictionary <NSString *, NSNumber *>*avgColor = [image averageColor];
        colorVector = SCNVector3Make([avgColor[@"red"] floatValue], [avgColor[@"green"]  floatValue], [avgColor[@"blue"]  floatValue]);
    }
    return colorVector;
}

@end
