# Shortcut Setting System Overhaul Implementation Plan

**Goal:** Give every editable Lattice shortcut the compact screenshot-style recorder interaction while preserving each owner's storage, validation, and takeover behavior.

**Architecture:** Extract the compact presentation and recording lifecycle from the oversized shared recorder file into reusable SwiftUI components. Keep validation and persistence behind owner-specific adapters so global roles, window layouts, radial profiles, command-bar entries, mouse mappings, and screenshot tools retain their domain rules.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit, Carbon.HIToolbox, repository shell test harness

---

### Task 1: Extract the compact recorder foundation

**Files:**
- Modify: `Sources/Vorssaint/UI/ShortcutRecorderButton.swift`
- Create: `Sources/Vorssaint/UI/CompactShortcutRecorder.swift`
- Create: `Sources/Vorssaint/UI/CompactShortcutField.swift`
- Test: `Tests/CompactShortcutValidationTests.swift`
- Test: `Tests/DirectCaptureRequirementsComprehensiveTests.swift`

**Step 1: Write failing structural and lifecycle tests**

Add expectations that the reusable compact field owns fixed dimensions, inline actions, transient error presentation, and shared single-recorder cancellation while the role adapter preserves reset validation.

**Step 2: Run the focused test and verify failure**

Run: `./build.sh --test-suite=screenshots`

Expected: FAIL because the shared compact field and extracted source do not exist.

**Step 3: Extract the reusable presentation and coordinator**

Move compact-only types out of `ShortcutRecorderButton.swift`. Introduce a reusable field configured by shortcut value, enabled and recording states, error text, width, reset and clear availability, and action callbacks. Keep keyboard capture and role validation in `CompactShortcutRecorder`. Keep handwritten source files at 300 lines or fewer.

**Step 4: Run the focused test and verify success**

Run: `./build.sh --test-suite=screenshots`

Expected: PASS.

**Step 5: Commit**

Run: `git commit -m "refactor(shortcuts): extract compact recorder foundation"`

### Task 2: Migrate ordinary global shortcut rows

**Files:**
- Modify: `Sources/Vorssaint/UI/ShortcutRecorderButton.swift`
- Modify: `Sources/Vorssaint/UI/Settings/GeneralSettings.swift`
- Modify: `Sources/Vorssaint/UI/Settings/ShelfSettings.swift`
- Modify: `Sources/Vorssaint/UI/Settings/QuickToolsSettings.swift`
- Modify: `Sources/Vorssaint/UI/Settings/CommandBarSettings.swift`
- Modify: `Sources/Vorssaint/UI/Settings/ClipboardSettings.swift`
- Modify: `Sources/Vorssaint/UI/Settings/SwitcherSettings.swift`
- Modify: `Sources/Vorssaint/UI/Settings/TextSnippetsSettings.swift`
- Modify: `Sources/Vorssaint/UI/Settings/DisplayBrightnessShortcutControls.swift`
- Modify: `Sources/Vorssaint/UI/Settings/ShortcutsSettings.swift`
- Modify: `Sources/Vorssaint/UI/MenuPanel/MixerSection.swift`
- Test: `Tests/CompactShortcutValidationTests.swift`
- Test: `Tests/UtilitiesFeatureTests.swift`

**Step 1: Write failing role-row parity tests**

Cover enabled and disabled values, reset and clear behavior, self-conflict exclusion, additional conflict providers, and supported macOS takeover decisions.

**Step 2: Run the focused test and verify failure**

Run: `./build.sh --test-suite=screenshots`

Expected: FAIL on parity expectations that still depend on the legacy row.

**Step 3: Make ShortcutPreferenceRow use the compact recorder**

Preserve its public initializer, labels, captions, Super Key alternative, status text, additional conflicts, inactive-conflict option, and takeover sheet. Replace its recorder presentation and remove obsolete external unavailable messages at call sites.

**Step 4: Run focused regressions**

Run: `./build.sh --test-suite=screenshots`

Run: `./build.sh --test-suite=utilities`

Expected: PASS.

**Step 5: Commit**

Run: `git commit -m "feat(shortcuts): standardize global shortcut setters"`

### Task 3: Adapt dynamic and specialized shortcut owners

