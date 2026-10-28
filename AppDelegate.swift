//
//  AppDelegate.swift
//  MagicChord
//

import Cocoa
import SwiftUI
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let engine = MagicChordEngine.shared
    private let deviceManager = MultitouchDeviceManager()
    private let preferences = Preferences.shared
    private var permissionPollTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Connect device manager to engine
        deviceManager.delegate = engine

        setupMenuBar()
        checkAccessibilityAndStart()
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.stop()
        deviceManager.stop()
    }

    // MARK: - Menu Bar
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: "MagicChord")
        }

        rebuildMenu()

        // Rebuild menu when device status or preferences change
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.rebuildMenu()
        }
    }

    private func rebuildMenu() {
        preferences.refreshStartAtLogin()
        let menu = NSMenu()

        // Status Header
        let statusTitle = preferences.isEnabled ? "MagicChord: Active" : "MagicChord: Paused"
        let statusItemHeader = NSMenuItem(title: statusTitle, action: #selector(toggleEnabled), keyEquivalent: "")
        statusItemHeader.target = self
        statusItemHeader.state = preferences.isEnabled ? .on : .off
        menu.addItem(statusItemHeader)

        // Device Connection Indicator
        let deviceTitle = deviceManager.isMagicMouseConnected ? "Magic Mouse: Connected" : "Magic Mouse: Not Detected"
        let deviceItem = NSMenuItem(title: deviceTitle, action: nil, keyEquivalent: "")
        deviceItem.isEnabled = false
        menu.addItem(deviceItem)

        menu.addItem(NSMenuItem.separator())

        // Quick Toggles
        let rightIntoBoth = NSMenuItem(title: "Right Click → Both Down", action: #selector(toggleRightIntoBoth), keyEquivalent: "")
        rightIntoBoth.target = self
        rightIntoBoth.state = preferences.enableRightIntoBothDown ? .on : .off
        menu.addItem(rightIntoBoth)

        let simultaneous = NSMenuItem(title: "Simultaneous Click Both Down", action: #selector(toggleSimultaneous), keyEquivalent: "")
        simultaneous.target = self
        simultaneous.state = preferences.enableSimultaneousPress ? .on : .off
        menu.addItem(simultaneous)

        let leftIntoBoth = NSMenuItem(title: "Left Click → Both Down", action: #selector(toggleLeftIntoBoth), keyEquivalent: "")
        leftIntoBoth.target = self
        leftIntoBoth.state = preferences.enableLeftIntoBothDown ? .on : .off
        menu.addItem(leftIntoBoth)

        menu.addItem(NSMenuItem.separator())

        // Start at Login
        let startAtLoginItem = NSMenuItem(title: "Start at Login", action: #selector(toggleStartAtLogin), keyEquivalent: "")
        startAtLoginItem.target = self
        startAtLoginItem.state = preferences.startAtLogin ? .on : .off
        menu.addItem(startAtLoginItem)

        menu.addItem(NSMenuItem.separator())

        // Visualizer & Settings
        let visualizerItem = NSMenuItem(title: "Visualizer & Preferences…", action: #selector(openVisualizer), keyEquivalent: ",")
        visualizerItem.target = self
        menu.addItem(visualizerItem)

        if !AXIsProcessTrusted() {
            let permItem = NSMenuItem(title: "Grant Accessibility Access…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
            permItem.target = self
            menu.addItem(permItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit MagicChord", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    // MARK: - Menu Actions
    @objc private func toggleEnabled() {
        preferences.isEnabled.toggle()
        rebuildMenu()
    }

    @objc private func toggleRightIntoBoth() {
        preferences.enableRightIntoBothDown.toggle()
        rebuildMenu()
    }

    @objc private func toggleSimultaneous() {
        preferences.enableSimultaneousPress.toggle()
        rebuildMenu()
    }

    @objc private func toggleLeftIntoBoth() {
        preferences.enableLeftIntoBothDown.toggle()
        rebuildMenu()
    }

    @objc private func toggleStartAtLogin() {
        preferences.startAtLogin.toggle()
        rebuildMenu()
    }

    @objc private func openVisualizer() {
        SettingsWindowController.shared.show(deviceManager: deviceManager)
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Accessibility & Startup
    private func checkAccessibilityAndStart() {
        if AXIsProcessTrusted() {
            startServices()
        } else {
            // Prompt user once for accessibility
            let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)

            // Poll until permission is granted
            permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    self?.permissionPollTimer = nil
                    self?.startServices()
                    self?.rebuildMenu()
                }
            }
        }
    }

    private func startServices() {
        print("[MagicChord] Starting services...")
        deviceManager.start()
        engine.start()
    }
}
