# PR 19 review follow-up

Baseline: fix/settings-followups-part1 at 68ace28eeb8fc685f7f88153b426a69b92c32803, isolated checkout at /Users/samuel/.codex/worktrees/pr19-review/Lattice. PR base lattice/main. Preserve the user's stacked part-2 work.

- Evaluate all four CodeRabbit inline findings against actual source and approved contracts.
- Verify OCR unavailable/empty fallback selection through generated production outcome/recognition code with synthetic Vision/barcode responses; preserve QR and successful-text paths.
- Verify capture panels are visible but pointer-inert, with a flushed transition, before focus release using the existing isolated capture contract.
- Give the menu-icon switch an accessible name without altering the visible row or binding.
- Preserve commit-on-finger-lift for native swipes. The installed Apple SDK NSEvent.h documents ended as physical success, cancelled as failure, and isComplete as animation teardown. Assess the suggested animation delay against that contract; cover zero-progress and cancelled/late native endings.
- Run affected suites and a Developer build serially. No real grants, app activation, player control or hardware changes.
- Independent review, topic commits, push only the PR 19 branch, and reply/resolve each thread with evidence. No merge or part-2 branch change.

Review decisions:
- Fix the OCR result-classification, capture-panel input handoff and menu-toggle accessibility findings.
- Reject waiting for native swipe animation completion: installed AppKit NSEvent.h lines 502–513 distinguishes successful physical `.ended` from `.cancelled`, and defines `isComplete` for animation teardown. Existing model/controller tests require one action at accepted lift. Waiting would contradict the approved timing contract; cancellation is already separate.
- Inspect the 20 additional comments: 18 are approvals/refuted concerns; two low-value suggestions identify three equivalent OptionSet membership expressions. Prefer isDisjoint for clarity and verify existing gesture checks.
- Docstring coverage warning is a generic review threshold, not a correctness defect. No unrelated comment expansion.

Isolation: the main checkout had concurrent Dock edits. Removed only this task’s test/doc edits and stopped only its test process before continuing in the separate worktree. Did not restore or switch the main checkout again. App-managed creation could not resolve the repository ref, so this is a standard Git worktree; all subsequent commands use its explicit path.

Final verification:
- Regression run failed exactly the new capture-input and partial-OCR assertions (2 of 2,788 checks). No unrelated failures.
- Final settings, screenshot and notch suites passed: 59,270 checks (920 settings, 1,868 screenshots, 56,482 notch).
- Developer app build and strict signature verification passed. No installation or normal app lifecycle launch.
- Independent spec/source/SDK review: ready, no actionable findings. Reviewer confirmed the native swipe rejection rationale.
- git diff --check passed. Full unrelated suite not repeated; prior PR-head CI was green before these changes. Fresh remote CI remains separate from local verification.
- Topic commits: 161a81f2 OCR, f33b918d capture input, dfce820d accessibility, 19934c65 native contract/OptionSet cleanup.
- Deliver only fix/settings-followups-part1 to PR 19. Record fixed/rejected findings in their respective threads, resolve those four threads, and leave the main checkout and PR 20 unchanged.
