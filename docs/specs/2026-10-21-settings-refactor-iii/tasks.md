# Settings Refactor III Implementation Plan

**Goal:** Apply the approved settings navigation, grouping, app-list editing and automatic appearance behavior.

**Architecture:** Reuse existing service-backed bindings and feature runtime gates. Extract shared sheet and presentation components within Settings; automatic appearance depends on OS capability and accessibility settings.

**Tech Stack:** SwiftUI, AppKit, Swift standalone contract tests.
---

### Task 1: Automatic appearance
Files: Core/LiquidGlassSupport.swift, App/AppAppearanceController.swift, UI/Settings/GeneralSettings.swift, UI/SharedUI.swift, UI/Theme.swift, UI/Notch/NotchComponents.swift and appearance callers/defaults/tests.
1. Inspect existing preferences tests and supported-OS behavior.
2. Replace stored appearance gates with capability checks; remove obsolete preference keys and controls.
3. Update affected preference contracts; run preferences/settings suites.

### Task 2: Shared App List Sheet and page grouping
Files: UI/Settings/AppBundleList.swift, DockSettings.swift, DockQuitOnCloseSettings.swift, WindowLayoutSettings.swift, exclusion wrappers and window preview presentation.
1. Add reusable fixed-size sheet row supporting protected entries and existing app picker semantics.
2. Apply it to Dock Preview, snapping, maximization and auto quit.
3. Merge Dock thumbnail settings, flatten experimental rows and move Windows & Spaces behaviors.
4. Verify services, anchors and navigation ownership with affected existing suites.

### Task 3: Dynamic Island detail navigation
Files: UI/Settings/NotchSettings.swift, NotchSettingsTabRow.swift and extracted detail/navigation components.
1. Replace columns with a list and detail destination state.
2. Add feature install/uninstall toggles and preserve inclusion controls and previews.
3. Add Companion row and retain module/companion deep links.
4. Verify feature gates and navigation tests.

### Task 4: Copy and standard switches
Files: localized setting labels, capture/audio setting views and search/catalog ownership.
1. Rename Launcher Grid, Dock Tiles and requested window/audio labels.
2. Remove capture status badges; standardize only requested switches.
3. Run localization and settings regressions.

### Task 5: Final verification and review
1. Build with ./build.sh --dev and run ./build/LatticeDeveloper --selftest.
2. Request independent whole-diff review and address substantiated issues.
3. Refresh affected checks and record evidence here.
4. Preserve branch settings-refactor-III for the user, as requested.

## Status
Implementation pending. Baseline source commit: 689edf39. Clean checkout.
