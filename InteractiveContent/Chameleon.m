//
//  Chameleon.m
//  InteractiveContent
//
//  Created by Scott Rocca on 12/30/17.
//  Copyright © 2017 Scott Rocca. All rights reserved.
//

#import "Chameleon.h"
#import "ARSCNView+HPAdditions.h"

//simd = Single Instruction Multiple Data

typedef NS_ENUM(NSInteger, RelativeCameraPositionToHead) {
    withinFieldOfView,
    needsToTurnLeft,
    needsToTurnRight,
    tooHighOrLow
};

typedef NS_ENUM(NSInteger, Distance) {
    outsideTargetLockDistance,
    withinTargetLockDistance,
    withinShootTongueDistance
};

typedef NS_ENUM(NSInteger, MouthAnimationState) {
    mouthClosed,
    mouthMoving,
    shootingTongue,
    pullingBackTongue
};

static NSString * const kRelativeCameraPostionToHead = @"kRelativeCameraPostionToHead";
static NSString * const kDistance = @"kDistance";

@interface Chameleon()

//Special Nodes used to control animations of the model
@property (nonatomic, strong)SCNNode *contentRootNode;
@property (nonatomic, strong)SCNNode *geometryRoot;
@property (nonatomic, strong)SCNNode *head;
@property (nonatomic, strong)SCNNode *leftEye;
@property (nonatomic, strong)SCNNode *rightEye;
@property (nonatomic, strong)SCNNode *jaw;
@property (nonatomic, strong)SCNNode *tongueTip;
@property (nonatomic, strong)SCNNode *focusOfTheHead;
@property (nonatomic, strong)SCNNode *focusOfLeftEye;
@property (nonatomic, strong)SCNNode *focusOfRightEye;
@property (nonatomic, strong)SCNNode *tongueRestPositionNode;
@property (nonatomic, strong)SCNMaterial *skin;

//Animation
@property (nonatomic, strong)SCNAnimation *idleAnimation;
@property (nonatomic, strong)SCNAnimation *turnLeftAnimation;
@property (nonatomic, strong)SCNAnimation *turnRightAnimation;

//State variables
@property (assign) BOOL modelLoaded;
@property (assign) BOOL headIsMoving;
@property (assign) BOOL chameleonIsTurning;

@property (assign) simd_float3 focusNodeBasePosition;
@property (assign) simd_float3 leftEyeTargetOffset;
@property (assign) simd_float3 rightEyeTargetOffset;
@property (assign) simd_float3 currentTonguePosition;
@property (assign) float relativeTongueStickOutFactor;
@property (assign) NSInteger readyToShootCounter;
@property (assign) NSInteger triggerTurnLeftCounter;
@property (assign) NSInteger triggerTurnRightCounter;

@property (assign) RelativeCameraPositionToHead lastRelativePosition;

@property (assign) float lastDistance;
@property (assign) BOOL didEnterTargetLockDistance;

@property (assign) MouthAnimationState mouthAnimationState;

@property (strong, nonatomic) NSTimer * changeColorTimer;
@property (readwrite, nonatomic) SCNVector3 lastColorFromeEnvironment;;




@end


@implementation Chameleon

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        _contentRootNode = [SCNNode new];
        _focusOfTheHead = [SCNNode new];
        _focusOfLeftEye  = [SCNNode new];
        _focusOfRightEye  = [SCNNode new];
        _tongueRestPositionNode  = [SCNNode new];
        
        _modelLoaded = NO;
        _headIsMoving = NO;
        _chameleonIsTurning = NO;
        
        _focusNodeBasePosition = simd_make_float3(0, 0.1, 0.25);
        _relativeTongueStickOutFactor = 0;
        _readyToShootCounter = 0;
        _triggerTurnLeftCounter = 0;
        _triggerTurnRightCounter = 0;
        _lastRelativePosition = tooHighOrLow;
        
        _didEnterTargetLockDistance = NO;
        _mouthAnimationState = mouthClosed;
        _lastColorFromeEnvironment = SCNVector3Make(130.0 / 255.0, 196.0 / 255.0, 174.0 / 255.0);
        self.lightingEnvironment.contents = [UIImage imageNamed:@"art.scnassets/environment_blur.exr"];
        
        [self loadModel];
        
        
    }
    
    return self;
}

