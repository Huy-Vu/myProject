//
//  MGameScene.m
//  projectBoard
//
//  Created by Huy Vu on 10/4/15.
//  Copyright (c) 2015 Huy Vu. All rights reserved.
//



#define kConnectingDevicesText @"Tap to Connect"
#define kGameStartedText       @"Game Started"
#define kConnectedDevicesText  @"Devices Connected"

// Blue is the First and Red is the Second Player
#define kFirstPlayerLabelText  @"You're First Player"
#define kSecondPlayerLabelText @"You're Second Player"

#define kMaxTankPacketSize 1024

#import "MGameScene.h"
#import <CoreMotion/CoreMotion.h>

//declare the category Bit Mask for physics objects we have
static const uint32_t puckCategory = 0x1 << 0;
static const uint32_t malletCategory = 0x1 << 1;
static const uint32_t goalCategory = 0x1 << 2;
//static const uint32_t bodyCategory = 0x1 << 3;

//length of vector
static inline float vectorLength(CGVector a){
    return sqrtf(a.dx*a.dx+a.dy*a.dy);
}
//normalize the vector
static inline CGVector normalizeVector(CGVector a){
    float length = vectorLength(a);
    return CGVectorMake(a.dx/length, a.dy/length);
}
//boost Vector
static inline CGVector boostVector(CGVector a, float b){
    return CGVectorMake(a.dx*b, a.dy*b);
}

typedef enum {
    kGameStatePlayerToConnect,
    kGameStatePlayerAllotment,
    kGameStatePlaying,
    kGameStateComplete,
} GameState;

typedef enum {
    KNetworkPacketCodePlayerAllotment,
    KNetworkPacketCodePlayerMove,
    KNetworkPacketCodePlayerLost,
} NetworkPacketCode;

typedef struct {
//    CGPoint playerPreviousPosition;
    CGPoint playerPosition;
//    CGPoint puckPreviousPosition;
//    CGPoint puckPosition;
} MatchInfo;



@interface MGameScene() <MCSessionDelegate,SKPhysicsContactDelegate>
{
    int gameUniqueIdForPlayerAllocation;
    MatchInfo statsForLocal;
}

@property (nonatomic, assign) int gamePacketNumber;

@property (nonatomic, strong) MCSession* gameSession;
@property (nonatomic, strong) MCPeerID* gamePeerID;
@property (nonatomic, strong) NSString* serviceType;
@property (nonatomic, strong) MCAdvertiserAssistant* advertiser;

@property (nonatomic, strong) SKLabelNode* gameInfoLabel;
@property (nonatomic, assign) GameState gameState;

@property (nonatomic)CMMotionManager *motionManager;
@property (nonatomic)double startX;
@property (nonatomic)double startY;

@property (nonatomic) NSDate *lastUpdateTime;
@property (nonatomic) NSTimeInterval lastUpdateTimeInterval;
@property (nonatomic)double MAXX;
@property (nonatomic)double MAXY;

@property (nonatomic)int scorePlayer;
@property (nonatomic)int scoreOpponent;
@property (nonatomic)CGVector speedPlayer;

@property (nonatomic, strong) SKSpriteNode * Player1;
@property (nonatomic, strong) SKSpriteNode * Player2;
@property (nonatomic, strong) SKShapeNode * MiddleLine;
@property (nonatomic, strong) SKShapeNode * CircleCenter;
@property (nonatomic, strong) SKSpriteNode * remotePlayer;

@end

@implementation MGameScene



#pragma mark - Overridden Methods

-(void)didMoveToView:(SKView *)view {
    /* Setup your scene here */
    
    gameUniqueIdForPlayerAllocation = arc4random();
    
    [self addGameInfoLabelWithText:kConnectingDevicesText];
    self.gameState = kGameStatePlayerToConnect;
    
    [self addGameBackground];
    [self add_puck];
    [self add_mallet];
    [self add_opponent];
    self.scorePlayer = 0;
    self.scoreOpponent = 0;
    [self score:self.scorePlayer and:self.scoreOpponent];
    
    [self add_goals];
    [self setupPhysicsContact];
    [self positioning];
}

