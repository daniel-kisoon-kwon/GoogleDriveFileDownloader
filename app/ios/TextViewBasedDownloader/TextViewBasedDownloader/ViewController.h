//
//  ViewController.h
//  TextViewBasedDownloader
//
//  Created by daniel-kisoon-kwon on 2016. 9. 18..
//  Copyright © 2016년 daniel-kisoon-kwon. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "GTMOAuth2ViewControllerTouch.h"
#import "GTLDrive.h"

@interface ViewController : UIViewController

@property (nonatomic, strong) GTLServiceDrive *service;
@property (nonatomic, strong) UITextView *output;

@end
