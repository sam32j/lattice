# PRs 20 and 21 review disposition

Baseline: fix/settings-followups at a9545822, clean. PR 20 is closed; PR 21 is its active replacement. User authorizes review, applicable corrections, push and a consolidated comment on PR 21. Preserve approved feature contracts.

Baseline settings checks: 1,004 passed.

## Findings

- PR 20 r4379078033: defer quit-protection window lookup/presentation until after event-tap return; cancel stale work when the original press ends or ownership changes.
- PR 20 r4379078060: natural Turkish Esc caption.
- PR 20 r4379078078: accessible feedback subject and diagnostics control labels.
- PR 20 r4379078096 / PR 21 r4380225168: assigned shortcut and dismissed system takeover conflicts use the shared alert; invalid shortcut retains its real message.
- PR 20 r4379078113: reject permanent brightness readout. Approved UX uses native sliders with value only while sliding.
- PR 20 r4379078127 / PR 21 r4380225172: preserve custom Dock Preview delay as an honest selectable value, without changing preferences on view load.
- PR 20 r4379078137 / PR 21 r4380225183: localize hold-duration presets.
- PR 20 r4379078151 / PR 21 r4380225200: preserve custom hold durations as selectable values, rather than silently snapping saved configuration.
- PR 20 r4379078170: retain invalid-shortcut errors instead of inventing an assigned action.
- PR 21 r4380225138: shared feedback draft validation, including encoded subject/message/diagnostics URL budget and visible correction guidance.
- PR 21 r4380225162: a saved update-attempt timestamp cannot establish success; retain the timestamp but start idle when the result is unknown.

## Verification boundaries

Reuse approved isolated preference/service, feedback URL, shortcut validation and native rendering seams. Fake application, HUD, window lookup and browser boundaries. Do not install an event tap, quit applications, change real permissions/hardware, open a browser or submit issues. Focused settings, updates, quit-protection and shortcut regressions plus Developer build; independent review before publication.

The two oversized service files require cohesive extension files before behavioral edits under the implementation skill's file-size rule. Preserve existing behavior during that separation and update generated test sources to compile the real implementation pieces.

## Final disposition and evidence

All 15 inline comments were reviewed (11 distinct findings). Ten distinct findings are fixed; the permanent brightness readout request is rejected because it conflicts with the approved tooltip-only slider contract. The custom-value findings are fixed by preserving saved values, rather than applying the suggested automatic migration on view appearance.

- Feedback: exact shared encoded-URL validation includes subject, message and selected diagnostics; subject-only overflow is explained before Send. Accessibility labels added. Correction guidance updated in all 15 languages. The review's claim of a generic overflow error was inaccurate; the existing error was specific, but prevalidation was missing.
- Timing and shortcuts: localized hold presets and Turkish Esc caption; preserve custom hold durations; Dock selection/custom tag share runtime sanitization without changing stored preferences. Both shortcut surfaces use assigned-action alerts while retaining invalid-input errors.
- Services: keep historical update timestamp but start idle without a proven result. Quit HUD window enumeration runs on a worker; presentation checks unique press identity, ownership, target, live permission/session/configuration and hold deadline. Activated the previously uninvoked real-service routing fixture.
- Regression cycle: update initialization failed before correction; HUD callback test failed before deferral; encoded feedback validation was absent before implementation; final Dock boundary checks failed exactly for saved 0 and 1500 ms before using runtime sanitization.
- Combined affected checks passed: window-layout 473, updates 564, screenshots 1,869, settings 1,040, quit-protection 249; total 4,195. Final settings rerun after the Dock boundary correction: 1,040 passed.
- Independent source review: ready, no remaining actionable findings. All localized feedback guidance and final Dock sanitization delta re-reviewed.
- Final Developer build and strict bundle signature verification passed with the final Dock boundary refinement.
- No real grants, taps, app termination, browser submission or hardware changes. Live many-window WindowServer latency was not benchmarked. Unrelated test suites were not run.

Publication: user authorizes topic commits, push to fix/settings-followups and consolidated disposition on PR 21 covering the closed PR 20. Keep both PR states and base branches unchanged.

## Follow-up review round

Baseline: 204074ef, clean. User requested the new comments be addressed and a manual before/after test plan covering every review fix.

- r4382192712: fix the preview renderer to accept the requested scheme and set matching SwiftUI preferred scheme plus native hosting/window appearance. Existing callers retain the light default.
- r4382192734: reject restoring additional Request buttons. Section 7 of the user-supplied implementation spec explicitly marks Accessibility, Screen Recording, Notifications, Camera and Bluetooth as non-requestable on this page. Retain the approved policy and feature-specific request flows.
- r4382192742: remove the redundant outline action tone, retaining compact native bordered Settings buttons per the user's visual correction. Status text, dot and tile continue to distinguish state.
- r4382192749: add an always-selectable 2000 ms hold preset for both quit and close. The new regression failed before implementation; custom saved values and the 800 ms default remain intact.
- Manual testing: manual-testing.md covers the old failure, reproduction steps and expected fixed behavior, including release-only update checks, legacy custom values, deliberate spec-driven non-changes and rendering-tool verification.

Previous CI (40396129847) failed 3 of 103,479 checks. Reproduced all three locally: the new update-test domain was outside the cleanup sweep, and two pointer-input source guards did not follow Quit Protection's extracted extensions. Renamed the disposable domain into the existing swept namespace and taught the source reader to include both extensions, failing closed when a source is missing. Existing session/permission assertions are unchanged.

Final verification: harness 518, pointer-input 1,037, settings 1,041, quit-protection 249; total 2,845 passed. Developer build and strict signature verification passed. Disposable light/dark previews rendered successfully and were visually inspected; diagnostics confirm matching Aqua/Dark Aqua appearance for both native window and host. Independent source review is ready with no remaining findings, including the CI harness corrections. Unrelated suites were not repeated locally; fresh CI remains separate.

Manual test plan completed in manual-testing.md. Topic commits and publication authorized; post the follow-up disposition and resolve the four reviewed threads without changing PR state or base.