- (void)loadModel {
    SCNScene *virtualObectScene = [SCNScene sceneNamed:@"chameleon" inDirectory:@"art.scnassets" options:nil];
    
    SCNNode *wrapperNode = [SCNNode new];
    
    for(SCNNode *child in virtualObectScene.rootNode.childNodes){
        [wrapperNode addChildNode:child];
    }
    
    [self.rootNode addChildNode:self.contentRootNode];
    [self.contentRootNode addChildNode:wrapperNode];
    [self hide];
    [self setupSpecialNodes];
    [self setupConstraints];
    [self setupShader];
    [self preloadAnimation];
    [self resetState];
    
    self.modelLoaded = YES;
    
}

- (void)show {
    self.contentRootNode.hidden = NO;
}

-(void)hide{
    self.contentRootNode.hidden = YES;
    [self resetState];
}

- (BOOL)isVisible {
    return !self.contentRootNode.isHidden;
}

- (void)setTransform:(simd_float4x4) transform{
    self.contentRootNode.simdTransform = transform;
}

- (void)resetState{
    self.relativeTongueStickOutFactor = 0;
    self.mouthAnimationState = mouthClosed;
    self.readyToShootCounter = 0;
    self.triggerTurnLeftCounter = 0;
    self.triggerTurnRightCounter = 0;
    
    if(self.changeColorTimer != nil){
        [self.changeColorTimer invalidate];
        self.changeColorTimer = nil;
    }
}

// PRAGMA MARK: - Turn left/right and idle animations
- (void)preloadAnimation {
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"anim_idle.dae" withExtension:nil subdirectory:@"art.scnassets"];
    SCNSceneSource *sceneSource = [SCNSceneSource sceneSourceWithURL:url options:nil];
    CAAnimation *animationObject = [sceneSource entryWithIdentifier:@"unnamed_animation__8" withClass:CAAnimation.self];
    self.idleAnimation = [SCNAnimation animationWithCAAnimation:animationObject];
    self.idleAnimation.repeatCount = -1;
    
    
    url = [[NSBundle mainBundle] URLForResource:@"anim_turnleft.dae" withExtension:nil subdirectory:@"art.scnassets"];
    sceneSource = [SCNSceneSource sceneSourceWithURL:url options:nil];
    animationObject = [sceneSource entryWithIdentifier:@"unnamed_animation__8" withClass:CAAnimation.self];
    self.turnLeftAnimation = [SCNAnimation animationWithCAAnimation:animationObject];
    
    self.turnLeftAnimation.repeatCount = 1;
    self.turnLeftAnimation.blendInDuration = 0.3;
    self.turnLeftAnimation.blendOutDuration = 0.3;

    url = [[NSBundle mainBundle] URLForResource:@"anim_turnright.dae" withExtension:nil subdirectory:@"art.scnassets"];
    sceneSource = [SCNSceneSource sceneSourceWithURL:url options:nil];
    //NSArray<NSString *>*list = [sceneSource identifiersOfEntriesWithClass:CAAnimation.self];
    animationObject = [sceneSource entryWithIdentifier:@"unnamed_animation__8" withClass:CAAnimation.self];
    self.turnRightAnimation = [SCNAnimation animationWithCAAnimation:animationObject];
    
    self.turnRightAnimation.repeatCount = 1;
    self.turnRightAnimation.blendInDuration = 0.3;
    self.turnRightAnimation.blendOutDuration = 0.3;
    
    if(self.idleAnimation != nil){
        [self.contentRootNode.childNodes[0] addAnimation:self.idleAnimation forKey:self.idleAnimation.keyPath];
    }
    
    [self.tongueTip removeAllAnimations];
    [self.leftEye removeAllAnimations];
    [self.rightEye removeAllAnimations];
    
    self.chameleonIsTurning = NO;
    self.headIsMoving = NO;
}

