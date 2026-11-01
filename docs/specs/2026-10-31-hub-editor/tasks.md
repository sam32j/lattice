# Shared Hub Editor Implementation Plan

**Goal:** Make hub editing match display order, keep all editing actions reachable, and provide responsive drag/drop and localized management controls.

**Architecture:** One rail layout renders both island modes. A native drag session provides insertion and edge scrolling, committing preferences only on a successful drop. The editing presentation retains its size until the outgoing strip collapses.

**Tech Stack:** SwiftUI, AppKit, Swift standalone regression runner, isolated developer presentation fixtures.

---

### Task 1: Management availability and localized copy

Files: `Sources/Lattice/Services/LatticeHub/LatticeHubControlsSupport.swift`, `Sources/Lattice/Core/HubCustomizationStrings.swift`, hub chrome/tray/control views, `Sources/Lattice/Support/HubEditingProbe.swift`.

1. Exercise the existing production management action with only quick controls available; verify its current disabled state.
2. Add `canManageTools = enabledCount > 0 || !visibleControls.isEmpty || !hiddenControls.isEmpty`; use it for the menu, empty-state action and editing lifetime.
3. Add a typed language switch for all supported locales and replace hardcoded hub copy.
4. Verify quick-control-only management and localization through the isolated production fixture.

### Task 2: Shared rail and bounded editing presentation

Files: `Sources/Lattice/UI/LatticeHub/LatticeHubView.swift`, `LatticeHubGrid.swift`, `LatticeHubEditingTray.swift`, `HubAccordion.swift`; `Sources/Lattice/Services/LatticeHub/LatticeHubService.swift` and presentation extension; `Sources/Lattice/Services/Notch/NotchToolRailLayout.swift`, `NotchSupport.swift`, `NotchService.swift`; `Tests/HubEditingLayoutTests.swift`.

1. Add a geometry regression expecting an 11-tool editor to add only the 60-point strip and remain the same size with many hidden tools. Run `./build.sh --test-suite=hub-editing` and observe the failure.
2. Extract existing presentation methods from the oversized service before adding editor state. Keep handwritten modules below 300 lines.
3. Use the same normal rail row calculation and view in both modes. Bound the Available Tools strip and options region; scroll any genuinely short viewport.
4. Retain editor geometry until accordion completion and preserve outgoing options while clearing keyboard state.
5. Run geometry and real presentation checks including rapid reversals, Done, short displays and complete tray visibility.

### Task 3: Native drag/drop and edge scrolling

Files: new `Sources/Lattice/UI/LatticeHub/HubDragSession.swift`, `HubDragView.swift`, `HubDragModifier.swift`, `HubDragScrolling.swift`; hub grid/tray/control views; service order helpers; isolated drag fixture.

1. Reproduce preference writes and moving targets during the existing hover reorder.
2. Introduce typed local payloads, stable insertion targets, native session cleanup, and successful-drop-only persistence.
3. Add timed edge scrolling in native scroll views, stopping on exit, cancellation, drop or view removal.
4. Verify actual drag boundaries: before/after insertion, hidden/unavailable order preservation, cancellation, edge scrolling and drop-to-hide.

### Task 4: Verification and delivery

1. Run `./build.sh --test-suite=hub-editing --test-suite=launcher --test-suite=notch --test-suite=features --test-suite=overlays` and the isolated production presentation/drag fixtures.
2. Request independent review of the complete task delta against `/private/tmp/lattice-hub-editor-baseline`, fix confirmed findings and repeat affected checks.
3. Build/install the reviewed developer app and verify the existing user configuration through native UI, including an actual drag.
4. Record evidence and limitations here. Leave source changes uncommitted in the main workspace.

## Progress

- Design approved; baseline `0a3439a1` with existing uncommitted work preserved.
- Root causes confirmed: edit-only grid replaces display rail, capped editor geometry has no overflow path, and hover reorder persists preferences on each target crossing.
- Management availability now includes hidden/visible quick controls. New typed hub copy covers all 15 app languages.
- The island uses one rail in both modes. The editor adds a fixed 60-point horizontally scrolling strip; options use a bounded scroll region. Native expansion settles before revealing the strip, and closing reverses the sequence with generation guards for quick reversals.
- User refinements implemented: two rows starting at eight apps, leading alignment for incomplete hub rows, and a complete 160-point empty state/action even when controls remain or only hidden controls are available. Other rail consumers retain their default alignment.
- Native drag sessions show insertion feedback, preserve destination positions while hovering, and write the full stored order only on drop. Hidden and unavailable entries retain their relative order. Cancellation clears transient state. Edge scrolling uses a common/tracking-mode timer and stops with the drag lifecycle.

## Verification

- `./build.sh --test-suite=hub-editing --test-suite=launcher --test-suite=notch --test-suite=features --test-suite=overlays`: 48,913 checks passed.
- `./build.sh --test-suite=localization`: 7,734 checks passed. Total focused checks: 56,647.
- The initial geometry regression failed against the grid-based editor, then passed with the shared rail and bounded strip. The eight-app and empty-state checks failed before their fixes. The sparse presentation initially began at x=127.5; it now starts at the leading edge in both modes.
- Final `--hub-editor-test` production fixture passed: 300x112, 424x282 and 504x282 viewports; complete drop zone bounds; normal/edit/Done cell-position equality; native island height 222 to 282 and back, retaining its editor size during closing; sparse leading alignment; full empty-state renders with visible controls, all controls hidden, and only hidden controls available.
- Native persistence/session boundary checks passed: hover leaves order unchanged; cancel clears state without persistence; drop preserves hidden/unavailable entries; quick controls drag to hide; stationary edge scrolling advances an actual NSScrollView and stops on cancellation.
- Final `--hub-presentation-test` passed: floating HUD top/header/footer drift 0, options dismissal, Escape after Done, rapid reversals and anchored reopening.
- Signed developer build and task-file whitespace checks passed. Existing unrelated source changes are preserved. No commit or staging performed.

## Native interaction verification limit

The interactive isolated fixture runs the production native source/destination views under NSApplication's real event loop. Computer use initiated actual native source sessions, and a real destination callback accepted the original typed session with move mask 16. Its synthetic gesture then showed no global mouse button held and a global pointer outside the fixture, so it did not establish a complete physical mouse-up/drop. Direct commit/cancel and native scrolling checks passed independently. Temporary pointer and destination diagnostics were removed from the final source.

The reviewed developer build is being installed using the user's existing authorization. A physical mouse reorder and edge-scroll check is the remaining acceptance step. This must stay pending until the user reports the result or explicitly accepts that verification limit.

## Corner-radius explanation

The attached silhouette uses circular Bézier bottom arcs with a radius scaled by height and separately calculated tighter inverse top shoulders. That combination explains the rounded-rectangle impression in the short, wide screenshot. No contour change was requested explicitly; the correction here is to the hub's content sizing and empty-state presentation.
