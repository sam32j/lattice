# Design Specification: Lattice Hub & Surface Simplification

**Date:** 2026-10-27  
**Status:** Approved  
**Author:** Samuel Ji & Antigravity  
**Branch:** `refactor/simplify-application-interface`

---

## 1. Executive Summary

Lattice currently suffers from fragmented surfaces and duplicate feature presentations:
1. **Utilities vs. Launcher Grid**: The Menu Bar's Utilities section and the floating Launcher Grid HUD share 12 tools, but have separate enums, separate storage keys, and slight discrepancies (`keepAwake` and `micMute` in Launcher Grid; `appUpdates` and `portManager` in Utilities).
2. **Circular Dependencies**: The Utilities section includes a tile that summons the floating Launcher Grid, and another tile that summons the Command Bar dispatcher.
3. **Zombie Code**: Screen OCR and Color Picker entrypoints were retired from standalone UI in commit `958182c7`, but retained as runtime-filtered zombie cases in views and enums.
4. **Naming Fragmentation**: The feature is simultaneously named "Quick Launcher", "Launcher Grid", "Tools", and erroneously translated as "App Grid" (`Grille d’apps` / `App-Raster`) in non-English locales.
5. **Spatial Continuity Whiplash**: Clicking an entry in the Menu Bar popover closes the popover in the top-right and teleports a floating HUD to the center of the display.

This specification unifies these surfaces into **Lattice Hub**, adopting **Option 1 (The Ergonomic Split)** to ensure zero duplication, clean architecture, and seamless spatial continuity.

---

## 2. Architectural Boundaries (Option 1: The Ergonomic Split)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        LATTICE HUB (Full Suite)                        │
│  [Tier 1] Quick Controls (1-Touch): Mic, Awake, Dark Mode, Files, Trash│
│  [Tier 2] Workspace Utilities Grid: Screenshot, Cleaner, Uninstaller...│
│                                                                        │
│  • Hotkey Trigger (⌃⌘V)     ──► Centered Floating HUD                 │
│  • Dynamic Island Tab       ──► Docked Notch Dropdown                  │
│  • Menu Bar Bridge Click    ──► Anchored Dropdown (under Menu Bar)     │
└────────────────────────────────────────────────────────────────────────┘
                                    ▲
                                    │ (Spatial Bridge: No Whiplash)
┌───────────────────────────────────┴────────────────────────────────────┐
│                             MENU BAR PANEL                             │
│ • Telemetry & Sensors (CPU, RAM, Disks, Network, Battery, Fans, Mixer) │
│ • Quick Controls Strip (1-touch pills: Mic, Awake, Dark Mode, Trash)   │
│ • Lattice Hub Button [⌃⌘V ↗] (Smooth anchored drop-down to full Hub)   │
└────────────────────────────────────────────────────────────────────────┘
```

### 2.1 The Ergonomic Split
* **Quick Controls (Instant 1-Touch Switches)**:
  * Fast binary state switches (`micMute`, `keepAwake`, `darkMode`, `hiddenFiles`, `desktopIcons`, `emptyTrash`, `lockScreen`).
  * Lives in the **Menu Bar Panel** (as a compact strip), in **Lattice Hub** (as the top tier), and in the **Dynamic Island**.
* **Workspace Utilities (Page/Modal Workspaces)**:
  * Workflow tools (`screenshot`, `screenRecorder`, `cameraPreview`, `cleaner`, `uninstaller`, `cleaningMode`, `clipboardHistory`, `windowLayout`, `mediaTools`, `urlCleaner`, `scratchpad`, `homebrew`, `appUpdates`, `portManager`).
  * Removed from the Menu Bar scrolling list to eliminate bloat and duplication.
  * Lives exclusively in **Lattice Hub** (Floating HUD and Dynamic Island).

### 2.2 Spatial Continuity Bridge
* When clicking the **Lattice Hub** button in the Menu Bar panel:
  * The popover closes, and `LatticeHubService` opens the HUD **anchored directly below the menu bar status item**, avoiding the jarring jump to screen center.
* When summoned via global hotkey (`⌃⌘V`):
  * Opens centered on the active display (or expands the Dynamic Island if routed there).

---

## 3. Safety Boundaries: Preserving OCR & Color Services

> [!IMPORTANT]
> The underlying OCR, QR detection, and Color Sampler services are critical components of the Screenshot tool and must **NOT** be removed.
>
> **Untouched Services:**
> - `Sources/Lattice/Services/QuickTools/ScreenTextService.swift`
> - `Sources/Lattice/Services/Vision/VisionTextRecognition.swift`
> - `Sources/Lattice/Services/QuickTools/ColorSamplerService.swift`
> - Screenshot context menus, preview inspectors, and magnifier controls.
>
> **Purged Dead Code:**
> - Dead cases `.screenOCR` and `.colorPicker` in `UtilityPanelItem` and `QuickLauncherItem`.
> - Dead runtime filters (`guard self != .screenOCR && self != .colorPicker`).
> - Dead `EmptyView()` rendering branches.
> - Unused `@AppStorage` keys (`DefaultsKey.panelUtilityScreenOCR`, `DefaultsKey.panelUtilityColorPicker`).

---

## 4. Canonical Naming & File Migration

| Current Path / Symbol | New Canonical Path / Symbol |
| :--- | :--- |
| `Sources/Lattice/UI/QuickLauncher/` | `Sources/Lattice/UI/LatticeHub/` |
| `Sources/Lattice/UI/QuickLauncher/QuickLauncherView.swift` | `Sources/Lattice/UI/LatticeHub/LatticeHubView.swift` |
| `Sources/Lattice/Services/QuickTools/QuickLauncherService.swift` | `Sources/Lattice/Services/LatticeHub/LatticeHubService.swift` |
| `struct QuickLauncherView` | `struct LatticeHubView` |
| `final class QuickLauncherService` | `final class LatticeHubService` |
| `enum QuickLauncherItem` | `enum LatticeHubItem` |
| `IslandDestination.launcherGrid` | `IslandDestination.latticeHub` |
| `SettingsPage.launcherGrid` | `SettingsPage.latticeHub` |
| `AppFeature.quickLauncher` | Feature name displayed as `"Lattice Hub"` |
| `Tests/QuickLauncherActionTests.swift` | `Tests/LatticeHubActionTests.swift` |

---

## 5. Verification Plan

1. **AST Code Generation**: Update `Tests/generate_sources.py` and `Tests/mutation_checks.py` for new file paths and types.
2. **Suite Tests**: Run `./build.sh --test-suite=launcher`, `./build.sh --test-suite=settings`, `./build.sh --test-suite=utilities`, `./build.sh --test-suite=features`.
3. **Full Regression**: Run `./build.sh --test` to ensure 100% pass across all 105,000+ test checks.
