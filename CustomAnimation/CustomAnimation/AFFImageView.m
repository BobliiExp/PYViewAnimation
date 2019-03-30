//
//  AFFImageView.m
//  AnyfishApp
//
//  Created by Bob Lee on 14-4-8.
//  Copyright (c) 2014年 Anyfish. All rights reserved.
//

#import "AFFImageView.h"

@interface AFFImageView() {
    NSTimer *loopTimer;
    NSInteger curIndex;
    CALayer *layerAnimate;
    NSString *imageNameKey;
    NSString *imagePart; // 除了key后面的后缀部分
    NSArray *arrNames;
    
    UIColor *colorBgOrg; // 记住原来的背景
    
}

@property (nonatomic, assign) BOOL isLoading;    ///< 是否正在加载数据
@property (nonatomic, weak) UIActivityIndicatorView *activity;    ///< 加载
@property (nonatomic, copy) blockResult blockWill, blockDid, blockEnd;

@end

@implementation AFFImageView

- (id)initWithFrame:(CGRect)frame fileName:(NSString *)fName {
    return [self initWithFrame:frame fileName:fName config:[AFFAppSettings getExpPlistInfo:fName]];
}

- (id)initWithFrame:(CGRect)frame fileName:(NSString *)fName config:(NSMutableDictionary*)config {
    self = [super initWithFrame:frame];
    if (self) {
        curIndex = 1;
        _callStop = YES;
        self.fileName = fName;
        self.mDic = config;
        self.stopIndex = 1;
        
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame key:(NSString*)key part:(NSString*)part isSource:(BOOL)isSource {
    self = [super initWithFrame:frame];
    if (self) {
        curIndex = 0;
        _callStop = YES;
        imageNameKey = key;
        imagePart = part;
        
        layerAnimate = [[CALayer alloc] init];
        layerAnimate.frame = CGRectMake(0, 0, CGRectGetWidth(frame), CGRectGetHeight(frame));
        [self.layer addSublayer:layerAnimate];
        
        self.arrImages = [UIHelper getAnimationImages:imageNameKey isSource:isSource isName:NO part:part];
        
        if(isSource){
            arrNames = [UIHelper getAnimationImages:imageNameKey isSource:YES isName:YES part:part];
            
            if(self.arrImages.count!=arrNames.count){
                [self pullSource];
            }
        }
        
        self.stopIndex = 1;
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame key:(NSString*)key isSource:(BOOL)isSource {
    return [self initWithFrame:frame key:key part:nil isSource:isSource];
}

- (id)initWithFrame:(CGRect)frame key:(NSString*)key {
    return [self initWithFrame:frame key:key isSource:NO];
}

- (void)updateWithKey:(NSString*)key part:(NSString*)part isSource:(BOOL)isSource {
    self.callStop = YES;
    curIndex = 0;
    imageNameKey = key;
    imagePart = part;
    
    self.arrImages = [UIHelper getAnimationImages:imageNameKey isSource:isSource isName:NO part:part];
    
    if(isSource){
        arrNames = [UIHelper getAnimationImages:imageNameKey isSource:YES isName:YES part:part];
        
        if(self.arrImages.count!=arrNames.count){
            [self pullSource];
        }
    }
    self.callStop = NO;
}

- (void)setIsLoading:(BOOL)isLoading {
    if(_isLoading==isLoading)return;
    
    _isLoading = isLoading;
    
    if(self.activity==nil){
        UIActivityIndicatorView *activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        activity.color = kSetting.color_ffffff;
        [self addSubview:activity];
        self.activity = activity;
        
        CGFloat width = MIN(self.width, self.height);
        width =  MIN(width-kPadding_Cell_H, 50);
        
        CGFloat scale = 1.0;
        if((self.width-kPadding_Cell_H)>50){
            scale = 1.5;
        }else if(width<25){
            scale = 0.6;
        }
        
        if(scale!=1.0){
            activity.transform = CGAffineTransformMakeScale(scale, scale);
        }
        
        self.activity.frame = CGRectMake(0, 0, width, width);
        self.activity.center = CGPointMake(self.width/2, self.height/2);
    }
    
    self.activity.hidden = !isLoading;
    if(isLoading)
        [self.activity startAnimating];
    else
        [self.activity stopAnimating];
    
    
}

// 注意：动画只支持一套图
- (void)pullSource {
    self.arrImages = [NSMutableArray array]; // 这样就需要等待拉取回来才播放
    self.isLoading = YES;
//    colorBgOrg = self.backgroundColor;
//    self.backgroundColor = kSetting.color_Bg_Image;
    
    @weakify(self);
    [AFFImageView pullSourceAnimate:imageNameKey part:imagePart block:^(U32 progress, AFFDataError *error) {
        @strongify(self);
        if(self.arrImages==nil)
            return ;
        
        if(error.succeed){
            if(progress>=100){
                self.isLoading = NO;
//                self.backgroundColor = colorBgOrg;
                NSArray *arr = [UIHelper getAnimationImages:imageNameKey isSource:YES isName:NO part:imagePart];
                
                if(arr.count>0){
                    self.arrImages = arr;
                    // 判断当前是不是需要启动动画
                    if(!_callStop){
                        [self animationLoop];
                    }else {
                        // 检查是否停止在某个图片
                        self.stopIndex=self.stopIndex;
                    }
                    
                    return;
                }
            }else {
                return;
            }
        }
        
        self.isLoading = NO;
        // 失败要通知外部做相关处理
        
        if(self.delegate&&[self.delegate respondsToSelector:@selector(layerAnimateEnd:)]){
            [self.delegate layerAnimateEnd:self];
        }
        
        if(self.blockEnd){
            self.blockEnd(1, self);
        }
    }];
}

+ (BOOL)needPullAnimate:(NSString*)imageNameKey {
    return [self needPullAnimate:imageNameKey part:nil];
}

+ (BOOL)needPullAnimate:(NSString*)imageNameKey part:(NSString*)part {
    NSArray *mArrName = [UIHelper getAnimationImages:imageNameKey isSource:YES isName:YES part:part];
    NSArray *mArrImage = [UIHelper getAnimationImages:imageNameKey isSource:YES isName:NO part:part];
    
    return mArrImage.count!=mArrName.count;
}

+ (void)pullSourceAnimate:(NSString*)imageNameKey block:(void(^)(U32 progress, AFFDataError *error))block {
    [self pullSourceAnimate:imageNameKey part:nil block:block];
}

+ (void)pullSourceAnimate:(NSString*)imageNameKey part:(NSString*)part block:(void(^)(U32 progress, AFFDataError *error))block {
    NSArray *mArrName = [UIHelper getAnimationImages:imageNameKey isSource:YES isName:YES part:part];
    NSArray *mArrImage = [UIHelper getAnimationImages:imageNameKey isSource:YES isName:NO part:part];
    
    if(mArrName.count != mArrImage.count){
        NSMutableArray *mArr = [NSMutableArray array];
        for(NSDictionary *dic in mArrName){
            BOOL exist = NO;
            for(NSDictionary *dicx in mArrImage){
                if([[dicx stringForKey:@"imageName"] isEqualToString:[dic stringForKey:@"imageName"]]){
                    exist = YES;
                    break;
                }
            }
            
            if(!exist){
                [mArr addObject:[NSString stringWithFormat:@"%@.png",[dic stringForKey:@"imageName"]]];
            }
        }
        
        if(mArr.count>0){
            [AFFLAPIPublic getResourceMeida:mArr block:block];
            return;
        }
    }
    
    if(block)block(100, [AFFDataError errWithDesc:nil]);
}

- (void)setReplaceColor:(UIColor *)replaceColor {
    _replaceColor = replaceColor;
    if(_callStop)
        self.stopIndex = self.stopIndex;
}

- (void)setStopWithImage:(UIImage *)stopWithImage {
    _stopWithImage = stopWithImage;
    if(_callStop)
        [self setStopIndex:_stopIndex];
}

- (void)setStopWithCustomImage:(NSString *)stopWithCustomImage {
    _stopWithCustomImage = stopWithCustomImage;
    if(_callStop)
        [self setStopIndex:_stopIndex];
}

- (void)setStopIndex:(int)stopIndex {
    if(stopIndex>self.arrImages.count-1){
        stopIndex = (int)self.arrImages.count-1;
    }
    
    _stopIndex = stopIndex;
    
    if(_callStop){
        if(![NSString isNilOrEmpty:self.stopWithCustomImage]){
            UIImage *img = [UIImage imageWithFileName:self.stopWithCustomImage];
            if(self.replaceColor && img){
                img = [img imageWithTintColor:self.replaceColor];
            }
            if(layerAnimate){
                if(img)
                    [layerAnimate setContents:(id)img.CGImage];
            }else {
                self.image = img;
            }
        }else if(self.stopWithImage){
            UIImage *img = self.stopWithImage;
            if(self.replaceColor){
                img = [img imageWithTintColor:self.replaceColor];
            }
            
            if(layerAnimate){
                [layerAnimate setContents:(id)img.CGImage];
            }else {
                self.image = img;
            }
        }else {
            if(layerAnimate){
                NSDictionary *dic = [self.arrImages objectWithIndex:_stopIndex];
                UIImage *img = [dic objectForKey:@"image"];
                if(img){
                    if(self.replaceColor){
                        img = [img imageWithTintColor:self.replaceColor];
                    }
                    [layerAnimate setContents:(id)img.CGImage];
                }
            }else {
                UIImage *img = [UIImage imageWithFileName:[NSString stringWithFormat:@"%@%03d",self.fileName,_stopIndex]];
                if(self.replaceColor){
                    img = [img imageWithTintColor:self.replaceColor];
                }
                self.image = img;
            }
        }
    }
}

- (void)setImages:(NSArray *)images{
    self.arrImages = images;
}

- (void)animationStart{
    if(loopTimer){
        [loopTimer invalidate];
        loopTimer = nil;
    }
    
    if(self.delegate && [self.delegate respondsToSelector:@selector(imageView:didChangeToIndex:)]){
        [self.delegate imageView:self didChangeToIndex:curIndex];
    }
    
    if(self.superview == nil){
        return;
    }
    
    // 移除鱼信气泡
    if([self.superview isKindOfClass:[NSClassFromString(@"AFFBoardBase") class]]){
        if(![AFFAppSettings sharedInstance].isInRoomChat){
            return;
        }
    }
    
    if(self.mDic==nil)
        return;
    
    if(_callStop){
        self.stopIndex = self.stopIndex;
        return;
    }
    
    if(self.isLoading)
        return;
    
    double duration = 0.1;
    NSString *imageName = @"";
    
    if(self.mDic){
        imageName = [NSString stringWithFormat:@"%@%03d",self.fileName,(int)curIndex];
        duration = [[self.mDic objectForKey:imageName] doubleValue]/1000;
    }else if(self.arrImages){
        imageName = [self.arrImages objectWithIndex:(curIndex-1)];
    }
    
    curIndex ++;
    if(curIndex>self.mDic.count){
        if(self.noRepeat){
            _callStop = YES;
            return;
        }
        
        curIndex=1;
    }
    
    [self setImage:[UIImage imageWithFileName:imageName]];
    
    loopTimer = [NSTimer timerWithTimeInterval:duration
                                        target:self
                                      selector:@selector(animationStart)
                                      userInfo:nil
                                       repeats:NO];
    
    [[NSRunLoop currentRunLoop] addTimer:loopTimer forMode:NSRunLoopCommonModes];
    
    if(self.delegate && [self.delegate respondsToSelector:@selector(imageView:willChangeToIndex:)]){
        [self.delegate imageView:self willChangeToIndex:curIndex];
    }
}

- (void)animationLoop {
    if(loopTimer){
        [loopTimer invalidate];
        loopTimer = nil;
    }
    
    if(self.delegate && [self.delegate respondsToSelector:@selector(layerAnimate:didChangeToIndex:)]){
        [self.delegate layerAnimate:self didChangeToIndex:curIndex];
    }
    
    if(self.blockDid){
        self.blockDid(curIndex, self);
    }
    
    if(self.arrImages==nil || self.arrImages.count==0)
        return;
    
    if(layerAnimate.superlayer==nil){
        [self.layer addSublayer:layerAnimate];
    }
    
    if(_callStop){
        self.stopIndex = self.stopIndex;
        return;
    }
    
    if(layerAnimate.superlayer==nil || self.superview==nil){
        return;
    }
    
    NSDictionary *dic = [self.arrImages objectWithIndex:curIndex];
    double duration = (float)[dic integerForKey:@"duration"]/1000.0;
    UIImage *img = [dic objectForKey:@"image"];
    if(self.replaceColor){
        img = [img imageWithTintColor:self.replaceColor];
    }
    [layerAnimate setContents:(id)img.CGImage];
    
    curIndex ++;
    if(curIndex>=self.arrImages.count){
        if(self.noRepeat){
            _callStop = YES;
            
            if(self.delegate&&[self.delegate respondsToSelector:@selector(layerAnimateEnd:)]){
                [self.delegate layerAnimateEnd:self];
            }
            
            if(self.blockEnd){
                self.blockEnd(1, self);
            }
            
            return;
        }
        
        curIndex=0;
    }
    
    if(self.delegate && [self.delegate respondsToSelector:@selector(layerAnimate:willChangeToIndex:)]){
        [self.delegate layerAnimate:self willChangeToIndex:curIndex];
    }
    
    if(self.blockWill){
        self.blockWill(curIndex, self);
    }
    
    loopTimer = [NSTimer timerWithTimeInterval:duration
                                        target:self
                                      selector:@selector(animationLoop)
                                      userInfo:nil
                                       repeats:NO];
    
    [[NSRunLoop currentRunLoop] addTimer:loopTimer forMode:NSRunLoopCommonModes];
}

- (void)setCallStop:(BOOL) callStop{
    if(callStop == _callStop)
        return;
    
    _callStop = callStop;
    curIndex = self.stopIndex;
    // 非重复动画，再次触发索引还原
    if(_noRepeat && !callStop)
        curIndex = 0;
    
    if(![NSString isNilOrEmpty:self.fileName]){
        loopTimer = [NSTimer timerWithTimeInterval:0.1
                                            target:self
                                          selector:@selector(animationStart)
                                          userInfo:nil
                                           repeats:NO];
    }else {
        loopTimer = [NSTimer timerWithTimeInterval:0.1
                                            target:self
                                          selector:@selector(animationLoop)
                                          userInfo:nil
                                           repeats:NO];
    }
    
    [[NSRunLoop mainRunLoop] addTimer:loopTimer forMode:NSRunLoopCommonModes];
}

- (NSInteger)currentIndex {
    return curIndex;
}

- (void)removeFromSuperview {
    [self dispose];
}

- (void)dispose {
    if(loopTimer){
        [loopTimer invalidate];
        loopTimer = nil;
    }
    
    _callStop = YES;
    [layerAnimate removeFromSuperlayer];
    layerAnimate = nil;
    imageNameKey = nil;
    arrNames = nil;
    if(self.activity){
        [self.activity stopAnimating];
        [self.activity removeFromSuperview];
        self.activity = nil;
    }
    
    colorBgOrg = nil;
    [self.mDic removeAllObjects];
    self.mDic = nil;
    self.arrImages = nil;
    self.delegate = nil;
    
    self.blockWill = nil;
    self.blockDid = nil;
    self.blockEnd = nil;
}

- (void)dealloc {
    [self dispose];
}

#pragma mark block 通知

- (void)animateWillToBlock:(blockResult)block {
    self.blockWill = block;
}

- (void)animateDidToBlock:(blockResult)block {
    self.blockDid = block;
}

- (void)animateEndBlock:(blockResult)block {
    self.blockEnd = block;
}

+ (NSArray*)getAnimationImages:(NSString*)key isSource:(BOOL)isSource isName:(BOOL)isName part:(NSString*)part {
    if(kSetting.mDicAnimate==nil){
        kSetting.mDicAnimate = [NSMutableDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"exp_animation_config" ofType:@"plist"]];
    }
    
    NSMutableDictionary *mDic = kSetting.mDicAnimate;
    
    NSString *imgs = [mDic objectForKey:key];
    NSArray *arr = [imgs componentsSeparatedByString:@","];
    
    NSMutableArray *mArr = [NSMutableArray arrayWithCapacity:arr.count];
    for(NSString *sub in arr){
        NSInteger count = 1;
        NSString *str = sub;
        
        // 扩展支持
        if([str containsString:@"*"]){
            NSArray *arr = [str componentsSeparatedByString:@"*"];
            if(arr.count>1)
                count = [[arr lastObject] integerValue];
            
            str = [arr firstObject];
        }
        
        while (count>0) {
            NSArray *temp = [str componentsSeparatedByString:@":"];
            NSString *from = [temp firstObject];
            U32 start = 0, end = 0, duration=[[temp lastObject] intValue];
            if([from containsString:@"~"]){
                NSArray *arr = [from componentsSeparatedByString:@"~"];
                start = [[arr firstObject] intValue];
                end = [[arr lastObject] intValue];
            }else {
                start = end = [from intValue];
            }
            
            S32 i=start;
            
            while (true) {
                NSString *imgName = [NSString stringWithFormat:@"%@%@%03d", key, part?part:@"", i];
                
                if(isName){
                    [mArr addObject:@{@"imageName":imgName, @"duration":@(duration)}];
                }else {
                    UIImage *img = isSource ? [UIImage imageWithContentsOfFile:[UIImage imageNameFileNameDownload:imgName]] : [UIImage imageWithFileName:imgName];
                    if(img)
                        [mArr addObject:@{@"image":img, @"duration":@(duration), @"imageName":imgName}];
                }
                
                i = i + (start>end?-1:+1);
                
                if(start>end){
                    if(i<end)
                        break;
                }else {
                    if(i>end)
                        break;
                }
                
                // 保护下
                if(abs(i)>100){
                    break;
                }
            }
            
            count--;
        }
    }
    
    return mArr;
}


@end
