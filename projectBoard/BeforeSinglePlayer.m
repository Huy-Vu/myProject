//
//  BeforeSinglePlayer.m
//  projectBoard
//
//  Created by Huy Vu on 10/14/15.
//  Copyright © 2015 Huy Vu. All rights reserved.
//

#import "BeforeSinglePlayer.h"
#import "GameViewController.h"
@interface BeforeSinglePlayer ()

@property (nonatomic) NSArray *arrayBackground;
@property (nonatomic) NSArray *arrayMallet;
@property (weak, nonatomic) IBOutlet UIPickerView *picker;
- (IBAction)playButton:(id)sender;
@property (weak, nonatomic) IBOutlet UIButton *playOutlet;
@end

@implementation BeforeSinglePlayer

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.arrayBackground =@[@"background1.png",@"background2.png"];
    self.arrayMallet= @[@"waitingpenguin.png",@"seal.png",@"lion.gif",@"lionTransparentBack.gif"];
}
-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:YES];
    self.playOutlet.enabled = NO;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView{
    return 2;
}

-(NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component{
    return component ==0 ? self.arrayBackground[row] : self.arrayMallet[row];
}

-(NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component{
    return component == 0 ?  [self.arrayBackground count] : [self.arrayMallet count];
  
    
}

-(void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component{
    
    if (component ==0 ) {
        self.thebackground = self.arrayBackground[row];
    }
    if (component ==1 ) {
        self.themallet = self.arrayMallet[row];
    }
    
    self.playOutlet.enabled = YES;
}

//- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view{
//    UIImage *img = [UIImage imageNamed:[NSString stringWithFormat:@"your image number %@.png", (long)row]];
//    UIImageView *temp = [[UIImageView alloc] initWithImage:img];
//    temp.frame = CGRectMake(-70, 10, 60, 40);
//    
//    UILabel *channelLabel = [[UILabel alloc] initWithFrame:CGRectMake(50, -5, 80, 60)];
//    channelLabel.text = [NSString stringWithFormat:@"%@", [your array objectAtIndex:row]];
//    channelLabel.textAlignment = UITextAlignmentLeft;
//    channelLabel.backgroundColor = [UIColor clearColor];
//    
//    UIView *tmpView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 110, 60)];
//    [tmpView insertSubview:temp atIndex:0];
//    [tmpView insertSubview:channelLabel atIndex:1];
//    
//    return tmpView;
//}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)playButton:(id)sender {
    
    GameViewController *gamestart = [self.storyboard instantiateViewControllerWithIdentifier:@"GameSingle"];
    
    gamestart.thebackground = self.thebackground;
    gamestart.themallet = self.themallet;
    [self.navigationController pushViewController:gamestart animated:YES];
}

- (IBAction)backButton:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

@end
