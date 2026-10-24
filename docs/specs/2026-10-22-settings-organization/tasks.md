# Settings Organization Implementation Plan

**Goal:** Make input, display, monitoring and capture settings clear and give each control one owner.

**Architecture:** Reuse service-backed settings and feature lifecycle APIs. Move presentation controls to their owning pages, preserve stored choices, and separate temporary Cleaning Mode activation from shortcut registration.

**Tech Stack:** SwiftUI, AppKit, standalone Swift regression suites.
---

### Task 1: Cleaning Mode lifecycle
- Inspect GlobalShortcut, CleaningModeManager, FeatureCatalog and permanent shortcut visibility.
- Cover shortcut installation, clearing, and active-session preservation with the existing public test seams.
- Implement on-demand activation and a dedicated CleaningModeSettings view with trailing button and screen-visibility switch above the shortcut.

### Task 2: Input pages
- Extract MouseSettings and KeyboardSettings responsibilities into cohesive files before extending oversized views.
- Order feature cards by task with titles inside each container, and rewrite feature captions in natural, concise language.
- Verify keyboard, pointer-input, linear-scroll and settings suites.

### Task 3: Displays
- Update DisplaySettings and EnergyDisplaySettings; extract row helpers as needed.
- Separate system appearance, flatten brightness options and keep disabled controls visible.
- Verify display-restoration, preferences, settings and development build.

### Task 4: Activity Monitor ownership
- Add dedicated module controls and keep monitor sidebar/search reachable via FeatureVisibilitySupport.
- Exclude module installation from Features and route prerequisite links to MonitorSettings.
- Test visibility, install/uninstall and service sampling with features, metrics and settings regressions.

### Task 5: Capture settings
- Trace NotchSupport, ScreenCaptureService and preview/history routing.
- Correct the settings bindings without changing persisted preference semantics.
- Verify independent control and preview routing with screenshot/notch regressions.

### Task 6: Finish
- Run ./build.sh --test with affected suites, ./build.sh --dev and ./build/LatticeDeveloper --selftest.
- Render relevant settings fixtures where available and inspect their layout.
- Review complete task changes, address findings, run git diff --check and record evidence here.

## Status
Input-page refinement and Danger Zone adjustment implemented and verified on refactor/settings-refactor-III at 3f98d758, preserving all existing uncommitted work.

## App icon replacement
- Imported the user-provided Untitled.icon unchanged as Resources/Brand/Lattice.icon, including its light/dark source layers. Desktop source remains unchanged; no absolute Desktop dependency is required for subsequent builds.
- Compiled the matching macOS fallback to Resources/Brand/Lattice.icns. Tools/MakeLatticeIcon.swift now copies this fallback rather than generating the old app artwork, while retaining the existing menu-bar and brand-glyph rendering.
- Lattice builds now compile the adaptive AppIcon catalog instead of bypassing it. Package both Assets.car and the compiler's AppIcon.icns; builds without the adaptive compiler use the checked-in fallback and cannot accidentally package a stale catalog.
- Verified the copied project matches the Desktop source, inspected the compiled icon preview, compared the packaged fallback to the source fallback, and verified the catalog is packaged. Menu-bar images and BrandMark were byte-for-byte unchanged in the developer configuration.
- Development build, strict bundle signature verification, SELFTEST OK, shell syntax and git diff --check passed. No installed app, Dock process, source artwork or user preferences were modified. Work remains local and uncommitted.

## First-launch documentation and DMG follow-up

