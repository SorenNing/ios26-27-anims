//
//  CG27GenieDriver.m
//  iOS 27 动画 Reborn — 逆向重建
//
//  每个方法都标注了原版 IMP 地址，实现依据为对应函数的反汇编
//  （完整清单见 docs/asm/，地址映射见 docs/METHODS.md）。
//

#import "CG27GenieDriver.h"
#import "CG27Spring.h"
#import "../Shared/CG27Globals.h"
#import "../Shared/CG27Prefs.h"
#import <math.h>
#import <objc/runtime.h>
#import <objc/message.h>

// UIKit private symbol; arm64e original consumes s0 immediately after the call.
extern float UIAnimationDragCoefficient(void);

static NSString *const kCG27GrabberHideReason = @"iOS27AnimsRebornGrabberHide";
static NSString *const kCG27MeshAnimationKey = @"iOS27AnimsRebornMesh";
static NSString *const kCG27CornerResetKey = @"cg27.cornerReset";
static NSString *const kCG27FlyInKey = @"iOS27AnimsRebornFlyIn";
static NSString *const kCG27FlyBlurFilter = @"CG27FlyBlur";
static NSString *const kCG27MovingGrabberOpacity = @"CG27MovingGrabberOpacity";

static inline void CG27SetMeshTransform(CALayer *layer, id mesh)
{
    if (!layer) {
        return;
    }
    static SEL sel;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sel = NSSelectorFromString(@"setMeshTransform:");
    });
    if ([layer respondsToSelector:sel]) {
        ((void (*)(id, SEL, id))objc_msgSend)(layer, sel, mesh);
    }
}

static inline void CG27SetHighFrameRateReason(CADisplayLink *link, unsigned int reason)
{
    static SEL sel;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sel = NSSelectorFromString(@"setHighFrameRateReason:");
    });
    if ([link respondsToSelector:sel]) {
        ((void (*)(id, SEL, unsigned int))objc_msgSend)(link, sel, reason);
    }
}


// 原版常量（__const 段实测值）
static const double kCG27LeadLimit = 0.05;       // @0x19ac0
static const double kCG27MinScaleLimit = 0.034;  // @0x19ae8
static const double kCG27EpsilonA = 0.004;       // @0x19af0
static const double kCG27EpsilonB = 0.01;        // @0x19af8
static const double kCG27EpsilonC = 0.002;       // @0x19b00
static const double kCG27EpsilonD = -0.01;       // @0x19b08
static const double kCG27ConvergeEpsilon = 0.99; // @0x19b20
static const double kCG27TwoPi = 6.283185307;    // @0x19b10

@implementation CG27GenieDriver

@synthesize native = _native;
@synthesize nativeActive = _nativeActive;
@synthesize nativeMeshToken = _nativeMeshToken;
@synthesize icon = _icon;
@synthesize genieScale = _genieScale;
@synthesize response = _response;
@synthesize zeta = _zeta;
@synthesize layoutSettings = _layoutSettings;
@synthesize container = _container;
@synthesize accessory = _accessory;
@synthesize accessorySearches = _accessorySearches;
@synthesize appLayout = _appLayout;
@synthesize startTime = _startTime;
@synthesize lastTime = _lastTime;
@synthesize intensity = _intensity;
@synthesize sawLayout = _sawLayout;
@synthesize renderedB = _renderedB;
@synthesize retargeted = _retargeted;
@synthesize accessoryOverflows = _accessoryOverflows;
@synthesize iconFits = _iconFits;
@synthesize iconMeshViews = _iconMeshViews;
@synthesize link = _link;
@synthesize owner = _owner;
@synthesize previousMesh = _previousMesh;
@synthesize appliedMesh = _appliedMesh;
@synthesize openingShade = _openingShade;
@synthesize shadeStartTime = _shadeStartTime;
@synthesize glassRim = _glassRim;
@synthesize glassBeginTime = _glassBeginTime;
@synthesize grabbers = _grabbers;
@synthesize movingGrabbers = _movingGrabbers;
@synthesize movingGrabberToken = _movingGrabberToken;
@synthesize movingGrabberSearches = _movingGrabberSearches;
@synthesize badge = _badge;
@synthesize badgeCopy = _badgeCopy;
@synthesize badgeSearches = _badgeSearches;
@synthesize iconWidth = _iconWidth;
@synthesize opening = _opening;