#pragma mark - Public Methods

- (void)startGame
{
    if (self.gameState == kGameStatePlayerAllotment)
    {
        self.gameState = kGameStatePlaying;
        
        [self hideGameInfoLabelWithAnimation];
    }
}

- (void)discardSession
{
    self.gameState = kGameStatePlayerToConnect;
    
    self.gameSession = nil;
    self.gamePeerID = nil;
    self.serviceType = nil;
    self.advertiser = nil;
}

#pragma mark - Touch Methods

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    /* Called when a touch begins */
    
    if (self.gameState == kGameStatePlayerToConnect)
    {
        [self instantiateMCSession];
        
        if ([self.gameSceneDelegate respondsToSelector:@selector(showMCBrowserControllerForSession:serviceType:)])
        {
            [self.gameSceneDelegate showMCBrowserControllerForSession:self.gameSession
                                                          serviceType:self.serviceType];
        }
    }
    else if (self.gameState == kGameStatePlaying)
    {
        [self positioning];
    }
}

-(void)update:(CFTimeInterval)currentTime {
    /* Called before each frame is rendered */
    CFTimeInterval timeSinceLast = currentTime - self.lastUpdateTimeInterval ;
    self.lastUpdateTimeInterval = currentTime;
    if (timeSinceLast > 1){ //more than a second since last update
        timeSinceLast = 1.0/60.0;
        self.lastUpdateTimeInterval = currentTime;
    }
    [self opponentMoving];

}

- (void)dealloc
{
    NSLog(@"I'm being dealloc'd");
}

- (void)setMySceneDelegate:(id<GameSceneDelegate>)mySceneDelegate
{
    self.gameSceneDelegate = mySceneDelegate;
    
    NSLog(@"Setting mySceneDelegate");
}

