# Settings Consolidation Implementation Plan

**Goal:** Consolidate Settings ownership, remove retired flows, and enforce real feature lifecycle and permission-reset behavior.

**Architecture:** Keep capability probing independent of service construction and use a shared runtime policy for toggle-owned controls. Settings pages own cohesive controls, while shared panel controls remain reusable. Enforce window geometry in both SwiftUI and AppKit.

**Tech Stack:** Swift, SwiftUI, AppKit, Foundation, existing Swift executable test harness.
---

Each task follows one behavioral test, observed failure, implementation, and affected regression checks. New modules remain below 300 lines. Existing large files receive only approved integration edits. Preserve the unrelated `docs/settings-pr5-review.md` and the main capture checkout.

### 1. Permission reset isolation

- [x] Extend `Tests/SelfUninstallTests.swift` at the reset seam: failed uninstall-only cleanup cannot prevent reset; failed TCC reset reports failure; reset unregisters login, preserves unrelated helper intent, and keeps input paused until restart.
- [x] Run `./build.sh --test-suite=features`, observe the new assertion fail.
- [x] Modify `Sources/Vorssaint/Services/SelfUninstall.swift`: block all input interception, suspend interceptors, unregister login, call `resetTCC()`, refresh permission state, and report reset or login failure. Keep input paused until restart; do not invoke sleep restoration, helper detachment, or sudoers removal.
- [x] Re-run the suite and preserve the full-uninstall safety tests.

### 2. Toggle-owned lifecycle and migration

- [x] Add behavior cases to `Tests/FeatureAvailabilityTransitionTests.swift` for Dock, maximizer, Quit on Close, Clipboard-owned plain paste, and hardware controls. Test old uninstalled choices migrate to disabled toggles.
- [x] Run `./build.sh --test-suite=features`, observe failures.
- [x] Update `Core/FeatureCatalog.swift`, `App/FeatureRuntime.swift`, `Core/Defaults.swift`, and `Core/SettingsBackupSupport.swift`; create cohesive capability/migration modules in `Core/`. Keep stable shortcut identifiers without independent install gates.
- [x] Verify enabled supported features load, disabling tears down, unsupported services never start, fan recovery remains safe, and bulk installation leaves toggle-owned state alone.

### 3. Retired flow removal

- [x] Capture retained startup/update and generic-download behavior in affected repository tests.
- [x] Remove onboarding/tour/preset UI and sole-use startup paths from `App/AppDelegate.swift`, `UI/Onboarding/`, `UI/UpdateHighlightsView.swift`, `UI/Settings/FeatureHubSettings.swift`, and sole-use Core resources.
- [x] Remove WhatsApp cleaning sources from `Services/ManagedDownloads/`, `UI/Settings/WhatsAppDownloadsSettings.swift`, and sole-use Core strings. Remove its defaults, notifications, cleaner links, catalog entries, tests, and build registrations.
- [x] Audit with `rg -n 'WhatsApp|WhatsNewView|OnboardingView|FeaturePreset|showOnboarding|reviewIntro' Sources Tests build.sh`; classify every remaining match. Never delete user downloads.
- [x] Run affected suites and `./build.sh --dev`.

### 4. Page and audio ownership

- [x] Extend actual directory/search consumer tests for Desktop & Dock, Window Management, Finder consolidation, Wallpaper relocation, and removed standalone entries.
- [x] Update `UI/Settings/SettingsDirectory.swift`, `SettingsDirectoryPages.swift`, `FeatureVisibilitySupport.swift`, `DockSettings.swift`, `WindowLayoutSettings.swift`, and Finder/Clipboard owners. Replace `AutoQuitSettings.swift` with a compact Dock-owned control.
- [x] Extract cohesive input controls from `UI/MenuPanel/MixerSection.swift` and split `AudioPrioritySection.swift` by direction. Integrate in `UI/Settings/AudioInputSettings.swift` and `AudioOutputSettings.swift` without changing saved device selections.
- [x] Move XDR into `UI/Settings/EnergyDisplaySettings.swift` More Options; remove eager XDR observation in `EnergySettings.swift`; hide unsupported controls using independent capability probes.
- [x] Run `./build.sh --test-suite=settings` and relevant audio/feature suites, then build.

### 5. Native Settings shell

