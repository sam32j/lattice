# Settings Refactor III Implementation Plan

**Goal:** Apply the approved settings navigation, grouping, app-list editing and automatic appearance behavior.

**Architecture:** Reuse existing service-backed bindings and feature runtime gates. Extract shared sheet and presentation components within Settings; automatic appearance depends on OS capability and accessibility settings.

**Tech Stack:** SwiftUI, AppKit, Swift standalone contract tests.
---

### Task 1: Automatic appearance
Files: Core/LiquidGlassSupport.swift, App/AppAppearanceController.swift, UI/Settings/GeneralSettings.swift, UI/SharedUI.swift, UI/Theme.swift, UI/Notch/NotchComponents.swift and appearance callers/defaults/tests.
1. Inspect existing preferences tests and supported-OS behavior.
2. Replace stored appearance gates with capability checks; remove obsolete preference keys and controls.
3. Update affected preference contracts; run preferences/settings suites.

### Task 2: Shared App List Sheet and page grouping
Files: UI/Settings/AppBundleList.swift, DockSettings.swift, DockQuitOnCloseSettings.swift, WindowLayoutSettings.swift, exclusion wrappers and window preview presentation.
1. Add reusable fixed-size sheet row supporting protected entries and existing app picker semantics.
2. Apply it to Dock Preview, snapping, maximization and auto quit.
3. Merge Dock thumbnail settings, flatten experimental rows and move Windows & Spaces behaviors.
4. Verify services, anchors and navigation ownership with affected existing suites.

### Task 3: Dynamic Island detail navigation
Files: UI/Settings/NotchSettings.swift, NotchSettingsTabRow.swift and extracted detail/navigation components.
1. Replace columns with a list and detail destination state.
2. Add feature install/uninstall toggles and preserve inclusion controls and previews.
3. Add Companion row and retain module/companion deep links.
4. Verify feature gates and navigation tests.

### Task 4: Copy and standard switches
Files: localized setting labels, capture/audio setting views and search/catalog ownership.
1. Rename Launcher Grid, Dock Tiles and requested window/audio labels.
2. Remove capture status badges; standardize only requested switches.
3. Run localization and settings regressions.

### Task 5: Final verification and review
1. Build with ./build.sh --dev and run ./build/LatticeDeveloper --selftest.
2. Request independent whole-diff review and address substantiated issues.
3. Refresh affected checks and record evidence here.
4. Preserve branch settings-refactor-III for the user, as requested.

## Status
Implementation complete on branch `settings-refactor-III`, based on `689edf39`.

- Dynamic Island: single-column content navigation, Companion detail, per-feature availability gates, preserved drag/context-menu/accessibility reordering and deep links. Captures and System expose their underlying gates separately from section visibility.
- Appearance: retired preference keys, migration, UI controls, exclusive localized copy and rendering preference branches removed. OS and accessibility support still determine native material availability.
- Dock and Window Management: requested ownership, descriptions, grouping, chips, standard switch sizes and shared app-list sheet implemented. Mandatory auto-quit exceptions remain protected.
- Shared App List Sheet: 520 by 460 points, scrolling list, nested picker, protected entries, localized Edit/Done labels.
- Extracted settings view helpers into focused files and updated the source-backed test generator to follow their owners.

## Verification

- `./build.sh --dev`: passed on the final one-column layout implementation.
- `./build/LatticeDeveloper --selftest`: passed on the final implementation.
- Twelve affected regression suites: `TESTS OK (83676 checks)` covering preferences, window layout, audio settings, screenshots, recorder, Dynamic Island, features, settings, feature hub layout, localization, Dock auto-hide and Spaces ordering.
- After localized toggle-label and disabled app-list-row refinements: settings/localization repeated, `TESTS OK (7856 checks)`.
- Independent Code Reviewer examined the full task diff. Feature-gate and reorder findings fixed and re-reviewed; no remaining material findings.
- Development rendering probe produced Dock, Window Management, Content list, Timer detail, Companion detail and empty/populated app-sheet images. Both app-sheet fixtures measured exactly 520 by 460 points. Final rendering repeat passed across all seven fixtures. Global header, tabs and back navigation remain visible on long pages.
- `git diff --check`: passed.
- Final independent source review of the scroll containment adjustments: ready, no material findings.
- Limitation: the WindowServer reports probe windows as occluded, so the reused live Island preview and native glass material were not visually exercised. The layout, navigation rows, Companion stage and fixed sheet dimensions were inspected from the rendered images.

## Branch outcome

Preserve the new branch and checkout for the user. The design/plan was committed as `bbd10ae8`; implementation changes remain uncommitted. No push, merge or PR was requested.


## Follow-up: app-list wording and Dock exclusions