**Files:**
- Modify: `Sources/Vorssaint/UI/CompactShortcutRecorder.swift`
- Modify: `Sources/Vorssaint/UI/Settings/WindowLayoutSettings.swift`
- Modify: `Sources/Vorssaint/UI/Settings/RadialMenuSettings.swift`
- Modify: `Sources/Vorssaint/UI/Settings/CommandBarAppShortcutsView.swift`
- Modify: `Sources/Vorssaint/UI/Settings/MouseButtonSettings.swift`
- Modify: `Sources/Vorssaint/UI/Settings/CutPasteSettings.swift`
- Test: `Tests/WindowLayoutFeatureTests.swift`
- Test: `Tests/CommandBarFeatureTests.swift`
- Test: `Tests/PointerInputFeatureTests.swift`
- Test: `Tests/UtilitiesFeatureTests.swift`

**Step 1: Write failing adapter tests**

Cover dynamic identity, current-owner exclusion, modifier-only directional capture, optional clearing, feature-specific conflicts, and takeover preservation.

**Step 2: Run affected suites and verify failure**

Run: `./build.sh --test-suite=window-layout`

Run: `./build.sh --test-suite=command-bar`

Run: `./build.sh --test-suite=pointer-input`

Expected: FAIL on new compact-adapter expectations.

**Step 3: Replace raw recorder buttons with compact adapters**

Give each dynamic owner a stable recording identity and callbacks for current value, save, clear, reset, and validation. Preserve modifier-only capture and existing takeover offers.

**Step 4: Run all affected suites**

Run the three commands from Step 2 plus `./build.sh --test-suite=utilities`.

Expected: PASS.

**Step 5: Commit**

Run: `git commit -m "feat(shortcuts): migrate specialized shortcut setters"`

### Task 4: Reuse the shared field for screenshot tools and shorten errors

**Files:**
- Modify: `Sources/Vorssaint/UI/Screenshot/ScreenshotToolOrderControls.swift`
- Modify: `Sources/Vorssaint/Core/CaptureWorkflowStrings.swift`
- Modify: `Tests/ScreenshotToolShortcutTests.swift`
- Modify: `Tests/ScreenshotFeatureTests.swift`
- Modify: `Tests/DirectCaptureRequirementsComprehensiveTests.swift`

**Step 1: Write failing tool-field tests**

Assert that tool shortcuts use the shared compact field at the narrow width, retain duplicate and reset conflict prevention, coordinate recording with role setters, and show `Unavailable` instead of `Shortcut Unavailable` in English.

**Step 2: Run screenshot-focused tests and verify failure**

Run: `./build.sh --test-suite=keyboard`

Run: `./build.sh --test-suite=screenshots`

Expected: FAIL on shared-field and compact-copy expectations.

**Step 3: Migrate the tool recorder and localizations**

Replace duplicated field chrome with `CompactShortcutField`, keep tool key semantics and conflicts, and shorten every localized `shortcutUnavailable` value to fit the 86-point field.

**Step 4: Run screenshot-focused regressions**

Run both commands from Step 2 and `./build.sh --test-suite=capture-requirements`.

Expected: PASS.

**Step 5: Commit**

Run: `git commit -m "feat(screenshot): unify tool shortcut setter"`

### Task 5: Verify the complete migration

**Files:**
- Modify if needed: files already owned by Tasks 1 through 4

**Step 1: Audit every editable shortcut call site**

Run: `rg -n "ShortcutRecorderButton\\(|ShortcutPreferenceRow\\(|CompactShortcutPreferenceRow\\(" Sources/Vorssaint/UI --glob '*.swift'`

Expected: raw recorder uses remain only inside the shared implementation or a documented non-setting exception.

**Step 2: Check file sizes and the complete diff**

Run: `wc -l Sources/Vorssaint/UI/CompactShortcutBindingRecorder.swift Sources/Vorssaint/UI/CompactShortcutRecorder.swift Sources/Vorssaint/UI/CompactShortcutField.swift`

Run: `git diff --check`

Expected: shared handwritten files are at most 300 lines and no whitespace errors exist.

**Step 3: Run the full test harness**

Run: `./build.sh --test`

Expected: PASS with no failures.

**Step 4: Build and run selftest**

Run: `./build.sh --dev`

Run: `./build/LatticeDeveloper --selftest`

Expected: the build succeeds without warnings and selftest passes.

**Step 5: Perform independent review and resolve findings**

Request a review of `origin/lattice/main...HEAD` plus uncommitted changes, with the approved design and verification evidence. Fix substantiated findings through focused tests and rerun affected checks.

**Step 6: Commit verification fixes if needed**

Run: `git commit -m "fix(shortcuts): address overhaul review"`
