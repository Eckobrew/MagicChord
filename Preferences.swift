//
//  Preferences.swift
//  MagicChord
//

import Foundation
import Combine

final class Preferences: ObservableObject {
    static let shared = Preferences()

    private enum Keys {
        static let isEnabled = "magicchord_isEnabled"
        static let enableSimultaneousPress = "magicchord_enableSimultaneousPress"
        static let enableRightIntoBothDown = "magicchord_enableRightIntoBothDown"
        static let enableLeftIntoBothDown = "magicchord_enableLeftIntoBothDown"
        static let leftZoneThreshold = "magicchord_leftZoneThreshold"
        static let rightZoneThreshold = "magicchord_rightZoneThreshold"
        static let palmRejectionY = "magicchord_palmRejectionY"
        static let releaseWhenFingerLifts = "magicchord_releaseWhenFingerLifts"
        static let synthesizeBothDragEvents = "magicchord_synthesizeBothDragEvents"
    }

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Keys.isEnabled) }
    }

    /// When true, physically clicking down with both fingers resting on the surface produces both mouse buttons down.
    @Published var enableSimultaneousPress: Bool {
        didSet { UserDefaults.standard.set(enableSimultaneousPress, forKey: Keys.enableSimultaneousPress) }
    }

    /// When true, holding Right Click down and touching the left side of the mouse surface adds Left Mouse Down (Both Down).
    @Published var enableRightIntoBothDown: Bool {
        didSet { UserDefaults.standard.set(enableRightIntoBothDown, forKey: Keys.enableRightIntoBothDown) }
    }

    /// When true, holding Left Click down and touching the right side of the mouse surface adds Right Mouse Down (Both Down).
    @Published var enableLeftIntoBothDown: Bool {
        didSet { UserDefaults.standard.set(enableLeftIntoBothDown, forKey: Keys.enableLeftIntoBothDown) }
    }

    /// Normalized X coordinate (< this is left zone, e.g. 0.46)
    @Published var leftZoneThreshold: Double {
        didSet { UserDefaults.standard.set(leftZoneThreshold, forKey: Keys.leftZoneThreshold) }
    }

    /// Normalized X coordinate (> this is right zone, e.g. 0.54)
    @Published var rightZoneThreshold: Double {
        didSet { UserDefaults.standard.set(rightZoneThreshold, forKey: Keys.rightZoneThreshold) }
    }

    /// Normalized Y coordinate (touches below this are rejected as palm resting near bottom)
    @Published var palmRejectionY: Double {
        didSet { UserDefaults.standard.set(palmRejectionY, forKey: Keys.palmRejectionY) }
    }

    /// If true, lifting the secondary finger while physical click is held releases the emulated button.
    @Published var releaseWhenFingerLifts: Bool {
        didSet { UserDefaults.standard.set(releaseWhenFingerLifts, forKey: Keys.releaseWhenFingerLifts) }
    }

    /// If true, cursor movement while both buttons are down ensures both drag event types are delivered.
    @Published var synthesizeBothDragEvents: Bool {
        didSet { UserDefaults.standard.set(synthesizeBothDragEvents, forKey: Keys.synthesizeBothDragEvents) }
    }

    private init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            Keys.isEnabled: true,
            Keys.enableSimultaneousPress: true,
            Keys.enableRightIntoBothDown: true,
            Keys.enableLeftIntoBothDown: true,
            Keys.leftZoneThreshold: 0.46,
            Keys.rightZoneThreshold: 0.54,
            Keys.palmRejectionY: 0.20,
            Keys.releaseWhenFingerLifts: true,
            Keys.synthesizeBothDragEvents: true
        ])

        self.isEnabled = defaults.bool(forKey: Keys.isEnabled)
        self.enableSimultaneousPress = defaults.bool(forKey: Keys.enableSimultaneousPress)
        self.enableRightIntoBothDown = defaults.bool(forKey: Keys.enableRightIntoBothDown)
        self.enableLeftIntoBothDown = defaults.bool(forKey: Keys.enableLeftIntoBothDown)
        self.leftZoneThreshold = defaults.double(forKey: Keys.leftZoneThreshold)
        self.rightZoneThreshold = defaults.double(forKey: Keys.rightZoneThreshold)
        self.palmRejectionY = defaults.double(forKey: Keys.palmRejectionY)
        self.releaseWhenFingerLifts = defaults.bool(forKey: Keys.releaseWhenFingerLifts)
        self.synthesizeBothDragEvents = defaults.bool(forKey: Keys.synthesizeBothDragEvents)
    }

    func resetToDefaults() {
        isEnabled = true
        enableSimultaneousPress = true
        enableRightIntoBothDown = true
        enableLeftIntoBothDown = true
        leftZoneThreshold = 0.46
        rightZoneThreshold = 0.54
        palmRejectionY = 0.20
        releaseWhenFingerLifts = true
        synthesizeBothDragEvents = true
    }
}