- Every ALS header and empty placeholder now uses the shared localized Disable for these apps label. The three requested feature-specific descriptions are in SettingsAppListDescriptions; empty placeholders center within the fixed scrolling region.
- Dock exclusions apply to the app owning the hovered tile. Scheduling, prefetched window enumeration and session opening enforce the target exclusion. Saving the list immediately cancels excluded pending hovers and closes excluded active/pinned sessions; pinned refresh independently rechecks membership.
- Dock capture no longer pauses when a listed app is in front. Switcher capture keeps its separate foreground-pause policy.
- Keep Dock visible and Dynamic Island now share the orange ExperimentalBadge component.
- Regression reproduced before the fix: switcher-model failed on the new foreground-capture expectation. After implementation, switcher-model/settings/feature-hub-layout/localization passed 9,653 checks.
- Final development build, selftest, all seven rendering fixtures and diff whitespace check passed. Empty and populated sheets retained 520 by 460 dimensions; centered placeholder, requested Dock description and orange chip were visually inspected.
- Independent source review found no actionable issues. Live Dock hover interaction was not exercised in this test run.

### Dynamic Island ownership, focus, and music follow-up

- Preserve foreground app ordering when the Island takes keyboard focus; dismiss Island on every deliberate Settings entry.
- Move Calendar, Notifications, Downloads, AI Agents, Watch, Companion, Gestures, Lyrics, Up Next, live waveform, and Accessory alerts installation controls out of Features and into their settings controls.
- Verify service teardown, including changes while Island is suspended.
- Rename Tools to Launcher Grid and live waveform to Show Live Music Waveform.
- Bound per-band normalization to reduce persistent bass dominance without adding energy to silent bands.
- Implemented all items. Dedicated controls use FeatureRuntime.setIslandFeature, retaining installation bookkeeping and explicitly synchronizing preference-only changes. Existing installs and opt-in defaults are preserved.
- Runtime callbacks stop Calendar, Notifications, Downloads, Agents, Watch and Accessory services directly before presentation synchronization, so suspended Island presentation cannot bypass teardown. Accessory stop unregisters Bluetooth notifications, drops the monitor subscription, cancels work and releases accessory monitoring.
- Island opening retains nonactivating panel keyboard focus without activating the app. Every Settings window entry dismisses expanded presentation, releases capture-control keys without cancelling its session, clears internal drag state and suppresses hover reopening.
- Removed hub entries link to their owning detail page or Behavior/Activity tab when referenced elsewhere.
- Waveform regression failed before normalization and passed after. Per-band gain is capped at 2.5 times shared gain and blended with shared scaling; silent bands remain zero.
- Independent review: initial finding for capture/internal-drag dismissal fixed and re-reviewed; no remaining blocking findings.
- Development build and selftest passed. Native cross-app focus sequence and listening-based waveform appearance remain manual runtime checks.
- Final regression run: preferences, screenshots (including dedicated extension transitions and extracted focus transition), notch, features, settings, feature-hub-layout and localization passed 82,208 checks. Separate notch-music subset also passed 1,985 checks. Diff whitespace check passed. The capture test harness emitted its known simulated handoff warnings; no checks failed.

### Timer and Dynamic Island ownership follow-up

- Timer and Dynamic Island installation are owned by their dedicated settings switches; neither appears in Features.
- Dynamic Island remains visible in the sidebar and search while uninstalled.
- The Dynamic Island page starts with a SettingsCard containing Enable Dynamic Island, a standard switch and a concise localized description.
- Turning off Dynamic Island stops its runtime while retaining child choices; enabling again restores those choices. Preserve first-install defaults.
- Remove the obsolete hub card, expansion/reveal branches, uninstall-extension prompt, unused localized strings, and Companion's dependency on Features installation.
- Verify runtime transitions, sidebar/search behavior, hub rendering, development build and selftest; request independent review.
- Completed: root and Timer now join the dedicated installation path; the shared API is setIslandFeature. Parent removal stops runtime without clearing child choices, and Features bulk actions do not touch it.
- Menu Panel, Command Bar and Companion enable actions use the same installation path. Managed prerequisite text now says to enable the feature in its own settings rather than Features.
- Removed the dedicated hub card, special reveal state, extension-uninstall prompt and all four exclusive localized prompt fields across 15 languages. First-install defaults and catalog identities remain intact.
- Regression evidence: new sidebar/search/hub assertions failed before implementation; final screenshots, command-bar, notch, features, settings, feature-hub-layout and localization suites passed 82,861 checks. Updated three older assertions that required the retired hidden-page behavior.
- Development build passed. Seven rendering fixtures passed; the labeled main enable card, standard switch, orange Experimental chip and concise caption were visually inspected. Existing fixture limitation on live Island preview painting remains.
- Independent review found no remaining material issues. The original Shelf preference field was retained after build verification confirmed its use by islandOn.
- Final rebuilt binary selftest and diff whitespace check passed. Branch remains settings-refactor-III with implementation changes uncommitted.
