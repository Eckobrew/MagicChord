# MagicChord

A native macOS menu bar application designed for the **Apple Magic Mouse** to emulate **simultaneous left and right mouse buttons down** ("Both Down" / mouse chording) and **seamless cross-button finger transitions**.

---

## The Problem with Apple Magic Mouse

The Apple Magic Mouse features a single mechanical switch beneath its shell and a multi-touch capacitive top surface. Because of this hardware design:
1. **No Simultaneous Mechanical Clicks**: You cannot physically press left and right buttons down at the same time. Clicking with two fingers resting on the mouse defaults to a standard left click in macOS.
2. **No Secondary Click While Holding**: When holding down a Right Click (e.g. steering the camera in World of Warcraft or other games), you cannot physically click the left button because the single mechanical switch is already depressed.
3. **No Finger Force Hand-Off**: If you start clicking on the left side, bring your right finger down to chord both buttons, and then lift your left finger to steer with only right click:
   - macOS continues holding **Left Click** indefinitely because the mechanical switch was initially pressed on the left.
   - macOS never generates `leftMouseUp` or `rightMouseDown` when you transfer your finger contact.

---

## How MagicChord Solves It

MagicChord maps the physical switch plus the capacitive touch surface into an independent dual-button state machine:

### 1. "Right Click" into "Both Buttons Down"
* **Steer**: Physically click and hold **Right Click** (index finger lifted).
* **Chord Both Down**: While holding Right Click down, place your index finger onto the **left side** of the touch surface.
* **Result**: MagicChord immediately synthesizes `leftMouseDown`. From the perspective of macOS and games, **both mouse buttons are held down simultaneously**.

### 2. Cross-Finger Hand-Off (Lifting the Initial Button)
* **Left → Both → Right**:
  1. Start with Left Click (physical switch down).
  2. Put your right finger down (`rightMouseDown` synthesized → **Both Down**).
  3. **Lift your left finger**: MagicChord immediately synthesizes `leftMouseUp`! Left button releases, and **Right button remains held down**.
  4. Moving the mouse converts hardware left drag into `rightMouseDragged` seamlessly.
  5. Releasing the mouse button safely sends `rightMouseUp`.
* **Right → Both → Left**:
  1. Start with Right Click.
  2. Put your left finger down (`leftMouseDown` synthesized → **Both Down**).
  3. **Lift your right finger**: MagicChord synthesizes `rightMouseUp`! Right button releases, and **Left button remains held down**.
  4. Moving the mouse converts hardware right drag into `leftMouseDragged`.
  5. Releasing the mouse button safely sends `leftMouseUp`.

### 3. Pressing "Both Down" Simultaneously
* Rest both index and middle fingers on the left and right halves of the mouse surface and click down.
* MagicChord detects both contacts at the moment of click and instantly emits **both** `leftMouseDown` and `rightMouseDown`.
* Lifting either finger transitions cleanly into single-button hold; releasing the mouse releases all.

---

## Features

- **Live Touch Visualizer & HUD**: Real-time visual display showing your Magic Mouse touch surface, active finger positions, left/right zones, and live button state (Physical vs Emulated).
- **Full Drag Conversion**: Dynamically converts drag events when transitioning between left and right holds without unclicking the mechanical switch.
- **Zero Input Lag**: Direct C callback integration with `MultitouchSupport` and non-blocking event taps.
- **Palm Rejection**: Discards touches at the bottom base of the mouse to prevent palm contact from triggering accidental chords.
- **Start at Login**: Seamless integration with macOS System Settings login items to launch automatically on bootup.
- **Menu Bar Resident**: Lightweight, minimal resource usage (~19MB, 0.1% CPU), runs silently in your menu bar.

---

## Building and Running

### Build
Run the build script from the repository root:
```bash
./build.sh
```

### Run
Launch directly:
```bash
open build/MagicChord.app
```

Or install to Applications:
```bash
cp -R build/MagicChord.app /Applications/
```