### Updated supplied app icon
- Replaced the previous Untitled.icon artwork with /Users/samuel/Desktop/Lattice.icon, including both appearance assets and its exact Icon Composer configuration (JSON formatting aside). Desktop original untouched; menu bar artwork and icon build logic unchanged.
- Recompiled the checked-in static fallback, inspected its preview, then rebuilt the Developer app with the adaptive catalog. Strict bundle signature verification, fallback-to-bundle comparison, catalog presence, SELFTEST OK and whitespace checks passed. No installation, Dock restart, commit or push.
- Added a prominent README notarization notice and standalone root TROUBLESHOOTING.md. Linked the existing detailed troubleshooting page to the Lattice-specific guide and corrected outdated release wording.
- The guide leads with Apple's Open Anyway process, then documents targeted quarantine removal only for a verified, trusted copy. It explicitly rejects blanket safety guarantees, global Gatekeeper disabling and bypassing malware/tampering warnings.
- Clarified local-first privacy and optional network features instead of claiming everything is offline or 100% safe. Checked Apple's current guidance, existing privacy documentation and network service implementations.
- Both DMG packaging paths include the standalone guide. The styled DMG has a dedicated guide icon and first-launch hint below the install row.
- Validation: shell syntax, whitespace checks, generated background inspection and an isolated DMG build using a copy of the existing staged app. Mounted the final image read-only, confirmed the guide matches the source byte-for-byte, verified the bundled app signature and confirmed Finder layout metadata is present. No app rebuild or actual first-launch bypass was needed for this content/packaging-only change. No installed app or security preferences changed. Independent review unavailable; performed task-diff self-review. Work remains local and uncommitted.

## Input-page refinement plan
1. Refactor MouseSettings, MouseScrollingSettings, MousePointerSettings and MouseButtonSettings into the three approved cards. Split the oversized MouseButtonSettings view into focused presentation/capture extensions without changing runtime behavior.
2. Add shared native slider/value-tooltip presentation under UI/Settings, preserving ranges and steps. Apply it to Mouse controls, quit-protection timing and keyboard backlight. Convert selectors/toggles to trailing controls.
3. Update MouseExceptionsList to use AppBundleList's ALS mode. Keep scope ownership, executable identities and picker behavior. Use the exact Disable in these apps label.
4. Update KeyboardSuperKeySettings and KeyboardDebounceSettings with accessible status dots, and preserve real failure reasons. Reuse service state and existing regression seams rather than changing services.
5. Update localized titles/copy and the existing rendering probe. Render enabled and disabled input pages plus status states and app-list fixtures. Reuse pointer-input, keyboard, features, settings, localization and preferences suites, then development build and selftest.
6. Self-review final task diffs if no independent reviewer is available, record checks and gaps here, and leave all work uncommitted without pushing or merging.

### Input-page refinement results
- Mouse Scrolling, Mouse Clicks and Mouse Buttons now each use one container. Trackpad middle-click remains separate. Enabled smooth-scroll settings are flat; disabled feature options remain hidden as before.
- All per-feature input exclusions use the existing ALS editor, with Disable in these apps and a trailing Edit button. Separate scopes and executable identities are preserved.
- Native tick-free NSSliders replace the input-page sliders. Removed permanent readout columns and endpoint labels. Hover and drag presentation expose the formatted value; accessibility retains the value. Existing ranges/steps and keyboard-backlight editing callbacks remain intact.
- Added native-control checks for range, continuous updates, step quantization, endpoints, disabled state and keyboard arrows. The arrow check first failed because native increments could round back to the same coarse step; the corrected control honors the configured step for arrows, Home/End and Page Up/Down.
- Short menu selectors explicitly use trailing alignment inside their shared-width column. Visual rendering caught the default centering before this correction.
- Super Key uses Enable super key, an indented Super Key selector and accessible status dot. Duplicate-key filtering also uses an inline dot. Removed dedicated success/error status blocks while preserving truthful failure/permission/pause tooltip messages. Green/red/neutral states follow the approved model.
- Renamed Space-drag labels in every supported language. Added localized Mouse groups, side-button identification and status/enable labels. The rendering probe checked all new language/key combinations.
- Split MouseButtonSettings into its section, row presentation and capture/persistence extensions, all below 300 lines. Compared the extracted capture/persistence bodies against HEAD after normalizing access modifiers; behavior is unchanged. Updated source-bound regression fixtures to follow the split and the new shared status-dot dependency.
- Danger Zone now uses matching native bordered, destructive, text-only Clear and Uninstall buttons with centered labels on the same trailing edge. Removed unused custom button styles. Confirmation and destructive-operation handlers are unchanged; no real reset or uninstall was executed.
- Final seven-suite run passed: TESTS OK (31079 checks), covering pointer-input, preferences, features, settings, keyboard, localization and uninstaller. Final development build and SELFTEST OK passed.
- All 24 isolated rendering fixtures passed. Inspected expanded/disabled Mouse groups, trackpad, Super Key, duplicate-key filtering, quit protection and Data & Permissions. Final images: /tmp/lattice-input-settings-final.fi0KkM/rendered.
- Whole-task source self-review and git diff --check passed. Independent review was unavailable. Real input-tap activation, actual mapping conflicts and a live mouse-drag tooltip interaction were not exercised. Work remains local and uncommitted; no push or merge performed.

