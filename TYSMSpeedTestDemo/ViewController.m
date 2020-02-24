//
//  ViewController.m
//  TYSMSpeedTestDemo
//
//  Created by jele lam on 24/2/2020.
//  Copyright © 2020 CookiesJ. All rights reserved.
//

#import "ViewController.h"
#import "MLSpeedTest.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    MLSpeedTest *test = [[MLSpeedTest alloc] initWithQueue:nil];
    [test prepareTestServer:^{
        [test startTestLatency:^{
            [test startTestDownload:^{
                [test startTestUpload:^{
                }];
            }];
        }];
    }];
    // Do any additional setup after loading the view.
}


@end
