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
//static const uint32_t bodyCategory = 0x1 << 3;

//length of vector
static inline float vectorLength(CGVector a){
    return sqrtf(a.dx*a.dx+a.dy*a.dy);
}

@interface GameScene()<SKPhysicsContactDelegate>

@property (nonatomic)CMMotionManager *motionManager;
@property (nonatomic)double startX;
@property (nonatomic)double startY;

@property (nonatomic) NSDate *lastUpdateTime;
@property (nonatomic)NSTimeInterval lastUpdateTimeInterval;
@property (nonatomic)double MAXX;
@property (nonatomic)double MAXY;
@property (nonatomic)BOOL flag;

@end

@implementation GameScene

-(void)didMoveToView:(SKView *)view {
    /* Setup your scene here */

}

-(id)initWithSize:(CGSize)size{
    if (self == [super initWithSize:size]) {
        
        self.physicsWorld.contactDelegate = self;
        //set up the physics world with no gravity, it bases on vector value
        self.physicsWorld.gravity = CGVectorMake(0.0f, 0.0f);
        
        //set up the backgound (playfield)
        SKSpriteNode *body = [SKSpriteNode spriteNodeWithColor:[UIColor grayColor] size:self.frame.size];
        body.position = CGPointMake(self.frame.size.width/2, self.frame.size.height/2);
        [self addChild:body];
        
        //cannot use node as the static edge?
//        body.physicsBody = [SKPhysicsBody bodyWithEdgeLoopFromRect:CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, self.frame.size.height)];
//        body.physicsBody.friction =0.0f;
        
        // set up the evironment of box2D
        //1 create a physics body that borders the screen
        SKPhysicsBody *borderBody = [SKPhysicsBody bodyWithEdgeLoopFromRect:self.frame];
        //2 Set physicsBody of scene to borderBody
        self.physicsBody = borderBody;
        //3 Set the friction of that physicsBody to zero
        self.physicsBody.friction =0.0f;
        
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
        puck.name = @"puck";
        [self addChild:puck];
        
        
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
        
        mallet.name = @"mallet";
        [self addChild:mallet];
        
        mallet.physicsBody.dynamic = YES;
        
        //set up oponent mallet
        SKSpriteNode *oponent = [SKSpriteNode spriteNodeWithImageNamed:@"seal.png"];
        oponent.position = CGPointMake(self.frame.size.width/2, self.frame.size.height - oponent.size.height/2);
        
        oponent.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:oponent.size.height/2];
        oponent.physicsBody.friction = 0.0f;
        oponent.physicsBody.restitution = 1.0f;
        oponent.physicsBody.linearDamping = 0.0f;
        oponent.physicsBody.density=1000.0f;
        oponent.physicsBody.mass = 1000.0f;
        oponent.name = @"oponent";
        [self addChild:oponent];
        
        oponent.physicsBody.dynamic = YES;
        
        //create the goal
        SKSpriteNode *goal = [SKSpriteNode spriteNodeWithColor:[UIColor yellowColor] size:CGSizeMake(self.frame.size.width/3,1.6f)];
        goal.position = CGPointMake(self.frame.size.width/2, 0.8f);
        goal.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake(self.frame.size.width/3,1.6f)];
        goal.physicsBody.dynamic = NO;
        [self addChild:goal];
        
        SKSpriteNode *goal2 = [SKSpriteNode spriteNodeWithColor:[UIColor yellowColor] size:CGSizeMake(self.frame.size.width/3,1.6f)];
        goal2.position = CGPointMake(self.frame.size.width/2, self.frame.size.height -0.8f);
        goal2.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake(self.frame.size.width/3,1.6f)];
        goal2.physicsBody.dynamic = NO;
        [self addChild:goal2];
        
        //setup the Category Bit Mask
        puck.physicsBody.categoryBitMask = puckCategory;
        mallet.physicsBody.categoryBitMask = malletCategory;
        goal.physicsBody.categoryBitMask = goalCategory;
        
        //define the interaction that we care about
        puck.physicsBody.contactTestBitMask = goalCategory | malletCategory; //get notice when puck touch goal
        
        puck.physicsBody.collisionBitMask = malletCategory; //physics force when puck interact with mallet
        
        [self positioning];
        
    };
    return self;
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
        
        self.startX = self.startX + secondsSinceLastDraw *acceData.acceleration.x*500;
        self.startY = self.startY + secondsSinceLastDraw *acceData.acceleration.y*1000;
        //NSLog(@"the X: %f the Y: %f",self.theX,self.theY);
        
        self.startX = MIN(self.MAXX, self.startX);
        self.startX = MAX(mallet.size.width/2, self.startX);
        self.startY = MAX(mallet.size.width/2, self.startY);
        self.startY = MIN(self.MAXY, self.startY);
        
        mallet.position = CGPointMake(self.startX, self.startY);
        
    //    self.lastUpdateTime = [NSDate date];
        
    }];

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
        SKSpriteNode *puck =(SKSpriteNode *)[self childNodeWithName:@"puck"];
        SKSpriteNode *mallet =(SKSpriteNode *)[self childNodeWithName:@"mallet"];
        NSLog(@" go inside contact between puck and mallet");
        if ([self checkspeed]==YES) {
           [puck.physicsBody applyImpulse:[self getVectorfrom:puck.position to:mallet.position]];
          
        } else {
//            [puck.physicsBody applyImpulse:[self getVectorfrom:puck.position to:mallet.position]];
            CGVector force = [self getVectorfrom:puck.position to:mallet.position];
            CGVector mforce = CGVectorMake(force.dx*500000, force.dy*500000);
            [puck.physicsBody applyForce:mforce];
        }
        
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

    
   // SKSpriteNode *puck =(SKSpriteNode *)[self childNodeWithName:@"puck"];
   // SKSpriteNode *oponent =(SKSpriteNode *)[self childNodeWithName:@"oponent"];
   // CGVector force = [self getVectorfrom:puck.position to:oponent.position];
  //  CGVector mforce = CGVectorMake(force.dx*10, force.dy*10);
   // [oponent.physicsBody applyForce:mforce];
}

@end
