//
//  MultitouchDeviceManager.swift
//  MagicChord
//

import Foundation
import Combine

protocol MultitouchDeviceManagerDelegate: AnyObject {
    func multitouchDeviceDidUpdateTouches(_ touches: [SurfaceTouch], timestamp: Double)
}

final class MultitouchDeviceManager: ObservableObject {
    @Published var isMagicMouseConnected: Bool = false
    @Published var connectedDeviceCount: Int = 0

    weak var delegate: MultitouchDeviceManagerDelegate?

    private var activeDevices: [MTDeviceRef] = []
    private var pollTimer: Timer?
    fileprivate static weak var sharedCallbackInstance: MultitouchDeviceManager?

    // Thread-safe storage for latest touches
    private var latestTouches: [SurfaceTouch] = []
    private let touchesLock = os_unfair_lock_t.allocate(capacity: 1)

    init() {
        touchesLock.initialize(to: os_unfair_lock())
        MultitouchDeviceManager.sharedCallbackInstance = self
    }

    func start() {
        refreshDevices()
        startHotplugPolling()
    }

    func stop() {
        stopHotplugPolling()
        detachAllDevices()
        os_unfair_lock_lock(touchesLock)
        latestTouches.removeAll()
        os_unfair_lock_unlock(touchesLock)

        DispatchQueue.main.async {
            self.isMagicMouseConnected = false
            self.connectedDeviceCount = 0
        }
    }

    func getLatestTouches() -> [SurfaceTouch] {
        os_unfair_lock_lock(touchesLock)
        defer { os_unfair_lock_unlock(touchesLock) }
        return latestTouches
    }

    private func startHotplugPolling() {
        pollTimer?.invalidate()
        // Check every 2.0 seconds for device connection/disconnection changes
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkForDeviceChanges()
        }
    }

    private func stopHotplugPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func checkForDeviceChanges() {
        guard let listRef = MTDeviceCreateList() else {
            if !activeDevices.isEmpty {
                detachAllDevices()
            }
            return
        }

        let deviceArray = listRef.takeRetainedValue() as NSArray
        let count = CFArrayGetCount(deviceArray)

        var externalCount = 0
        for i in 0..<count {
            let device = unsafeBitCast(CFArrayGetValueAtIndex(deviceArray, i), to: MTDeviceRef.self)
            if !MTDeviceIsBuiltIn(device) {
                externalCount += 1
            }
        }

        if externalCount != activeDevices.count {
            refreshDevices()
        }
    }

    func refreshDevices() {
        detachAllDevices()

        guard let listRef = MTDeviceCreateList() else {
            DispatchQueue.main.async {
                self.isMagicMouseConnected = false
                self.connectedDeviceCount = 0
            }
            return
        }

        let deviceArray = listRef.takeRetainedValue() as NSArray
        let count = CFArrayGetCount(deviceArray)
        var newExternalDevices: [MTDeviceRef] = []

        for i in 0..<count {
            let device = unsafeBitCast(CFArrayGetValueAtIndex(deviceArray, i), to: MTDeviceRef.self)
            let isBuiltIn = MTDeviceIsBuiltIn(device)

            // Only hook into external devices (Magic Mouse)
            if !isBuiltIn {
                newExternalDevices.append(device)
                MTRegisterContactFrameCallback(device, globalTouchCallback)
                MTDeviceStart(device, 0)
            }
        }

        self.activeDevices = newExternalDevices
        let hasMouse = !newExternalDevices.isEmpty

        DispatchQueue.main.async {
            self.isMagicMouseConnected = hasMouse
            self.connectedDeviceCount = newExternalDevices.count
        }
    }

    private func detachAllDevices() {
        for device in activeDevices {
            MTUnregisterContactFrameCallback(device, globalTouchCallback)
            MTDeviceStop(device)
        }
        activeDevices.removeAll()
    }

    fileprivate func handleRawTouches(_ rawTouches: UnsafeMutablePointer<MTTouch>?, count: Int, timestamp: Double) {
        var parsedTouches: [SurfaceTouch] = []

        if let touches = rawTouches, count > 0 {
            parsedTouches.reserveCapacity(count)
            for i in 0..<count {
                let t = touches[i]
                parsedTouches.append(SurfaceTouch(
                    id: t.identifier,
                    x: Double(t.normalized.position.x),
                    y: Double(t.normalized.position.y),
                    state: t.state,
                    timestamp: timestamp
                ))
            }
        }

        // Store latest touches thread-safely
        os_unfair_lock_lock(touchesLock)
        self.latestTouches = parsedTouches
        os_unfair_lock_unlock(touchesLock)

        // Low-latency delivery directly to engine
        delegate?.multitouchDeviceDidUpdateTouches(parsedTouches, timestamp: timestamp)
    }

    deinit {
        stop()
        touchesLock.deallocate()
    }
}

// Global C callback function for MultitouchSupport
private func globalTouchCallback(device: Int32, touches: UnsafeMutablePointer<MTTouch>?, numTouches: Int32, timestamp: Double, frame: Int32) -> Int32 {
    if let manager = MultitouchDeviceManager.sharedCallbackInstance {
        manager.handleRawTouches(touches, count: Int(numTouches), timestamp: timestamp)
    }
    return 0
}