- (void)playTurnAnimation:(SCNAnimation *)animation {
    float rotationAngle = 0;
    if (animation == self.turnLeftAnimation){
        rotationAngle = M_PI / 4;
    } else if (animation == self.turnRightAnimation){
        rotationAngle = -M_PI / 4;
    }
    SCNNode *modelBaseNode = self.contentRootNode.childNodes[0];
   [ modelBaseNode addAnimation:animation forKey:animation.keyPath];
    
    self.chameleonIsTurning = YES;
    
    [SCNTransaction begin];
    SCNTransaction.animationTimingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    SCNTransaction.animationDuration = animation.duration;
    modelBaseNode.transform = SCNMatrix4Mult(modelBaseNode.presentationNode.transform, SCNMatrix4MakeRotation(rotationAngle, 0, 1, 0));
    SCNTransaction.completionBlock = ^{
        self.chameleonIsTurning = NO;
    };
    [SCNTransaction commit];
}

- (void)setupSpecialNodes {
    self.geometryRoot = [self.rootNode childNodeWithName:@"Chameleon" recursively:YES];
    self.head = [self.rootNode childNodeWithName:@"Neck02" recursively:YES];
    self.jaw = [self.rootNode childNodeWithName:@"Jaw" recursively:YES];
    self.tongueTip = [self.rootNode childNodeWithName:@"TongueTip_Target" recursively:YES];
    self.leftEye = [self.rootNode childNodeWithName:@"Eye_L" recursively:YES];
    self.rightEye = [self.rootNode childNodeWithName:@"Eye_R" recursively:YES];
    
    self.skin = [self.geometryRoot.geometry.materials firstObject];
    
    self.geometryRoot.geometry.firstMaterial.lightingModelName = SCNLightingModelPhysicallyBased;
    
    self.geometryRoot.geometry.firstMaterial.roughness.contents = @"art.scnassets/textures/chameleon_ROUGHNESS.png";
    
    SCNNode *shadowPlane = [self.rootNode childNodeWithName:@"Shadow" recursively:YES];
    shadowPlane.castsShadow = NO;
    
    self.focusOfTheHead.simdPosition = self.focusNodeBasePosition;
    self.focusOfLeftEye.simdPosition = self.focusNodeBasePosition;
    self.focusOfRightEye.simdPosition = self.focusNodeBasePosition;
    
    [self.geometryRoot addChildNode:self.focusOfTheHead];
    [self.geometryRoot addChildNode:self.focusOfLeftEye];
    [self.geometryRoot addChildNode:self.focusOfRightEye];
    
}

