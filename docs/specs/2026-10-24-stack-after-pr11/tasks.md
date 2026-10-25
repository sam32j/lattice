# Advance the remaining chain after PR 11 merged

User request: update the stacked settings PR chain after PR 11 was merged into lattice/main. Preserve all reviewed work and keep main unchanged.

## Baseline and method

- Main: 4b94ec2b (PR 11 rebase merge), original part 2: e1c1d04d. Their trees were verified identical before integration.
- Saved original tips under refs/codex/chain-before-11-merge/{part-3,part-4,part-5,final}. No remote history is rewritten.
- A naive merge using the historical common ancestor produced redundant conflicts across already merged code and was aborted without edits. An equivalence bridge records main and original part 2 as parents with their identical tree. Normal forward merges then use the correct content ancestry.
- Part 3: 43eb18f1, part 4: cdaaf793, part 5: 68c129d5, final: 1894d257. Every original tip and merged main is an ancestor of the corresponding updated branch.

## Conflict decisions

- Preserve keyboard-light capability gating and disable retired OCR/color-picker entrypoints.
- Preserve manual Cleaning Mode availability while retaining removal of retired tool entrypoints.
- Preserve music cancellation and the 18/54-point finger-lift contract without restoring retired island capture controls.
- Combine camera/launcher destination support, later localized Clipboard layout, remembered menu selection, new sidebar ordering, and both sets of rendering options.
- Preserve on-demand permission handling, Camera Preview's owning toggle, delayed-action safeguards, protected Cleaner roots and standalone lock-sound initialization.
- Union regression coverage and remove duplicate build source entries. Existing oversized files receive only conflict resolution, not broad refactoring.

## Verification and publication

- Independent source/Git review: ready, no actionable findings. All four branches preserve main's music model/controller/state blobs exactly; ancestry and backup preservation verified.
- Part 3: focused settings/notch suite passed 67,100 checks. Remaining slice checks and final build pending.
- Target chain: #12 -> lattice/main; #13 -> part 3; #14 -> part 4; #9 -> part 5. Mark #10 and #11 as merged in active PR descriptions. Publish only the four remaining branches; do not merge any PR or push main.

## Final integration corrections and results

- Part 4 focused settings/notch checks passed 56,920 checks; isolated screenshots passed 1,828. Part 5 focused settings/notch/screenshots/Cleaner checks passed 58,881; its subsequent destination-guard merge has an identical tree to the tested tip.
- Full integration caught an automatic merge restoring OCR/color-picker shortcut rows. Removed them again in part 4 (7bafec79) and propagated forward. Developer compilation caught a stale captureControls reference in the new music helper; removed the retired guard in part 4 (0f452884). A backup-to-current audit also restored part 4's app-menu opt-out guard (95c46f82), preserving the more complete Settings recovery in later slices.
- An unchanged 200-ms window-layout timing assertion and native font-focus checks failed under load, then passed isolated reruns without relaxing tests or changing their production code. The corrected combined screenshot/window suites passed 2,331 checks.
- Follow-up independent source review examined the automatic merges as well as explicit conflict resolutions and returned ready with no additional findings.
- Final full isolated regression passed all 102,775 checks, plus preference cleanup, uninstall-spaces and Developer-install isolation. Developer build and strict deep signature verification passed. Final source tip 9decbfb4 has the same tree as the corrected e19043e6 tip apart from this task record. No real permissions or hardware state were changed.
- Isolated copied-bundle SELFTEST passed. Remote PRs #12, #13, #14 and #9 remained open at their expected original heads, and remote main remained 4b94ec2b immediately before publication. All four branch updates are fast forwards; publication uses an atomic push. PR base/chain metadata is updated after the push.
