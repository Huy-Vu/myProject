//
//  GameScene.m
//  projectBoard
//
//  Created by Huy Vu on 10/4/15.
//  Copyright (c) 2015 Huy Vu. All rights reserved.
//

#import "GameScene.h"
#import <CoreMotion/CoreMotion.h>

//declare the category Bit Mask for physics objects we have
static const uint32_t puckCategory = 0x1 << 0;
static const uint32_t malletCategory = 0x1 << 1;
static const uint32_t goalCategory = 0x1 << 2;
static const uint32_t borderCategory = 0x1 << 3;
static const uint32_t opponentCategory = 0x1 << 4;

//length of vector
static inline float vectorLength(CGVector a){
    return sqrtf(a.dx*a.dx+a.dy*a.dy);
}
//add two vector
static inline CGVector addVector(CGVector a,CGVector b){
    return CGVectorMake(a.dx+b.dx, a.dy+b.dy);
}
//substract vector
static inline CGVector subVector(CGVector a,CGVector b){
    return CGVectorMake(a.dx-b.dx, a.dy-b.dy);
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


@interface GameScene()<SKPhysicsContactDelegate>

@property (nonatomic)CMMotionManager *motionManager;
@property (nonatomic)double startX;
@property (nonatomic)double startY;

@property (nonatomic) NSDate *lastUpdateTime;
@property (nonatomic)NSTimeInterval lastUpdateTimeInterval;
@property (nonatomic)double MAXX;
@property (nonatomic)double MAXY;

@property (nonatomic)int scorePlayer;
@property (nonatomic)int scoreOpponent;
@property (nonatomic)float speedOpponent;
@property (nonatomic)CGPoint targetOpponent;

@property (nonatomic)CGVector speedPlayer;

@property (nonatomic)int scoreWin;
//extern NSString * thebackgound;
//extern NSString * themallet;
@end

@implementation GameScene

-(void)didMoveToView:(SKView *)view {
    /* Setup your scene here */
    [self addGameBackground];
    
    [self add_puck];
    [self add_mallet];
    [self add_opponent];
    
    self.scorePlayer = 0;
    self.scoreOpponent = 0;
    [self score:self.scorePlayer and:self.scoreOpponent];
    
    [self add_goals];
    [self setupPhysicsContact];
    
    //[self positioning];
    
    //setting the difficulty of game:
    self.speedOpponent = 1000000.0;
    self.scoreWin =3;
}

-(id)initWithSize:(CGSize)size{
    if (self == [super initWithSize:size]) {

    };
    return self;
}

-(void)reset{
    
    SKSpriteNode *puck = (SKSpriteNode *)[self childNodeWithName:@"puck"];
    SKSpriteNode *mallet = (SKSpriteNode *)[self childNodeWithName:@"mallet"];
    SKSpriteNode *opponent = (SKSpriteNode *)[self childNodeWithName:@"opponent"];
    
    [puck removeFromParent];
    [mallet removeFromParent];
    [opponent removeFromParent];
    
    
    [self add_puck];
    [self add_mallet];
    [self add_opponent];
    [self setupPhysicsContact];
    SKSpriteNode *over = (SKSpriteNode *)[self childNodeWithName:@"over"];
    [over removeFromParent];
    self.scorePlayer = 0;
    self.scoreOpponent = 0;
    [self score:self.scorePlayer and:self.scoreOpponent];

}

-(void)addGameBackground
{
    self.physicsWorld.contactDelegate = self;
    //set up the physics world with no gravity, it bases on vector value
    self.physicsWorld.gravity = CGVectorMake(0.0f, 0.0f);
    
    //set up the backgound (playfield)
    
    SKSpriteNode *body = [SKSpriteNode spriteNodeWithImageNamed:self.thebackground];
    //SKSpriteNode *body = [SKSpriteNode spriteNodeWithColor:[UIColor grayColor] size:self.frame.size];
    
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
    circle.zPosition = 1;
    [self addChild:circle];
    
    //draw the middle line
    CGRect midLine = CGRectMake(0, self.frame.size.height/2-3, self.frame.size.width, 6);
    SKShapeNode *line = [SKShapeNode shapeNodeWithRect:midLine];
    line.strokeColor =[UIColor blueColor];
    line.fillColor = [UIColor blueColor];
    line.zPosition =1;
    [self addChild:line];
    
//    // set up the evironment of box2D
//    //1 create a physics body that borders the screen
//    SKPhysicsBody *borderBody = [SKPhysicsBody bodyWithEdgeLoopFromRect:self.frame];
//    //2 Set physicsBody of scene to borderBody
//    self.physicsBody = borderBody;
//    //3 Set the friction of that physicsBody to zero
//    self.physicsBody.friction =0.0f;
    
    // set up the surround edge for sound effect
    //1 create a physics body that borders the screen
    SKSpriteNode *border =[[SKSpriteNode alloc] init];
    //border.physicsBody =[SKPhysicsBody bodyWithEdgeLoopFromRect:self.frame];
    border.physicsBody = [SKPhysicsBody bodyWithEdgeLoopFromRect:CGRectMake(5, 5, self.frame.size.width-5,self.frame.size.height - 5)];
    //2 Set physicsBody of scene to borderBody
    self.physicsBody = border.physicsBody;
    //3 Set the friction of that physicsBody to zero
    self.physicsBody.friction =0.0f;
    //4 body position
    border.zPosition= 5;
    border.name = @"border";
    //[self addChild:border];
    
    
}

-(void)gameOverBackground{
//    SKSpriteNode *over = [SKSpriteNode spriteNodeWithImageNamed:self.thebackground];
//    //SKSpriteNode *body = [SKSpriteNode spriteNodeWithColor:[UIColor grayColor] size:self.frame.size];
//    over.position = CGPointMake(self.frame.size.width/2, self.frame.size.height/2);
//    over.zPosition = 20;
//    over.name =@"over";
//    [self addChild:over];
    SKSpriteNode *puck = (SKSpriteNode *)[self childNodeWithName:@"puck"];
    SKSpriteNode *mallet = (SKSpriteNode *)[self childNodeWithName:@"mallet"];
    SKSpriteNode *opponent = (SKSpriteNode *)[self childNodeWithName:@"opponent"];
    //[self.motionManager stopAccelerometerUpdates];
    [puck removeFromParent];
    [mallet removeFromParent];
    [opponent removeFromParent];
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
    puck.physicsBody.mass = 2.0f;
    puck.physicsBody.usesPreciseCollisionDetection = YES;
    puck.physicsBody.allowsRotation = YES;
    puck.zPosition = 5;
    puck.name = @"puck";
    [self addChild:puck];
}

-(void)add_mallet{
    //set up the mallet
    SKSpriteNode *mallet = [SKSpriteNode spriteNodeWithImageNamed:self.themallet];
    mallet.position = CGPointMake(self.frame.size.width/2, mallet.size.height/2);
    
    //physics body of mallet
    mallet.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:mallet.size.width/2];
    mallet.physicsBody.friction = 0.0f;
    mallet.physicsBody.restitution = 1.0f;
    mallet.physicsBody.linearDamping = 0.0f;
    mallet.physicsBody.density= 10000.0f; //fail to simulate the speed for mallet to have force from moving object
    mallet.physicsBody.mass = 10000.0f;
    mallet.physicsBody.usesPreciseCollisionDetection=YES;
    mallet.zPosition =5;
    mallet.name = @"mallet";
    [self addChild:mallet];
    
    mallet.physicsBody.dynamic = NO;
    [self positioning];
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
    opponent.physicsBody.mass = 1000.0f;
    opponent.zPosition =5;
    opponent.name = @"opponent";
    [self addChild:opponent];

    opponent.physicsBody.dynamic = YES;
}

