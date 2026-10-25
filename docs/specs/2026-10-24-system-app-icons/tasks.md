# System-provided app icons

Goal: prevent Dock Preview and Switcher icon resolution from reading other apps' preferences or inspecting custom-icon resources.

Approved choice: use system icons for all apps, accepting that app-specific alternate icon preferences may not be reflected. Commit on `refactor/settings-refactor-III-part-5` for PR #14. Baseline `f69033be`; isolated checkout `/Users/samuel/.codex/worktrees/music-icon-permission/Lattice`. Preserve other worktrees and stack branches. No real grants or app preferences are changed.

Evidence: the shared `SwitcherAppIconCache.stableBundleIcon` reads arbitrary target preference domains with `CFPreferencesCopyAppValue("DockIconResourceName", bundleIdentifier)`. Dock Preview calls it when drawing app icons. Local sandbox/TCC logs at 10:18:09 attribute Media Library checks to Lattice Developer. This supports an indirect protected-data trigger, but the redacted logs do not identify the exact accessed path. The running installed build was `65aa438d` (part 2), which lacks part 5's earlier Cleaner safeguards.

Acceptance and work:
- [x] Establish focused baseline.
- [x] RED/GREEN at the shared icon-loading boundary, using injected system-image results and inert PIDs. Cover system source selection, session reuse, fresh lookup outside sessions, missing images and missing processes without loading Music or requesting access.
- [x] Remove the target-preferences lookup and custom-icon resource traversal. Remove tests specific to that retired behavior. Keep appearance rendering, native bundle/app icon resolution and existing session cache ownership.
- [x] Run affected switcher/model/Dock suites and Developer build. Review the complete change independently; no live hover, Music command or permission reset is performed.
- [x] Commit only this fix and its evidence to part 5. Do not merge, rebase the stack, or change PR metadata.

Verification limits: no controlled real-permission reset/hover reproduction is authorized. The fix removes the identified cross-app preference path by construction; it does not prove every macOS API is incapable of an unrelated indirect prompt.


## Results

- Baseline Switcher suite: 307 checks. Baseline model/Dock suites: 1,986 checks.
- RED: isolated icon regression failed to compile because the system-icon loading boundary did not exist. GREEN: `SYSTEM_APP_ICONS_OK (6 checks)` against the real shared resolver with injected system-image results.
- Final affected suites: `TESTS OK (2287 checks)` across switcher-model, switcher and dock-autohide. Retired twelve custom-resource assertions and added six system-source/cache/drawing/unavailable-process checks.
- Developer build and strict deep signature verification passed. `git diff --check` passed.
- Independent source review: ready with no actionable findings. The native system-icon APIs themselves were not exercised after a real permission reset; the eliminated preference/custom-resource paths are confirmed absent by source audit.
- Publish only the owning part 5 branch as a normal fast-forward. Do not edit PR metadata, merge, or rewrite downstream stack branches.
