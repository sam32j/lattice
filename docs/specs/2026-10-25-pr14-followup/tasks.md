# PR 14 follow-up review

Request: address new CodeRabbit comments against the approved product contracts. Baseline 2fd1521c, part 5. PR 13 has merged; align with lattice/main 958182c7, whose tree is identical to the prior parent. Preserve linear history and the final PR's independent changes.

- Screen Recording loss: valid. Simple Switcher mode does not capture previews; keep it enabled on Screen Recording loss while still revoking preview modes, Dock Preview, and required Accessibility activation.
- Cleaner scan/removal consistency: valid. Filter protected-descendant roots from leftovers, ordinary logs and the DiagnosticReports aggregate before offering them; retain final removal checks.
- Capture privacy: valid. Visual preview identity must remain true during a new capture session so the frozen image excludes it. Keep capture-session keyboard suppression at both screenshot and recorder preview consumers.
- Dialog levels: valid, refine the proposal to preserve the established no-owner workspace fallback. Raise dialogs above their actual owner; retain the below-Liftoff band for pins/editors and their dialogs.

Verification uses isolated preferences, temporary filesystem fixtures, generated production-method doubles, and unshown native window-level checks. No real permissions, hardware, captures of user content or cleanup actions. RED/GREEN, review and publication pending.

## Evidence and disposition

All four new findings accepted; no product-contract changes. The modal-level suggestion was refined to preserve the no-owner workspace fallback rather than lower it to the modal-panel band.

- RED: settings regression reproduced Simple Switcher revocation; screenshot/notch/Cleaner regressions reproduced the remaining bugs (12 failures). Existing keyboard checks continued to protect selection-session input.
- GREEN: `./build.sh --test-suite=settings --test-suite=cleaner --test-suite=screenshots --test-suite=notch` passed 58,910 checks (settings 859, Cleaner 84, screenshots 1,842, notch 56,125). Generated fixtures run the actual screenshot and recorder keyboard monitors and shortcut matching, plus actual island visibility/exclusion properties.
- Independent source/spec review: `/root/review_followup`, no actionable findings. No build or system actions performed by the reviewer.
- Developer build passed; `codesign --verify --deep --strict` passed. Self-test in a disposable copy with a unique preferences domain passed (`SELFTEST OK`). A sandbox-extension warning was emitted for the temporary copy; self-test exited successfully.
- Fix commits: 811133d0 (Switcher), a3bd90dc (Cleaner), 5a28228d (capture exclusion/input), 01a6e2c2 (modal levels).
- Publication: preserve linear history and advance the dependent final slice with its independent patch unchanged. No merge or main mutation. GitHub CI/re-review remains separate from local validation.
