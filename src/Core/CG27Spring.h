//
//  CG27Spring.h
//  iOS 27 动画 Reborn — 逆向重建
//
//  对应原版 sub_5b9c（弹簧解析解积分）、sub_5260（3×3 网格构建）
//  与原版 CG27GenieDriver 的 engine:xy: 计算。
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import "CG27GenieDriver.h"

NS_ASSUME_NONNULL_BEGIN

/// 9 点（3×3）网格，xy 交替存放，与 _shownXY 布局一致。
typedef double CG27Grid[9][2];

/// CAMutableMeshTransform 的顶点/面结构与原版传参布局一致（40 / 16 字节）。
typedef struct CG27MeshVertex { double u, v, x, y, z; } CG27MeshVertex;
typedef struct CG27MeshFace { unsigned int indices[4]; } CG27MeshFace;

/// 单步弹簧积分（对应 sub_5b9c，0x5b9c）。
/// 使用解析解：临界阻尼 / 欠阻尼 / 过阻尼三种分支，与 CGFloat 动画系统一致。
FOUNDATION_EXPORT void CG27EngineStep(CG27Engine *engine, double dt);

/// 由 engine 计算 9 个输出点（对应 -[CG27GenieDriver engine:xy:]，0x50c4）。
FOUNDATION_EXPORT void CG27EngineSampleXY(const CG27Engine *engine, double intensity, CG27Grid _Nonnull out);

/// 由 9 点网格构建 CAMutableMeshTransform（对应 sub_5260，0x5260）。
FOUNDATION_EXPORT id _Nullable CG27MeshFromGrid(const CG27Grid _Nonnull grid);

/// 3×3 网格双线性采样（对应 -[CG27GenieDriver deformAccessoryPoint:]，0x831c）。
FOUNDATION_EXPORT CGPoint CG27GridSample(const CG27Grid _Nonnull grid, CGPoint p);

NS_ASSUME_NONNULL_END
