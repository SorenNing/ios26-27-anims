//
//  CG27Spring.m
//  iOS 27 动画 Reborn — 逆向重建
//

#import "CG27Spring.h"
#import <math.h>
#import <objc/message.h>

static const double kCG27Epsilon = 1e-6;       // @0x19b18
static const double kCG27TwoPi   = 6.283185307; // @0x19b10

/// 单轴弹簧解析解。与 +[CASpringAnimation] 内部一致的三种阻尼分支。
static inline void CG27SpringAxis(double *value, double *velocity,
                                  double target, double zeta,
                                  double h, double dt)
{
    const double d = *value - target;
    const double v = *velocity;

    if (fabs(zeta - 1.0) < kCG27Epsilon) {
        // 临界阻尼
        const double a = h * d + v;
        const double e = exp(-h * dt);
        *value    = (d + a * dt) * e + target;
        *velocity = (-h * a * dt + v) * e;
        return;
    }

    if (zeta < 1.0) {
        // 欠阻尼
        const double s = sqrt(1.0 - zeta * zeta);
        const double wd = h * s;
        const double sigma = h * zeta;
        const double e = exp(-sigma * dt);
        const double b = (sigma * d + v) / wd;
        const double phase = wd * dt;
        const double sn = sin(phase);
        const double cs = cos(phase);
        *value    = e * (d * cs + b * sn) + target;
        *velocity = e * ((-sigma * d + b * wd) * cs + (-sigma * b - d * wd) * sn);
        return;
    }

    // 过阻尼
    const double s = sqrt(zeta * zeta - 1.0);
    const double slow = -(h * (zeta - s));
    const double fast = -(h * (zeta + s));
    const double c = (v - slow * d) / (fast - slow);
    const double rest = d - c;
    const double e1 = exp(slow * dt);
    const double e2 = exp(fast * dt);
    *value    = rest * e1 + c * e2 + target;
    *velocity = slow * rest * e1 + fast * c * e2;
}

void CG27EngineStep(CG27Engine *e, double dt)
{
    if (dt <= 0.0 || !e->active) {
        return;
    }

    for (int i = 0; i < 9; i++) {
        const double response = e->response[i];
        if (!isfinite(response) || response <= 0.0) {
            continue;
        }
        const double h = kCG27TwoPi / response;
        for (int k = 0; k < 2; k++) {
            CG27SpringAxis(&e->p[i][k], &e->v[i][k], e->target[i][k], e->zeta, h, dt);
        }
    }

    if (isfinite(e->bResponse) && e->bResponse > 0.0) {
        const double h = kCG27TwoPi / e->bResponse;
        CG27SpringAxis(&e->b, &e->bv, e->bTarget, e->zeta, h, dt);
    }
}

void CG27EngineSampleXY(const CG27Engine *e, double intensity, CG27Grid out)
{
    const double b  = e->b;
    const double ms = e->ms;
    const double gs = e->gs;

    // progress：网格强度与主体进度的混合比例
    const double num = (1.0 - ms) * (1.0 - b) + ms;
    const double den = (1.0 - b) * (1.0 - ms * gs) + ms * gs;
    const double progress = num / den;

    // 水平方向的附加修饰项
    const double px = e->px;
    const double tweak = (gs * (px - 0.5) + (0.5 - px)) * (progress - 1.0) / (1.0 / gs - 1.0);

    const double cx = e->p[4][0];
    const double cy = e->p[4][1];
    for (int i = 0; i < 9; i++) {
        out[i][0] = (e->p[i][0] - cx) * progress + cx + tweak;
        out[i][1] = (e->p[i][1] - cy) * progress + cy;
    }

    if (intensity != 1.0) {
        for (int i = 0; i < 9; i++) {
            const double u = (double)(i % 3);
            const double v = (double)(i / 3);
            out[i][0] = u + intensity * (out[i][0] - u);
            out[i][1] = v + intensity * (out[i][1] - v);
        }
    }
}

id CG27MeshFromGrid(const CG27Grid grid)
{
    static Class CG27MeshClass = Nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        CG27MeshClass = NSClassFromString(@"CAMutableMeshTransform");
    });
    if (!CG27MeshClass) {
        return nil;
    }
    id mesh = ((id (*)(id, SEL))objc_msgSend)(CG27MeshClass, @selector(meshTransform));
    const SEL setSubdivision = NSSelectorFromString(@"setSubdivisionSteps:");
    if ([mesh respondsToSelector:setSubdivision]) {
        ((void (*)(id, SEL, long long))objc_msgSend)(mesh, setSubdivision, -1LL);
    }

    for (int row = 0; row < 3; row++) {
        for (int col = 0; col < 3; col++) {
            // 顶点结构：{ u, v, x, y, z }，与原版 addVertex: 传入的 40 字节布局一致
            CG27MeshVertex v;
            v.u = (double)col;
            v.v = (double)row;
            const double *pt = grid[row * 3 + col];
            v.x = pt[0];
            v.y = pt[1];
            v.z = 0.0;
            ((void (*)(id, SEL, void *))objc_msgSend)(mesh, NSSelectorFromString(@"addVertex:"), &v);
        }
    }

    for (int row = 0; row < 2; row++) {
        for (int col = 0; col < 2; col++) {
            const unsigned int base = (unsigned int)(row * 3 + col);
            CG27MeshFace face;
            face.indices[0] = base;
            face.indices[1] = base + 1;
            face.indices[2] = base + 4;
            face.indices[3] = base + 3;
            ((void (*)(id, SEL, void *))objc_msgSend)(mesh, NSSelectorFromString(@"addFace:"), (void *)&face);
        }
    }

    return mesh;
}

CGPoint CG27GridSample(const CG27Grid grid, CGPoint point)
{
    double u = point.x * 2.0;
    double v = point.y * 2.0;

    double fu = floor(u);
    fu = fmax(fu, 0.0);
    fu = fmin(fu, 1.0);

    double fv = floor(v);
    fv = fmax(fv, 0.0);
    fv = fmin(fv, 1.0);

    const int iu = (int)fu;
    const int iv = (int)fv;
    const double tx = u - (double)iu;
    const double ty = v - (double)iv;

    const int base = iv * 3 + iu;
    const double w00 = (1.0 - tx) * (1.0 - ty);
    const double w10 = tx * (1.0 - ty);
    const double w01 = (1.0 - tx) * ty;
    const double w11 = tx * ty;

    const double x = grid[base][0] * w00 + grid[base + 1][0] * w10
                   + grid[base + 3][0] * w01 + grid[base + 4][0] * w11;
    const double y = grid[base][1] * w00 + grid[base + 1][1] * w10
                   + grid[base + 3][1] * w01 + grid[base + 4][1] * w11;
    return CGPointMake(x, y);
}
