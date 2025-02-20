//
//  VPMPContainerErrorView.m
//  VideoPlsLuaViewManagerSDK
//
//  Created by Zard1096-videojj on 2019/8/6.
//  Copyright © 2019 videopls. All rights reserved.
//

#import "VPMPContainerErrorView.h"
#import "VPUPViewScaleUtil.h"
#import "VPUPEncryption.h"
#import "VPUPHexColors.h"

NSString *const kContainerErrorImage = @"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";

@interface VPMPContainerErrorView()

@property (nonatomic) UIImageView *errorImageView;
@property (nonatomic) UILabel *errorLabel;

@end

@implementation VPMPContainerErrorView

- (void)initView {
    [super initView];
    
    _errorImageView = [[UIImageView alloc] initWithFrame:CGRectMake((self.bounds.size.width - 68 * VPUPViewScale) / 2, 67 * VPUPViewScale, 68 * VPUPViewScale, 78 * VPUPViewScale)];
    _errorImageView.image = [VPUPBase64Util imageFromBase64String:kContainerErrorImage];
    _errorImageView.contentMode = UIViewContentModeScaleAspectFit;
    
    [self addSubview:_errorImageView];
    
    _errorLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, 28 * VPUPViewScale)];
//    _errorLabel.numberOfLines = 2;
    _errorLabel.text = @"小程序服务不可用,换个标签再试";
    _errorLabel.textAlignment = NSTextAlignmentCenter;
    _errorLabel.textColor = [VPUPHXColor vpup_colorWithHexARGBString:@"cccccc"];
    _errorLabel.font = [UIFont boldSystemFontOfSize:12 * VPUPFontScale];
    
    [self addSubview:_errorLabel];
    
    _errorLabel.center = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2 + 7 * VPUPViewScale);
}

- (void)useDefaultMessage {
    _errorLabel.text = @"小程序服务不可用,换个标签再试";
}

- (void)changeErrorMessage:(NSString *)message {
    if (message != nil && ![message isEqualToString:@""]) {
        _errorLabel.text = message;
    }
}

@end
