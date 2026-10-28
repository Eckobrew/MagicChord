//
//  VisualizerView.swift
//  MagicChord
//

import SwiftUI
import AppKit

struct VisualizerView: View {
    @ObservedObject var deviceManager: MultitouchDeviceManager
    @ObservedObject var preferences = Preferences.shared
    @State private var snapshot = ChordEngineSnapshot()
    @State private var touches: [SurfaceTouch] = []
    @State private var isAccessibilityGranted: Bool = AXIsProcessTrusted()

    // 30 FPS update cadence for visualizer rendering
    private let refreshTimer = Timer.publish(every: 0.033, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            // Header / Connection Status
            headerView

            // Main Content: Mouse Visualizer & Button Status
            HStack(alignment: .top, spacing: 24) {
                // Left: Mouse Surface Canvas
                mouseSurfaceCard

                // Right: Real-time Status & Quick Controls
                VStack(spacing: 16) {
                    statusCard
                    settingsCard
                }
                .frame(width: 320)
            }

            // Footer
            footerView
        }
        .padding(20)
        .frame(width: 660, height: 620)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            checkAccessibility()
            pullState()
        }
        .onReceive(refreshTimer) { _ in
            pullState()
        }
    }

    private func pullState() {
        self.snapshot = MagicChordEngine.shared.getSnapshot()
        self.touches = deviceManager.getLatestTouches()
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Image(systemName: "magicmouse")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("MagicChord")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Apple Magic Mouse Simultaneous Button Emulation")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Device Connection Pill
            HStack(spacing: 6) {
                Circle()
                    .fill(deviceManager.isMagicMouseConnected ? Color.green : Color.orange)
                    .frame(width: 9, height: 9)
                Text(deviceManager.isMagicMouseConnected ? "Magic Mouse Connected" : "Waiting for Mouse...")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }

    // MARK: - Mouse Canvas Card
    private var mouseSurfaceCard: some View {
        VStack(spacing: 10) {
            Text("Touch Surface & Zones")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            ZStack {
                // Mouse Outer Body
                RoundedRectangle(cornerRadius: 48, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(NSColor.controlBackgroundColor), Color(NSColor.windowBackgroundColor)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 48, style: .continuous)
                            .stroke(Color.secondary.opacity(0.35), lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)

                // Mouse Zones Division
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height

                    // Left Zone Highlight
                    Path { p in
                        p.addRect(CGRect(x: 0, y: 0, width: w * CGFloat(preferences.leftZoneThreshold), height: h * CGFloat(1.0 - preferences.palmRejectionY)))
                    }
                    .fill(Color.blue.opacity(snapshot.hasLeftTouch ? 0.22 : 0.08))

                    // Right Zone Highlight
                    Path { p in
                        let startX = w * CGFloat(preferences.rightZoneThreshold)
                        p.addRect(CGRect(x: startX, y: 0, width: w - startX, height: h * CGFloat(1.0 - preferences.palmRejectionY)))
                    }
                    .fill(Color.orange.opacity(snapshot.hasRightTouch ? 0.22 : 0.08))

                    // Deadzone Vertical Strip
                    Path { p in
                        let startX = w * CGFloat(preferences.leftZoneThreshold)
                        let endX = w * CGFloat(preferences.rightZoneThreshold)
                        p.addRect(CGRect(x: startX, y: 0, width: endX - startX, height: h * CGFloat(1.0 - preferences.palmRejectionY)))
                    }
                    .fill(Color.gray.opacity(0.06))

                    // Palm Rejection Area (Bottom)
                    Path { p in
                        let topY = h * CGFloat(1.0 - preferences.palmRejectionY)
                        p.addRect(CGRect(x: 0, y: topY, width: w, height: h - topY))
                    }
                    .fill(Color.red.opacity(0.05))

                    // Center Guide Line
                    Path { p in
                        p.move(to: CGPoint(x: w / 2, y: 20))
                        p.addLine(to: CGPoint(x: w / 2, y: h * CGFloat(1.0 - preferences.palmRejectionY)))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundColor(Color.secondary.opacity(0.4))

                    // Zone Labels
                    Text("LEFT ZONE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.blue.opacity(0.7))
                        .position(x: w * CGFloat(preferences.leftZoneThreshold) / 2, y: 35)

                    Text("RIGHT ZONE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.orange.opacity(0.7))
                        .position(x: w * CGFloat(preferences.rightZoneThreshold) + (w * CGFloat(1.0 - preferences.rightZoneThreshold) / 2), y: 35)

                    Text("PALM REJECTION")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color.secondary.opacity(0.5))
                        .position(x: w / 2, y: h - 20)

                    // Real-Time Active Touches
                    ForEach(touches) { touch in
                        if touch.isTouching {
                            // Convert normalized coordinates to canvas (inverted Y since Y=1.0 is tip)
                            let posX = w * CGFloat(touch.x)
                            let posY = h * CGFloat(1.0 - touch.y)

                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.35))
                                    .frame(width: 38, height: 38)
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 14, height: 14)
                                    .shadow(radius: 3)
                            }
                            .position(x: posX, y: posY)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 48, style: .continuous))
            }
            .frame(width: 240, height: 360)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(16)
    }

    // MARK: - Status Card
    private var statusCard: some View {
        VStack(spacing: 12) {
            // Both Buttons Down Banner
            if snapshot.isBothButtonsActive {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.yellow)
                    Text("BOTH BUTTONS DOWN ACTIVE")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing))
                )
                .shadow(color: .indigo.opacity(0.5), radius: 6, x: 0, y: 2)
            } else {
                HStack {
                    Image(systemName: "mouse")
                        .foregroundColor(.secondary)
                    Text("Standard Button State")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
            }

            // Left vs Right Indicators
            HStack(spacing: 14) {
                buttonStateView(
                    title: "Left Button",
                    isActive: snapshot.isLeftButtonActive,
                    isEmulated: snapshot.isLeftEmulated,
                    hasTouch: snapshot.hasLeftTouch,
                    tintColor: .blue
                )

                buttonStateView(
                    title: "Right Button",
                    isActive: snapshot.isRightButtonActive,
                    isEmulated: snapshot.isRightEmulated,
                    hasTouch: snapshot.hasRightTouch,
                    tintColor: .orange
                )
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(14)
    }

    private func buttonStateView(title: String, isActive: Bool, isEmulated: Bool, hasTouch: Bool, tintColor: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)

            Text(isActive ? "DOWN" : "UP")
                .font(.system(size: 16, weight: .black))
                .foregroundColor(isActive ? tintColor : .secondary)

            // Status tag
            if isActive {
                Text(isEmulated ? "EMULATED" : "PHYSICAL")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(isEmulated ? .purple : .green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((isEmulated ? Color.purple : Color.green).opacity(0.15))
                    .cornerRadius(4)
            } else if hasTouch {
                Text("TOUCHED")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(4)
            } else {
                Text("RELEASED")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isActive ? tintColor.opacity(0.8) : Color.clear, lineWidth: 1.5)
        )
    }

    // MARK: - Settings Card
    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Emulation Modes")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)

            Toggle("Right Click into Both Down", isOn: $preferences.enableRightIntoBothDown)
                .font(.system(size: 12))
                .help("Touch left side of mouse while holding right click down to add Left Click.")

            Toggle("Press Both Down Simultaneously", isOn: $preferences.enableSimultaneousPress)
                .font(.system(size: 12))
                .help("Physical click with both fingers resting activates both mouse buttons.")

            Toggle("Left Click into Both Down", isOn: $preferences.enableLeftIntoBothDown)
                .font(.system(size: 12))
                .help("Touch right side of mouse while holding left click down to add Right Click.")

            Toggle("Release when finger lifts", isOn: $preferences.releaseWhenFingerLifts)
                .font(.system(size: 12))

            Toggle("Start at Login", isOn: $preferences.startAtLogin)
                .font(.system(size: 12))
                .help("Automatically launch MagicChord when logging into macOS.")

            Divider().padding(.vertical, 2)

            Text("Sensitivity Thresholds")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)

            HStack {
                Text("Left Boundary: \(Int(preferences.leftZoneThreshold * 100))%")
                    .font(.system(size: 11))
                Spacer()
                Slider(value: $preferences.leftZoneThreshold, in: 0.35...0.49, step: 0.01)
                    .frame(width: 140)
            }

            HStack {
                Text("Right Boundary: \(Int(preferences.rightZoneThreshold * 100))%")
                    .font(.system(size: 11))
                Spacer()
                Slider(value: $preferences.rightZoneThreshold, in: 0.51...0.65, step: 0.01)
                    .frame(width: 140)
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(14)
    }

    // MARK: - Footer
    private var footerView: some View {
        HStack {
            if !isAccessibilityGranted {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Accessibility permission required.")
                        .font(.caption)
                    Button("Grant Access") {
                        openAccessibilitySettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Accessibility Authorized")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button("Reset Defaults") {
                preferences.resetToDefaults()
            }
            .controlSize(.small)

            Toggle("Enable App", isOn: $preferences.isEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 4)
    }

    private func checkAccessibility() {
        isAccessibilityGranted = AXIsProcessTrusted()
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
