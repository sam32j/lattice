# PR 10 and PR 11 spec review

Requested: audit merged PR 10 against the agreed specs, then resolve every CodeRabbit thread on PR 11 using the actual requirements rather than accepting suggestions automatically. No merge or unrelated stack changes.

Baseline: PR 10 head `7402d2f3`, merged as `e3873b7a`; PR 11 base `lattice/main`, head `f695e604`. Reuse the clean existing `refactor/settings-refactor-III-part-2` branch in `/Users/samuel/Developer/Lattice`. PRs attached to the chat. The complete six-part branch remains untouched.

## PR 10 audit

Independent read-only review of the original baseline and final review-fix commit found no concrete spec regression in its scope: island settings remain reachable, ALS sizing/protected exceptions persist, automatic glass respects Reduce Transparency, dock action/exclusion behavior and reset confirmations remain, and shared utility ownership is preserved. Later stacked requirements are not treated as failures of part 1. Evidence is source review, not a fresh live UI or hardware test of the merged revision.

## PR 11 threads

Bluetooth decision superseded by the owner's follow-up approval: sleep handling alone controls feature availability. Restore-on-wake is a saved subordinate option, greyed out while sleep handling is off. Pending restoration must still complete independently. The original OR-gate decision is replaced by this contract.

- Bluetooth engagement: the sleep toggle owns availability. Keep the saved restore option subordinate and preserve already owed restoration independently, including at launch.
- Cleaning Mode manual entry points: investigate lost application-menu/Command Bar actions when shortcut registration is off. Manual activation is intended to remain available.
- Per-button backup exceptions: investigate nonportable executable paths in export and local-path preservation during restore.
- Brightness confirmation: preserve the explicit removal of standalone brightness feedback and retain island notices; do not silently reintroduce a HUD.
- Natural scrolling: preserve the explicit opposite physical-swipe behavior between natural/non-natural modes and inspect the complete event normalization path.
- Input slider: verify compact panel width versus Settings width.
- Displays enable switch: evaluate the proposed disable gate against toggle-owned installation; an off switch must remain usable to enable the feature.
- Three-finger drag tooltip: retain the short requested guidance, localize it and keep it accessible.

User approved isolated backup export/restore, manual-action availability, gesture direction and settings-layout checks. Do not change real permissions, key mappings, brightness, Bluetooth, or activate Cleaning Mode during verification. Update only PR 11's existing branch; no merge or other stack rewrites.

## Findings and dispositions

- Thread `PRRT_kwDOVKaLVc6v1fHi`: accept the engagement concern following the owner's revised approval. The original OR gate reported the feature available by default even though the service only monitored sleep when its sleep toggle was on. Availability now follows the sleep toggle; restore-on-wake is disabled while sleep handling is off without losing its saved value. A narrow launch exception settles pending restores without marking the feature enabled.
- Thread `PRRT_kwDOVKaLVc6v1fHq`: fixed manual Cleaning Mode availability in the application menu, Command Bar, Launcher Grid, and configured radial actions. Shortcut registration remains opt-in and clearing it does not end an active cleaning session. Existing launcher behavior tests reproduced three failures; an additional radial availability test reproduced the same stale gate.
- Thread `PRRT_kwDOVKaLVc6v1fHt`: fixed per-button export/import filtering and local-path preservation during restore. Cohesive exception helpers moved to `SettingsBackupSupport+MouseExceptions.swift` rather than extending the oversized owner. Export RED reproduced the username/path leak. Actual generated `SettingsBackup.applyAndRelaunch` with isolated defaults reproduced an older-backup fallback bug found by independent review. Missing button entries now inherit the restored shared list before carrying local paths; explicit empty overrides retain their meaning. No real restore/relaunch performed.
- Thread `PRRT_kwDOVKaLVc6v1fHw`: no standalone brightness HUD. The approved design explicitly removes the overlay and retains optional island notices and native key behavior. Adding a generic fallback would reintroduce removed feedback.
- Thread `PRRT_kwDOVKaLVc6v1fHz`: retain the natural-scrolling-dependent action choice. Apple's installed NSEvent header confirms event deltas invert with the preference; normalization recovers physical motion, then the action choice applies the requested opposite mapping. Four new tests compose both stages with literal event-delta/expected-action cases.
- Thread `PRRT_kwDOVKaLVc6v1fH2`: fixed compact input slider width to 164, with an explicit 220 on Audio Input Settings. Added compact/wide rendering fixtures.
- Thread `PRRT_kwDOVKaLVc6v1fH5`: do not disable the Displays master when off. `isAvailable` is derived from that toggle, so the proposed gate would prevent activation. Writing the toggle precedes synchronization and makes the service's computed availability true. Existing feature transition tests cover this behavior.
- Thread `PRRT_kwDOVKaLVc6v1fH6`: fixed localized and accessible short drag-conflict help in all supported languages. Preserved the owner's requested concise wording rather than restoring the older long explanation.

