# Settings Ergonomics Implementation Plan

**Goal:** Make updates and changelog ergonomic and place settings in the approved sidebar categories.

**Architecture:** Share update state with a small presentation model, preserving the existing update service and preview. Use SwiftUI dismissal for the sheet and one canonical Energy destination for keyboard light.

**Tech Stack:** Swift, SwiftUI, AppKit, existing standalone Swift test harness.
---

### Task 1: Update controls

Files: Core/UpdateSettingsPresentation.swift, Core/UpdateSettingsStrings.swift,
Services/Update/UpdateService.swift, UI/Settings/UpdatesView.swift,
Tests/UpdateSettingsPresentationTests.swift, Tests/MetricsTests.swift,
Tests/generate_sources.py, build.sh.

1. Add update-state tests covering idle, available, busy, progress, and failures.
2. Run the new tests and observe the missing presentation contract.
3. Implement the state/presentation model and stable actions; remove session state.
4. Run updates, localization, and affected regression suites.

### Task 2: Changelog sheet

Files: UI/Settings/ReleaseNotesSettings.swift, AboutSettings.swift,
Tests/SettingsChangelogTests.swift, build.sh, Tests/generate_sources.py.

1. Reproduce broken dismissal and header ownership in the current source.
2. Remove AppKit window mutation; add SwiftUI Done and Escape dismissal.
3. Separate title/version, scope picker, scroll content, and footer.
4. Verify dismissal and parent-window integrity in a real hosted sheet.

### Task 3: Sidebar and keyboard light

Files: UI/Settings/SettingsDirectory.swift, SettingsSidebarSupport.swift,
SettingsSearchSupport.swift, FeatureVisibilitySupport.swift, EnergySettings.swift,
KeyboardLightSettings.swift, ShortcutsSettings.swift, and affected tests.

1. Test category membership/order and Energy search destinations.
2. Move sidebar rows and canonical keyboard-light destination.
3. Extract cohesive Energy cards before extending the existing oversized page.
4. Move keyboard-light controls into their own component and remove obsolete
   shortcuts-only reveal/anchor logic.
5. Run settings, features, updates, and keyboard suites.

### Task 4: Final verification

1. Review complete diff and removed-symbol dependencies.
2. Obtain independent review and address findings.
3. Run the full harness, development build, and selftest sequentially.
4. Record evidence and leave changes in the established feature worktree.

### Utilities follow-up

- [x] Replace the shared utility form with focused, correctly owned components.
- [x] Remove Quick panel, Quick Toggles, and Camera preview sidebar entries.
- [x] Route shortcut-only tools to their exact Keyboard Shortcuts rows.
- [x] Move Wallpaper and complete Keyboard Light preferences into Energy.
- [x] Put dark-mode switching under Displays and disk exceptions under Command Bar.
- [x] Retain disk-exclusion filtering and persisted preferences.
- [x] Remove newly unused localization fields and translations.
- [x] Fix missing-utility navigation-history fallback after independent review.
- [x] Inspect the running app: sidebar, focused pages, Displays, exception editor,
  balanced update actions, changelog Done and Escape dismissal.
- [x] Full regression rerun: 116,622 checks passed, plus preference cleanup,
  uninstall Spaces, and developer-install isolation shell checks.
- [x] After the final unused cleaning-action label removal, recompiled and ran
  localization checks: 7,779 passed.
- [x] Final `./build.sh --dev` and `./build/LatticeDeveloper --selftest` passed.
- [x] Relaunched the exact final staged developer app and confirmed sidebar entries.

Review: independent reviewer verified the routing fallback and orphan removal,
with no remaining actionable findings. The first full run exposed three stale
assertions for deliberately changed sidebar/availability contracts; updated
those expectations and added Wallpaper-only Energy visibility coverage.

Status: implementation, review, and verification complete. Changes remain
uncommitted on `feat/settings-shortcut-overhaul` in the established worktree.