- (void)setupConstraints {
    SCNLookAtConstraint *headConstraint = [SCNLookAtConstraint lookAtConstraintWithTarget:self.focusOfTheHead];
    headConstraint.gimbalLockEnabled = YES;
    self.head.constraints = @[headConstraint];
    
    SCNLookAtConstraint *leftEyeLookAtConstraint = [SCNLookAtConstraint lookAtConstraintWithTarget:self.focusOfLeftEye];
    leftEyeLookAtConstraint.gimbalLockEnabled = YES;
    
    SCNLookAtConstraint *rightEyeLookAtConstraint = [SCNLookAtConstraint lookAtConstraintWithTarget:self.focusOfRightEye];
    rightEyeLookAtConstraint.gimbalLockEnabled = YES;
    
    SCNTransformConstraint *eyeRotationConstraint = [SCNTransformConstraint transformConstraintInWorldSpace:NO withBlock:^SCNMatrix4 (SCNNode *node, SCNMatrix4 transform){
        float eulerX = node.presentationNode.eulerAngles.x;
        float eulerY = node.presentationNode.eulerAngles.y;
        
        if(eulerX < [self rad:-20]){
            eulerX = [self rad:-20];
        }
        if(eulerX > [self rad:20]){
            eulerX = [self rad:20];
        }
        
        if([node.name isEqualToString:@"Eye_R"]){
            if(eulerY < [self rad:-150]){
                eulerY = [self rad:-150];
            }
            if(eulerY > [self rad:-5]){
                eulerY = [self rad:-5];
            }
        }
        else{
            if(eulerY < [self rad:150]){
                eulerY = [self rad:150];
            }
            if(eulerY > [self rad:5]){
                eulerY = [self rad:5];
            }
        }
        
        SCNNode *tempNode = [SCNNode new];
        tempNode.transform = node.presentationNode.transform;
        tempNode.eulerAngles = SCNVector3Make(eulerX, eulerY, 0);
        
        return tempNode.transform;
        
    }];
    
    if(self.leftEye != nil){
        self.leftEye.constraints = @[leftEyeLookAtConstraint, eyeRotationConstraint];
    }
    if(self.rightEye != nil){
        self.rightEye.constraints = @[rightEyeLookAtConstraint, eyeRotationConstraint];
    }
    
    // The tongueRestPositionNode always remains at the tongue rest position.
    // even if the tongue is animated. It helps to calculate the intermediate position in the tongue animation.
    [self.tongueTip.parentNode addChildNode:self.tongueRestPositionNode];
    self.tongueRestPositionNode.transform = self.tongueTip.transform;
    self.currentTonguePosition = self.tongueTip.simdPosition;
    
    
}

- (void) setupShader {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"skin" ofType:@"shaderModifier" inDirectory:@"art.scnassets"];
    NSString *shader = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    
    self.skin.shaderModifiers = @{SCNShaderModifierEntryPointSurface : shader };
    
    [self.skin setValue:@0.0 forKey:@"blendFactor"];
    [self.skin setValue:[NSValue valueWithSCNVector3:SCNVector3Zero] forKey:@"skinColorFromEnvironment"];
    
    SCNMaterialProperty *sparseTexture = [SCNMaterialProperty materialPropertyWithContents:[UIImage imageNamed:@"art.scnassets/textures/chameleon_DIFFUSE_BASE.png"]];
    [self.skin setValue:sparseTexture forKey:@"sparseTexture"];
    
}



// PRAGMA MARK: - React to Placement and Tap
- (void) reactToPositionChange:(ARSCNView *)view {
    [self reactToPlacement:view];
}


- (void)reactToInitialPlacement:(ARSCNView *)view {
    [self reactToPlacement:view isInitial:NO];
}


- (void) reactToPlacement:(ARSCNView *)view {
    [self reactToPlacement:view isInitial:NO];
}

- (void)reactToPlacement:(ARSCNView *)sceneView isInitial:(BOOL)isInitial{
    
    if(isInitial){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self getColorFromEnvironment:sceneView];
            [self activeCamouflage:YES];
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateCamouflage:sceneView];
        });
    }
}

- (void)reactToTap:(ARSCNView *)sceneView {
    [self activeCamouflage:NO];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self activeCamouflage:YES];
    });
}

- (void)activeCamouflage:(BOOL)activate {
    [self.skin setValue:[NSValue valueWithSCNVector3:self.lastColorFromeEnvironment] forKey:@"skinColorFromEnvironment"];
    
    double blendFactor = activate ? 1.0 : 0.0;
    
    [SCNTransaction begin];
    SCNTransaction.animationDuration = 1.5;
    [self.skin setValue:[NSNumber numberWithDouble:blendFactor] forKey:@"blendFactor"];
    [SCNTransaction commit];
}

- (void)updateCamouflage:(ARSCNView *)sceneView {
    [self getColorFromEnvironment:sceneView];
    [SCNTransaction begin];
    SCNTransaction.animationDuration = 1.5;
    [self.skin setValue:[NSValue valueWithSCNVector3:self.lastColorFromeEnvironment] forKey:@"skinColorFromEnvironment"];
    [SCNTransaction commit];
}

