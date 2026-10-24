# PR 10 and PR 11 spec review

Requested: audit merged PR 10 against the agreed specs, then resolve every CodeRabbit thread on PR 11 using the actual requirements rather than accepting suggestions automatically. No merge or unrelated stack changes.

Baseline: PR 10 head `7402d2f3`, merged as `e3873b7a`; PR 11 base `lattice/main`, head `f695e604`. Reuse the clean existing `refactor/settings-refactor-III-part-2` branch in `/Users/samuel/Developer/Lattice`. PRs attached to the chat. The complete six-part branch remains untouched.

## PR 10 audit

Independent read-only review of the original baseline and final review-fix commit found no concrete spec regression in its scope: island settings remain reachable, ALS sizing/protected exceptions persist, automatic glass respects Reduce Transparency, dock action/exclusion behavior and reset confirmations remain, and shared utility ownership is preserved. Later stacked requirements are not treated as failures of part 1. Evidence is source review, not a fresh live UI or hardware test of the merged revision.

## PR 11 threads

- Bluetooth engagement: investigate against the explicit rule that either page toggle owns installation. Do not disable independent restore or change the agreed OR gate merely because restore defaults on.
- Cleaning Mode manual entry points: investigate lost application-menu/Command Bar actions when shortcut registration is off. Manual activation is intended to remain available.
- Per-button backup exceptions: investigate nonportable executable paths in export and local-path preservation during restore.
- Brightness confirmation: preserve the explicit removal of standalone brightness feedback and retain island notices; do not silently reintroduce a HUD.
- Natural scrolling: preserve the explicit opposite physical-swipe behavior between natural/non-natural modes and inspect the complete event normalization path.
- Input slider: verify compact panel width versus Settings width.
- Displays enable switch: evaluate the proposed disable gate against toggle-owned installation; an off switch must remain usable to enable the feature.
- Three-finger drag tooltip: retain the short requested guidance, localize it and keep it accessible.

User approved isolated backup export/restore, manual-action availability, gesture direction and settings-layout checks. Do not change real permissions, key mappings, brightness, Bluetooth, or activate Cleaning Mode during verification. Update only PR 11's existing branch; no merge or other stack rewrites.

## Findings and dispositions

- Thread `PRRT_kwDOVKaLVc6v1fHi`: retain Bluetooth's OR gate. The owner explicitly requested either toggle to count as installed, including restore-on-wake independently; the registered default is not evidence to override that contract. Existing transition tests cover all four toggle combinations.
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
