//
//  UIView+VPLView.m
//  VideoPlsLuaViewManagerSDK
//
//  Created by Zard1096-videojj on 2019/11/8.
//  Copyright © 2019 videopls. All rights reserved.
//

#import "UIView+VPLView.h"
#import <VPLuaViewSDK/UIView+LuaView.h>
#import "NSObject+VPLView.h"


@implementation UIView (UIViewVPLView)

-(void) lv_callbackAddClickGesture {
    if( self.lv_isCallbackAddClickGesture ){
        self.lv_isCallbackAddClickGesture = NO;
        UITapGestureRecognizer* gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(lv_buttonCallBack:)];
        self.userInteractionEnabled = YES;
        [self addGestureRecognizer:gesture];
    }
}

@end
