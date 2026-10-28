//
//  MagicChordEngine.swift
//  MagicChord
//

import Foundation
import CoreGraphics
import AppKit

final class MagicChordEngine: MultitouchDeviceManagerDelegate {
    static let shared = MagicChordEngine()

    // MARK: - Logical Button State (Thread-Safe via stateLock)
    private var isLeftDownInOS: Bool = false
    private var isRightDownInOS: Bool = false
    private var isPhysicalSwitchDown: Bool = false
    private var initialPhysicalButton: CGMouseButton? = nil

    private var hasLeftTouch: Bool = false
    private var hasRightTouch: Bool = false
    private var lastKnownLocation: CGPoint = .zero

    // Tag to identify our synthetic events and avoid infinite event tap recursion
    private let syntheticEventTag: Int64 = 0x4D474943 // 'MGIC'

    // Dedicated event source to ensure zero suppression of hardware inputs
    private let chordEventSource: CGEventSource? = {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return nil }
        source.localEventsSuppressionInterval = 0
        let permitAll: CGEventFilterMask = [
            .permitLocalMouseEvents,
            .permitLocalKeyboardEvents,
            .permitSystemDefinedEvents
        ]
        source.setLocalEventsFilterDuringSuppressionState(permitAll, state: .eventSuppressionStateSuppressionInterval)
        source.setLocalEventsFilterDuringSuppressionState(permitAll, state: .eventSuppressionStateRemoteMouseDrag)
        return source
    }()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let preferences = Preferences.shared
    private let stateLock = os_unfair_lock_t.allocate(capacity: 1)

    fileprivate static weak var sharedCallbackInstance: MagicChordEngine?

    init() {
        stateLock.initialize(to: os_unfair_lock())
        MagicChordEngine.sharedCallbackInstance = self
    }

    deinit {
        stop()
        stateLock.deallocate()
    }

    // MARK: - Lifecycle
    func start() {
        startEventTap()
    }

    func stop() {
        stopEventTap()
        releaseAllEmulatedButtons()
    }

    // MARK: - Snapshot for UI (Zero-lock-contention reading)
    func getSnapshot() -> ChordEngineSnapshot {
        os_unfair_lock_lock(stateLock)
        let leftDown = isLeftDownInOS
        let rightDown = isRightDownInOS
        let isInitialLeft = (initialPhysicalButton == .left)
        let isInitialRight = (initialPhysicalButton == .right)

        let leftEmu = leftDown && !isInitialLeft
        let rightEmu = rightDown && !isInitialRight

        let snapshot = ChordEngineSnapshot(
            isLeftButtonActive: leftDown,
            isRightButtonActive: rightDown,
            isBothButtonsActive: leftDown && rightDown,
            isLeftEmulated: leftEmu,
            isRightEmulated: rightEmu,
            hasLeftTouch: hasLeftTouch,
            hasRightTouch: hasRightTouch
        )
        os_unfair_lock_unlock(stateLock)
        return snapshot
    }

    // MARK: - Event Tap Setup
    private func startEventTap() {
        guard eventTap == nil else { return }

        let mask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue) |
                                (1 << CGEventType.leftMouseUp.rawValue) |
                                (1 << CGEventType.rightMouseDown.rawValue) |
                                (1 << CGEventType.rightMouseUp.rawValue) |
                                (1 << CGEventType.leftMouseDragged.rawValue) |
                                (1 << CGEventType.rightMouseDragged.rawValue) |
                                (1 << CGEventType.mouseMoved.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: chordEventTapCallback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            print("[MagicChord] Warning: Could not create CGEventTap. Please verify Accessibility permissions.")
            return
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[MagicChord] CGEventTap active.")
    }

    private func stopEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
        runLoopSource = nil
        eventTap = nil
    }

    // MARK: - MultitouchDelegate Callbacks
    func multitouchDeviceDidUpdateTouches(_ touches: [SurfaceTouch], timestamp: Double) {
        guard preferences.isEnabled else { return }

        let leftThresh = preferences.leftZoneThreshold
        let rightThresh = preferences.rightZoneThreshold
        let palmThresh = preferences.palmRejectionY

        var currentLeftTouch = false
        var currentRightTouch = false

        for t in touches where t.isTouching {
            switch t.zone(leftThreshold: leftThresh, rightThreshold: rightThresh, palmThreshold: palmThresh) {
            case .left:
                currentLeftTouch = true
            case .right:
                currentRightTouch = true
            case .deadzone, .palmRejection:
                break
            }
        }

        var shouldPostLeftDown = false
        var shouldPostLeftUp = false
        var shouldPostRightDown = false
        var shouldPostRightUp = false
        var targetLocation: CGPoint = .zero

        os_unfair_lock_lock(stateLock)
        self.hasLeftTouch = currentLeftTouch
        self.hasRightTouch = currentRightTouch
        targetLocation = self.lastKnownLocation

        // --- LEFT FINGER TRANSITIONS ---
        if currentLeftTouch && !self.isLeftDownInOS {
            // Can only chord left if physical switch is currently down
            if self.isPhysicalSwitchDown {
                if (preferences.enableRightIntoBothDown && self.isRightDownInOS) || preferences.enableLeftIntoBothDown {
                    self.isLeftDownInOS = true
                    shouldPostLeftDown = true
                }
            }
        } else if !currentLeftTouch && self.isLeftDownInOS && preferences.releaseWhenFingerLifts {
            // Left finger lifted: release left button immediately
            self.isLeftDownInOS = false
            shouldPostLeftUp = true
        }

        // --- RIGHT FINGER TRANSITIONS ---
        if currentRightTouch && !self.isRightDownInOS {
            // Can only chord right if physical switch is currently down
            if self.isPhysicalSwitchDown {
                if (preferences.enableLeftIntoBothDown && self.isLeftDownInOS) || preferences.enableRightIntoBothDown {
                    self.isRightDownInOS = true
                    shouldPostRightDown = true
                }
            }
        } else if !currentRightTouch && self.isRightDownInOS && preferences.releaseWhenFingerLifts {
            // Right finger lifted: release right button immediately
            self.isRightDownInOS = false
            shouldPostRightUp = true
        }
        os_unfair_lock_unlock(stateLock)

        // Post synthesized events OUTSIDE lock
        if shouldPostLeftDown {
            postMouseEvent(type: .leftMouseDown, button: .left, location: targetLocation)
        }
        if shouldPostLeftUp {
            postMouseEvent(type: .leftMouseUp, button: .left, location: targetLocation)
        }
        if shouldPostRightDown {
            postMouseEvent(type: .rightMouseDown, button: .right, location: targetLocation)
        }
        if shouldPostRightUp {
            postMouseEvent(type: .rightMouseUp, button: .right, location: targetLocation)
        }
    }

    // MARK: - CGEventTap Handler
    fileprivate func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return nil
        }

        // Ignore our own synthetic events to prevent recursion
        if event.getIntegerValueField(.eventSourceUserData) == syntheticEventTag {
            return Unmanaged.passUnretained(event)
        }

        // Cache cursor location
        let location = event.location
        os_unfair_lock_lock(stateLock)
        self.lastKnownLocation = location
        os_unfair_lock_unlock(stateLock)

        guard preferences.isEnabled else {
            return Unmanaged.passUnretained(event)
        }

        var shouldPostRightDown = false
        var shouldPostRightUp = false
        var shouldPostLeftDown = false
        var shouldPostLeftUp = false
        var shouldSwallowEvent = false

        os_unfair_lock_lock(stateLock)
        switch type {
        case .leftMouseDown:
            isPhysicalSwitchDown = true
            initialPhysicalButton = .left
            isLeftDownInOS = true

            // If right finger is also touching at the moment of click, trigger both down simultaneously!
            if preferences.enableSimultaneousPress && hasRightTouch && !isRightDownInOS {
                isRightDownInOS = true
                shouldPostRightDown = true
            }

        case .leftMouseUp:
            isPhysicalSwitchDown = false
            initialPhysicalButton = nil

            let wasLeftDown = isLeftDownInOS
            let wasRightDown = isRightDownInOS

            isLeftDownInOS = false
            isRightDownInOS = false

            // If right was also down, release it as the physical switch unclicked
            if wasRightDown {
                shouldPostRightUp = true
            }

            // If left was already released earlier by finger lift:
            if !wasLeftDown {
                if wasRightDown {
                    // Hand-off transition: left was lifted earlier while holding right.
                    // Now right is released by physical switch up.
                    // In-place mutate this physical leftMouseUp into rightMouseUp!
                    event.type = .rightMouseUp
                    event.setIntegerValueField(.mouseEventButtonNumber, value: 1)
                    shouldPostRightUp = false // already handled in-place
                    shouldSwallowEvent = false
                } else {
                    shouldSwallowEvent = true
                }
            }

        case .rightMouseDown:
            isPhysicalSwitchDown = true
            initialPhysicalButton = .right
            isRightDownInOS = true

            // If left finger is also touching at the moment of click, trigger both down simultaneously!
            if preferences.enableSimultaneousPress && hasLeftTouch && !isLeftDownInOS {
                isLeftDownInOS = true
                shouldPostLeftDown = true
            }

        case .rightMouseUp:
            isPhysicalSwitchDown = false
            initialPhysicalButton = nil

            let wasRightDown = isRightDownInOS
            let wasLeftDown = isLeftDownInOS

            isRightDownInOS = false
            isLeftDownInOS = false

            // If left was also down, release it as the physical switch unclicked
            if wasLeftDown {
                shouldPostLeftUp = true
            }

            // If right was already released earlier by finger lift:
            if !wasRightDown {
                if wasLeftDown {
                    // Hand-off transition: right was lifted earlier while holding left.
                    // Now left is released by physical switch up.
                    // In-place mutate this physical rightMouseUp into leftMouseUp!
                    event.type = .leftMouseUp
                    event.setIntegerValueField(.mouseEventButtonNumber, value: 0)
                    shouldPostLeftUp = false // already handled in-place
                    shouldSwallowEvent = false
                } else {
                    shouldSwallowEvent = true
                }
            }

        case .mouseMoved:
            // Crucial for Moonlight / Relative Mouse Mode:
            // When the physical switch is up but a button is emulated down, macOS hardware emits
            // mouseMoved instead of dragged. We mutate the event in-place so Moonlight receives
            // the exact event type and all raw deltaX/deltaY movement!
            if isLeftDownInOS && isRightDownInOS {
                event.type = .leftMouseDragged
                event.setIntegerValueField(.mouseEventButtonNumber, value: 0)
            } else if isRightDownInOS && !isLeftDownInOS {
                event.type = .rightMouseDragged
                event.setIntegerValueField(.mouseEventButtonNumber, value: 1)
            } else if isLeftDownInOS && !isRightDownInOS {
                event.type = .leftMouseDragged
                event.setIntegerValueField(.mouseEventButtonNumber, value: 0)
            }
            os_unfair_lock_unlock(stateLock)
            return Unmanaged.passUnretained(event)

        case .leftMouseDragged:
            if !isLeftDownInOS && isRightDownInOS {
                // In-place mutate left drag to right drag! Retains all hardware deltaX / deltaY
                event.type = .rightMouseDragged
                event.setIntegerValueField(.mouseEventButtonNumber, value: 1)
            }
            os_unfair_lock_unlock(stateLock)
            return Unmanaged.passUnretained(event)

        case .rightMouseDragged:
            if isLeftDownInOS && !isRightDownInOS {
                // In-place mutate right drag to left drag! Retains all hardware deltaX / deltaY
                event.type = .leftMouseDragged
                event.setIntegerValueField(.mouseEventButtonNumber, value: 0)
            }
            os_unfair_lock_unlock(stateLock)
            return Unmanaged.passUnretained(event)

        default:
            break
        }
        os_unfair_lock_unlock(stateLock)

        // Post any synthetic button clicks outside lock
        if shouldPostRightDown {
            postMouseEvent(type: .rightMouseDown, button: .right, location: location)
        }
        if shouldPostRightUp {
            postMouseEvent(type: .rightMouseUp, button: .right, location: location)
        }
        if shouldPostLeftDown {
            postMouseEvent(type: .leftMouseDown, button: .left, location: location)
        }
        if shouldPostLeftUp {
            postMouseEvent(type: .leftMouseUp, button: .left, location: location)
        }

        if shouldSwallowEvent {
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    // MARK: - Event Synthesis
    private func postMouseEvent(type: CGEventType, button: CGMouseButton, location: CGPoint) {
        let validLocation: CGPoint
        if location.x > 0 || location.y > 0 {
            validLocation = location
        } else {
            validLocation = CGEvent(source: nil)?.location ?? .zero
        }

        guard let event = CGEvent(
            mouseEventSource: chordEventSource,
            mouseType: type,
            mouseCursorPosition: validLocation,
            mouseButton: button
        ) else { return }

        event.setIntegerValueField(.eventSourceUserData, value: syntheticEventTag)
        event.post(tap: .cghidEventTap)
    }

    private func releaseAllEmulatedButtons() {
        var releaseLeft = false
        var releaseRight = false
        var loc: CGPoint = .zero

        os_unfair_lock_lock(stateLock)
        releaseLeft = isLeftDownInOS
        releaseRight = isRightDownInOS
        isLeftDownInOS = false
        isRightDownInOS = false
        isPhysicalSwitchDown = false
        initialPhysicalButton = nil
        loc = lastKnownLocation
        os_unfair_lock_unlock(stateLock)

        if releaseLeft {
            postMouseEvent(type: .leftMouseUp, button: .left, location: loc)
        }
        if releaseRight {
            postMouseEvent(type: .rightMouseUp, button: .right, location: loc)
        }
    }
}

// Global CGEventTap callback
private func chordEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let engine = Unmanaged<MagicChordEngine>.fromOpaque(userInfo).takeUnretainedValue()
    return engine.handleEvent(proxy: proxy, type: type, event: event)
}
