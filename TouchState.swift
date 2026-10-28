//
//  TouchState.swift
//  MagicChord
//

import Foundation
import CoreGraphics

enum MouseZone {
    case left
    case right
    case deadzone
    case palmRejection
}

struct SurfaceTouch: Identifiable, Equatable {
    let id: Int32
    let x: Double        // 0.0 (left) to 1.0 (right)
    let y: Double        // 0.0 (palm/bottom) to 1.0 (top tip)
    let state: Int32     // 3=make, 4=touching, etc.
    let timestamp: Double

    var isTouching: Bool {
        return state == 3 || state == 4
    }

    func zone(leftThreshold: Double, rightThreshold: Double, palmThreshold: Double) -> MouseZone {
        if y < palmThreshold {
            return .palmRejection
        }
        if x <= leftThreshold {
            return .left
        }
        if x >= rightThreshold {
            return .right
        }
        return .deadzone
    }
}

// Snapshot of engine state for thread-safe UI rendering
struct ChordEngineSnapshot: Equatable {
    var isLeftButtonActive: Bool = false
    var isRightButtonActive: Bool = false
    var isBothButtonsActive: Bool = false
    var isLeftEmulated: Bool = false
    var isRightEmulated: Bool = false
    var hasLeftTouch: Bool = false
    var hasRightTouch: Bool = false
}