## Baseline CI reconciliation

PR 11's existing CI built, self-tested and packaged successfully, then failed 16 regression checks. Local RED reproduced the relevant keyboard/launcher/brightness failures after moving stale generated fixtures from the later branch out of the build cache. A real keyboard-light dependency regression was corrected by promoting the narrow existing `501d7ce2` patch from the later stack: hardware-gated controls and notices, keyboard shortcut availability, service startup, permission-refresh synchronization and keyboard-light hotkeys remain independent of Control displays.

Stale test expectations now use the actual display-toggle preference, retain Displays/Bluetooth sidebar reachability, use an installable Port Manager card rather than a removed monitor card in the hub scroll test, assert explicit hub inclusions/exclusions rather than a stale fixed count, and use the accepted shared app-list label. Three English strings now use typographic apostrophes, retaining the repository copy-consistency check. No production hardware gates were weakened to satisfy tests.

Focused affected suites passed 68,715 checks. The first full regression run passed 112,616 checks before the additional legacy-backup/radial regressions. Export RED, restore-boundary RED and radial RED were observed before their respective corrections. Independent review found the legacy-backup issue, then re-reviewed its correction and the final source diff as ready with no remaining actionable findings. Final full-suite/build/render results and publishing state follow below.

## Final verification and publishing

- Full regression passed **112,624 checks**, plus preference cleanup, uninstall-spaces and developer-install isolation. Final compact unavailable-state polish was followed by another **596** audio/settings checks, a developer rebuild and strict signature verification.
- Isolated rendering passed at `/tmp/lattice-pr11-final-render`; compact input controls retain a single-line label without clipping, and Settings retains its wider slider and unavailable label. Unavailable help remains on the disabled compact slider. Isolated selftest passed. No real permission, Cleaning Mode, key mapping or hardware changes were performed.
- Independent source review confirmed the final unavailable-state polish as ready, with no remaining actionable findings.
- Topic commits: `6e8be638` backup portability/restore, `b403e994` manual Cleaning Mode, `03533f30` compact input layout, `54763fa3` localized concise help, `ca2f07de` keyboard-light independence, `080823a0` spec-aligned CI expectations, and `0ac01dd7` complete natural-scrolling routing regression. This record is the final topic commit.
- Publish only `refactor/settings-refactor-III-part-2` for PR 11, then reply with fixes/counterevidence and resolve the eight reviewed threads. No main merge, PR 10 history rewrite or other stack-branch update. CI on the new published revision is checked separately from local results.

## Follow-up review

- Live GitHub audit confirmed all eight inline threads resolved at published head `103d5fa5`, including CodeRabbit acknowledgements of the fixes and spec-based declines. The review summary also contained an unverified troubleshooting finding: the linked guide includes upstream Vorssaint permission commands. The first-launch guide now labels those instructions and identifies Lattice's release and Developer bundle identifiers, verified against `build.sh`.
- CI run `40063886908` passed build, selftest, packaging and downstream workflow tests, then failed before compiling unit tests: the generator wrote `MouseShortcutBackup.swift` before creating its output directory. Reproduced the same failure with a fresh temporary output directory. Moved the existing directory creation before the first write; clean generation now produces all 206 fixtures, and repeated generation is identical.
- Final regression verification uses a temporary snapshot of the published revision plus these follow-up changes, excluding unrelated in-progress physical music-swipe tests from the shared checkout. No hardware or real preference changes are involved.
- Follow-up verification passed: `./build.sh --test` reported **112,624 checks**, preference cleanup, uninstall-spaces and developer-install isolation all passed. Independent review of the generator and troubleshooting changes returned ready with no actionable findings. Fresh GitHub CI after publication remains separate from these local results.