#pragma mark - MCSessionDelegate Methods

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    // A peer has changed state - it's now either connecting, connected, or disconnected.
    
    if (state == MCSessionStateConnected)
    {
        NSLog(@"state == MCSessionStateConnected");
        
        // Remember the current peer.
        self.gamePeerID = peerID;
        // Make sure we have a reference to the game session and it is set up
        self.gameSession = session;
        self.gameSession.delegate = self;
        self.gameState = kGameStatePlayerAllotment;
        
        self.gameInfoLabel.text = kGameStartedText;
        
        [self sendNetworkPacketToPeerId:self.gamePeerID
                          forPacketCode:KNetworkPacketCodePlayerAllotment
                               withData:&gameUniqueIdForPlayerAllocation
                               ofLength:sizeof(int)
                               reliable:YES];
    }
    else if (state == MCSessionStateConnecting)
    {
        NSLog(@"state == MCSessionStateConnecting");
        
        
    }
    else if (state == MCSessionStateNotConnected)
    {
        NSLog(@"state == MCSessionStateNotConnected");
    }
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    // Data has been received from a peer.
    
    // Do something with the received data, on the main thread
    [[NSOperationQueue mainQueue]  addOperationWithBlock:^{
        // Process the data
        
        unsigned char *incomingPacket = (unsigned char *)[data bytes];
        int *pIntData = (int *)&incomingPacket[0];
        NetworkPacketCode packetCode = (NetworkPacketCode)pIntData[1];
        
        switch( packetCode ) {
            case KNetworkPacketCodePlayerAllotment:
            {
                NSInteger gameUniqueId = pIntData[2];
                
                if (gameUniqueIdForPlayerAllocation > gameUniqueId)
                {
                    self.gameInfoLabel.text = kFirstPlayerLabelText;
                    
                }
                else
                {
                    self.gameInfoLabel.text = kSecondPlayerLabelText;
                }
                break;
            }
            case KNetworkPacketCodePlayerMove:
            {
                // received move event from other player, update other player's position/destination info
                MatchInfo *ts = (MatchInfo *)&incomingPacket[8];
                
                self.remotePlayer.position = ts->playerPosition;
                NSLog(@"show remote Player position %f %f",self.remotePlayer.position.x,self.remotePlayer.position.y);
                break;
            }
            default:
                break;
        }
        
    }];
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress {
    // A file started being sent from a peer. (Not used in this example.)
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error {
    // A file finished being sent from a peer. (Not used in this example.)
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID {
    // Data started being streamed from a peer. (Not used in this example.)
}

#pragma mark - Networking Related Methods

- (void)instantiateMCSession
{
    if (self.gameSession == nil)
    {
        UIDevice *device = [UIDevice currentDevice];
        MCPeerID* peerID = [[MCPeerID alloc] initWithDisplayName:device.name];
        
        self.gameSession = [[MCSession alloc] initWithPeer:peerID];
        self.gameSession.delegate = self;
        
        self.serviceType = @"AirHockey129"; // should be unique
        
        self.advertiser =
        [[MCAdvertiserAssistant alloc] initWithServiceType:self.serviceType
                                             discoveryInfo:nil
                                                   session:self.gameSession];
        [self.advertiser start];
    }
}

- (void)sendNetworkPacketToPeerId:(MCPeerID*)peerId
                    forPacketCode:(NetworkPacketCode)packetCode
                         withData:(void *)data
                         ofLength:(NSInteger)length
                         reliable:(BOOL)reliable
{
    // the packet we'll send is resued
    static unsigned char networkPacket[kMaxTankPacketSize];
    const unsigned int packetHeaderSize = 2 * sizeof(int); // we have two "ints" for our header
    
    if(length < (kMaxTankPacketSize - packetHeaderSize))
    {
        // our networkPacket buffer size minus the size of the header info
        int *pIntData = (int *)&networkPacket[0];
        
        // header info
        pIntData[0] = self.gamePacketNumber++;
        pIntData[1] = packetCode;
        
        if (data)
        {
            // copy data in after the header
            memcpy( &networkPacket[packetHeaderSize], data, length );
        }
        
        NSData *packet = [NSData dataWithBytes: networkPacket length: (length+8)];
        
        NSError* error;
        
        if(reliable == YES)
        {
            [self.gameSession sendData:packet
                               toPeers:[NSArray arrayWithObject:peerId]
                              withMode:MCSessionSendDataReliable
                                 error:&error];
        }
        else
        {
            [self.gameSession sendData:packet
                               toPeers:[NSArray arrayWithObject:peerId]
                              withMode:MCSessionSendDataUnreliable
                                 error:&error];
        }
        
        if (error)
        {
            NSLog(@"Error:%@",[error description]);
        }
    }
}

#pragma mark - Adding Assets Methods

- (void)addGameInfoLabelWithText:(NSString*)labelText
{
    if (self.gameInfoLabel == nil) {
        self.gameInfoLabel = [SKLabelNode labelNodeWithFontNamed:@"Chalkduster"];
        self.gameInfoLabel.text = labelText;
        self.gameInfoLabel.fontSize = 32;
        self.gameInfoLabel.position = CGPointMake(CGRectGetMidX(self.frame),
                                                  CGRectGetMidY(self.frame));
        self.gameInfoLabel.zPosition = 100;
        
        [self addChild:self.gameInfoLabel];
    }
}


#pragma mark - Delevop Game theme and objects

-(void)addGameBackground
{
    self.physicsWorld.contactDelegate = self;
    //set up the physics world with no gravity, it bases on vector value
    self.physicsWorld.gravity = CGVectorMake(0.0f, 0.0f);
    
    //set up the backgound (playfield)
    SKSpriteNode *body = [SKSpriteNode spriteNodeWithColor:[UIColor grayColor] size:self.frame.size];
    body.position = CGPointMake(self.frame.size.width/2, self.frame.size.height/2);
    body.zPosition = 0;
    [self addChild:body];
    
    //draw a circle on the ground
    CGRect box = CGRectMake(self.frame.size.width*0.1, self.frame.size.height/2-self.frame.size.width*0.4, self.frame.size.width*0.8, self.frame.size.width*0.8);
    
    UIBezierPath *circlePath = [UIBezierPath bezierPathWithOvalInRect:box];
    
    // //another method to draw circle Path
    //CGMutablePathRef circlePath = CGPathCreateMutable();
    //CGPathAddArc(circlePath, NULL, 0, 0, 100, 0, M_PI * 2, YES);
    
    SKShapeNode *circle = [SKShapeNode node];
    circle.path = circlePath.CGPath;
    circle.lineWidth = 6.0;
    //circle.position = CGPointMake(self.frame.size.width/2, self.frame.size.height/2);
    circle.fillColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];
    circle.strokeColor = [UIColor blueColor];
    circle.zPosition = 0;
    [self addChild:circle];

    //draw the middle line
    CGRect midLine = CGRectMake(0, self.frame.size.height/2-3, self.frame.size.width, 6);
    SKShapeNode *line = [SKShapeNode shapeNodeWithRect:midLine];
    line.strokeColor =[UIColor blueColor];
    line.fillColor = [UIColor blueColor];
    line.zPosition =0;
    [self addChild:line];
    
    
    // set up the evironment of box2D
    //1 create a physics body that borders the screen
    SKPhysicsBody *borderBody = [SKPhysicsBody bodyWithEdgeLoopFromRect:self.frame];
    //2 Set physicsBody of scene to borderBody
    self.physicsBody = borderBody;
    //3 Set the friction of that physicsBody to zero
    self.physicsBody.friction =0.0f;

}

-(void)add_mallet{
    //set up the mallet
    SKSpriteNode *mallet = [SKSpriteNode spriteNodeWithImageNamed:@"waitingpenguin.png"];
    mallet.position = CGPointMake(self.frame.size.width/2, mallet.size.height/2);
    
    //physics body of mallet
    mallet.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:mallet.size.width/2];
    mallet.physicsBody.friction = 0.0f;
    mallet.physicsBody.restitution = 1.0f;
    mallet.physicsBody.linearDamping = 0.0f;
    mallet.physicsBody.density= 100000.0f; //fail to simulate the speed for mallet to have force from moving object
    mallet.physicsBody.mass = 100000.0f;
    mallet.zPosition = 1;
    mallet.name = @"mallet";
    [self addChild:mallet];
    
    mallet.physicsBody.dynamic = YES;
}

