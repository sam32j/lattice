# Settings Ownership Implementation Plan

**Goal:** Make settings control permission-backed activation, page-owned feature installation and consistent presentation without dead capture routes.

**Architecture:** Centralize activation decisions and destination/feature ownership in small testable support modules. Existing runtime services retain ownership of behavior; settings commit preferences only after capability checks and trigger normal runtime synchronization. Remove exclusive obsolete UI dependencies rather than add compatibility fallbacks.

**Tech Stack:** Swift, SwiftUI, AppKit, Foundation, existing generated Swift test fixtures and build.sh; bun/uv for project tooling.
---

Each task follows one behavioral case at a time: add regression, observe failure,
implement smallest cohesive change, run affected suite, then review surrounding
callers. New handwritten modules stay under 300 lines; extract cohesive affected
components from oversized files before extending them. Commit only when authorized.

### Task 1: Permission activation
- Inspect Core/Permissions.swift, Core/FeatureCatalog.swift, UI/Settings/SettingsCard.swift and all permission-requiring feature enable controls.
- Create Core/PermissionActivationSupport.swift and UI/Settings/PermissionGatedToggle.swift.
- Test required-grant success, denial/unresolved/cancel, stale callbacks, off and revocation at the approved preference/service boundary.
- Wire KeyboardDebounceSettings.swift first, then mouse/keyboard and feature-page controls, ScreenshotSettings.swift and ScreenRecorderSettings.swift.
- Run ./build.sh --test-suite=settings --test-suite=features --test-suite=keyboard --test-suite=pointer-input.

### Task 2: Feature ownership and sidebar
- Extract catalog ownership into Core/FeatureInstallationPolicy.swift from Core/FeatureCatalog.swift.
- Modify UI/Settings/FeatureVisibilitySupport.swift, SettingsDirectoryPages.swift, SettingsSidebarSupport.swift, SettingsView.swift and App/FeatureRuntime.swift as required.
- Add small Camera Preview, DMG Installer and Launcher Grid pages, updating dedicated routing/search.
- Update TextSnippetsSettings.swift, URLCleanerSettings.swift, ClipboardSettings.swift, ShelfSettings.swift and ScratchpadSettings.swift.
- Test off-page reachability, hub exclusion and exactly-one-toggle installation/teardown, then run features/settings/utilities/launcher suites.

### Task 3: Island ownership and app-menu destination
- Add small shared destination support; wire dedicated page switches to widget+route preferences as one operation.
- Update NotchSettingsBehavior.swift, NotchSettingsModuleOptions.swift, GeneralSettings.swift and the existing Menu Bar page.
- Test route/widget consistency, child visibility, invalid destinations and no-target recovery; render expanded/off pages.
- Rename user-facing Shelf and Tools references without changing unrelated persisted data keys.

### Task 4: Capture and standalone-tool removal
- Trace all captures/control/indicator paths in Services/Notch, Services/QuickTools and Services/Recorder.
- Remove exclusive island capture controls, hide-Lattice-windows preferences/UI/filtering, and standalone color/OCR screens/entry points.
- Preserve preview/history and internal editor color/OCR operations; remove stale generated/build/localization references.
- Test on-screen selection/recording lifecycle and remaining OCR/color functions, then run screenshots/recorder/notch/capture suites.

### Task 5: Window layering
- Inspect Liftoff bundle/window diagnostics without changing its settings.
- Update Services/QuickTools/ScreenshotWindowLayering.swift and pin/editor/dialog callers with one bounded level policy.
- Test relative layers, owner ordering and constraints; report any live third-party verification limits.

### Task 6: Input, hints, shortcuts and audio
- Modify KeyboardDebounceSettings.swift, KeyboardSuperKeySettings.swift, KeyboardQuitProtectionSettings.swift and SettingsStatusDot.swift.
- Keep native hint anchor stable across hover and layout updates; test delay, cancellation and flash regression.
- Trace active shortcut state ownership and fix publisher/invalidation rather than refresh text manually.
- Update audio-output pin controls and test pin state representation.
- Run settings/keyboard/pointer-input/audio-settings/audio-priority suites and isolated rendering.

### Task 7: Review and final verification
- Independent review of spec coverage first, then correctness/lifecycle/data retention.
- Resolve findings with regressions; run ./build.sh --test, ./build.sh --dev and developer selftest/signature check.
- Render affected layouts and verify every requested item against design.md.
- Preserve the final refactor/settings-refactor-III branch and report commits/worktree/remote state accurately; no unauthorized push/merge or app installation.

## Progress
- [x] User approved full design and isolated test boundaries.
- [x] Baseline revision and clean checkout recorded; isolated managed worktree created.
- [x] Baseline focused suites (1,829 checks).
- [x] Tasks 1-6 implemented with focused permission, lifecycle, routing, capture,
  native hint, shortcut and settings coverage. Audio-only access stays contextual
  by explicit user choice.
- [x] Independent review and final verification.

### Final verification

- Final full run passed: 102,551 checks, plus preference cleanup, uninstall Spaces and
  developer-install isolation checks. Rendering fixtures have an explicit
  isolated bundle-identity guard and are excluded from production writer checks.
- Forty-one isolated layout fixtures rendered successfully. Inspection found a
  blank Form-divider row in the three utility headers; fixed with grouped child
  rows and inspected corrected renders. Final developer build passed, strict deep
  signature verification passed, and the isolated test bundle reported SELFTEST OK.
- Independent review fixes covered denied/stale permission requests, complete
  snippet/clipboard/launcher teardown, persistent unavailable app-menu routing,
  and permission-gated brightness key-step selection. Final re-review found no
  remaining actionable findings.
- Final permission audit added Music blocking, optional Keep Awake mouse jiggle,
  and radial profile triggers. Jiggle revocation cancels its timer and delayed
  movement without ending the underlying Keep Awake session. Six regressions
  exercise the extracted production methods without posting real mouse events.
- Delayed radial grants validate the still-selected profile by ID, current feature
  state and profile existence. Profile editor identity cancels abandoned requests;
  regression scenarios cover switching, deletion, reordering, disabling and cancel.
  Affected suite rerun passed 1,570 checks before the final full suite.
- Validation changed no real permissions, key mappings, brightness, Bluetooth or
  main-app installation. Publishing is a separate user-authorized step below.

### Limits and outcome

- Hardware/permission checks use isolated preference domains, service doubles and
  production-method seams. No real grant/revocation or input/hardware change was
  performed. Selftest used a separate test bundle identity and temporary power
  assertion, not a persistent Keep Awake session.
- Liftoff's live window level was inspected read-only; pin/editor/dialog levels
  were tested below it. Live interaction/stacking with third-party windows was
  not exercised.
- Final source diff passes git diff --check. No generated artifacts are tracked.
- User selected topic commits and push to refactor/settings-refactor-III, then
  explicitly excluded PR work. No PR creation/update or merge to lattice/main.
