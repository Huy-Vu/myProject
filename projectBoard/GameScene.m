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

@interface GameScene()<SKPhysicsContactDelegate>

@property (nonatomic)CMMotionManager *motionManager;
@property (nonatomic)double startX;
@property (nonatomic)double startY;
@property (nonatomic)double theX;
@property (nonatomic)double theY;
@property (nonatomic)double velocityX;
@property (nonatomic)double velocityY;
@property (strong, nonatomic) NSDate *lastUpdateTime;
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
        puck.physicsBody.restitution = 1.0f;
        puck.physicsBody.linearDamping = 0.0f;
        puck.physicsBody.density = 1.0f;
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
        mallet.physicsBody.density= 10000.0f;
        mallet.name = @"mallet";
        [self addChild:mallet];
        
        mallet.physicsBody.dynamic = NO;
        
        //set up oponent mallet
        SKSpriteNode *oponent = [SKSpriteNode spriteNodeWithImageNamed:@"seal.png"];
        oponent.position = CGPointMake(self.frame.size.width/2, self.frame.size.height - oponent.size.height/2);
        
        oponent.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:oponent.size.height/2];
        oponent.physicsBody.friction = 0.0f;
        oponent.physicsBody.restitution = 1.0f;
        oponent.physicsBody.linearDamping = 0.0f;
        oponent.physicsBody.density=10000.0f;
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
        
        //try to deal with positioning
        self.motionManager = [CMMotionManager new];
        self.motionManager.accelerometerUpdateInterval = .1;
        self.motionManager.gyroUpdateInterval = .1;
        
        self.lastUpdateTime = [[NSDate alloc] init];
        self.startX = self.frame.size.width/2;
        self.startY = mallet.size.height/2;
        self.MAXX = self.frame.size.width - mallet.size.width/2;
        self.MAXY = self.frame.size.height/2 - mallet.size.height;
        NSLog(@"start rote X: %f start rote Y: %f",self.startX,self.startY);
        
        [self.motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue new] withHandler:^(CMAccelerometerData *acceData, NSError *error){
            
            NSTimeInterval secondsSinceLastDraw = -([self.lastUpdateTime timeIntervalSinceNow]);
            self.velocityX += acceData.acceleration.x *secondsSinceLastDraw;
            self.velocityY += acceData.acceleration.y *secondsSinceLastDraw;
            
            self.theX = self.startX + secondsSinceLastDraw *self.velocityX*500;
            self.theY = self.startY + secondsSinceLastDraw *self.velocityY*1000;
            //NSLog(@"the X: %f the Y: %f",self.theX,self.theY);
            
            self.startX = MIN(self.MAXX, self.theX);
            self.startX = MAX(mallet.size.width/2, self.startX);
            self.startY = MAX(mallet.size.width/2, self.theY);
            self.startY = MIN(self.MAXY, self.startY);
            
            
            self.theX=self.startX;
            self.theY=self.startY;
            
            //[self.scrollView scrollRectToVisible:CGRectMake(self.startX, self.startY, self.view.frame.size.width, self.view.frame.size.height) animated:YES];
            mallet.position = CGPointMake(self.startX, self.startY);
            CGVector force = [self getVectorfrom:puck.position to:mallet.position];
            [oponent.physicsBody applyImpulse:[self getVectorfrom:puck.position to:oponent.position]];
           // NSLog(@"start acc X: %f start acc Y: %f",self.startX,self.startY);
            self.lastUpdateTime = [NSDate date];

        }];
        
//        [self.motionManager startGyroUpdatesToQueue:[NSOperationQueue new] withHandler:^(CMGyroData *gyroData,NSError *error){
//            
//            NSTimeInterval secondsSinceLastDraw = -([self.lastUpdateTime timeIntervalSinceNow]);
//            self.velocityX += gyroData.rotationRate.y *secondsSinceLastDraw;
//            //self.velocityY += gyroData.rotationRate.y *secondsSinceLastDraw;
//            
//            self.theX = self.startX + secondsSinceLastDraw *self.velocityX*100;
//            //self.theY = self.startY + secondsSinceLastDraw *self.velocityY*300;
//                    NSLog(@"the X: %f the Y: %f",self.theX,self.theY);
//            self.startX = MAX(0.0, self.theX);
//            self.startX = MIN(self.MAXX, self.theX);
//            //self.startY = MAX(0.0, self.theY);
//            //self.startY = MIN(self.MAXY, self.theY);
//            
//            //[self.scrollView scrollRectToVisible:CGRectMake(self.startX, self.startY, self.view.frame.size.width, self.view.frame.size.height) animated:YES];
//            mallet.position = CGPointMake(self.startX, self.startY);
//            NSLog(@"start rote X: %f start rote Y: %f",self.startX,self.startY);
//            self.lastUpdateTime = [NSDate date];
//        }];
        
        self.flag == NO;

    };
    return self;
}



-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    /* Called when a touch begins */
    

}
-(CGVector)getVectorfrom:(CGPoint)point1
                      to:(CGPoint)point2{
    
    return CGVectorMake(0.5*(point2.x-point1.x), 0.5*(point2.y-point1.y));
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
        if (self.flag == NO) {
            [puck.physicsBody applyImpulse:[self getVectorfrom:puck.position to:mallet.position]];
            self.flag = YES;
        } else {
            CGVector force = [self getVectorfrom:puck.position to:mallet.position];
            CGVector mforce = CGVectorMake(force.dx*50, force.dy*50);
            [puck.physicsBody applyForce:mforce];
        }
        
    }
}

-(void)update:(CFTimeInterval)currentTime {
    /* Called before each frame is rendered */
    SKSpriteNode *puck =(SKSpriteNode *)[self childNodeWithName:@"puck"];
    SKSpriteNode *oponent =(SKSpriteNode *)[self childNodeWithName:@"oponent"];
    CGVector force = [self getVectorfrom:puck.position to:oponent.position];
    [oponent.physicsBody applyImpulse:[self getVectorfrom:puck.position to:oponent.position]];
}

@end
