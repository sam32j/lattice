# Feature Page Migration Implementation Plan

**Goal:** Retire Features and give each remaining owning page safe activation on current main.

**Architecture:** Adapt the approved reference implementation in vertical slices. Preserve main's feature identities and current services, split oversized touched files into cohesive modules, and integrate owned shutdown with both utility surfaces.

**Tech Stack:** Swift, SwiftUI, AppKit, existing isolated Swift test harness.
---

### Task 1: Reachability, ownership and compatibility
Files: Tests/FeaturePageOwnershipTests.swift; Core/FeatureInstallationPolicy.swift, Core/FeatureCatalog.swift and extracted feature policies; UI/Settings/FeatureVisibilitySupport.swift and settings routing modules.
1. Extend the existing ownership test: all ten disabled owners remain reachable; no Features hub owners remain; registered Video Downloader retains opt-in, enable-key and dedicated-page behavior.
2. Run ./build.sh --test-suite=settings and record the intended failures.
3. Adapt reference ownership/routing and lazy page hosts, preserving Video Downloader and current destinations.
4. Reconcile existing tests and run settings/preferences coverage.

### Task 2: Runtime and owned work lifecycle
Files: App/FeatureRuntime.swift and extracted activation/bindings; Services for Stay Awake, Cleaner, Homebrew, App Updates, Uninstaller, Media, Kill Process, Port Manager and Radial Now Playing; related lifecycle tests.
1. Reuse reference runtime transition tests; verify disabled launch, enable/disable and retained preferences fail before the corresponding implementation.
2. Port each owner's lifecycle and meaningful cancellation cases in slices, preserving main's newer implementations.
3. Guard accepted mutations and shared-owner work centrally. Run affected existing suites after each slice.
4. Retain main's Stay Awake assertions, Hub actions and lock recovery, and Video Downloader's existing availability and routing behavior.

### Task 3: Surface integration and rendering
Files: UI/Settings lazy activation/configuration hosts, SettingsView modules and owning page controls; UI/MenuPanel utility presentation; Services/LatticeHub and UI/LatticeHub.
1. Verify late actions and disabled/re-enabled utility presentation through production boundary fixtures.
2. Apply the reference panel session contract to current utility surfaces without replacing current Hub behavior.
3. Render disabled/enabled settings in isolated native fixtures: centered off states, persistent toolbar slots, grouped configuration controls and title sizing.
4. Verify Video Downloader settings/Hub/Island reachability remains unchanged.

### Task 4: Review and final checks
1. Request independent whole-diff review, specifically Video Downloader registration, current Hub surfaces and Stay Awake failure/lock behavior.
2. Fix supported issues, run focused and full regression checks, compile the developer executable without signing/installing/launching the real app.
3. Inspect diff, source-generation compatibility, temporary artifacts and reference-worktree preservation. Record actual evidence and limits.
4. Leave completed changes on the requested fresh branch; do not publish or install without an explicit outcome instruction.

## Status
Migration complete locally on the fresh branch based on ddba7332. Reference migration changes remain uncommitted and untouched in their original worktree. Independent review and final production compilation passed.

## Migration verification and review

- Ownership tracer initially failed for all ten remaining owners and retired Features. Final ownership/preferences slice passed 1,194 checks, including preservation of registered, opt-in Video Downloader and its enable preference.
- Runtime page-activation interface was missing before implementation. Focused integration then passed 4,911 checks across activation, settings, shared utilities, app management, updates, Hub and Stay Awake.
- Preserved main's Video Downloader implementation/settings/Island page files unchanged. Its current AppFeature enum identity, availability defaults, enable key, permission and destination policies survive extraction. Preserved current notch widget/companion routes, Hub implementations, lock transitions and haptic/input implementations.
- Independent review identified lost Stay Awake wake observation and hidden recovery after failed native shutdown. Added idempotent feature-owned wake/preference observation and a disable preflight that keeps activation on until native assertions release. Energy settings exposes the existing localized failure copy and retains Stop. Regression cases failed first and then passed. The wake fixture explicitly binds its isolated workspace notification center.
- The initial full run had one repository policy failure in the new preview's direct availability writes. The preview now uses the existing identity-guarded helper. Repository rerun passed 321 checks, followed by a clean complete run: TESTS OK (97,024 checks). Preference cleanup, uninstall paths with spaces, and developer-install isolation checks passed in temporary fixture directories. The real installed app was not changed.
- Native migration rendering passed all ten lazy off-content checks, actual settings layouts at 528/838-point heights, persistent activation/options toolbar slots and App Updates overflow. Cleaner light, App Updates dark and Command Bar grouped activation output were visually inspected. Evidence: /tmp/lattice-migration-rendering.log and /tmp/lattice-migration-rendering/.
- A further real-binding audit caught reference teardown closures omitted when preserving main's binding map. The real-runtime inert probe reproduced three owner-cancellation failures. Merged all reference lifecycle hooks while preserving LatticeHubService routing. The same probe then passed: disabled Homebrew executor status -1, enabled other-owner status 0, exactly one execution, shared-owner isolation, protected process-action gating and Hub closed state after re-enable. All ten migrated owners have production bindings. Evidence: /tmp/lattice-migration-bindings-red.log and /tmp/lattice-migration-bindings-green.log.
- After binding integration, 4,267 affected checks passed. The shared Kill Process options popover remains in the Settings toolbar and has an inline button in the toolbarless Hub workspace.
- Developer executable compilation passed after lifecycle and failure fixes. Final compile of the shared-view options adjustment passed (/tmp/lattice-migration-build-complete.log). No signing, installation or launch of the real application was performed.
- Reference worktree status matches the saved pre-migration status. All reference content remains uncommitted and untouched in its existing worktree.
- Limits: fixtures use isolated preferences and in-process process/package/filesystem boundaries. Actual native sleep/lid changes, permission prompts, destructive cleanup, package mutations, process termination and VoiceOver interaction were not exercised. Static inert service shells can remain until quit.

## Next requested task

After completing migration verification, investigate the user's reproducible input sequence: Magic Mouse track swipe works at launch; trackpad swipe/haptics work; after the first trackpad gesture, Magic Mouse stops changing tracks. Preserve trackpad behavior and first-swipe haptics. Keep this fix separate in scope and evidence.

## Final combined verification

Migration and the subsequent mouse follow-up are complete locally on refactor/feature-page-migration. Final full suite: TESTS OK (97,057 checks), including 1,799 Video Downloader checks, 100 notch-input checks, all island regressions and required preference/uninstall/install-isolation tests. Log: /tmp/lattice-final-verified-tests.log. The install-isolation checks used temporary fixture Applications directories only.

Final developer executable compilation passed (/tmp/lattice-final-verified-build.log). The final built executable passed the isolated real-runtime cancellation/mutation/Hub probe (/tmp/lattice-final-runtime-probe.log). The earlier native layout rendering remains valid; the only subsequent presentation adjustment preserves Kill Process options in toolbarless Hub hosts. Independent reviews found no remaining actionable blockers. git diff --check, zsh -n build.sh and new Swift file size checks passed. The reference worktree status remains unchanged.

Changes are committed locally by topic at the user’s request; no push was requested, and the real installed app was not changed. Physical input, real permission changes and destructive native operations remain outside fixture verification. The mouse follow-up's separate rationale and evidence are in docs/specs/2026-10-30-mixed-music-input/tasks.md.