- (void)getColorFromEnvironment:(ARSCNView *)sceneView {
    SCNVector3 worldPos = [sceneView projectPoint:self.contentRootNode.worldPosition];
    SCNVector3 colorVector = [sceneView averageColorFromEnvironment:worldPos];
    self.lastColorFromeEnvironment = colorVector;
}

//PRAGMA MARK: - React To Rendering
- (void)reactToRendering:(ARSCNView *)sceneView {
    // Update environment map to match ambient light level
    self.lightingEnvironment.intensity = sceneView.session.currentFrame.lightEstimate.ambientIntensity > 0 ? sceneView.session.currentFrame.lightEstimate.ambientIntensity / 100 : 1000 / 100;
    
    SCNNode *pointOfView;
    if (self.modelLoaded && !self.chameleonIsTurning){
        pointOfView = sceneView.pointOfView;
    } else {
        return;
    }
    
    simd_float3 localTarget = [self.focusOfTheHead.parentNode simdConvertPosition:pointOfView.simdWorldPosition fromNode:nil];
    
    [self followUserWithEyes:localTarget];
    
    
    // Obtain relative position of the head to the camera and act accordingly.
    NSDictionary *positions = [self relativePositionToHead:pointOfView.simdPosition];
    //RelativeCameraPositionToHead relativePos = [self relativePositionToHead:pointOfView.simdPosition];
    
    switch ([positions[kRelativeCameraPostionToHead] intValue]) {
        case withinFieldOfView:
            [self handleWithinfieldOfView:localTarget distance:[positions[kDistance] intValue]];
            break;
            
        case needsToTurnLeft:
            [self followUserWithHead:simd_make_float3(0.4, self.focusNodeBasePosition.y, self.focusNodeBasePosition.z)];
            self.triggerTurnLeftCounter += 1;
            
            if (self.triggerTurnLeftCounter > 150) {
                self.triggerTurnLeftCounter = 0;
                if (self.turnLeftAnimation != nil) {
                    [self playTurnAnimation:self.turnLeftAnimation];
                }
            }
            break;
            
        case needsToTurnRight:
            [self followUserWithHead:simd_make_float3(-0.4, self.focusNodeBasePosition.y, self.focusNodeBasePosition.z)];
            self.triggerTurnRightCounter += 1;
            
            if (self.triggerTurnRightCounter > 95) {
                self.triggerTurnRightCounter = 0;
                if (self.turnRightAnimation != nil) {
                    [self playTurnAnimation:self.turnRightAnimation];
                }
            }
            break;
            
        case tooHighOrLow:
            [self followUserWithHead:self.focusNodeBasePosition];
            
        default:
            break;
    }
    
    
}

- (void)followUserWithEyes:(simd_float3)target {
    self.leftEyeTargetOffset = [self randomlyUpdate:self.leftEyeTargetOffset];
    self.rightEyeTargetOffset = [self randomlyUpdate:self.rightEyeTargetOffset];
    self.focusOfLeftEye.simdPosition = target + self.leftEyeTargetOffset;
    self.focusOfRightEye.simdPosition = target + self.rightEyeTargetOffset;

}

- (void)followUserWithHead:(simd_float3)target {
    [self followUserWithHead:target instantly:NO];
}

- (void)followUserWithHead:(simd_float3)target instantly:(BOOL)instantly{
    if (self.headIsMoving) {
        return;
    }
    
    if (self.mouthAnimationState != mouthClosed || instantly){
        self.focusOfTheHead.simdPosition = target;
    } else {
        self.didEnterTargetLockDistance = NO;
        self.headIsMoving = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
           SCNAction *moveToTarget = [SCNAction moveTo:SCNVector3Make(target.x, target.y, target.z) duration:0.5];
            [self.focusOfTheHead runAction:moveToTarget completionHandler:^{
                self.headIsMoving = NO;
            }];
        });
    }
}

