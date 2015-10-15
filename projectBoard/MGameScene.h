//
//  MGameScene.h
//  projectBoard
//

//  Copyright (c) 2015 Huy Vu. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>

@protocol GameSceneDelegate <NSObject>

- (void)showMCBrowserControllerForSession:(MCSession*)session
                              serviceType:(NSString*)serviceType;
@end

@interface MGameScene : SKScene

@property (nonatomic, weak) id<GameSceneDelegate> gameSceneDelegate;
@property (nonatomic) NSString * thebackground;
@property (nonatomic) NSString * themallet;

-(void)startGame;
-(void)discardSession;

@end