-(void)add_goals{
    //create the goal
    SKSpriteNode *goal = [SKSpriteNode spriteNodeWithColor:[UIColor yellowColor] size:CGSizeMake(self.frame.size.width/3,1.6f)];
    goal.position = CGPointMake(self.frame.size.width/2, 0.8f);
    goal.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake(self.frame.size.width/3,1.6f)];
    goal.physicsBody.dynamic = NO;
    goal.zPosition=5;
    goal.name = @"goal";
    [self addChild:goal];
    
    SKSpriteNode *goal2 = [SKSpriteNode spriteNodeWithColor:[UIColor yellowColor] size:CGSizeMake(self.frame.size.width/3,3.6f)];
    goal2.position = CGPointMake(self.frame.size.width/2, self.frame.size.height -1.8f);
    goal2.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake(self.frame.size.width/3,1.6f)];
    goal2.physicsBody.dynamic = NO;
    goal2.zPosition = 5;
    goal2.name = @"goal2";
    [self addChild:goal2];
}

-(void)setupPhysicsContact{
    SKSpriteNode *puck = (SKSpriteNode *)[self childNodeWithName:@"puck"];
    SKSpriteNode *mallet = (SKSpriteNode *)[self childNodeWithName:@"mallet"];
    SKSpriteNode *goal = (SKSpriteNode *)[self childNodeWithName:@"goal"];
    SKSpriteNode *goal2 = (SKSpriteNode *)[self childNodeWithName:@"goal2"];
    SKSpriteNode *border = (SKSpriteNode *)[self childNodeWithName:@"border"];
   // SKSpriteNode *opponent =(SKSpriteNode *)[self childNodeWithName:@"opponent"];
    //setup the Category Bit Mask
    puck.physicsBody.categoryBitMask = puckCategory;
    mallet.physicsBody.categoryBitMask = malletCategory;
    goal.physicsBody.categoryBitMask = goalCategory;
    goal2.physicsBody.categoryBitMask = goalCategory;
    border.physicsBody.categoryBitMask = borderCategory;
    //opponent.physicsBody.categoryBitMask = opponentCategory;
    //define the interaction that we care about
    puck.physicsBody.contactTestBitMask = goalCategory | malletCategory | borderCategory | opponentCategory; //get notice when puck touch anything
    
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
        self.speedPlayer = CGVectorMake(secondsSinceLastDraw *acceData.acceleration.x*800, secondsSinceLastDraw *acceData.acceleration.y*1500);
        NSLog(@"speed of player %f", vectorLength(self.speedPlayer));
        if (vectorLength(self.speedPlayer)>20) {
            self.speedPlayer = boostVector(normalizeVector(self.speedPlayer),20);
        }
        self.startX = self.startX + self.speedPlayer.dx;
        self.startY = self.startY + self.speedPlayer.dy;
        
        
        //NSLog(@"the X: %f the Y: %f",self.theX,self.theY);
        
        self.startX = MIN(self.MAXX, self.startX);
        self.startX = MAX(mallet.size.width/2, self.startX);
        self.startY = MAX(mallet.size.width/2, self.startY);
        self.startY = MIN(self.MAXY, self.startY);
        
        mallet.position = CGPointMake(self.startX, self.startY);
        
        
    //    self.lastUpdateTime = [NSDate date];
        
    }];

}

