# Lattice Naming Implementation Plan

**Goal:** Make Lattice the active source, package, build, helper and UI identity while preserving attribution and installed-data compatibility.

**Architecture:** Relocate Sources/Vorssaint to Sources/Lattice and update all active consumers together. Rename private compiled symbols, build flags and packaged resource filenames consistently, keeping the production/developer bundle IDs and signing identities stable. Retain original copyright/license notices, upstream URLs/provenance, historical records and compatibility wire values deliberately.

**Tech Stack:** Swift, C, Perl, zsh, Python (uv), TypeScript (bun), GitHub Actions.
---

### Task 1: Baseline and compatibility inventory
- Baseline: origin/lattice/main 83d9b0d4 after merged #9; separate branch refactor/lattice-naming; clean checkout before work.
- Inspect Package.swift, build.sh, Resources/Info.plist, Sources/Vorssaint/Core/{Defaults,SettingsBackupSupport,BundleMigration,DownstreamIdentity}.swift and helper/plist consumers.
- Preserve GPL/SPDX/copyright lines; LICENSE; actual upstream service URLs/account identities; existing preference keys, serialized backup keys, saved icon raw value, saved audio choice IDs, scratchpad task scheme, shell-environment compatibility marker, legacy migration literals and security denylist domains.
- Do not alter real permissions, data, signing setup, hardware or other feature worktrees. No release or main push.

### Task 2: Source and build naming
- Move Sources/Vorssaint to Sources/Lattice, Resources/Vorssaint.entitlements to Resources/Lattice.entitlements and Resources/com.vorssaint.utils.fan-control.plist to Resources/io.github.sam32j.lattice.fan-control.plist.
- Update active source paths in Package.swift, build.sh, Tests/generate_sources.py, Tools scripts, .github workflows/config and current contributor docs. Leave historical docs/specs/changelogs intact.
- Rename compiled private Vorssaint/vorssaint/VORSSAINT symbols consistently across Swift/C/Perl, including Now Playing exported names and VM statistics interop. Match metadata readers/writers and helper template rewriting.
- Validate path existence, syntax, Swift package metadata and remaining-reference audit before compiling.

### Task 3: Branding and notices
- Replace active UI, accessibility, panel, process, queue and diagnostic names and localized copy with Lattice.
- Update SUPPORT.md and issue/PR templates to downstream support links. Keep upstream project/funding/provenance facts accurate. Preserve all applicable copyright and license notices.
- Add a concise rename/change notice with date and document intentional legacy identifiers. Keep old stored formats intact without resetting preferences.

### Task 4: Verification and review
- Run existing isolated full suite via ./build.sh --test; use failures to find missed naming consumers, not change functional expectations mechanically.
- Build Developer and production variants serially, verify signatures and packaged identifiers/resources. Do not install/start services. Run only isolated self-test using disposable bundle identity.
- Verify Now Playing exported names against script without invoking live playback; verify helper plists/bundle metadata and developer isolation.
- Independently review full diff, compatibility values, attribution preservation and tests. Reconcile any valid findings and rerun affected checks.
- This mechanical rename does not add implementation-mirroring tests; use existing behavioral tests and explicit structural/package audits.

### Task 5: Delivery
- Keep the branch local for review unless separately authorized to publish this new rename branch. Report exact verification and intentional remaining upstream/legacy references.

Status: audit completed; implementation and checks pending.

## Final disposition and evidence

Implementation complete locally. Original copyright/SPDX lines verified unchanged by a full tracked-text baseline comparison. GPL LICENSE, upstream links/guards and historical records retained. README contains the dated modification notice; docs/LATTICE-NAMING.md explains the compatibility exceptions.

- First full run exposed namespace cleanup mismatches, own-bundle safety checks using legacy-only IDs, and a shell marker assertion; corrected at their actual consumers. A timing-sensitive deferred-window callback also failed in that run under compilation load, then passed unchanged in the complete final rerun.
- Final Swift suite: **102,811 checks passed**. Preference cleanup and uninstall-spaces checks passed. The Developer-install fixture initially had mechanically duplicated historical sibling names; restored the original fixture unchanged and reran it successfully for both variants. No real installation occurred.
- `./build.sh --dev`: passed. Strict signature verification passed; disposable-identity self-test passed (`SELFTEST OK`, temporary-copy sandbox-extension warning with successful exit). Verified Developer ID `.dev`, metadata reader/writer keys, bundled resources, helper plist/Mach service and the three renamed Now Playing exports.
- `./build.sh`: optimized production build passed. Strict signature verification passed; verified production ID, executable/resources/metadata, helper registration and Now Playing symbols. No install, release, signing-setup change or app lifecycle start.
- Swift package manifest, shell/Python/Perl syntax, workflow YAML and bun compilation of release tools passed. Active source/build path audit found no old source-root/flag/library consumers; intentional upstream-only workflows and historical records remain original.
- Independent whole-diff source/compatibility review by /root/review_followup: ready, no remaining actionable findings. Its two valid findings about real upstream release lookup and an existing showcase filename were fixed by retaining the real upstream-only workflow definitions. Final doc/support review also passed.
- No additional tests that merely mirror a text replacement were added. Existing behavioral tests and resource/build boundaries provide coverage. Legacy backup/icon/audio/task-link values, both shell markers and privileged helper coordination paths are preserved.

