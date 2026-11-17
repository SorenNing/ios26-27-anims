//
//  CG27GenieDriver.h
//  iOS 27 动画 Reborn — 逆向重建
//
//  原始二进制: com.bazik1337.ios27animsreborn  1.0.0~beta1+ningzh1
//  架构: arm64 + arm64e (fat)
//  重建依据: AACLASS 元数据逐条对位（ivar 偏移 / 类型编码 / 属性 attributes / 方法类型编码）
//
//  说明: 类名、ivar 布局、属性、方法列表、选择器与类型编码均为原版二进制还原值；
//        方法体为按反汇编重建的等价实现（见 docs/VERIFICATION.md）。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <os/lock.h>

NS_ASSUME_NONNULL_BEGIN

/// _engine ivar 的内存布局（576 字节，与原始类型编码
/// {?="p"[9[2d]]"v"[9[2d]]"target"[9[2d]]"response"[9d]"b"d"bv"d"bTarget"d"
///   bResponse"d"zeta"d"px"d"ms"d"gs"d"active"B} 一致）
typedef struct CG27Engine {
    double p[9][2];          // +0x000  当前网格顶点（3×3）
    double v[9][2];          // +0x090  顶点速度
    double target[9][2];     // +0x120  目标网格
    double response[9];      // +0x1B0  每点弹簧响应
    double b;                // +0x1F8  主体弹簧位置
    double bv;               // +0x200  主体速度
    double bTarget;          // +0x208  主体目标
    double bResponse;        // +0x210  主体响应
    double zeta;             // +0x218  阻尼比
    double px;               // +0x220  水平进度
    double ms;               // +0x228  网格强度
    double gs;               // +0x230  网格缩放
    BOOL active;             // +0x238
} CG27Engine;

@interface CG27GenieDriver : NSObject {
    CG27Engine _engine;                              // +8
    double _shownXY[9][2];                           // +584
    BOOL _hasShownXY;                                // +728
    os_unfair_lock _nLock;                           // +732
    UIView *_nContainer;                             // +736
    UIView *_nAccessory;                             // +744
    NSArray *_nProps;                                // +752
    double _nPx;                                     // +760
    double _nMs;                                     // +768
    double _nGs;                                     // +776
    double _nGain;                                   // +784
    BOOL _nLive;                                     // +792
    unsigned int _nUpdating;                         // +796
    double _nPrev[19];                               // +800
    double _nPrevTime;                               // +952
    int _nCalls;                                     // +960
    int _nMainCalls;                                 // +964
    int _nLate;                                      // +968
    double _nCost;                                   // +976
    double _nMaxCost;                                // +984
    double _nLastCall;                               // +992
    double _nMaxGap;                                 // +1000
    double _nFirstCall;                              // +1008
    int _nSuppressedModel;                           // +1016
    int _nSuppressedPresentation;                    // +1020
    BOOL _native;                                    // +1024
    BOOL _nativeActive;                              // +1025
    BOOL _sawLayout;                                 // +1026
    BOOL _retargeted;                                // +1027
    BOOL _accessoryOverflows;                        // +1028
    BOOL _iconFits;                                  // +1029
    BOOL _opening;                                   // +1030
    int _accessorySearches;                          // +1032
    int _badgeSearches;                              // +1036
    id _nativeMeshToken;                             // +1040
    double _genieScale;                              // +1048
    double _response;                                // +1056
    double _zeta;                                    // +1064
    id _layoutSettings;                              // +1072
    __weak UIView *_container;                              // +1080
    __weak UIView *_accessory;                              // +1088
    id _appLayout;                                   // +1096
    double _startTime;                               // +1104
    double _lastTime;                                // +1112
    double _intensity;                               // +1120
    double _renderedB;                               // +1128
    NSHashTable *_iconMeshViews;                     // +1136
    CADisplayLink *_link;                            // +1144
    __weak id _owner;                                       // +1152
    id _previousMesh;                                // +1160
    id _appliedMesh;                                 // +1168
    CALayer *_openingShade;                          // +1176
    double _shadeStartTime;                          // +1184
    CALayer *_glassRim;                              // +1192
    double _glassBeginTime;                          // +1200
    NSHashTable *_grabbers;                          // +1208
    NSHashTable *_movingGrabbers;                    // +1216
    id _movingGrabberToken;                          // +1224
    unsigned long long _movingGrabberSearches;       // +1232
    __weak UIView *_badge;                                  // +1240
    UIView *_badgeCopy;                              // +1248
    double _iconWidth;                               // +1256
    CGRect _icon;                                    // +1264
}

