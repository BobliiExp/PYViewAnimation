//
//  AFFImageView.h
//  Gif_3_demo
//  这个类主要实现播放Gif动画功能，百鱼动画表情是已多张图片，通过设置Duration时间实现。
//  图片与时间间隔通过Dictionary存放在文件中
//  多个gif图片信息也保存在数据字典中
//
//  播放原理： 根据设置的gif字典名称，读取相应的图片链表、时间戳链表，然后循环播放。在收到停止标识后释放资源
//  Created by Bob Lee on 14-4-8.
//
//

#import <UIKit/UIKit.h>

@class AFFImageView;
@protocol AFFImageViewDelegate <NSObject>

@optional
/**
 * 即将切换到下一个索引
 */
- (void)imageView:(AFFImageView*)imageView willChangeToIndex:(NSInteger)index __attribute((deprecated("请使用layerAnimate:(AFFImageView*)imageView willChangeToIndex:(NSInteger)index")));
- (void)imageView:(AFFImageView*)imageView didChangeToIndex:(NSInteger)index __attribute((deprecated("请使用layerAnimate:(AFFImageView*)imageView didChangeToIndex:(NSInteger)index")));

/**
 * 即将切换到下一个索引
 */
- (void)layerAnimate:(AFFImageView*)imageView willChangeToIndex:(NSInteger)index;
- (void)layerAnimate:(AFFImageView*)imageView didChangeToIndex:(NSInteger)index;

/**
 * noRepeat=YES，时结束通知
 */
- (void)layerAnimateEnd:(AFFImageView*)imageView;

@end

@interface AFFImageView : UIImageView 
@property(nonatomic, strong) NSMutableDictionary *mDic;
@property(nonatomic, strong) NSArray *arrImages;
@property(nonatomic, assign) BOOL callStop;
@property (nonatomic, assign) NSString *stopWithCustomImage;    ///< 停止后使用自定义的图片
@property (nonatomic, strong) UIImage *stopWithImage;    ///< 停止显示的图片
@property(nonatomic, strong) NSString *fileName; /// 这个值会作为上一级字典中的Key
@property(nonatomic)         float currentOffset;
@property (nonatomic, assign) int stopIndex;    ///< 停止时索引
@property (nonatomic, weak) id<AFFImageViewDelegate> delegate;
@property (nonatomic, assign) NSInteger currentIndex;    ///< 当前索引
@property (nonatomic, assign) BOOL noRepeat;    ///< 是否只运行一次；默认NO
@property (nonatomic, strong) UIColor *replaceColor;    ///< 图片替换颜色；一般情况不要使用

/**
 * 即将播放第几帧flag
 */
- (void)animateWillToBlock:(blockResult)block;

/**
 * 正在播放第几帧flag
 */
- (void)animateDidToBlock:(blockResult)block;

/**
 * 非重复播放结束通知noRepeat=yes；flag=1
 */
- (void)animateEndBlock:(blockResult)block;

/**
 * @function
 * 说明 通过配置文件配置的gif图片序列
 * @param frame 
 * @param fName plist文件名
 
 * @return
 */
- (id)initWithFrame:(CGRect)frame fileName:(NSString *)fName __attribute((deprecated("请使用initWithFrame:(CGRect)frame key:(NSString*)key")));
- (id)initWithFrame:(CGRect)frame fileName:(NSString *)fName config:(NSMutableDictionary*)config __attribute((deprecated("请使用initWithFrame:(CGRect)frame key:(NSString*)key")));

/**
 * 通过layer实现动画
 * @param  frame
 * @param  key  统一配置文件中的图片序列key(exp_animation_config.plist)
 
 * @return
 */
- (id)initWithFrame:(CGRect)frame key:(NSString*)key;

/**
 * 支持服务器获取资源
 */
- (id)initWithFrame:(CGRect)frame key:(NSString*)key isSource:(BOOL)isSource;
- (id)initWithFrame:(CGRect)frame key:(NSString*)key part:(NSString*)part isSource:(BOOL)isSource;

/**
 * 特殊支持部分动画播放中需要更新替换的处理
 */
- (void)updateWithKey:(NSString*)key part:(NSString*)part isSource:(BOOL)isSource;

/**
 * @function
 * 说明 通过传入图片文件序列链
 * @param images 存放图片名称的链（仅图片名称，不要加入后缀名.
 
 * @return
 */
- (void)setImages:(NSArray *)images;

/**
 * 判断是否需要拉取
 */
+ (BOOL)needPullAnimate:(NSString*)imageNameKey;
+ (BOOL)needPullAnimate:(NSString*)imageNameKey part:(NSString*)part;

/**
 * 拉取动画媒体
 */
+ (void)pullSourceAnimate:(NSString*)imageNameKey block:(void(^)(U32 progress, AFFDataError *error))block;
+ (void)pullSourceAnimate:(NSString*)imageNameKey part:(NSString*)part block:(void(^)(U32 progress, AFFDataError *error))block;

@end