Branch: refactor/lattice-naming, based on merged main 83d9b0d4. All rename changes remain local and uncommitted; no PR, remote branch, main mutation or other feature-worktree edit. Existing feature branches will need to incorporate this rename when they next sync with main after it lands.

## Main update and publication

Updated the naming work from 83d9b0d4 onto lattice/main 4d4d0752, incorporating the merged Video Downloader work. Preserved the exact original staged rename under refs/codex/lattice-naming-uncommitted-backup before rebasing the local base.

Resolved the build test-source-array conflict by keeping the incoming downloader sources with Lattice paths. Relocated all ten incoming downloader source/probe/UI files; renamed their Developer flag and isolated test namespaces. All 16 new files match incoming main after those transformations; saved rename contents outside incoming main paths are byte-identical. No unresolved conflicts remain.

Fresh verification on the updated base: 103,219 Swift checks passed; preference cleanup, uninstall-spaces and Developer-install isolation passed. Developer build and strict signature verification passed. Independent source/compatibility review found no actionable issues. No dependency installation, real permissions or hardware state changes. The earlier production-build result belongs to the pre-downloader naming snapshot and was not repeated for this base update.

The user subsequently authorized committing/publishing this naming branch and opening its PR, followed by a separate fix branch and PR stacked on it. Keep the requested settings/capture fixes out of the naming PR.

## Corrective semantic audit after PR review

The earlier doc/support review was insufficient. The user identified semantic errors that mechanical naming and build checks did not catch.

Acceptance: distinguish Lattice from upstream Vorssaint; current docs and permission prompts must match implemented features and ownership; preserve copyright, compatibility wire values, actual upstream endpoints and dated history.

Confirmed and corrected:
- Upstream attribution was incorrectly relabeled Lattice in the downstream guide and release-assurance wording; the root reset instructions also conflated identities.
- Permissions described removed first-run onboarding, standalone Color Picker UI, outdated settings locations and automatic feature reactivation after a grant. Rewrote against FeatureCatalog, PermissionRevocationPolicy, permission controls and current service owners.
- Removed WhatsApp cleanup remained in 70 localized purpose strings and five base plist values. All 14 locales now match current file/download/capture/Cleaner uses; localized Bluetooth/audio purposes also match current base copy.
- Support links still targeted upstream; feedback dependencies, Shelf branding, price-list provenance and the README full-upstream-feature claim were stale.
- Lyrics request metadata named Lattice but linked upstream; corrected only its project URL. Actual sharing and price-list upstream endpoints remain unchanged.
- Added an explicit provenance banner to the historical upstream changelog without rewriting its release entries.

Verification completed:
- Base and all 14 localized plists parse successfully. Permission keys, localization keys and non-permission metadata are unchanged. All 75 retired WhatsApp purpose strings are gone.
- Current documentation local file links resolve; product/upstream mislabels and obsolete permission walkthrough/reset/reactivation instructions were checked explicitly.
- Affected settings and notch suites: 57,354 checks passed.
- Developer build and strict signature verification passed. Audited the built app’s Developer bundle identity and all 14 packaged permission localizations.
- Independent source review found the stale downstream support link, root reset identity conflation and two downloader privacy mismatches (local history and direct binary installation). All corrected and re-reviewed as ready. Later workflow-doc review tied the old snapshot hold to current release provenance rather than claiming it still blocks publication.
- No behavior, permission grant, identifier, stored preference or signing configuration changes. The only request metadata edit changes the lyric client’s project URL. Historical copyright, service endpoints, compatibility values and dated release entries remain intact.

This audit covers current documentation, permission-purpose resources and active identity references; it is not a claim that every historical document describes the current app. No real grants, hardware or download installs were exercised.
