# Refactor Follow-up Implementation Plan

**Goal:** Correct capture overlap/dialog behavior, app-menu entry paths and the requested permission/utility settings hierarchy.

**Architecture:** Keep presentation rules and permission lifecycle state separate from native side effects. Reuse shared island controls and native switches. Extract scoped responsibilities from oversized owners before extending them.

**Tech Stack:** SwiftUI, AppKit, CoreGraphics, ScreenCaptureKit, existing generated fixtures and native probes.
---

## 1. Settings hierarchy and copy

- Files: `Sources/Vorssaint/UI/Settings/{DedicatedUtilitySettings,IslandDestinationSettings,ClipboardSettings,ScratchpadSettings,ShelfSettings,GeneralToolSettings}.swift`, shared new utility controls and localized follow-up copy as needed; `Resources/Info.plist`.
- Implement exact hierarchy and regular switches, removal of separators/how-to, root global shortcut labels and disabled details. Preserve independent stored values while making the requested page controls read-only when disabled.
- Verify through isolated enabled/disabled/island on/off rendering, existing routing/service suites and developer build. Presentation-only checks use actual rendering, not source-shaped assertions.

## 2. Permission reset

- Extract reset row/state from `DataPermissionsSettings.swift` into a focused component. Add isolated lifecycle tests: confirmation cancel, success, failure and restart intent without invoking real TCC/login changes.
- RED: successful completion switches row to Restart now; failure never claims reset. Implement only after observed failure. Keep async working-state gating.

## 3. App-menu entry paths

- Extract scoped reopen/routing policy from oversized `AppDelegate.swift` before extending it. Test Don't show -> Settings for app reopen and icon click; retain available menu/island behavior.
- Implement path fix and run affected settings/reopen suites. No live app activation needed for unit coverage.

## 4. Capture overlap and system dialogs

- Files: `CapturePresentationPolicy.swift`, `CaptureChromeBackdrop.swift`, scoped extraction from `ScreenshotSelectionController.swift`, `ScreenshotCapturePolicy.swift`, `ScreenshotCaptureEngine.swift`, focused tests/probes.
- RED: overlap reduces whole-toolbar opacity; hover restores it; no intersection remains full strength. Remove old overlap-dependent solid plate and associated exclusive state.
- Establish native dialog metadata/ordering evidence before selecting a fix. Test eligible elevated surfaces and transparent bounds with isolated windows; preserve protected-window exclusions and safe capture fallback.

## 5. Media permission diagnosis and portal

- Trace scoped unified logs and callers without issuing new permission requests. Confirm caller where possible; report uncertainty honestly.
- Add non-prompting Media & Music status/settings access using supported API, plus isolated permission status mapping tests. Do not introduce startup requests or change P6 wording.

## 6. Verify/review/finish

- Run affected suites, full `./build.sh --test`, `./build.sh --dev`, isolated rendering, selftest and strict signing checks.
- Independent source review since 590fd058, including new files; fix substantiated findings and rerun affected checks.
- Keep one task record with exact checks and remaining live/protected-surface limits. No PR or merge. Topic commits on the existing refactor branch; confirm publishing authority before push if not established for this batch.

## Status

Approved; baseline clean at 590fd058. Source audit confirms inverted opacity and bypassed reopen route. P6 logs confirm MediaLibrary request attributed to the main Lattice Developer process, not yet the internal caller. Implementation starting.
