# PR 13 CodeRabbit review

Baseline 47884eb0, part 4. Review automated suggestions against the approved settings contract; publish only this slice and preserve the stack.

- Lost app-menu choice: valid defect, rejected automatic fallback proposal. The user approved remembering the chosen destination while unavailable, restoring it when available, and never switching surfaces automatically. Removed destructive reconciliation from the model and its callers; the picker reads its observed preferences directly. RED reproduced the lost-selection assertion; GREEN passed 758 settings checks, including explicit opt-out and target recovery.
- Duplicate island destinations: valid defect, use the owner's requested removal rather than synchronize redundant controls. Moved the already approved part-6 removal of Launcher Grid, Clipboard, Files and Scratchpad rows into their owning part-4 slice. Capture preview/history routing remains. Section focus now recognizes captures as the sole destination in this section.
- Tests use isolated preferences and service doubles. No real hardware or permission changes. Independent review and Developer build pending.
- Independent source review returned ready with no actionable findings. Developer build and strict signature verification passed. Final whitespace check passed. No automatic target fallback was added.
