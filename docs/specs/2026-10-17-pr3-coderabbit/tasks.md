# PR 3 CodeRabbit Follow-up Implementation Plan

**Goal:** Evaluate and address all CodeRabbit findings on PR #3 with focused fixes and behavior coverage.

**Architecture:** Keep the current capture and recorder modules. Correct shared availability/shortcut contracts, make capture and pin event handling idempotent, and localize added workflow controls through the existing language infrastructure.

**Tech Stack:** Swift, AppKit/SwiftUI, the existing generated-source test harness, GitHub PR tools.
---

## Baseline and boundaries

- PR: https://github.com/sam32j/lattice/pull/3
- Branch: `feat/screen-capture-improvements`; initial clean baseline `6c68c5c1e06ad9c3ccc549070d56caf56f06d654`. A concurrent documentation-only commit `04901a32aa68f80412ac9c0fa8364ad6f3f1d38c` is preserved on the same branch.
- CodeRabbit review: https://github.com/sam32j/lattice/pull/3#pullrequestreview-5559010726
- Nine inline findings, one outside-diff finding, fifteen minor findings, and two test notes.
- Continue the user's focused-fix preference for existing oversized files. New handwritten files remain below 300 lines.
- Review data is advisory: verify current code, preserve intentional behavior, and record reasoned rejections. User approved a recording-specific 5 / 10 / Unlimited segment, defaulting to Unlimited, and keeping the current chooser shortcuts.
- New regressions exercise availability changes, permission reporting, settings identity, native annotation keyboard behavior, shortcut validation/reset, capture/gesture routing, bounded text undo/measurement, and recorder delivery ownership.

## Work and dispositions

1. Companion bindings/session bookkeeping and derived availability reads: reproduce install/uninstall and permission reporting; fix runtime transitions, bulk paths, and orphaned-shortcut migration.
2. Recording retention: implemented recording-specific 5 / 10 / Unlimited retention, default Unlimited. Screenshot age cleanup only affects screenshots. Only owned cache copies are removed. External exports remain intact.
3. Capture focus: remove pre-capture activation and use nonactivating selection panels; preserve intentional click/gesture activation.
4. Multi-window pixels: reject ambiguous packed ScreenCaptureKit output in favor of the existing per-window composite; verify compositing with known image fixtures.
5. Pin hover focus and duplicate gesture delivery: make hover passive, consume handled local events, and prevent dual raw/magnify application without losing first-pinch behavior.
6. Numeric capture shortcuts: retain intentional removal of 1–4; document R toggle and clickable tool selection, correct stale test contracts.
7. Annotation keyboard handling: modifiers alone must not commit; Command-Return and Escape retain commit behavior.
8. Sidebar identity: assign synthetic section IDs outside enumerated group IDs and verify uniqueness.
9. Compact shortcut validation/reset: share conflict/takeover decisions with the regular recorder, localize errors, and never silently disable a whole feature to reset an unrelated shortcut.
10. Bounded text: preserve wrap width on styling; discard drafts without losing redo or leaving stale dirty/undo state.
11. Workflow localization: cover all supported languages for screenshot/recorder settings, guide labels/plurals, full-screen F hints, indicator tooltips, and shortcut controls.
12. Recorder delivery: skip redundant stashing after low-space stops; retain pending take ownership until asynchronous delivery completes.
13. Preview anchoring: pass the actual pin frame when reopening a preview.
14. Onboarding: count visible installable features and deselect hidden screenshot companions together.
15. Test notes: replace companion source-only checks with production-method behavior tests; restore shown-pin drag visibility/chrome assertions.

For each coherent change: establish a meaningful failing regression, implement the focused correction, and rerun affected suites. Reuse existing behavior coverage where sufficient; do not create tests mirroring implementation.

## Verification and finish

- Run relevant suites, then standard app build/selftest, signature verification, and diff checks. Record actual results and limits of headless tests.
- Obtain independent review of final changes under the implement skill and resolve substantiated issues.
- User authorized publishing and review replies: commit only task changes, push PR branch, reply to each inline thread with evidence, summarize remaining review notes, and resolve only addressed threads.

## Execution record

- Review inventory captured in `/private/tmp/lattice-pr3-review.json`.
- Production fixes implemented across all listed areas; affected regression suites are in progress.
- Red evidence: native Command+Shift modifier regression reproduced premature annotation commits; recording retention regression reproduced deletion of recordings by screenshot age.
- Independent review found two additional defects in the initial fixes: reset cleared an existing authorized takeover; empty accepted-size text drafts erased redo. Both corrected with behavioral regression coverage.
- Regression boundaries: production methods generated verbatim against isolated preferences, controlled recording callbacks, inert selection surfaces, real pixel buffers and native unordered AppKit text/pin views. No physical capture or trackpad interaction claimed.
- New handwritten Swift files are below 300 lines. Existing oversized files receive focused edits under the user's earlier exception.
- Final independent review: ready, no unresolved correctness defects. Review fixes also cover mixed-stream trailing gesture packets and close confirmation for uncommitted new text.
- Broad affected run: 33,020 of 33,022 checks passed; two stale English source-label expectations were corrected to use localized labels. Full standard Swift suite now running on final code.
- Downstream workflow validation: `bun test Tests/downstream-sync.test.ts Tests/lattice-release.test.ts` passed all 13 tests and 48 expectations.
- Numeric-shortcut disposition: removed the unused numeric metadata/helpers and their misleading metadata-only test. Production chooser remains R/click controlled.
- Reset disposition: reject a conflicting reset with a localized error instead of rewriting or disabling another feature. Existing authorized takeover of an unchanged shortcut remains preserved.
- Final standard verification passed: `./build.sh --test` with 116,857 checks, preference cleanup, uninstall-spaces, and developer-install isolation checks. Updated three older migration expectations to honor parent-derived companion availability.
- Release verification passed: `./build.sh`, `./build/Lattice --selftest` (`SELFTEST OK`), and `codesign --verify --deep --strict --verbose=2 build/stage/Lattice.app` outside the restricted sandbox. The sandbox-only signature check was inconclusive; the unrestricted check confirms a valid on-disk signature and designated requirement.
- Release compilation caught a nonexistent start-string property; the caller now uses the existing localized `startButton`, and recorder preparation fixtures use the real `RecorderFeatureStrings`.
- Environment: arm64 Mac, macOS 27.2. Native offscreen AppKit text and pin windows, pin drag visibility/chrome restoration, and synthetic gesture sequences were exercised. Physical trackpad behavior, foreground focus across applications, and real desktop capture were not manually exercised.
- Concurrent documentation and release-automation commits on this branch are preserved; they are separate from the task-owned commit.
- Local implementation and verification complete. Authorized branch outcome: commit/push these fixes and post the reviewed dispositions on PR #3.
