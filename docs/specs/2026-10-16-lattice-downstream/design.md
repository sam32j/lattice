# Lattice downstream distribution

Approved 2026-10-16: independent Lattice identity, `io.github.sam32j.lattice`,
downstream tags `vX.Y.Z-d.N`, and `lattice/main` as the personalized/default
branch. Keep `main` separate for upstream tracking. Preserve existing screenshot
customizations from `067c3fd23b45162e4b9d26bd07601c6ac2c6ae03`.

## Branch and release flow

The scheduled workflow lives on the default `lattice/main` branch. `main`
fast-forwards to upstream main without local patches. A temporary checkout
rebases personal commits onto the published stable upstream release commit.
Record the precise upstream base, tag and downstream revision. Do not release
unreleased upstream main under a stable upstream version number.

Conflicts abort the temporary rebase without changing remote refs. Diverged
tracking history, missing refs, invalid metadata, rewritten upstream tags and
concurrent pushes fail explicitly. Publish ref changes atomically with explicit
expected-old-SHA leases. Never resolve conflicts automatically or move published
release tags. The workflow invokes its release job directly so bot pushes do not
depend on recursive GitHub Actions events.

## Identity and trust

Use a distinct app/icon, `.dev` identity, helper IDs, preferences and release
feed. Keep upstream attribution and avoid automatic settings migration. The
installed upstream app and its data remain untouched. Use `vX.Y.Z-d.N` for tags
and user-visible versions; treat `d.N` as a downstream revision rather than a
beta channel. Record the upstream tag/SHA and downstream revision separately.

Pin the fork's own Developer ID team for updater and privileged helper checks.
Never accept any Apple signer or reuse the upstream maintainer's team. Missing
trust configuration prevents installation; missing signing/notary credentials
prevents publication. Local builds may use ad-hoc signing for verification but
cannot pass release gates. Apple Development signing is not notarized Developer
ID distribution.

## Validation and rollout

Validate real Git sync outcomes with disposable bare repositories, including
conflicts and concurrent edits. Validate version ordering/channel selection and
installer identity requirements through their public interfaces. Build and
selftest the final app; inspect final bundle, helpers, assets and provenance.
Retain the original checkout's untracked release plan unchanged.

Implement in small commits. The current request authorizes establishing the
approved branch/default layout; publishing a downloadable release remains gated
on signing setup and a release decision.
