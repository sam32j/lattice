# PR 28 review fixes

Baseline: `14ba78ab`, service layer of PRs 28, 29, and 30.

## Accepted findings

- Clear shared Homebrew loading indicators when their current read owner is disabled.
- Preserve newer reads, including reads from another enabled owner, when old work completes or is cancelled.
- Clear cancelled tap-trust state and permit a fresh attempt after re-enabling Homebrew.
- Keep media synchronization storage private to its lock-guarded types.
- Place extracted Now Playing documentation on the type it describes.

## Verification

Use the existing service-method fixture boundary. Hold command completion in memory; never execute Homebrew or change real package/trust state. Cover owner cancellation, replacement requests, late callbacks, and tap-trust retry. Compile the app to check private storage access. Request independent review, then propagate the lower-layer commit through both dependent PRs.

Results:

- Loading regression: four expected failures before the fix, then 1,079 settings checks passed.
- Trust regression: four expected failures before the fix; the corrected five affected suites passed 2,036 checks.
- Added successful installed-to-outdated chaining coverage; final settings suite passed 1,087 checks (2,038 distinct checks across affected suites).
- Independent review found no actionable issues; diff whitespace checks pass.
- Shared-checkout compilation was interrupted by another chat switching branches. Exact tested changes were restored from stash into the isolated PR-review worktree. Fresh isolated developer compilation passed without installing or launching the app.

Local verification is complete. Publish these fixes, propagate them through dependent PRs 29 and 30, and resolve the review threads; GitHub CI is checked separately after publication.