-(void)add_mallet2{
    //set up the mallet
    SKSpriteNode *mallet2 = [SKSpriteNode spriteNodeWithImageNamed:@"waitingpenguin.png"];
    mallet2.position = CGPointMake(self.frame.size.width/2, self.frame.size.height - mallet2.size.height/2);
    
    //physics body of mallet
    mallet2.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:mallet2.size.width/2];
    mallet2.physicsBody.friction = 0.0f;
    mallet2.physicsBody.restitution = 1.0f;
    mallet2.physicsBody.linearDamping = 0.0f;
    mallet2.physicsBody.density= 100000.0f; //fail to simulate the speed for mallet to have force from moving object
    mallet2.physicsBody.mass = 100000.0f;
    mallet2.zPosition = 1;
    mallet2.name = @"mallet2";
    [self addChild:mallet2];
    
    mallet2.physicsBody.dynamic = YES;
}
-(void)add_opponent{
    //set up opponent mallet
    SKSpriteNode *opponent = [SKSpriteNode spriteNodeWithImageNamed:@"seal.png"];
    opponent.position = CGPointMake(self.frame.size.width/2, self.frame.size.height - opponent.size.height/2);
    
    opponent.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:opponent.size.height/2];
    opponent.physicsBody.friction = 0.0f;
    opponent.physicsBody.restitution = 1.0f;
    opponent.physicsBody.linearDamping = 1.0f;
    opponent.physicsBody.density=1.0f;
    opponent.physicsBody.mass = 10.0f;
    opponent.zPosition = 1;
    opponent.name = @"opponent";
    [self addChild:opponent];
    self.remotePlayer = opponent;
    //    opponent.physicsBody.dynamic = YES;
}

-(void)add_puck{
    //set up the ball(puck)
    SKSpriteNode *puck = [SKSpriteNode spriteNodeWithImageNamed:@"ball.png"];
    puck.position = CGPointMake(self.frame.size.width/2, puck.size.height*4);
    
    //make the physics body of puck
    puck.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:puck.size.width/2];
    puck.physicsBody.friction = 0.0f;
    puck.physicsBody.restitution = 0.9f;
    puck.physicsBody.linearDamping = 0.0f;
    puck.physicsBody.density = 1.0f;
    puck.physicsBody.mass = 1.0f;
    puck.physicsBody.allowsRotation = YES;
    puck.zPosition = 1;
    puck.name = @"puck";
    [self addChild:puck];
}

