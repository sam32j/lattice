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
- [ ] Baseline focused checks.
- [ ] Tasks 1-6 with targeted red/green evidence.
- [ ] Review, final checks, topic commits and push.
