//
//  MultitouchBridge.h
//  MagicChord
//
//  Bridge header for private MultitouchSupport.framework
//

#ifndef MultitouchBridge_h
#define MultitouchBridge_h

#import <Foundation/Foundation.h>

// Touch coordinate point (normalized 0.0 - 1.0 or physical mm)
typedef struct {
    float x;
    float y;
} MTPoint;

// Touch readout (position and velocity vector)
typedef struct {
    MTPoint position;
    MTPoint velocity;
} MTReadout;

// Raw finger touch structure reported by MultitouchSupport
typedef struct {
    int frame;
    double timestamp;
    int identifier;
    int state;               // 0=not tracking, 1=start, 2=hover, 3=make touch, 4=touching, 5=break touch, 6=linger, 7=out of range
    int foo3;
    int foo4;
    MTReadout normalized;    // Normalized coordinates: x: 0 (left) - 1 (right), y: 0 (bottom) - 1 (top)
    float size;
    int zero1;
    float angle;
    float majorAxis;
    float minorAxis;
    MTReadout absoluteVector;
    int zero2[2];
    float unk2;
} MTTouch;

// Opaque multitouch device reference
typedef void* MTDeviceRef;

// Callback function type
typedef int (*MTContactCallbackFunction)(int device, MTTouch *touches, int numTouches, double timestamp, int frame);

#ifdef __cplusplus
extern "C" {
#endif

// Returns a CFMutableArray of MTDeviceRef for all connected multitouch surfaces
CFMutableArrayRef MTDeviceCreateList(void);

// Register contact frame callback for receiving raw touches
void MTRegisterContactFrameCallback(MTDeviceRef device, MTContactCallbackFunction callback);

// Unregister contact frame callback
void MTUnregisterContactFrameCallback(MTDeviceRef device, MTContactCallbackFunction callback);

// Start touch delivery on device
void MTDeviceStart(MTDeviceRef device, int unknown);

// Stop touch delivery on device
void MTDeviceStop(MTDeviceRef device);

// True if device is internal (e.g. MacBook trackpad), false if external (Magic Mouse / external trackpad)
bool MTDeviceIsBuiltIn(MTDeviceRef device);

// True if device surface is opaque
bool MTDeviceIsOpaqueSurface(MTDeviceRef device);

#ifdef __cplusplus
}
#endif

#endif /* MultitouchBridge_h */