@property (nonatomic) BOOL native;
@property (nonatomic) BOOL nativeActive;
@property (nonatomic, strong) id nativeMeshToken;
@property (nonatomic) CGRect icon;
@property (nonatomic) double genieScale;
@property (nonatomic) double response;
@property (nonatomic) double zeta;
@property (nonatomic, strong) id layoutSettings;
@property (nonatomic, weak) UIView *container;
@property (nonatomic, weak) UIView *accessory;
@property (nonatomic) int accessorySearches;
@property (nonatomic, strong) id appLayout;
@property (nonatomic) double startTime;
@property (nonatomic) double lastTime;
@property (nonatomic) double intensity;
@property (nonatomic) BOOL sawLayout;
@property (nonatomic) double renderedB;
@property (nonatomic) BOOL retargeted;
@property (nonatomic) BOOL accessoryOverflows;
@property (nonatomic) BOOL iconFits;
@property (nonatomic, strong, nullable) NSHashTable *iconMeshViews;
@property (nonatomic, strong, nullable) CADisplayLink *link;
@property (nonatomic, weak) id owner;
@property (nonatomic, strong, nullable) id previousMesh;
@property (nonatomic, strong, nullable) id appliedMesh;
@property (nonatomic, strong, nullable) CALayer *openingShade;
@property (nonatomic) double shadeStartTime;
@property (nonatomic, strong, nullable) CALayer *glassRim;
@property (nonatomic) double glassBeginTime;
@property (nonatomic, strong) NSHashTable *grabbers;
@property (nonatomic, strong) NSHashTable *movingGrabbers;
@property (nonatomic, strong, nullable) id movingGrabberToken;
@property (nonatomic) unsigned long long movingGrabberSearches;
@property (nonatomic, weak) UIView *badge;
@property (nonatomic, strong, nullable) UIView *badgeCopy;
@property (nonatomic) int badgeSearches;
@property (nonatomic) double iconWidth;
@property (nonatomic) BOOL opening;

// —— 原版方法列表（100 个，顺序与二进制方法表一致）——
- (void)updateGlassRim;
- (void)ensureGlassRimAt:(double)at;
- (void)restoreMovingGrabbers;
- (void)start;
- (void)stop;
- (void)engine:(const CG27Engine *)engine xy:(double *)xy;
- (id)meshForEngine:(const CG27Engine *)engine;
- (void)applyMeshWithLead:(double)lead at:(double)at frame:(double)frame;
- (void)tick:(CADisplayLink *)link;
- (void)meshIcons:(id)icons;
- (CGPoint)deformAccessoryPoint:(CGPoint)point;
- (id)meshForIcon:(id)icon;
- (void)makeBadgeCopy;
- (void)placeBadgeCopy;
- (void)advance:(double)delta;
- (void)nativeLoadEngine:(BOOL)load;
- (void)nativeSetUpWithContainer:(UIView *)container targetActive:(BOOL)targetActive;
- (void)nativePerform:(BOOL)perform;
- (void)nativeBounds:(CGRect)bounds of:(id)of;
- (void)nativeUpdate:(BOOL)update;
- (void)nativeSample:(double)sample;
- (void)nativeStop;
- (void)finish;

@end

NS_ASSUME_NONNULL_END
