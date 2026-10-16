# Lattice Downstream Implementation Plan

**Goal:** Preserve Samuel's customizations while establishing a safely synchronized, independently branded, fork-updating distribution.

**Architecture:** `main` tracks upstream; `dev-build/main` owns personal patches and automation. Disposable rebases and atomic leased pushes protect remote history. Signed/notarized releases use Lattice identity and downstream revision tags.

**Tech Stack:** Swift/AppKit, Bash/zsh, Python standard-library integration tests through uv, GitHub Actions, codesign/notarytool.
---

## Baseline and acceptance

- [x] Inspect original checkout, branches, remote metadata, updater, signing and existing release notes.
- [x] Preserve original untracked files and all screenshot commits in isolated worktree.
- [x] Approve identity, version scheme and branch/default layout.
- [x] Existing updates suite: 869 checks passed on source `067c3fd2` using Xcode beta.
- [ ] Agree test interfaces through pending choice dialog before writing tests.
- [ ] Complete independent review, final checks and approved remote branch/default setup.

The starting upstream snapshot `794608a5` already contains 46 commits after
stable `v3.4.1` (`aea106cb`). Do not drop those commits. Initial builds must
record this snapshot and releases remain blocked until a stable upstream tag
contains it. This protects existing behavior and truthful provenance.

## Task 1: Independent app identity and update trust

**Files:** `Resources/Info.plist`, `Sources/Vorssaint/Core/AppInfo.swift`,
`Sources/Vorssaint/Services/FanControl/FanControlXPC.swift`,
`Sources/Vorssaint/Services/Update/UpdateInstallerSupport.swift`, `build.sh`,
new `Downstream/` configuration/assets, `Tools/lattice-*.sh`,
new `Tests/DownstreamUpdateTests.swift`.

1. Test `v3.4.1-d.2 > v3.4.1-d.1`, stable-channel eligibility and rejection of upstream-only versions.
2. Observe failure with `./build.sh --test-suite=updates` before implementation.
3. Add strict downstream version/channel policy and build-time pinned fork identity.
4. Add public trust helper tests for missing/invalid/upstream team IDs and proper app/DMG requirements.
5. Keep existing trust checks intact, substituting only the fork's explicit pin.
6. Build distinct native geometric icon resources; keep attribution.
7. Run affected suites and commit identity/update changes separately.

## Task 2: Transactional sync command

**Files:** new `Tools/sync-downstream.sh`, `Tests/test_downstream_sync.py`,
`Downstream/release.json`.

1. Test a clean upstream advance and preservation of a personal file using temporary bare repositories.
2. Run `uv run --no-project python Tests/test_downstream_sync.py`; observe missing-command failure.
3. Implement disposable worktree rebase and explicit old-SHA leases on atomic main/personal pushes.
4. Add and exercise conflict, diverged-main, missing-branch, concurrent-push and already-current cases, one behavior at a time.
5. Hold release when the stable tag predates the recorded upstream base; reject rewritten provenance.
6. Commit sync and its tests.

## Task 3: Fork workflows and release gates

**Files:** new `.github/workflows/downstream.yml`,
`.github/workflows/lattice-release.yml`, `Tools/release-lattice.sh`,
`docs/LATTICE.md`; narrowly adjust existing CI/issue workflow fork guards where necessary.

1. Schedule sync on the approved default branch with concurrency and least permissions.
2. Invoke a reusable release job directly after successful sync; avoid relying on bot pushes triggering another run.
3. Validate exact source/ref/version/provenance before access to protected signing credentials.
4. Build, selftest, sign, notarize and verify app/DMG against the same configured fork pin.
5. Publish only a new, complete fork release with checksums; reject existing version/tag and never replace published assets.
6. Add manual dispatch for reviewable downstream revision releases; document secret/environment setup and recovery.
7. Validate syntax, refusal paths and workflow contracts, then commit.

## Task 4: Final verification and integration

1. Run full tests, optimized app build/selftest and final bundle identity/resource checks.
2. Independently review exact diff against `067c3fd2`; address actionable findings and rerun affected checks.
3. Record evidence and material limits here.
4. Push `dev-build/main` without changing upstream PR branches, then set it as fork default as approved.
5. Verify remote branch/default state and original checkout preservation. No downloadable release until distribution credentials and a release decision are present.