#pragma mark - 生命周期

// IMP 0x4000
- (void)updateGlassRim
{
    CALayer *rim = self.glassRim;
    if (!rim) {
        return;
    }
    UIView *container = self.container;
    if (!container) {
        return;
    }

    CALayer *containerLayer = container.layer;
    if (rim.superlayer != containerLayer) {
        [containerLayer addSublayer:rim];
    }

    CALayer *presentation = containerLayer.presentationLayer ?: containerLayer;
    if (!presentation) {
        return;
    }

    CATransform3D transform = presentation.transform;
    double scale = hypot(transform.m11, transform.m12);
    if (!isfinite(scale) || scale <= kCG27LeadLimit) {
        scale = 1.0;
    }

    CGRect bounds = presentation.bounds;
    if (bounds.size.width < 1.0 || bounds.size.height < 1.0) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        rim.hidden = YES;
        [CATransaction commit];
        return;
    }

    const double width = bounds.size.width * scale;
    const double iconWidth = self.iconWidth;
    const double inset = MAX(0.0, (width - iconWidth) * 0.5);
    const double radius = MIN(iconWidth, width) * 0.5;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    rim.hidden = NO;
    rim.frame = CGRectMake(bounds.origin.x + inset,
                           bounds.origin.y + inset,
                           MAX(0.0, width - inset * 2.0),
                           MAX(0.0, bounds.size.height * scale - inset * 2.0));
    rim.cornerRadius = radius;
    rim.borderWidth = 1.0;
    [CATransaction commit];
}

// IMP 0x44c0
- (void)ensureGlassRimAt:(double)at
{
    if (!self.container) {
        return;
    }
    if (!self.glassRim) {
        CALayer *rim = [CALayer layer];
        rim.name = kCG27MeshAnimationKey;
        rim.masksToBounds = YES;
        self.glassRim = rim;
    }
    if (self.glassBeginTime == 0.0) {
        self.glassBeginTime = at;
    }
    [self updateGlassRim];
}

// IMP 0x451c
- (void)restoreMovingGrabbers
{
    if (self.opening) {
        return;
    }
    CALayer *rim = self.glassRim;
    [rim removeFromSuperlayer];
    self.glassRim = nil;

    for (UIView *grabber in self.movingGrabbers.allObjects) {
        if ([grabber respondsToSelector:@selector(setAlpha:)]) {
            grabber.alpha = 1.0;
        }
    }
    [self.movingGrabbers removeAllObjects];
    self.movingGrabberToken = nil;
    self.movingGrabberSearches = 0;
}

