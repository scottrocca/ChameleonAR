//
//  Chameleon.h
//  InteractiveContent
//
//  Created by Scott Rocca on 12/30/17.
//  Copyright © 2017 Scott Rocca. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SceneKit/SceneKit.h>
#import <ARKit/ARKit.h>

@interface Chameleon : SCNScene

-(void) show;
-(void) hide;
- (BOOL)isVisible;
- (void)reactToTap:(ARSCNView *)sceneView;
- (void)setTransform:(simd_float4x4) transform;

- (void)reactToPositionChange:(ARSCNView *)view;
- (void)reactToInitialPlacement:(ARSCNView *)view;

- (void)reactToRendering:(ARSCNView *)sceneView;
- (void)reactToDidApplyConstraints:(ARSCNView *)sceneView;
@end