- (void)handleWithinfieldOfView:(simd_float3)localTarget distance:(Distance)distance {
    self.triggerTurnLeftCounter = 0;
    self.triggerTurnRightCounter = 0;
    
    switch (distance) {
        case outsideTargetLockDistance:
            [self followUserWithHead:localTarget];
            break;
        case withinTargetLockDistance:
            [self followUserWithHead:localTarget instantly:!self.didEnterTargetLockDistance];
            break;
        case withinShootTongueDistance:
            [self followUserWithHead:localTarget instantly:YES];
            if (self.mouthAnimationState == mouthClosed) {
                self.readyToShootCounter += 1;
                if (self.readyToShootCounter > 30) {
                    [self openClosedMouthAndShootTongue];
                }
            } else {
                self.readyToShootCounter = 0;
            }
            
        default:
            break;
    }
}

//PRAGMA MARK: - Head and tongue animations
- (NSDictionary *)relativePositionToHead:(simd_float3)pointOfViewPosition {
    // Compute angles between camera position and chameleon
    simd_float3 cameraPosLocal = [self.head simdConvertPosition:pointOfViewPosition fromNode:nil];
    simd_float3 cameraPosLocalComponentX = simd_make_float3(cameraPosLocal.x, cameraPosLocal.y, cameraPosLocal.z);
    float dist = simd_length(cameraPosLocal - self.head.simdPosition);
    
    double xAngle = acos(simd_dot(simd_normalize(self.head.simdPosition), simd_normalize(cameraPosLocalComponentX))) * 180 / M_PI;
    double yAngle = asin(cameraPosLocal.y / dist) * 180 / M_PI;
    
    float selfToUserDistance = simd_length(pointOfViewPosition - self.jaw.simdWorldPosition);
    
    RelativeCameraPositionToHead relativePosition;
    Distance distanceCategory = outsideTargetLockDistance;
    
    if (yAngle > 60){
        relativePosition = tooHighOrLow;
    } else if (xAngle > 60) {
        relativePosition = cameraPosLocal.x < 0 ? needsToTurnLeft : needsToTurnRight;
    } else {
        
        
        if ( selfToUserDistance < 0.3) {
            distanceCategory = withinShootTongueDistance;
        } else if ( selfToUserDistance < 0.45) {
            distanceCategory = withinTargetLockDistance;
            if ( self.lastDistance > 0.45 || self.lastRelativePosition > 0) {
                self.didEnterTargetLockDistance = YES;
            }
        }
        
        relativePosition = withinFieldOfView;
        
    }
    
    self.lastDistance = selfToUserDistance;
    self.lastRelativePosition = relativePosition;
    
    return @{kRelativeCameraPostionToHead : @(relativePosition), kDistance : @(distanceCategory)};
}

