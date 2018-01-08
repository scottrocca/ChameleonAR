//
//  ViewController.m
//  InteractiveContent
//
//  Created by Scott Rocca on 12/30/17.
//  Copyright © 2017 Scott Rocca. All rights reserved.
//

#import "ViewController.h"
#import <SceneKit/SceneKit.h>
#import <ARKit/ARKit.h>
#import "Chameleon.h"

@interface ViewController () <ARSCNViewDelegate, ARSessionObserver>
@property (weak, nonatomic) IBOutlet ARSCNView *sceneView;
@property (weak, nonatomic) IBOutlet UIVisualEffectView *toast;
@property (weak, nonatomic) IBOutlet UILabel *label;
@property (strong, nonatomic)Chameleon *chameleon;


@end

@implementation ViewController



- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Set the view's delegate
    self.sceneView.delegate = self;
    
    self.chameleon = [[Chameleon alloc] init];
    
    // Set the scene to the view
    self.sceneView.scene = self.chameleon;
    
    self.sceneView.automaticallyUpdatesLighting = NO;

    
}


- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    if(!ARWorldTrackingConfiguration.isSupported){
        return;
    }
    
    // Prevent the screen from being dimmed after a while
    UIApplication.sharedApplication.idleTimerDisabled = YES;
    
    [self startNewSession];
    
    
    
}


- (void)startNewSession{
    [self.chameleon hide];
    
    // Create a session configuration
    ARWorldTrackingConfiguration *configuration = [ARWorldTrackingConfiguration new];
    configuration.planeDetection = ARPlaneDetectionHorizontal; // no plane detection
    
    // Run the view's session
    [self.sceneView.session runWithConfiguration:configuration options:ARSessionRunOptionRemoveExistingAnchors | ARSessionRunOptionResetTracking];
    
}

- (IBAction)didTap:(UITapGestureRecognizer *)sender {
    CGPoint location = [sender locationInView:self.sceneView];
    NSArray<SCNHitTestResult *> *sceneHitTestResult =[self.sceneView hitTest:location options:nil];

    if( sceneHitTestResult.count > 0){
        [self.chameleon reactToTap:self.sceneView];
        return;
    }
    
     NSArray<ARHitTestResult *> *arHitTestResult = [self.sceneView hitTest:location types:ARHitTestResultTypeExistingPlane];
    
    if( arHitTestResult.count > 0){
        ARHitTestResult *hit = arHitTestResult[0];
        [self.chameleon setTransform:hit.worldTransform];
        [self.chameleon reactToPositionChange:self.sceneView];

    }
    
}

- (IBAction)didPan:(UIPanGestureRecognizer *)sender {
    CGPoint location = [sender locationInView:self.sceneView];
    // Drag the object on an infinite plane
    NSArray<ARHitTestResult *> *arHitTestResult = [self.sceneView hitTest:location types:ARHitTestResultTypeExistingPlane];
    if( arHitTestResult.count > 0){
        ARHitTestResult *hit = arHitTestResult[0];
        [self.chameleon setTransform:hit.worldTransform];
        if(sender.state == UIGestureRecognizerStateEnded){
            [self.chameleon reactToPositionChange:self.sceneView];
        }
    }
}



#pragma mark - ARSCNViewDelegate
- (void)renderer:(id<SCNSceneRenderer>)renderer didAddNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor{
    if( [self.chameleon isVisible] ){
        return;
    }
    
    // Unhide the content and position it on the detected plane
    if([anchor isKindOfClass:[ARPlaneAnchor class]]){
        [self.chameleon setTransform:anchor.transform];
        [self.chameleon show];
        [self.chameleon reactToInitialPlacement:self.sceneView];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideToast];
        });
    }
}

- (void)renderer:(id<SCNSceneRenderer>)renderer updateAtTime:(NSTimeInterval)time{
    [self.chameleon reactToRendering:self.sceneView];
}

- (void)renderer:(id<SCNSceneRenderer>)renderer didApplyConstraintsAtTime:(NSTimeInterval)time {
    [self.chameleon reactToDidApplyConstraints:self.sceneView];
}

- (void)sessionWasInterrupted:(ARSession *)session {
    [self showToast:@"Session was interrupted"];
}

- (void)sessionInterruptionEnded:(ARSession *)session {
    [self startNewSession];
}

- (void)session:(ARSession *)session didFailWithError:(NSError *)error {
    [self showToast:[[NSString alloc] initWithFormat:@"Session failed: %@", error.localizedDescription]];
    [self startNewSession];
}

- (void)session:(ARSession *)session cameraDidChangeTrackingState:(ARCamera *)camera {
    NSString *message;
    
    if (camera.trackingState == ARTrackingStateNotAvailable) {
        message = @"Tracking not available";
    }
    else{
        switch (camera.trackingStateReason) {
            case ARTrackingStateReasonInitializing:
                message = @"Initializing AR session";
                break;
                
            case ARTrackingStateReasonExcessiveMotion:
                message = @"Too much motion";
                break;
                
            case ARTrackingStateReasonInsufficientFeatures:
                message = @"Not enough surface details";
            default:
                if (camera.trackingState == ARTrackingStateNormal) {
                    if ([self.chameleon isVisible]) {
                        message = @"Move to find a horizontal surface";
                    }
                }
                break;
        }
    }
    
    message != nil ? [self showToast:message] : [self hideToast];

}

- (void)showToast:(NSString *)text {
    self.label.text = text;
    
    if (self.toast.alpha != 0) {
        return;
    }
    
    self.toast.layer.masksToBounds = YES;
    self.toast.layer.cornerRadius = 7.5;
    
    [UIView animateWithDuration:0.25 animations:^{
        self.toast.alpha = 1;
        self.toast.frame = CGRectInset(self.toast.frame, -5, -5);
    }];
    
}

- (void)hideToast{
    [UIView animateWithDuration:0.25 animations:^{
        self.toast.alpha = 0;
        self.toast.frame = CGRectInset(self.toast.frame, 5, 5);
    }];
}
@end



