## Implementation
- Input pages grouped by task; large views extracted into focused files below 300 lines. Detached introductions removed; short captions stay with their controls. English input descriptions rewritten, with localized grouping and activation labels.
- Cleaning Mode now offers on-demand activation, a trailing Keep screen visible switch, and an always-reachable shortcut. Valid assigned shortcuts own persistent registration. Clearing a shortcut leaves an active session intact. Migration preserves the old master-switch opt-out and travels in backups.
- Displays separates Appearance, Display Controls and Wallpaper. Dark Mode uses a switch. Removed More Options; disabled display controls stay visible. Connected screen names are shown without starting brightness control.
- Activity Monitor owns the eight module installation switches and stays visible/searchable with every module off. Features excludes these installation controls; prerequisite links route to their owner. Sensor lifecycle still uses FeatureRuntime.
- Dynamic Island routes preview placement through notchCapture and live controls through notchCaptureControls. Saved values retain their meaning. Recording-only installations can use both controls.

## Verification
- Eleven affected suites passed: TESTS OK (100546 checks), covering metrics, pointer input, preferences, screenshots, Command Bar, Dynamic Island, feature lifecycle, settings, display restoration, keyboard and localization.
- After recorder-only capture routing adjustment, linear-scroll/screenshots/recorder/notch passed: TESTS OK (68988 checks).
- Final ./build.sh --dev passed; ./build/LatticeDeveloper --selftest passed.
- Twelve isolated rendering fixtures passed. Inspected Mouse, Keyboard, Cleaning Mode, disabled Displays, and all-modules-off Monitor. Screenshots: /tmp/lattice-settings-organization-final.OFZmar/rendered.
- Rendering initially exposed stale incremental Swift metadata after moving opaque view declarations. Rebuilt the development objects from a clean cache; all fixtures then passed.
- Source self-review and git diff --check passed. Independent review was unavailable and remains a follow-up. Real cleaning-lock activation, sensor hardware changes and live capture interaction were not exercised.
- Pre-existing Refactor III edits were preserved. No commit, push or merge performed.

## Follow-up revisions and final verification
- Removed standalone Mouse/Keyboard headings and their unused shared view/localizations. Titles stay inside feature cards. Keep screen visible now uses an icon-free control row.
- Displays/Bluetooth destination navigation no longer draws the blue content outline. Other settings pages retain their destination highlighting.
- Audio Input uses a headline for Mute Audio Input; the localized mute-status menu-bar switch comes before the vertically centered shortcut row.
- Removed the standalone brightness-overlay window, its Settings/menu controls, preference, localized labels, key-routing option, write bookkeeping, segment formatter and exclusive tests/mutation. Retained percentage formatting used by Dynamic Island notices and preserved native/island brightness key handling.
- Removed Captures from Indicators and from NotchEvent, including its duration/priority and availability logic. Dedicated preview routing preserves screenshot/recording previews, history destinations, recorder-only setups and the live capture toolbar.
- The removed-preference regression failed before implementation and passed afterward. Capture regressions initially exposed a stale generated-fixture substitution after the routing rename; corrected the substitution without weakening the tests.
- Final combined twelve-suite run passed: TESTS OK (102653 checks). Suites: pointer-input, preferences, screenshots, recorder, command-bar, notch, switcher-model, features, settings, display-restoration, keyboard, localization.
- Final development build, SELFTEST OK and all fifteen isolated rendering fixtures passed. Inspected Mouse, Keyboard, Cleaning Mode, Audio Input, disabled Displays, Bluetooth and Indicators. Displays and Bluetooth fixtures issue real destination requests before rendering. Output: /tmp/lattice-settings-revision-final.9IBXiU/rendered.
- Source self-review, orphan-reference audit and git diff --check passed. Independent review was unavailable; live hardware changes and interactive capture sessions were not exercised. No commit, push or merge performed.