- [x] Test `SettingsWindowSupport` restoration always returns width 772 and preserves valid height. Test native split item min/max 230 and noncollapsing state.
- [x] Implement fixed native width in `App/AppDelegate.swift` and `UI/Settings/SettingsWindow.swift`, with a cohesive split configurator module if needed.
- [x] Update `UI/Settings/SettingsView.swift`: fixed sidebar, static categories, no sidebar toggle, shared Back/Forward/title header; remove duplicate page headers.
- [x] Run Settings suite and render the developer window at 772 points, including search, navigation and sheets.

### 6. Localization, cleanup and final verification

- [x] Update all 15 language catalogs for changed headings, labels and search terms. Remove only strings made orphaned by these changes.
- [x] Run source-reference and dependency audits, `git diff --check`, full `./build.sh --test`, `./build.sh --dev`, and `./build/LatticeDeveloper --selftest` on the final state.
- [x] Request independent whole-diff review with the approved design, baseline `4f739374`, tests, and limitations; address substantiated findings and re-run affected checks.
- [x] Record actual UI validation separately from mocked system tests. Do not clear real permissions or change live hardware settings.
- [x] Commit by functional topic and follow the previously authorized PR #5 update workflow only after verification. Preserve the branch/worktree and unrelated files.

### Approved follow-up: reset safety and System Settings shell

- [x] Extend `Tests/SelfUninstallTests.swift` to require a process-wide lock before teardown, login unregistration, no automatic rearming after either reset result, and observable unregister failure. Run `./build.sh --test-suite=uninstaller` and observe the old flow fail.
- [x] Add `Services/InputEventTap.swift` with a thread-safe, process-lifetime gate. Track native ports at creation, disable/invalidate them before revocation, deny subsequent creation and rearming, and allow teardown. Route all production tap calls through the gate; test real gate behavior with inert ports and a source audit preventing bypasses. Test concurrent reset versus creation without installing real taps.
- [x] Update `Services/SelfUninstall.swift`: begin the safety lock before teardown, unregister login with an explicit result, reset TCC, leave input capture suspended on success or failure, and preserve unrelated integrations. Keep the uninstall recovery contract separate. Update reset results and confirmation copy in all 15 catalogs; keep Restart available after failure too.
- [x] Update `SettingsHostingController.swift`, `SettingsWindow.swift`, and `SettingsView.swift` for the 230-point full-height grey sidebar and detail-only header. Reorder `DataPermissionsSettings.swift` so Data is first. Extend native geometry and page-order tests, then verify rendered placement and sheet interactions in an isolated preview.
- [x] Refresh independent review, final full tests, signed developer build, selftest and whitespace checks before committing/pushing PR #5. Preserve the main capture checkout and unrelated review note.

## Verification and handoff

- Baseline: `4f739374`; follow-up design: `2c87c377`. Only task-owned implementation and design/plan files are staged. The unrelated `docs/settings-pr5-review.md` is preserved.
- Final source checks: `./build.sh --test` passed **115,888 checks**, plus preference cleanup, uninstall Spaces, and developer-install isolation checks. `./build.sh --dev`, `./build/LatticeDeveloper --selftest`, and `git diff --check` passed.
- Regression failures reproduced before fixes: reset resuming interception and skipping login removal; cross-surface Quick Controls teardown; off-state XDR discoverability; off/cleared Plain Paste shortcut inventory; stale queued global shortcut execution; logical Command-F on alternate layouts. Rendered audio composition previously reproduced misplaced microphone/output-priority controls. Gate concurrency and native login-removal results use inert system-boundary doubles.
- Native isolated preview verified 772-point window, fixed 230-point uncollapsible sidebar, full-height adaptive grey, detail-side navigation/title, Data-first order and renamed permission label. Back/Forward, permission details and changelog Done/Escape, Finder/audio ownership, unsupported XDR hiding, search Cmd-F/arrow/Return/Escape/clear focus, frosted/native glass, and light/dark rendering were exercised.
- No real permission reset, login unregistration, fan/helper/sleep changes, or system appearance changes were performed. Preview appearance changes were confined to an isolated test bundle. Hardware lifecycle and reset failures were tested at injected system boundaries, not claimed as live-device validation.
- Independent whole-diff review and follow-up safety/search reviews have no remaining actionable findings. Removed orphan maximizer status strings, publisher and Combine import after confirming no consumers. All new handwritten modules/tests are below 300 lines.
- Main checkout remains `feat/scroll-capture-preview` with its 56 pending capture files unchanged.
- Integration handoff: commit and push the verified implementation to existing PR #5 as previously authorized; do not merge. CI results after publication remain external verification.