-(void)add_goals{
    //create the goal
    SKSpriteNode *goal = [SKSpriteNode spriteNodeWithColor:[UIColor yellowColor] size:CGSizeMake(self.frame.size.width/3,1.6f)];
    goal.position = CGPointMake(self.frame.size.width/2, 0.8f);
    goal.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake(self.frame.size.width/3,1.6f)];
    goal.physicsBody.dynamic = NO;
    goal.zPosition =1;
    goal.name = @"goal";
    [self addChild:goal];
    
    SKSpriteNode *goal2 = [SKSpriteNode spriteNodeWithColor:[UIColor yellowColor] size:CGSizeMake(self.frame.size.width/3,3.6f)];
    goal2.position = CGPointMake(self.frame.size.width/2, self.frame.size.height -1.8f);
    goal2.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake(self.frame.size.width/3,1.6f)];
    goal2.physicsBody.dynamic = NO;
    goal2.zPosition = 1;
    goal2.name = @"goal2";
    [self addChild:goal2];
}

-(void)setupPhysicsContact{
    SKSpriteNode *puck = (SKSpriteNode *)[self childNodeWithName:@"puck"];
    SKSpriteNode *mallet = (SKSpriteNode *)[self childNodeWithName:@"mallet"];
    SKSpriteNode *goal = (SKSpriteNode *)[self childNodeWithName:@"goal"];
    SKSpriteNode *goal2 = (SKSpriteNode *)[self childNodeWithName:@"goal2"];
    
    //setup the Category Bit Mask
    puck.physicsBody.categoryBitMask = puckCategory;
    mallet.physicsBody.categoryBitMask = malletCategory;
    goal.physicsBody.categoryBitMask = goalCategory;
    goal2.physicsBody.categoryBitMask = goalCategory;
    
    //define the interaction that we care about
    puck.physicsBody.contactTestBitMask = goalCategory | malletCategory; //get notice when puck touch goal
    
    puck.physicsBody.collisionBitMask = malletCategory; //physics force when puck interact with mallet
}
-(void)positioning{
    SKSpriteNode *mallet = (SKSpriteNode *)[self childNodeWithName:@"mallet"];
    
    //try to deal with positioning
    self.motionManager = [CMMotionManager new];
    self.motionManager.accelerometerUpdateInterval = 1.0/60.0;
    self.motionManager.gyroUpdateInterval = .05;
    
    self.lastUpdateTime = [[NSDate alloc] init];
    self.startX = self.frame.size.width/2;
    self.startY = mallet.size.height/2;
    self.MAXX = self.frame.size.width - mallet.size.width/2;
    self.MAXY = self.frame.size.height/2 - mallet.size.height;
    NSLog(@"start rote X: %f start rote Y: %f",self.startX,self.startY);
    //
    [self.motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue new] withHandler:^(CMAccelerometerData *acceData, NSError *error){
        
        
        // NSTimeInterval secondsSinceLastDraw = -([self.lastUpdateTime timeIntervalSinceNow]);
        NSTimeInterval secondsSinceLastDraw = self.lastUpdateTimeInterval;
        if (secondsSinceLastDraw >1) {
            secondsSinceLastDraw = 1.0/60.0;
        }
        
        self.startX = self.startX + secondsSinceLastDraw *acceData.acceleration.x*700;
        self.startY = self.startY + secondsSinceLastDraw *acceData.acceleration.y*1500;
        
        
        //NSLog(@"the X: %f the Y: %f",self.theX,self.theY);
        
        self.startX = MIN(self.MAXX, self.startX);
        self.startX = MAX(mallet.size.width/2, self.startX);
        self.startY = MAX(mallet.size.width/2, self.startY);
        self.startY = MIN(self.MAXY, self.startY);
        
        mallet.position = CGPointMake(self.startX, self.startY);
        
        //    self.lastUpdateTime = [NSDate date];
        
        // Send NetworkPacket for syncing the data at both the players
        statsForLocal.playerPosition = [self reverseCoordinator:mallet.position];
        
        if (self.gameState == kGameStatePlaying) {
            NSLog(@"go inside sending movement, ");
            [self sendNetworkPacketToPeerId:self.gamePeerID
                              forPacketCode:KNetworkPacketCodePlayerMove
                                   withData:&statsForLocal
                                   ofLength:sizeof(MatchInfo)
                                   reliable:YES];
        }
        
    }];
    
}
-(void)opponentMoving{
    
    SKSpriteNode *opponent = (SKSpriteNode *)[self childNodeWithName:@"opponent"];
    opponent.position = self.remotePlayer.position;
    NSLog(@"remote position: %f %f",opponent.position.x,opponent.position.y);
    
}
-(void)score:(int)playerScore and:(int)opponentScore{
    //clear previous Score
    SKLabelNode *clearLabel =(SKLabelNode *)[self childNodeWithName:@"scorePlayer"];
    [clearLabel removeFromParent];
    SKLabelNode *clearLabel2 =(SKLabelNode *)[self childNodeWithName:@"scoreOpponent"];
    [clearLabel2 removeFromParent];
    
    //update score
    SKLabelNode *scorePlayer = [SKLabelNode labelNodeWithFontNamed:@"ArialHebrew-Bold"];
    scorePlayer.position = CGPointMake(10, self.frame.size.height/2 - 30);
    scorePlayer.fontSize = 40;
    scorePlayer.fontColor = [SKColor blackColor];
    scorePlayer.zPosition = 120;
    scorePlayer.text = [NSString stringWithFormat:@"%d",playerScore];
    scorePlayer.name = @"scorePlayer";
    [self addChild:scorePlayer];
    
    SKLabelNode *scoreOpponent = [SKLabelNode labelNodeWithFontNamed:@"ArialHebrew-Bold"];
    scoreOpponent.position = CGPointMake(10, self.frame.size.height/2 + 10);
    scoreOpponent.fontSize = 40;
    scoreOpponent.fontColor = [SKColor blackColor];
    scoreOpponent.zPosition = 120;
    scoreOpponent.text = [NSString stringWithFormat:@"%d",opponentScore];
    scoreOpponent.name = @"scoreOpponent";
    [self addChild:scoreOpponent];
}

