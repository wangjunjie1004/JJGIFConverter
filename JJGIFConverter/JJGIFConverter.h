//
//  JJGIFConverter.h
//  JJGIFConverter
//
//  Created by wjj on 2019/10/21.
//  Copyright © 2019 wjj. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface JJGIFConverter : NSObject

+ (void)convertGifToMp4:(NSURL *)pathUrl completion:(void(^)(NSURL * _Nullable url))handler;

@end

NS_ASSUME_NONNULL_END
