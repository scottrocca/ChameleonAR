//
//  ARSCNView+HPAdditions.h
//  InteractiveContent
//
//  Created by Scott Rocca on 1/2/18.
//  Copyright © 2018 Scott Rocca. All rights reserved.
//
#import <SceneKit/SceneKit.h>
#import <ARKit/ARKit.h>

@interface ARSCNView (HPAdditions)
- (SCNVector3)averageColorFromEnvironment:(SCNVector3) screenPos;
@end