// IMP 0x47c0
- (void)start
{
    const double now = CACurrentMediaTime();
    self.lastTime = now;
    self.startTime = now;

    if (self.link) {
        return;
    }

    CADisplayLink *link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    self.link = link;

    if ([link respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
        link.preferredFrameRateRange = CAFrameRateRangeMake(80.0f, 120.0f, 120.0f);
    }
    CG27SetHighFrameRateReason(link, 0x110001u);
    [link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

// IMP 0x4944
- (void)stop
{
    [self restoreMovingGrabbers];

    CADisplayLink *link = self.link;
    [link invalidate];
    self.link = nil;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [[self.container layer] removeAnimationForKey:kCG27MovingGrabberOpacity];
    [CATransaction commit];

    CG27SetMeshTransform([self.container layer], nil);
    CG27SetMeshTransform([self.accessory layer], nil);
    for (UIView *view in self.iconMeshViews.allObjects) {
        CG27SetMeshTransform(view.layer, nil);
    }

    CALayer *rim = self.glassRim;
    [rim removeFromSuperlayer];
    self.glassRim = nil;

    CALayer *shade = self.openingShade;
    [shade removeFromSuperlayer];
    self.openingShade = nil;

    UIView *badgeCopy = self.badgeCopy;
    [badgeCopy removeFromSuperview];
    self.badgeCopy = nil;

    self.appliedMesh = nil;
    self.previousMesh = nil;
    self.glassBeginTime = 0.0;
    self.shadeStartTime = 0.0;
    self.sawLayout = NO;
    self.renderedB = 0.0;

    _engine.active = NO;
    CG27UnregisterDriver(self);
}

#pragma mark - 网格

// IMP 0x50c4
- (void)engine:(const CG27Engine *)engine xy:(double *)xy
{
    CG27Grid grid;
    CG27EngineSampleXY(engine, self.intensity, grid);
    memcpy(xy, grid, sizeof(CG27Grid));
}

// IMP 0x51f0
- (id)meshForEngine:(const CG27Engine *)engine
{
    CG27Grid grid;
    [self engine:engine xy:(double *)grid];
    return CG27MeshFromGrid(grid);
}

// IMP 0x53a0
- (void)applyMeshWithLead:(double)lead at:(double)at frame:(double)frame
{
    CG27Engine engine;
    memcpy(&engine, &_engine, sizeof(CG27Engine));

    if (lead > 0.0 && lead < kCG27LeadLimit) {
        CG27EngineStep(&engine, lead);
    }

    self.renderedB = engine.b;

    id mesh = [self meshForEngine:&engine];
    [self engine:&engine xy:(double *)_shownXY];
    _hasShownXY = YES;

    if (self.previousMesh && mesh) {
        // 与上一帧的网格交叉淡化：由 layer 动画负责，这里只保留引用
        self.appliedMesh = mesh;
    } else {
        self.appliedMesh = mesh;
    }
    self.previousMesh = mesh;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    CG27SetMeshTransform([self.container layer], mesh);
    CG27SetMeshTransform([self.accessory layer], mesh);
    for (UIView *view in self.iconMeshViews.allObjects) {
        id iconMesh = [self meshForIcon:view];
        if (iconMesh) {
            CG27SetMeshTransform(view.layer, iconMesh);
        }
    }
    [CATransaction commit];
}

// IMP 0x831c
- (CGPoint)deformAccessoryPoint:(CGPoint)point
{
    CG27Grid grid;
    memcpy(grid, _shownXY, sizeof(CG27Grid));
    return CG27GridSample(grid, point);
}

// IMP 0x83b0
- (id)meshForIcon:(id)icon
{
    UIView *accessory = self.accessory;
    if (!accessory || !icon) {
        return nil;
    }

    CALayer *accessoryLayer = accessory.layer;
    CALayer *accessoryPresented = accessoryLayer.presentationLayer ?: accessoryLayer;
    CALayer *iconLayer = ((UIView *)icon).layer;
    CALayer *iconPresented = iconLayer.presentationLayer ?: iconLayer;

    CGRect accessoryBounds = accessoryPresented.bounds;
    CGRect iconBounds = iconPresented.bounds;
    if (accessoryBounds.size.width < 1.0 || accessoryBounds.size.height < 1.0 ||
        iconBounds.size.width < 1.0 || iconBounds.size.height < 1.0) {
        return nil;
    }

    // 图标四角映射到附件坐标系，再经 _shownXY 采样成 genie 网格
    const CGPoint corners[4] = {
        CGPointMake(CGRectGetMinX(iconBounds), CGRectGetMinY(iconBounds)),
        CGPointMake(CGRectGetMaxX(iconBounds), CGRectGetMinY(iconBounds)),
        CGPointMake(CGRectGetMinX(iconBounds), CGRectGetMaxY(iconBounds)),
        CGPointMake(CGRectGetMaxX(iconBounds), CGRectGetMaxY(iconBounds)),
    };

    CGPoint mapped[4];
    for (int i = 0; i < 4; i++) {
        CGPoint inAccessory = [iconLayer convertPoint:corners[i] toLayer:accessoryPresented];
        const double u = (inAccessory.x - CGRectGetMinX(accessoryBounds)) / accessoryBounds.size.width;
        const double v = (inAccessory.y - CGRectGetMinY(accessoryBounds)) / accessoryBounds.size.height;
        mapped[i] = CGPointMake(u, v);
    }

    const double width = hypot(mapped[1].x - mapped[0].x, mapped[1].y - mapped[0].y);
    const double height = hypot(mapped[2].x - mapped[0].x, mapped[2].y - mapped[0].y);
    if (width < 1e-6 || height < 1e-6) {
        return nil;
    }

    CG27Grid grid;
    for (int row = 0; row < 3; row++) {
        for (int col = 0; col < 3; col++) {
            const double u = (double)col * 0.5;
            const double v = (double)row * 0.5;
            CGPoint local = CGPointMake(mapped[0].x + width * u, mapped[0].y + height * v);
            CGPoint sampled = CG27GridSample((const double (*)[2])_shownXY, local);
            grid[row * 3 + col][0] = sampled.x;
            grid[row * 3 + col][1] = sampled.y;
        }
    }
    return CG27MeshFromGrid(grid);
}

// IMP 0x809c
- (void)meshIcons:(id)icons
{
    NSArray *views = nil;
    if ([icons isKindOfClass:[NSArray class]]) {
        views = icons;
    } else if ([icons isKindOfClass:[NSSet class]]) {
        views = [(NSSet *)icons allObjects];
    } else if (icons) {
        views = @[icons];
    }
    if (views.count == 0) {
        return;
    }

    if (!self.iconMeshViews) {
        self.iconMeshViews = [NSHashTable weakObjectsHashTable];
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (UIView *view in views) {
        if (![view isKindOfClass:[UIView class]]) {
            continue;
        }
        id mesh = [self meshForIcon:view];
        if (mesh) {
            CG27SetMeshTransform(view.layer, mesh);
            [self.iconMeshViews addObject:view];
        }
    }
    [CATransaction commit];
}

#pragma mark - 每帧推进

// IMP 0x649c
- (void)tick:(CADisplayLink *)link
{
    const double now = CACurrentMediaTime();

    if (!self.container) {
        [self stop];
        return;
    }
    if (![[self.container window] windowScene]) {
        return;
    }
    if (self.lastTime > 0.0) {
        const double gap = now - self.lastTime;
        _nCalls++;
        if (gap > _nMaxGap) {
            _nMaxGap = gap;
        }
    }
    self.lastTime = now;

    // 动画超过 2 秒（含拖慢系数）即收尾
    const double elapsed = now - self.startTime;
    const float drag = UIAnimationDragCoefficient();
    const double limit = (drag > 0.0f && isfinite(drag)) ? (double)drag * 2.0 : 2.0;
    if (elapsed > limit) {
        [self finish];
        return;
    }

    const double delta = link ? (link.targetTimestamp - link.timestamp) : (1.0 / 120.0);
    [self advance:delta];

    if (self.native) {
        [self nativeUpdate:YES];
    }
}

// IMP 0x8fe4
- (void)advance:(double)delta
{
    UIView *container = self.container;
    CALayer *layer = container.layer;
    CALayer *source = layer.presentationLayer ?: layer;
    if (!source) {
        return;
    }

    const CGRect bounds = source.bounds;
    const CGRect screen = [UIScreen mainScreen].bounds;

    const BOOL valid = (bounds.size.width > 1.0 &&
                        bounds.size.height < bounds.size.width + 1.0 &&
                        bounds.size.height > bounds.size.width - 1.0 &&
                        bounds.size.height < screen.size.height + 1.0 &&
                        fabs(bounds.size.width - screen.size.width) < 1.0);
    if (!valid) {
        return;
    }

    CG27EngineStep(&_engine, delta);

    const double b = _engine.b;
    const double ms = _engine.ms;
    const double gs = _engine.gs;

    // 主体进度到端点后收敛
    if (b <= kCG27LeadLimit || b >= 1.0 - kCG27LeadLimit) {
        self.retargeted = YES;
    }

    if (self.accessory && ms > kCG27EpsilonA && gs > kCG27EpsilonC) {
        CGPoint origin = [self deformAccessoryPoint:CGPointMake(0.0, 0.0)];
        CGPoint center = [self deformAccessoryPoint:CGPointMake(0.5, 0.5)];
        const double travel = hypot(center.x - origin.x, center.y - origin.y);
        self.renderedB = travel;
    }

    [self applyMeshWithLead:delta at:_engine.b frame:0.0];

    if (b <= 1e-6 || b >= 1.0 - 1e-6) {
        [self finish];
    }
}

// IMP 0x9620 (finish 前的收尾判定)
- (void)finish
{
    if (self.link) {
        [self stop];
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    CG27SetMeshTransform([self.container layer], nil);
    CG27SetMeshTransform([self.accessory layer], nil);
    for (UIView *view in self.iconMeshViews.allObjects) {
        CG27SetMeshTransform(view.layer, nil);
    }
    [CATransaction commit];

    [self restoreMovingGrabbers];

    if (self.badgeCopy) {
        UIView *badgeCopy = self.badgeCopy;
        self.badgeCopy = nil;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [badgeCopy removeFromSuperview];
        });
    }

    if (self.openingShade) {
        CALayer *shade = self.openingShade;
        self.openingShade = nil;
        [shade removeFromSuperlayer];
    }

    [self.movingGrabbers removeAllObjects];
    self.movingGrabberToken = nil;
    self.movingGrabberSearches = 0;
    self.badgeSearches = 0;
    self.accessorySearches = 0;
    self.iconMeshViews = nil;
    self.previousMesh = nil;
    self.appliedMesh = nil;
    _engine.active = NO;
}

#pragma mark - 徽标

// IMP 0x86e4
- (void)makeBadgeCopy
{
    UIView *badge = self.badge;
    if (!badge) {
        return;
    }
    if (self.badgeCopy) {
        [self.badgeCopy removeFromSuperview];
        self.badgeCopy = nil;
    }

    CGRect frame = badge.bounds;
    if (frame.size.width < 1.0 || frame.size.height < 1.0) {
        return;
    }

    UIGraphicsImageRenderer *renderer =
        [[UIGraphicsImageRenderer alloc] initWithBounds:frame];
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [badge.layer renderInContext:context.CGContext];
    }];
    if (!image) {
        return;
    }

    UIImageView *copy = [[UIImageView alloc] initWithImage:image];
    copy.frame = [badge convertRect:frame toView:badge.superview];
    copy.userInteractionEnabled = NO;
    copy.layer.zPosition = badge.layer.zPosition + 1.0;

    [badge.superview addSubview:copy];
    self.badgeCopy = copy;
    self.badgeSearches = 0;
}

// IMP 0x8a00
- (void)placeBadgeCopy
{
    UIView *copy = self.badgeCopy;
    UIView *badge = self.badge;
    if (!copy || !badge) {
        return;
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    copy.frame = [badge.superview convertRect:badge.frame fromView:badge.superview];
    copy.layer.transform = badge.layer.transform;
    copy.alpha = badge.alpha;
    [CATransaction commit];
}

#pragma mark - 原生引擎（iOS 27 native genie）

// IMP 0x9728
- (void)nativeLoadEngine:(BOOL)load
{
    if (!load) {
        _native = NO;
        _nLive = NO;
        _nContainer = nil;
        _nAccessory = nil;
        _nProps = nil;
        _nativeMeshToken = nil;
        return;
    }

    UIView *container = self.container;
    if (!container) {
        _native = NO;
        return;
    }

    _nContainer = container;
    _nAccessory = self.accessory;
    _nPx = _engine.px;
    _nMs = _engine.ms;
    _nGs = _engine.gs;
    _nGain = 1.0;
    _nLive = YES;
    _nUpdating = 0;
    _nCalls = 0;
    _nMainCalls = 0;
    _nLate = 0;
    _nCost = 0.0;
    _nMaxCost = 0.0;
    _nLastCall = 0.0;
    _nMaxGap = 0.0;
    _nFirstCall = CACurrentMediaTime();
    _nSuppressedModel = 0;
    _nSuppressedPresentation = 0;

    if (!_nProps) {
        NSMutableArray *props = [NSMutableArray array];
        if ([container respondsToSelector:@selector(_createTransformerWithInputAnimatableProperties:modelValueSetter:presentationValueSetter:)]) {
            _nProps = props;
        } else {
            _nProps = nil;
        }
    }

    _native = YES;
    _nativeActive = YES;
}

// IMP 0x9984
- (void)nativeSetUpWithContainer:(UIView *)container targetActive:(BOOL)targetActive
{
    if (!container) {
        _native = NO;
        _nativeActive = NO;
        return;
    }

    _nContainer = container;
    _nAccessory = self.accessory;
    _nLive = YES;

    const CGRect bounds = container.bounds;
    const CGPoint mid = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
    _nPx = (bounds.size.width > 0.0) ? (mid.x / bounds.size.width) : 0.0;
    _nMs = _engine.ms;
    _nGs = _engine.gs;
    _nGain = 1.0;
    _nPrevTime = CACurrentMediaTime();
    for (int i = 0; i < 19; i++) {
        _nPrev[i] = 0.0;
    }

    os_unfair_lock_lock(&_nLock);
    _nativeActive = targetActive;
    _nLive = YES;
    os_unfair_lock_unlock(&_nLock);
}

// IMP 0x9f04
- (void)nativePerform:(BOOL)perform
{
    if (!_native || !_nContainer) {
        return;
    }
    _nUpdating += perform ? 1u : 0u;
    [self nativeUpdate:perform];
}

// IMP 0xa1a8
- (void)nativeBounds:(CGRect)bounds of:(id)of
{
    if (!_native) {
        return;
    }
    const double width = bounds.size.width;
    const double height = bounds.size.height;
    if (width < 1.0 || height < 1.0) {
        _native = NO;
        return;
    }
    _nPx = MIN(1.0, MAX(0.0, width / MAX(1.0, [UIScreen mainScreen].bounds.size.width)));
    _nMs = _engine.ms;
    _nGs = _engine.gs;
    _nGain = MIN(1.0, MAX(0.0, height / MAX(1.0, width)));
}

// IMP 0xa438
- (void)nativeUpdate:(BOOL)update
{
    if (!_native || !_nativeActive || !_nContainer) {
        return;
    }

    os_unfair_lock_lock(&_nLock);
    if (!_nativeActive) {
        os_unfair_lock_unlock(&_nLock);
        return;
    }
    _nUpdating++;
    os_unfair_lock_unlock(&_nLock);

    const double now = CACurrentMediaTime();
    const double gap = (_nLastCall > 0.0) ? (now - _nLastCall) : 0.0;
    _nLastCall = now;
    if (gap > _nMaxGap) {
        _nMaxGap = gap;
    }
    _nMainCalls++;
    if (gap > 1.0 / 30.0) {
        _nLate++;
    }

    _nPrev[_nCalls % 19] = _nPx;
    _nCost += [self.container.layer.presentationLayer bounds].size.width;

    [self applyMeshWithLead:0.0 at:_engine.b frame:0.0];

    os_unfair_lock_lock(&_nLock);
    _nUpdating--;
    os_unfair_lock_unlock(&_nLock);
}

// IMP 0xa8a0
- (void)nativeSample:(double)sample
{
    if (!_native || !_nContainer) {
        return;
    }
    if (sample <= 0.0) {
        return;
    }

    _nPrevTime = CACurrentMediaTime();
    _nPx = _engine.px;
    _nMs = _engine.ms;
    _nGs = _engine.gs;

    const double phase = sample * kCG27TwoPi;
    const double gain = _nGain * (0.5 + 0.5 * cos(phase));
    _nGain = gain;

    CG27Engine snapshot;
    memcpy(&snapshot, &_engine, sizeof(CG27Engine));
    snapshot.px = _nPx;
    snapshot.ms = _nMs;
    snapshot.gs = _nGs;

    CG27Grid grid;
    [self engine:&snapshot xy:(double *)grid];
    [self meshIcons:[self.iconMeshViews allObjects]];

    BOOL finite = YES;
    for (int i = 0; i < 9; i++) {
        if (!isfinite(grid[i][0]) || !isfinite(grid[i][1])) {
            finite = NO;
            break;
        }
    }
    if (!finite) {
        _native = NO;
    }
}

// IMP 0xb1e8
- (void)nativeStop
{
    _nLive = NO;
    _nUpdating = 0;
    _nativeActive = NO;

    os_unfair_lock_lock(&_nLock);
    _nContainer = nil;
    _nAccessory = nil;
    _nProps = nil;
    _nativeMeshToken = nil;
    _nCalls = 0;
    _nMainCalls = 0;
    _nLate = 0;
    _nCost = 0.0;
    _nMaxCost = 0.0;
    _nLastCall = 0.0;
    _nMaxGap = 0.0;
    _nFirstCall = 0.0;
    os_unfair_lock_unlock(&_nLock);
}

@end
