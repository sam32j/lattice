# Video Downloader progress and edited-search reliability

Baseline: fix/settings-followups at a18b712e, clean. Continue in the primary checkout without a worktree. User requests stable progress and Search after any URL edit. Provided reproduction: https://www.youtube.com/watch?v=6f7ojkd4_Wc.

## Evidence

- Baseline downloader suite: 45 checks passed. Its existing service fixture wrote a fixture URL to the clipboard and played a completion sound; subsequent tests inject both boundaries to avoid those effects.
- Live metadata-only inspection returned about 11.7 MB. The existing 64 MB metadata allowance accepts it; retain that earlier fix.
- Selected streams were HLS video 616 (no fixed byte size) and separate HTTPS audio 251-20. A bounded yt-dlp --test download into a temporary directory produced 100% at HLS fragment 0/59, then 0.8% at fragment 1/59, then a restart near 0% for audio. This confirms that per-fragment/per-stream percentages cannot be forwarded as whole-job progress.
- Verified the before_dl stream projection and progress-template fields against the installed tool and upstream yt-dlp source. Recorded only the plan/progress lines as a fixture, without signed media URLs or output paths.
- Dynamic Island bound the field directly to link without calling linkChanged; its Clear action depended only on the presence of old results. Existing settings-view callbacks alone did not protect the shared state.

## Implementation

- Split oversized request/info and service files into cohesive modules before behavioral edits. Keep all handwritten modules below 300 lines where edited substantially; the existing large island view receives only localized button-condition changes.
- Capture the selected stream plan before transfer. Fix weights from known sizes when all are available, otherwise use equal stream work units. Prefer HLS completed-fragment ratios over unstable byte estimates. Each stream keeps its own high-water mark; whole-job progress therefore does not regress on retries or estimated-size changes. Audio consumes its remaining share instead of resetting the bar.
- All planned streams must report finished before the finishing phase. Cap numeric transfer progress at 99% until validation/publication succeeds. Detailed bytes are cumulative; omit incomplete total/whole-job ETA rather than displaying a partial stream as a job total.
- Observe URL edits in the model, idempotently with existing view callbacks. Idle edits discard prior results and invalidate thumbnail callbacks. Editing during metadata lookup cancels/invalidate that lookup; old results cannot reappear. Editing during download preserves that captured operation and the newer URL, and offers Search disabled until the job ends. Old result cleanup must not erase the newer draft.
- Search/Clear uses the shared current-search-result state. Clear is disabled during a running job. Dependencies, quality selection, file verification, non-overwriting publication and process cancellation retain their existing behavior.

## Verification

- Regression for direct edits failed before the model observation fix.
- Progress regressions cover revised estimates, HLS initialization fragments, retries, split streams, audio-only downloads, missing/nonfinite percentages, byte aggregation, known-size weighting and the recorded URL events.
- Service fixtures cover inspect/download/probe/publication and the actual published progress sequence. Input fixtures cover clearing/replacing URLs, stale inspection cancellation and preservation of a draft edited during download.
- A failed older download after a URL edit also clears stale Retry controls while preserving the new draft. Its regression failed before the cleanup correction. Idle edits advance the generation so old thumbnail responses cannot repaint.
- Final checks passed: harness 521, Video Downloader 67, settings 1,048; total 1,636. Developer build and strict signature verification passed. Independent source review, including the final failure/thumbnail deltas: ready, no actionable findings.
- Live verification is a metadata lookup and bounded tool smoke test, not a full-quality download of the entire video. No dependencies were installed, credentials read or download history modified by live checks; test downloads live in temporary directories.

Publication: commit the fixes and verification record, push fix/settings-followups and update PR 21. No merge or base change.
