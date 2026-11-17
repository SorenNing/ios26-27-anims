//
//  CG27Globals.h
//  iOS 27 动画 Reborn — 逆向重建
//
//  原版在 __DATA 中维护的全局状态：活跃 driver 表 + 配置快照。
//

#import <Foundation/Foundation.h>

@class UIView;

NS_ASSUME_NONNULL_BEGIN

/// 全体活跃的 CG27GenieDriver（原版 @0x250890 的全局容器，弱引用）。
FOUNDATION_EXPORT NSHashTable *CG27Drivers(void);

/// 按 appLayout 找到匹配的 driver。
FOUNDATION_EXPORT id _Nullable CG27DriverForAppLayout(id _Nullable appLayout);

/// 按 container / accessory 找驱动它的 driver。
FOUNDATION_EXPORT id _Nullable CG27DriverForContainer(UIView * _Nullable container);
FOUNDATION_EXPORT id _Nullable CG27DriverForAccessory(UIView * _Nullable accessory);

/// 取出全部 driver 的快照（原版在枚举前会先 copy 一份）。
FOUNDATION_EXPORT NSArray *CG27DriverSnapshot(void);

/// 注册 / 注销 driver。
FOUNDATION_EXPORT void CG27RegisterDriver(id driver);
FOUNDATION_EXPORT void CG27UnregisterDriver(id driver);

NS_ASSUME_NONNULL_END