## Bluetooth follow-up implementation

Approved behavior: sleep handling owns availability; restore-on-wake is disabled while sleep handling is off without clearing its saved value; already owed restoration remains independent. Reuse PR 11's branch. Baseline `65aa438d` includes the separately completed music-swipe work; preserve it.

- Complete: availability follows sleep handling; the restore group is disabled while off without changing the saved restore value. All four toggle combinations use isolated catalog/runtime tests. The new expectation failed against the original OR condition before correction.
- Complete: launch dispatches disabled Bluetooth only when recovery is pending, without reporting it enabled or synchronizing twice when already enabled. A standalone extraction of production `syncAtLaunch` reproduced the skipped recovery before the narrow exception and passed afterward. Production service sync/recovery tests use an inert controller and verify saved preferences, stopped monitoring, already-on Bluetooth, pending recovery with either restore option and no duplicate power writes.
- Full isolated regression passed **112,573 checks**, preference cleanup, uninstall-spaces and developer-install isolation. The preliminary RED run also hit a capture-matching timing threshold under concurrent compilation load; the same screenshots suite passed all 1,832 checks in the final full run. Independent source review returned ready with no actionable findings.
- Developer build and strict signature verification passed. Both isolated Bluetooth rendering runs reported `SETTINGS_RENDERING_OK`; inspected `/tmp/lattice-pr11-bluetooth-render.Zb223H/off/bluetooth.png` and `on/bluetooth.png`. The saved-on restore switch is disabled with sleep handling off and becomes editable when on. The isolated test app reported `SELFTEST OK`. No real Bluetooth power changes or installed-app preference changes were performed.
- Publish this correction on PR 11 and reply to the original Bluetooth thread to supersede its earlier decline. No merge or other stack-branch update.

## New CodeRabbit review at baseline 7450b985

Scope: PR 11 / refactor/settings-refactor-III-part-2 only. Preserve the approved half-inch, first-original-finger-lift commit, two event-driven haptic stages, no position shift, and shared compact/full music layouts.

- Completion cue (4369372457): accepted the defect, refined the proposed correction. Preserve only an accepted completion on the same enabled surface until its existing 0.22-second deadline, including duplicate terminal packets. A blocked stroke alone is insufficient because cancellation also blocks input. Disabled, cancelled, rejected and presentation-mismatched input must clear immediately.
- Hover during a track notice (4369372462): accepted. Refresh cleanup must use the same music-surface predicate as pointer handling. Keep notice-specific fit-in-place geometry separate and unchanged.
- Spoken notice artist (4369372465): accepted. Both capsule and notched strips must announce the artist actually displayed, including notices without live playback.
- Review-summary publication suggestions: accepted. Do not publish identical held/empty frames, but always maintain completion metadata and cancel/rearm expiry even for unchanged frames.
- Initial focused RED reproduced premature completion clearing and redundant publications (5 failures / 71 checks). Added deterministic expiry coverage and production-body refresh regression; final verification pending.
- Verification boundaries: synthetic contacts, fake commands/haptics, isolated presentation fixtures/preferences and a Developer build. No real playback commands, permission changes or hardware mutation.
- Production-body hover RED failed exactly its two preservation assertions (66,333 total checks). Final focused notch regression passed all 66,333 checks with preference cleanup. Tests include completion publication counts, expiry cancellation/rearming, staggered/duplicate release, invalidated completion and hover cleanup on leaving the music surface.
- Developer build and strict deep signature verification passed. An isolated copied bundle reported MUSIC_SWIPE_RESTING_RECEIVERS_OK, MUSIC_SWIPE_RENDERING_OK and SELFTEST OK. Inspected full-music-notch-100.png and full-music-capsule-100.png from /tmp/lattice-pr11-comments-render. Spoken-artist fixes use the existing displayed property directly; live VoiceOver was not exercised.
- Independent whole-diff source review returned ready with no actionable findings. All five findings are accepted; the completion suggestion is deliberately narrowed to accepted feedback rather than generic blocked gestures. Existing oversized service/fixture files receive only localized predicate/wiring edits; new behavioral test modules remain separate. Final diff whitespace check passed. Publish topic commits to part 2 only, reply with evidence, resolve the three inline threads, and leave the other stack branches unchanged.