- (void)openClosedMouthAndShootTongue {
    SCNAnimationEvent* startShootEvent = [SCNAnimationEvent animationEventWithKeyTime:0.07 block:^(id<SCNAnimation>  _Nonnull animation, id  _Nonnull animatedObject, BOOL playingBackward) {
        self.mouthAnimationState = shootingTongue;
    }];
    
    SCNAnimationEvent* endShootEvent = [SCNAnimationEvent animationEventWithKeyTime:0.65 block:^(id<SCNAnimation>  _Nonnull animation, id  _Nonnull animatedObject, BOOL playingBackward) {
        self.mouthAnimationState = pullingBackTongue;
    }];
    
    SCNAnimationEvent* mouthClosedEvent = [SCNAnimationEvent animationEventWithKeyTime:0.99 block:^(id<SCNAnimation>  _Nonnull animation, id  _Nonnull animatedObject, BOOL playingBackward) {
        self.mouthAnimationState = mouthClosed;
        self.readyToShootCounter = -100;
        
    }];
    
    CAKeyframeAnimation *animation =[CAKeyframeAnimation animationWithKeyPath:@"eulerAngles.x"];
    animation.duration = 4.0;
    animation.keyTimes = @[@0.0, @0.05, @0.75, @1.0];
    animation.values = @[@0, @(-0.4), @(-0.4), @0];
    animation.timingFunctions = @[[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut],
                                 [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
                                 [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
    
    
    animation.animationEvents = @[startShootEvent, endShootEvent, mouthClosedEvent];
    
    self.mouthAnimationState = mouthMoving;
    [self.jaw addAnimation:animation forKey:@"open close mouth"];
    
    // Move the head a little bit up.
    CAKeyframeAnimation *headUpAnimation =[CAKeyframeAnimation animationWithKeyPath:@"position.y"];
    float startY = self.focusOfTheHead.position.y;
    headUpAnimation.duration = 4.0;
    headUpAnimation.keyTimes = @[@0.0, @0.05, @0.75, @1.0];
    headUpAnimation.values = @[@(startY), @(startY + 0.1), @(startY + 0.1), @(startY)];
    headUpAnimation.timingFunctions = @[[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut],
                                       [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
                                       [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
    
    [self.focusOfTheHead addAnimation:headUpAnimation forKey:@"move head up"];
    
    
    
}

//PRAGMA MARK: - React To DidApplyConstraints
- (void)reactToDidApplyConstraints:(ARSCNView *)sceneView {
    if (!self.modelLoaded || sceneView.pointOfView == nil){
        return;
    }
    
    // Correct the user position such that it is a few centimeters in front of the camera.
    SCNVector3 translationLocal = SCNVector3Make(0, 0, -0.012);
    SCNVector3 translationWorld = [sceneView.pointOfView convertVector:translationLocal toNode:nil];
    SCNMatrix4 camTransform = SCNMatrix4Translate(sceneView.pointOfView.transform, translationWorld.x, translationWorld.y, translationWorld.z);
    simd_float3 userPosition = simd_make_float3(camTransform.m41, camTransform.m42, camTransform.m43);
    
    [self updateTongue:userPosition];
}

- (void)updateTongue:(simd_float3)target {
    // When the tongue is in motion, update the relative amount how much it sticks out
    // between 0 (= in the mouth) and 1 (= at the target).
    if (self.mouthAnimationState == shootingTongue){
        if (self.relativeTongueStickOutFactor < 1) {
            self.relativeTongueStickOutFactor += 0.08;
        } else {
            self.relativeTongueStickOutFactor = 1;
        }
    } else if (self.mouthAnimationState == pullingBackTongue) {
        if (self.relativeTongueStickOutFactor > 0) {
            self.relativeTongueStickOutFactor -= 0.02;
        } else {
            self.relativeTongueStickOutFactor = 0;
        }
    }
    simd_float3 startPos = self.tongueRestPositionNode.presentationNode.simdWorldPosition;
    simd_float3 endPos = simd_make_float3(target);
    simd_float3 intermediatePos = (endPos - startPos) * self.relativeTongueStickOutFactor;
    
    self.currentTonguePosition = startPos + intermediatePos;
    self.tongueTip.simdPosition = [self.tongueTip.parentNode.presentationNode simdConvertPosition:self.currentTonguePosition fromNode:nil];
    
    
}

//PRAGMA MARK: - Helper functions
- (float)rad:(float)deg {
    return deg * M_PI / 180;
}

- (simd_float3)randomlyUpdate:(simd_float3)vector {
    switch (arc4random() % 400) {
        case 0: vector.x = 0.1;
            break;
        case 1: vector.x = -0.1;
            break;
        case 2: vector.y = 0.1;
            break;
        case 3: vector.y = -0.1;
            break;
        case 4:
        case 5:
        case 6:
        case 7: vector = simd_make_float3(0.0, 0.0, 0.0);
            break;
        default: break;
            
    }
    
    return simd_make_float3(vector);
}



@end
