-(void)flashMessage:(NSString *)message atPosition:(CGPoint)position duration:(NSTimeInterval)duration{
    //a method to make a sprite for a flash message at a certain position on the screen
    //to be used for instructions
    
    //make a label that is invisible
    SKLabelNode *flashLabel = [SKLabelNode labelNodeWithFontNamed:@"MarkerFelt-Wide"];
    flashLabel.position = position;
    flashLabel.fontSize = 60;
    flashLabel.fontColor = [SKColor blackColor];
    flashLabel.text = message;
    flashLabel.alpha =0;
    flashLabel.zPosition = 100;
    [self addChild:flashLabel];
    //make an animation sequence to flash in and out the label
    SKAction *flashAction = [SKAction sequence:@[
                                                 [SKAction fadeInWithDuration:duration/3.0],
                                                 [SKAction waitForDuration:duration],
                                                 [SKAction fadeOutWithDuration:duration/3.0]
                                                 ]];
    // run the sequence then delete the label
    [flashLabel runAction:flashAction completion:^{[flashLabel removeFromParent];}];
    
}

-(CGVector)getVectorfrom:(CGPoint)point1
                      to:(CGPoint)point2{
    
    return CGVectorMake(10*(point2.x-point1.x), 10*(point2.y-point1.y));
}

