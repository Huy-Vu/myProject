//
//  GameViewController.m
//  projectBoard
//
//  Created by Huy Vu on 10/4/15.
//  Copyright (c) 2015 Huy Vu. All rights reserved.
//

#import "MGameViewController.h"
#import "MGameScene.h"

@interface MGameViewController() <MCBrowserViewControllerDelegate, GameSceneDelegate>

@property (nonatomic, strong) MGameScene* gameScene;

@end

@implementation SKScene (Unarchive)

+ (instancetype)unarchiveFromFile:(NSString *)file {
    /* Retrieve scene file path from the application bundle */
    NSString *nodePath = [[NSBundle mainBundle] pathForResource:file ofType:@"sks"];
    /* Unarchive the file to an SKScene object */
    NSData *data = [NSData dataWithContentsOfFile:nodePath
                                          options:NSDataReadingMappedIfSafe
                                            error:nil];
    NSKeyedUnarchiver *arch = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    [arch setClass:self forClassName:@"SKScene"];
    SKScene *scene = [arch decodeObjectForKey:NSKeyedArchiveRootObjectKey];
    [arch finishDecoding];
    
    return scene;
}

@end

@implementation MGameViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Configure the view.
    SKView * skView = (SKView *)self.view;
    //skView.showsFPS = YES;
    //skView.showsNodeCount = YES;
    /* Sprite Kit applies additional optimizations to improve rendering performance */
    skView.ignoresSiblingOrder = YES;
    
    // Create and configure the scene.
    
    //CGSize mysize = CGSizeMake(640, 1136);
    //self.gameScene = [MGameScene sceneWithSize:mysize];
    self.gameScene = [MGameScene sceneWithSize:skView.frame.size];
    //self.gameScene = [MGameScene unarchiveFromFile:@"GameScene"];
    self.gameScene.scaleMode = SKSceneScaleModeAspectFill;
    
    self.gameScene.gameSceneDelegate = self;
    // Present the scene.
    [skView presentScene:self.gameScene];
}

-(void)viewWillLayoutSubviews{
    [super viewWillLayoutSubviews];

    
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskAllButUpsideDown;
    } else {
        return UIInterfaceOrientationMaskAll;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

#pragma mark - MCBrowserViewControllerDelegate Methods

- (void)browserViewControllerDidFinish:(MCBrowserViewController *)browserViewController {
    // The MCSession is now ready to use.
    
    [self dismissViewControllerAnimated:YES completion:nil];
    
    if (self.gameScene)
    {
        [self.gameScene startGame];
    }
}

- (void)browserViewControllerWasCancelled:(MCBrowserViewController *)browserViewController {
    // The user cancelled.
    
    [self dismissViewControllerAnimated:YES completion:nil];
    
    if (self.gameScene)
    {
        [self.gameScene discardSession];
    }
}


#pragma mark - GameSceneDelegate Methods

- (void)showMCBrowserControllerForSession:(MCSession*)session
                              serviceType:(NSString*)serviceType
{
    MCBrowserViewController* viewController = [[MCBrowserViewController alloc] initWithServiceType:serviceType session:session];
    
    viewController.minimumNumberOfPeers = 2;
    viewController.maximumNumberOfPeers = 2;
    
    viewController.delegate = self;
    
    [self presentViewController:viewController animated:YES completion:nil];
}

- (IBAction)stopButton:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

@end
