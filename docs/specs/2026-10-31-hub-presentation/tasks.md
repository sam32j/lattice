# Hub presentation corrections

Baseline: `0a3439a1` on `ui/settings-refinements`, with existing uncommitted UI and permissions work preserved.

- [x] Inspect crash reports and exercise the production hub view and full island host in an isolated identity. The reported crash was not reproduced on current source; its cause remains unverified.
- [x] Keep the floating HUD top edge fixed while Manage Tools expands and collapses. Keep header and footer geometry stable; reveal editing content as an accordion.
- [x] Verify the production presentations, focused regression suites and a developer build.
- [x] Independently review task changes and report other actionable issues in the recent hub changes.

Test boundary approved by the user: actual SwiftUI/AppKit hub presentations in an isolated fixture. No tool action or permission request is invoked.

## Implementation and verification

SwiftUI owns the accordion animation. A direct natural-content geometry observer supplies the panel size for each frame; AppKit updates the frame synchronously around its fixed top edge. Hosting retains intrinsic content measurement without independently resizing the window through preferred content size. The header has no transition, and the editing section clips from the bottom. Local outgoing options content remains visible during collapse while service state clears immediately, preserving Escape behavior.

The oversized hub view was split into chrome and editing-tray extensions, preserving their existing behavior and copy. The test-source extractor now reads the relocated footer. Done's accessibility label now describes Done.

- Developer build: `./build.sh --dev`, including a clean-object rebuild during investigation, passed. After explicit user approval, `./build.sh --dev --install` installed `/Applications/Lattice (Developer).app`; its final signature verified. The app was relaunched. No commit performed.
- `./build.sh --test-suite=launcher --test-suite=notch`: 47,719 checks passed.
- `./build.sh --test-suite=features --test-suite=overlays`: 1,190 checks passed.
- Isolated production fixture: `--hub-presentation-test --output-directory <directory>` passed. It covers compact and wide island layouts, normal/edit transitions, item/control visibility changes, three full island open/collapse cycles, HUD expansion and collapse, intermediate animation heights, native header position, options-card dismissal, actual Escape handling after Done, rapid reversals and anchored reopening after a utility.
- HUD height changed 621 to 687 points and returned to 621. Closing with options open changed 795 to 621. Window top drift was 0; settled neutral-header raster drift was 0.5 points; footer drift was 0. The header's existing native drag handle was tracked throughout animation. Bitmap captures are limited to settled endpoints because forcing snapshot draws during animation distorts the rendering clock.
- Task-file whitespace checks passed. A full-workspace diff check reports an existing unrelated blank line at the end of `PermissionResetSettingsRow.swift`; it was preserved.

## Crash investigation limit

The two 21:44 Developer crash reports fault in `NotchRail.column(_:)` with an invalid pointer. Their executable UUID differs from the previously installed 21:59 Developer executable. Neither current-source production-view fixtures nor repeated full-host island transitions reproduced the crash, including after a clean rebuild. No speculative rail change was made, and this is not evidence of a specific source-level crash fix.

After installation and relaunch, native UI verification using the user's existing configuration successfully opened the Dynamic Island hub, entered Manage Tools, clicked Done and reopened the hub. The crash did not recur and no new Developer crash report appeared. One computer-use call timed out, but a subsequent fresh accessibility snapshot confirmed the app remained running with the hub open.

## Separate recent-change findings for user review

- P2: Manage Tools is gated by workflow-item `enabledCount` while quick controls are excluded. If all workflow features are off, available or hidden quick controls can remain but Manage Tools is disabled. The matching forced-exit condition has the same limitation. This can prevent restoring hidden controls.
- New menu, empty-state and drag-target copy is hardcoded English instead of following the existing localization system.

Independent review found and corrected an outgoing-options Escape regression during this task. Final code review is ready conditional on the now-passing build and presentation verification. The two broader findings above remain separate from this animation correction.
