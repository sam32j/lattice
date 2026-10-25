# Lattice

Lattice is Samuel Ji's unofficial GPL-3.0-or-later downstream distribution of
[Vorssaint](https://github.com/vorssaint/vorssaint-utils). It has its own app
icon, bundle identity (`io.github.sam32j.lattice`), helper identities and release
feed. Original copyright/license notices remain as attribution.

## Branches and upstream updates

- `main`: upstream main only, updated by fast-forward. Never put personal changes here.
- `lattice/main`: the default branch, with personal changes and downstream automation.
- `downstream-backups/<old-commit>`: immutable recovery refs created atomically before a successful automated rebase.
- Existing screenshot submission branches and upstream PRs remain separate.

Every six hours, or when manually dispatched, **Lattice downstream** fetches
upstream main and the latest published stable upstream tag. It rebases the
personal commits onto that release in a disposable clone. Main and personal
refs are pushed atomically with explicit expected-old-SHA leases. Conflicts,
diverged tracking main, rewritten upstream tags, missing provenance or concurrent
edits stop the operation. No conflict resolution is guessed.

The initial snapshot once included upstream commits beyond the stable release.
That historical hold is not the current release state: `Downstream/release.json`
records the adopted upstream tag and commits. The sync workflow holds a rebase
when a proposed stable release predates the preserved base rather than dropping
those commits. Read its result and current provenance before publishing.

Schedules require this workflow on the repository's default branch and Actions
enabled for the fork. If GitHub refuses a push that changes workflow files,
configure optional repository secret `LATTICE_SYNC_TOKEN`: a narrowly scoped
GitHub App token or fine-grained PAT with repository Contents and Workflows
write access. Otherwise the workflow uses `GITHUB_TOKEN` with Contents write.
Do not grant the sync token access to upstream.

## Versions and release activation

`v3.4.1-d.1`, `v3.4.1-d.2`, then `v3.4.2-d.1` preserve the upstream version and
order downstream revisions numerically. The GitHub release is stable in the
fork's release universe; `d.N` does not hide it behind the beta preference.
Upstream-only tags cannot be selected by an installed downstream build.

`Downstream/release.json` records the upstream tag, its peeled commit, the adopted
base and downstream revision. Builds stamp the full version, provenance and
upstream build number plus downstream revision into the bundle. For a new
personal release on the same upstream base, increase `revision`, commit and push
to `lattice/main`, then run **Lattice downstream**. New upstream releases reset
the downstream revision to 1. Never move an existing tag or replace its assets.

Publication is disabled until the repository variable
`LATTICE_RELEASES_ENABLED` is explicitly set to `true`. Before enabling it:

1. Set `DownstreamIdentity.signingTeamID` to your own Developer ID team and review/commit the public pin. The upstream team is rejected.
2. Create the protected GitHub environment `lattice-release`, restrict it to `lattice/main`, and configure required reviewers as desired.
3. Add environment secrets `LATTICE_SIGNING_CERT_P12` (base64 Developer ID Application certificate and private key), `LATTICE_SIGNING_CERT_PASSWORD`, `LATTICE_NOTARY_API_KEY_P8` (base64), `LATTICE_NOTARY_KEY_ID`, and `LATTICE_NOTARY_ISSUER_ID`.
4. Confirm the adopted base matches the recorded published stable tag for a normal release. The release tool also supports an explicit `allowSnapshotRelease` override; do not infer release eligibility from old snapshot documentation.
5. Enable publication and dispatch the workflow. It tests before importing signing secrets, revalidates the source, builds, selftests, verifies the exact signer/bundle, notarizes the app and DMG, checks uploaded asset digests, then publishes.

The workflow calls the reusable release job directly. It does not rely on a
bot push/tag triggering another workflow. Existing tags/releases are not reused;
an interrupted draft remains for inspection. Inspect its tag, exact commit,
assets and workflow failure before recovery. Prefer a new downstream revision
over replacing an existing public artifact. Enable GitHub immutable releases for
additional repository-level protection if desired.

## Local builds and data

```sh
./build.sh
./build/Lattice --selftest
./build.sh --dev
./build/LatticeDeveloper --selftest
./build.sh --test
bun test Tests/downstream-sync.test.ts Tests/lattice-release.test.ts
```

Builds use Xcode/Command Line Tools. Downstream automation and its tests use bun; generated Swift tests use Python through uv when available. `--install` is an explicit
local installation action; it replaces only the corresponding Lattice bundle.
No installation is performed by ordinary build/test commands.

`Lattice (Developer)` uses `io.github.sam32j.lattice.dev` and never self-updates.
Lattice has separate preferences, cache/history, macOS grants, login registration
and closed-lid permission rules. No existing data or grants are migrated or
deleted. External integrations that target the old bundle's cache need retargeting.
The stable and developer rules are named `lattice-clamshell` and
`lattice-developer-clamshell`; sudo ignores rule filenames containing periods.
The fan hardware ownership lock is intentionally shared to prevent simultaneous
controllers; authenticated helper access still requires the fork's configured team.

An empty signing pin denies update installation and authenticated fan-helper
access. Local ad-hoc signing can verify a build but does not provide persistent
permission grants or Developer ID distribution. Apple Development signing is
not a substitute for notarized Developer ID signing. Never weaken updater or
helper checks to make unsigned builds install.

Upstream donation/community links remain explicitly attributed. Optional temporary
screenshot and recording links use upstream-operated sharing services. Feedback
opens an issue draft in sam32j/lattice. These services do not supply Lattice updates. Developer screenshot and recording endpoint overrides use
the Lattice developer bundle ID.

## Conflict recovery

Inspect the failed run's conflicting paths. Fetch both remotes and work on a
separate branch. Rebase from the recorded `baseCommit` onto the published tag,
resolve each conflict intentionally, and run focused tests plus build/selftest.
Update the provenance and version before integrating. If a lease failed, fetch
and include the concurrent personal work; never retry with an unconditional
force push. Use the backup ref to recover the pre-rebase history when needed.
