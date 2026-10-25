# Capture and Settings Follow-up Implementation Plan

**Goal:** Fix the reported capture presentation, permission lifecycle and utility settings inconsistencies.

**Architecture:** Reuse the permission coordinator and page-owned feature model. Keep capture geometry/layer policy testable separately from AppKit surfaces; make persisted settings the observable source of truth. Preserve data keys and existing shared capabilities.

**Tech Stack:** Swift, SwiftUI, AppKit, CoreBluetooth, existing generated test fixtures, build.sh and isolated render probes.
---

## Tasks

1. Permission lifecycle: add a revoked-grant regression in Tests/PermissionActivationTests.swift;
   synchronize Sources/Vorssaint/UI/Settings/PermissionGatedToggle.swift with verified
   access changes and test immediate preference/details consistency without rearming.
   Inspect KeyboardLightSettings.swift and BrightnessService shortcut registration,
   then remove only the unnecessary grant row.
2. Observable routing: test AppMenuDestination and IslandDestinationSupport at the
   saved-selection seam; fix AppMenuDestinationSettings.swift binding invalidation.
   Extend DedicatedUtilitySettings.swift/IslandDestinationSettings.swift for camera
   and launcher shortcuts, route and widget state. Update SettingsDirectoryPages.swift
   and GeneralToolSettings.swift positive menu-icon switch and child picker.
3. Input persistence: test first-added key order, edits, removal and reload; extract
   an ordered override helper if needed. Wire KeyboardDebounceSettings.swift without
   changing debounce timing. Trace SnippetLibraryService and every Quick Snippets
   entry point and gate availability using the canonical enable key.
4. Bluetooth: add a small authorization support owner using public CoreBluetooth
   status without requesting on inspection. Wire Permissions.swift, AppPermission,
   PermissionsPortalSections.swift, PermissionPortalRow/Presentation/DetailsSheet
   exhaustively. Update Resources/Info.plist and user-facing accessory copy.
5. Capture contrast/window selection: tests at ScreenshotCapturePolicy and capture
   chrome geometry/render seams, then fix eligible dialog layers, overlay level and
   readable overlap backing. Extract focused helpers from oversized controller as
   needed. Never bypass OS-protected content.
6. Capture workspace layering: correct ScreenshotWindowLayering.swift relative to
   the actual Liftoff surface, test all pin/editor/dialog callers and boundaries.
7. For each task: observe the targeted regression fail, apply the smallest fix,
   run affected suites, and record evidence here. Use ./build.sh --test-suite=settings
   --test-suite=features initially; run screenshot/capture/keyboard/utilities suites
   for their corresponding changes.
8. Independent review: spec first, then lifecycle/correctness, resolve findings.
   Final ./build.sh --test, ./build.sh --dev, isolated rendering/selftest, signature
   and git diff --check. Commit by topic, fast-forward the original named branch
   if unchanged, push only, and verify the remote head and unchanged lattice/main.

## Progress

- [x] Approved design, seams and branch outcome.
- [x] Verified clean baseline in both checkouts; reused attached worktree.
- [x] Baseline focused checks: features/settings, 1,913 checks.
- [x] Tasks 1-6 with targeted red/green evidence.
- [x] Independent review, final checks and topic commits. Publication status is
  recorded in the final handoff after the authorized branch push.

## Implementation and verification evidence

- Permission lifecycle is owned by an application-lifetime subscriber rather than
  mounted settings controls. Unknown state is not treated as denial; queued states
  are revalidated before clearing activation. Restored permission does not rearm a
  feature. Cleaning Mode releases its lock while retaining the shortcut definition.
  Regression coverage includes optional capabilities, stale denial and global
  revocation. Direct keyboard brightness and its Carbon shortcuts retain access.
- Ordered duplicate-key overrides: missing-helper regression failed first; settings
  passed after preserving insertion, replacement and remove/re-add order.
- Quick Snippets: generated real-service boundary regression failed on delayed
  presentation/insertion after disable, then passed with canonical-owner guards.
- Camera/launcher combined destination tests and sidebar order checks failed before
  implementation, then passed. The menu picker now reads and writes its observed
  AppStorage values, rather than reading raw defaults without view invalidation.
- Bluetooth authorization and permission attribution are covered without creating
  a radio manager. The review regression failed with an uninstalled power module,
  then passed after attribution matched the actual accessory service dependency.
- Capture tests cover elevated eligible dialogs, protected/excluded layers,
  selection/chrome overlap, contrast opacity and pin/editor/dialog levels. Read-only
  WindowServer metadata showed Liftoff's full-size launcher at level 26; its level
  1000 surface was a 2x2 helper. Workspace levels are now 22/23/24.
- Focused final settings/features: 1,939 checks passed. Broader focused capture,
  feature, settings, repository and pin suites also passed during implementation.
- Full `./build.sh --test`: 102,587 checks passed, followed by preference cleanup,
  uninstall-spaces and developer-install isolation checks. AppKit/sandbox diagnostic
  warnings did not fail any suite.
- `./build.sh --dev` and strict deep signature verification passed. Independent
  source review cleared all findings after stale-permission, Cleaning Mode and
  Bluetooth-attribution corrections.
- Final isolated rendering passed all 49 fixtures. Inspected camera/launcher,
  menu-bar visible/hidden, permission rows, duplicate-key rows and light/dark
  capture contrast. The same-host accessible popup value followed None, Menu Bar
  and Dynamic Island without rebuilding the settings view. Isolated selftest:
  `SELFTEST OK`. Final whitespace validation passed.
- Validation does not change real grants, shortcuts, brightness or Bluetooth state.
  Protected macOS content remains subject to system capture restrictions. Native
  Liftoff interaction and actual permission revocation were not performed.