-(void)didBeginContact:(SKPhysicsContact *)contact{
    
    SKPhysicsBody *firstBody;
    SKPhysicsBody *secondBody;
    
    if (contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask) {
        firstBody = contact.bodyA;
        secondBody = contact.bodyB;
    } else {
        firstBody = contact.bodyB;
        secondBody = contact.bodyA;
    }
    
    if (firstBody.categoryBitMask == puckCategory && secondBody.categoryBitMask == malletCategory) {
        SKSpriteNode *puck =(SKSpriteNode *)[self childNodeWithName:@"puck"];
        SKSpriteNode *mallet =(SKSpriteNode *)[self childNodeWithName:@"mallet"];
        NSLog(@" go inside contact between puck and mallet");
        
        //        CGVector impulseForce = addVector(puck.physicsBody.velocity,[self getVectorfrom:puck.position to:mallet.position]);
        //        [puck.physicsBody applyImpulse:impulseForce];
        if ([self checkspeed]==YES) {
            [puck.physicsBody applyImpulse:[self getVectorfrom:puck.position to:mallet.position]];
        } else {
            //            [puck.physicsBody applyImpulse:[self getVectorfrom:puck.position to:mallet.position]];
            CGVector force = [self getVectorfrom:puck.position to:mallet.position];
            CGVector mforce = CGVectorMake(force.dx*500000, force.dy*500000);
            [puck.physicsBody applyForce:mforce];
            
        }
        
    }
    
    if (firstBody.categoryBitMask == puckCategory && secondBody.categoryBitMask == goalCategory) {
        SKSpriteNode *puck = (SKSpriteNode *)[self childNodeWithName:@"puck"];
        SKSpriteNode *mallet = (SKSpriteNode *)[self childNodeWithName:@"mallet"];
        SKSpriteNode *opponent = (SKSpriteNode *)[self childNodeWithName:@"opponent"];
        // SKSpriteNode *goal = (SKSpriteNode *)[self childNodeWithName:@"goal"];
        
        [self flashMessage:@"GOOAL!!!" atPosition:CGPointMake(self.frame.size.width/2, self.frame.size.height/2) duration:2];
        if (puck.position.y > self.frame.size.height/2){
            self.scorePlayer +=1;
        }else self.scoreOpponent +=1;
        
        [puck removeFromParent];
        [mallet removeFromParent];
        [opponent removeFromParent];
        [self add_puck];
        [self add_mallet];
        [self add_opponent];
        [self setupPhysicsContact];
        [self positioning];
        [self score:self.scorePlayer and:self.scoreOpponent];
    }
}

-(BOOL)checkspeed{
    SKSpriteNode *puck =(SKSpriteNode *)[self childNodeWithName:@"puck"];
    
    float speed = vectorLength(puck.physicsBody.velocity);
    NSLog(@"speed of puck %f",speed);
    if (speed < 100){
        return YES;
    }
    return NO;
}
#pragma mark - game updation methods


- (void)hideGameInfoLabelWithAnimation
{
    SKAction* gameInfoLabelHoldAnimationCallBack =
    [SKAction customActionWithDuration:2.0
                           actionBlock:^(SKNode *node,CGFloat elapsedTime)
     {
     }];
    
    SKAction* gameInfoLabelFadeOutAnimation =
    [SKAction fadeOutWithDuration:1.0];
    
    SKAction* gameInfoLabelRemoveAnimationCallBack =
    [SKAction customActionWithDuration:0.0
                           actionBlock:^(SKNode *node,CGFloat elapsedTime)
     {
         [node removeFromParent];
         
         self.gameInfoLabel = nil;
     }];
    
    NSArray* gameLabelAnimationsSequence =
    [NSArray arrayWithObjects:gameInfoLabelHoldAnimationCallBack,gameInfoLabelFadeOutAnimation, gameInfoLabelRemoveAnimationCallBack, nil];
    SKAction* gameInfoSequenceAnimation =
    [SKAction sequence:gameLabelAnimationsSequence];
    [self.gameInfoLabel runAction:gameInfoSequenceAnimation];
}


#pragma mark - reverse position of remote player 
-(CGPoint)reverseCoordinator:(CGPoint)input{
    
    NSLog(@"before reverse position: %f %f",input.x, input.y);
    CGPoint reverse = CGPointMake(self.frame.size.width-input.x ,self.frame.size.height-input.y);
    NSLog(@"before reverse position: %f %f",reverse.x, reverse.y);
    return reverse;
}
@end