-(void)score:(int)playerScore and:(int)opponentScore{
    //clear previous Score
    SKLabelNode *clearLabel =(SKLabelNode *)[self childNodeWithName:@"scorePlayer"];
    [clearLabel removeFromParent];
    SKLabelNode *clearLabel2 =(SKLabelNode *)[self childNodeWithName:@"scoreOpponent"];
    [clearLabel2 removeFromParent];
    
    //update score
    SKLabelNode *scorePlayer = [SKLabelNode labelNodeWithFontNamed:@"ArialHebrew-Bold"];
    scorePlayer.position = CGPointMake(10, self.frame.size.height/2 - 20);
    scorePlayer.fontSize = 25;
    scorePlayer.fontColor = [SKColor blackColor];
    scorePlayer.zPosition = 120;
    scorePlayer.text = [NSString stringWithFormat:@"%d",playerScore];
    scorePlayer.name = @"scorePlayer";
    [self addChild:scorePlayer];
    
    SKLabelNode *scoreOpponent = [SKLabelNode labelNodeWithFontNamed:@"ArialHebrew-Bold"];
    scoreOpponent.position = CGPointMake(10, self.frame.size.height/2 + 20);
    scoreOpponent.fontSize = 25;
    scoreOpponent.fontColor = [SKColor blackColor];
    scoreOpponent.zPosition = 120;
    scoreOpponent.text = [NSString stringWithFormat:@"%d",opponentScore];
    scoreOpponent.name = @"scoreOpponent";
    [self addChild:scoreOpponent];
}

-(void)opponentMoving{
    
    SKSpriteNode *opponent = (SKSpriteNode *)[self childNodeWithName:@"opponent"];
    SKSpriteNode *puck = (SKSpriteNode *)[self childNodeWithName:@"puck"];
    
    //self.targetOpponent = CGPointMake(<#CGFloat x#>, <#CGFloat y#>)
    
    //vector to steer the puck, target is the very top point of moving puck

    CGVector toPuck = CGVectorMake(puck.position.x-opponent.position.x, puck.position.y+puck.size.height-opponent.position.y);
    CGVector normalizeToPuck = normalizeVector(toPuck);
    CGVector boostSteerOpponent = boostVector(normalizeToPuck, self.speedOpponent);
    
    //vector to come back original position
    CGVector backOrigin = CGVectorMake(self.frame.size.width/2-opponent.position.x, self.frame.size.height-opponent.size.height/2-opponent.position.y);
    CGVector normalizeBackOrigin = normalizeVector(backOrigin);
    CGVector boostBackOrigin = boostVector(normalizeBackOrigin, self.speedOpponent);
    
    if (puck.position.y > self.frame.size.height/2) {
        [opponent.physicsBody applyForce:boostSteerOpponent];
    } else{
        [opponent.physicsBody applyForce:boostBackOrigin];
    }
    
    // New method to computing 2D Vector : GLKVector2
    //    //Work out the direction to this position
    //    GLKVector2 opponentPosition = GLKVector2Make(opponent.position.x, opponent.position.y);
    //    GLKVector2 targetPosition = GLKVector2Make(puck.position.x, puck.position.y);
    //
    //    GLKVector2 offset = GLKVector2Subtract(targetPosition, opponentPosition);
    //
    //    //Reduce this vector to be the same length as our movement speed
    //    offset = GLKVector2Normalize(offset);
    //    offset = GLKVector2MultiplyScalar(offset, 5000);
    //
    //    [opponent.physicsBody applyForce:CGVectorMake(offset.x, offset.y)];
}

