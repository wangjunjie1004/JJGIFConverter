//
//  ViewController.m
//  JJGIFConverter
//
//  Created by wjj on 2019/10/21.
//  Copyright © 2019 wjj. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "JJGIFConverter.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [JJGIFConverter convertGifToMp4:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"test" ofType:@"gif"]] completion:^(NSURL * _Nullable url) {
        NSLog(@"convert url: %@",url);
    }];
    [JJGIFConverter convertGifToMp4:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"test1" ofType:@"gif"]] completion:^(NSURL * _Nullable url) {
        NSLog(@"convert url 1: %@",url);
    }];
    [JJGIFConverter convertGifToMp4:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"test2" ofType:@"gif"]] completion:^(NSURL * _Nullable url) {
        NSLog(@"convert url 2: %@",url);
    }];
    [JJGIFConverter convertGifToMp4:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"test3" ofType:@"gif"]] completion:^(NSURL * _Nullable url) {
        NSLog(@"convert url 3: %@",url);
    }];
    [JJGIFConverter convertGifToMp4:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"test4" ofType:@"gif"]] completion:^(NSURL * _Nullable url) {
        NSLog(@"convert url 4: %@",url);
    }];
}


@end
