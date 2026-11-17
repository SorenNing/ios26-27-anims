//
//  CG27Globals.m
//  iOS 27 动画 Reborn — 逆向重建
//

#import "CG27Globals.h"
#import <UIKit/UIKit.h>
#import "../Core/CG27GenieDriver.h"

static NSHashTable *gDrivers;
static os_unfair_lock gDriversLock = OS_UNFAIR_LOCK_INIT;

NSHashTable *CG27Drivers(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gDrivers = [NSHashTable weakObjectsHashTable];
    });
    return gDrivers;
}

void CG27RegisterDriver(id driver)
{
    if (!driver) {
        return;
    }
    NSHashTable *table = CG27Drivers();
    os_unfair_lock_lock(&gDriversLock);
    [table addObject:driver];
    os_unfair_lock_unlock(&gDriversLock);
}

void CG27UnregisterDriver(id driver)
{
    if (!driver) {
        return;
    }
    NSHashTable *table = CG27Drivers();
    os_unfair_lock_lock(&gDriversLock);
    [table removeObject:driver];
    os_unfair_lock_unlock(&gDriversLock);
}

NSArray *CG27DriverSnapshot(void)
{
    NSHashTable *table = CG27Drivers();
    os_unfair_lock_lock(&gDriversLock);
    NSArray *copy = [table.allObjects copy];
    os_unfair_lock_unlock(&gDriversLock);
    return copy ?: @[];
}

static BOOL CG27SameObject(id a, id b)
{
    if (a == b) {
        return YES;
    }
    return [a respondsToSelector:@selector(isEqual:)] && [a isEqual:b];
}

id CG27DriverForAppLayout(id appLayout)
{
    if (!appLayout) {
        return nil;
    }
    for (CG27GenieDriver *driver in CG27DriverSnapshot()) {
        id candidate = [driver respondsToSelector:@selector(appLayout)] ? driver.appLayout : nil;
        if (CG27SameObject(candidate, appLayout)) {
            return driver;
        }
    }
    return nil;
}

id CG27DriverForContainer(UIView *container)
{
    if (!container) {
        return nil;
    }
    for (CG27GenieDriver *driver in CG27DriverSnapshot()) {
        if (driver.container == container) {
            return driver;
        }
    }
    return nil;
}

id CG27DriverForAccessory(UIView *accessory)
{
    if (!accessory) {
        return nil;
    }
    for (CG27GenieDriver *driver in CG27DriverSnapshot()) {
        if (driver.accessory == accessory) {
            return driver;
        }
    }
    return nil;
}