-(void)flashMessage:(NSString *)message atPosition:(CGPoint)position duration:(NSTimeInterval)duration{
    //a method to make a sprite for a flash message at a certain position on the screen
    //to be used for instructions
    
    //make a label that is invisible
    SKLabelNode *flashLabel = [SKLabelNode labelNodeWithFontNamed:@"MarkerFelt-Wide"];
    flashLabel.position = position;
    flashLabel.fontSize = 17;
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

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    /* Called when a touch begins */
    

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
        [self runAction:[SKAction playSoundFileNamed:@"touch.mp3" waitForCompletion:NO]];
        
        SKSpriteNode *puck =(SKSpriteNode *)[self childNodeWithName:@"puck"];
        SKSpriteNode *mallet =(SKSpriteNode *)[self childNodeWithName:@"mallet"];
        //NSLog(@" go inside contact between puck and mallet");
        
        CGVector vector = CGVectorMake(puck.position.x - mallet.position.x,puck.position.y-mallet.position.y);
        CGVector sum = addVector(vector, boostVector(self.speedPlayer,50));
        [puck.physicsBody applyImpulse:sum];


        
    }
    
    if (firstBody.categoryBitMask == puckCategory && secondBody.categoryBitMask == goalCategory) {
        [self runAction:[SKAction playSoundFileNamed:@"drop.mp3" waitForCompletion:NO]];
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
        //[self positioning];
        [self score:self.scorePlayer and:self.scoreOpponent];
        
        if (self.scorePlayer >= self.scoreWin) {
            [self gameOverBackground];
            [self gameOverWithWin:YES];
        }
        
        if (self.scoreOpponent >= self.scoreWin) {
            [self gameOverBackground];
            [self gameOverWithWin:NO];
        }
    }
    
    if (firstBody.categoryBitMask == puckCategory && secondBody.categoryBitMask == borderCategory) {
        [self runAction:[SKAction playSoundFileNamed:@"edge.mp3" waitForCompletion:NO]];
    }
    
    if (firstBody.categoryBitMask == puckCategory && secondBody.categoryBitMask == opponentCategory) {
        [self runAction:[SKAction playSoundFileNamed:@"touch.mp3" waitForCompletion:NO]];
    }
}

- (void)gameOverWithWin:(BOOL)didWin
{   [self.motionManager stopAccelerometerUpdates];
//    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:didWin ? @"You won!" : @"You lost!"
//                                                    message:@"Game Over" delegate:nil cancelButtonTitle:nil otherButtonTitles:nil, nil];
//    
//    [alert show];
//    [self performSelector:@selector(goBack:) withObject:alert afterDelay:3.0];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:didWin ? @"YOU WIN!!!":@"YOU LOST!" message:@"Do you want to rematch ?" preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *yes = [UIAlertAction actionWithTitle:@"YES" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        [self reset];
    }];
    UIAlertAction *back = [UIAlertAction actionWithTitle:@"Back To Menu" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        [self.motionManager stopAccelerometerUpdates];
        [self.mainviewController.backgroundMusicPlayer stop];
        [self.mainviewController.navigationController popToRootViewControllerAnimated:YES];
        //[self.mainviewController dismissViewControllerAnimated:YES completion:nil];
//        [self removeFromParent];
//        [self.view presentScene:nil];
    }];
    [alertController addAction:yes];
    [alertController addAction:back];
    
    [self.mainviewController presentViewController:alertController animated:YES completion:nil];
}

- (void)goBack:(UIAlertView *)alert
{
    [alert dismissWithClickedButtonIndex:0 animated:YES];
    [self.mainviewController.navigationController popToRootViewControllerAnimated:NO];
}

-(BOOL)checkspeed{
    SKSpriteNode *puck =(SKSpriteNode *)[self childNodeWithName:@"puck"];
    
    float speed = vectorLength(puck.physicsBody.velocity);
    //NSLog(@"speed of puck %f",speed);
    if (speed < 100){
        return YES;
    }
    return NO;
}
-(void)update:(CFTimeInterval)currentTime {
    /* Called before each frame is rendered */
    //handle time delta.
    //If we drop below 60fps, we still want everything to move the same distance.
    CFTimeInterval timeSinceLast = currentTime - self.lastUpdateTimeInterval ;
    self.lastUpdateTimeInterval = currentTime;
    if (timeSinceLast > 1){ //more than a second since last update
        timeSinceLast = 1.0/60.0;
        self.lastUpdateTimeInterval = currentTime;
    }
    [self opponentMoving];

}

@end
