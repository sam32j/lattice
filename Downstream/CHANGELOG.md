# Lattice Changelog

## [3.4.1-d.2] - 2026-10-17

## [3.4.2-d.4] - 2026-10-27

### Added
- **Settings**: Add Show on Dynamic Island toggle to Video Downloader settings
- **I18n**: Implement full VideoDownloaderStrings internationalization across 15 languages
- **Settings**: Implement VideoWebsiteSessionsSheet adhering to dark appearance spec
- **Settings**: Redesign Video Downloader settings hierarchy and 40px inputs
- **Notch**: Update NotchView and NotchSectionsView for video downloader strip and transitions
- **Notch**: Register video downloader support utilities and page title mappings
- **Notch**: Adapt NotchService window geometry and auto-fit heights for video downloader
- **Notch**: Implement VideoDownloaderSearchBar with clipboard URL detection
- **Notch**: Implement ScrollableVideoQualitySegments component with centering
- **Video Downloader**: Add Bilibili detection and HTTP 567 byte range retry fallback
- **Video Downloader**: Support session cookies and retry handling during video download
- **Video Downloader**: Pass session cookies during video inspection and classify errors
- **Video Downloader**: Inject session cookies into VideoDownloadProcess execution
- **Video Downloader**: Integrate website sessions into main VideoDownloader model
- **Video Downloader**: Add website sessions state to VideoDownloaderJob
- **Video Downloader**: Implement VideoDownloaderWebsiteSessions extension
- **Video Downloader**: Implement VideoWebsiteSessions models and profile detection
- **Video Downloader**: Configure ATS arbitrary loads for thumbnail image loading

### Changed
- **Settings**: Use system native dialog scheme supporting light and dark modes in Browser Session sheet
- **Settings**: Localize video downloader page title in SettingsUtilitiesDirectory
- **Settings**: Extract VideoDownloaderSettingsComponents subviews and layout helpers
- **Notch**: Streamline NotchVideoDownloaderView layout and recent downloads navigation
- **Notch**: Extract modular NotchVideoDownloaderComponents subviews

### Fixed
- **Settings**: Keep Cancel button enabled in website sessions sheet while busy
- **Notch**: Use localized Finder reveal label in download complete status
- **Video Downloader**: Upgrade HTTP thumbnail URLs to HTTPS for ATS compatibility

## [3.4.2-d.3] - 2026-10-27

### Added
- **Settings**: Animate conditional follow-up settings with native expansion
- **About**: Align updates section layout and toggle style
- **Dock**: Redesign dock settings, autohide visibility handling, and preview controls
- **Feedback**: Redesign feedback modal with contextual subjects and modern styling
- Support native Magic Mouse music swipes
- **Downloader**: Glass sound, hover crossfade to Open, prominent complete banner, and focus-persistent expanded view
- **Downloader**: Sync UI with settings page, swap search/clear, finder open on complete, and recent history shortcut
- **Notch**: Camera-side compact activity, 10s completion sustain, and adaptive expanded island layout
- **Notch**: Implement video downloader dynamic island widget and compact activity
- **Downloader**: Clean, stacked, and centered error state for invalid video URLs
- **Downloader**: Containerized missing tools repair section, download confirmation dialog, and bundle ID based app support directory
- **Downloader**: Standalone toolchain installer, centered toggle, clean toggle states, and clear history button
- **Downloader**: Deduplicate qualities, position toggle at right titlebar edge without glass container
- **Downloader**: Add skeleton screen, tint download button, enlarge pause/cancel, and simplify completion
- **Downloader**: Separate fetch state and reuse card real estate for progress and completion
- **Downloader**: Responsive layout and feature uninstall lifecycle
- **Downloader**: Self-managed toolchain, audio extraction, and v2 media cards
- **Downloader**: Add guided setup and video download settings
- **Downloader**: Add cancellable downloads and safe output publication
- **Downloader**: Validate video metadata and discover local dependencies

### Changed
- **Settings**: Unify Data and Permissions with compact native rows
- **Cleaning**: Remove keep screen visible toggle and clean up overlay
- **Quit Protection**: Refine protection HUD and routing contracts
- **Shortcuts**: Add conflict detection and recorder refinements
- Clarify native swipe completion and phase checks
- Complete Lattice source and build naming

### Fixed
- **Video Downloader**: Default requested_formats to empty array in parts template
- **Video Downloader**: Check bitrate estimate bounds before Int64 conversion
- **Video Downloader**: Restore audio progress and refresh island input
- **Video Downloader**: Stabilize progress and invalidate edited searches
- **Feedback**: Present a native sheet from Settings
- **Keyboard**: Retain the intentional hold preset limit
- **Settings**: Honor preview appearance and remove redundant action tone
- **Keyboard**: Keep the two-second hold preset selectable
- **Services**: Defer quit HUD lookup and restore truthful update state
- **Settings**: Preserve timing choices and clarify shortcut conflicts
- **Feedback**: Validate encoded drafts and label form controls
- **About**: Refresh update status on appear, center feedback window, and respect system timezone
- **I18n**: Localize dock click section and audit settings copy across all languages
- **Settings**: Update input, debounce, energy, and video settings controls
- Name the menu icon switch for accessibility
- Release capture pointer input before focus handoff
- Preserve watch readings after partial OCR failure
- Allow music swipes with system page gestures disabled
- Retain watch readings during temporary OCR unavailability
- Preserve capture focus handoff and recover transient OCR failures
- Align settings controls and add explicit Dock click Off mode
- Audit Lattice attribution and current feature documentation
- Remove retired feature claims from localized permission prompts
- **Downloader**: Pin asset versions and verify SHA-256 digests before installation
- **Notch**: Address review findings on video downloader activity gating, preview isolation, and options refresh
- **Downloader**: Address review findings on toolchain, dependencies discovery, and error state
- **Downloader**: Deduplicate quality options, show actual resolution with Best, remove duplicate title, and expand save path
- **Downloader**: Protect title from truncation and show resolved tool paths in advanced settings
- **Downloader**: Hard limit save path width with middle truncation and preserve quality picker layout
- **Downloader**: Isolate test history store and make save location visible

## [3.4.2-d.2] - 2026-10-25

### Added
- **Sound**: Standalone padlock sounds, dock action tiles, and final settings polish
- **Permissions**: Verified permission activation and page-owned installation
- **Notch**: Animate compact and expanded music swipe progress
- **Notch**: Require physical travel for music track swipes
- **Branding**: Adopt latest Lattice icon across app and README
- **Monitor**: Install individual sensors from Activity Monitor modules
- **Displays**: Expose page-owned controls and inline brightness sliders
- **Mouse**: Support independent exclusions for each button shortcut
- **Mouse**: Edit scoped app exclusions in app-list sheets
- **Keyboard**: Offer on-demand Cleaning Mode activation
- **Cleaning**: Register persistent mode only with a valid shortcut
- **Features**: Derive display and Bluetooth installation from page toggles
- **Settings**: Add native tick-free value sliders
- **Permissions**: Add Danger Zone section and improve permissions details UX
- **Dock**: Make dock tile click actions mutually exclusive and refine labels
- **Settings**: Settings refactor III baseline implementation

### Changed
- **Settings**: Unify destinations, routing, and capture entrypoints
- **Settings**: Remove redundant capture and switcher introductions
- **Island**: Label widgets and show enabled status
- **Monitor**: Extract menu bar appearance and usage controls
- **Brightness**: Remove standalone adjustment overlay and dependencies
- **Audio**: Align output and microphone level sliders
- **Keyboard**: Compose focused settings cards
- **Keyboard**: Align backlight controls with native sliders
- **Keyboard**: Indent enabled quit and close protection options
- **Keyboard**: Simplify duplicate-key protection and delay controls
- **Keyboard**: Group Super Key setup and app exclusions
- **Mouse**: Streamline button configuration and Space capability feedback
- **Mouse**: Organize scrolling clicks and buttons into cards
- **Mouse**: Simplify click and trackpad gesture controls
- **Mouse**: Group scrolling controls and keep disabled options visible
- **Settings**: Simplify localized control and Dock copy
- **Input**: Clarify mouse buttons and Super Key labels
- **Settings**: Add localized task-oriented section labels
- **Window Layout**: Refine snapping dial, margin edge slider, and shortcuts layout
- **Notch**: Consolidate dynamic island settings and handle disabled state
- **General**: Update menu bar icon picker and simplify general settings

### Fixed
- **Sound**: Respect macOS interface sound preference
- **Capture**: Raise save dialogs above their preview owner
- **Capture**: Preserve preview exclusion during new selections
- **Cleaner**: Omit protected trees from leftover and log scans
- **Permissions**: Preserve Simple Switcher on recording access loss
- **Permissions**: Permission prompt safeguards and capture toolbar layering
- **Notch**: Correct music swipe threshold to three-quarter inch
- **Notch**: Adjust music swipe haptic and arming distances
- **Notch**: Announce the displayed track notice artist
- **Notch**: Retain music hover during track notices
- **Notch**: Preserve accepted swipe feedback through final lift
- **Notch**: Recover music swipes and unify track-change feedback
- **Notch**: Skip tracks on finger lift and keep track notices swipeable
- **Bluetooth**: Make wake restore depend on sleep handling
- **Review**: Support clean test generation and clarify Lattice permissions
- **Keyboard**: Keep lighting independent of display controls
- **Settings**: Localize concise trackpad conflict guidance
- **Audio**: Fit input controls in compact menu panels
- **Cleaning**: Keep manual actions available without a shortcut
- **Backup**: Preserve portable per-button mouse exceptions
- **Permissions**: Align native Danger Zone action buttons
- **Captures**: Separate preview routing from capture controls
- **Island**: Respect natural scrolling for track gestures
- **Settings**: Remove energy-page landing highlight
- **Settings**: Keep page-owned controls discoverable in navigation
- **Audio**: Align microphone mute and shortcut controls
- **Mouse**: Retry button capture and exempt Space drags from exclusions
- **Preferences**: Preserve cleaning migration and shortcut app exclusions
- **Settings**: Provide native status tooltips and accessible dots
- **Settings**: Address review feedback on baseline, controls, and localization
- **Settings**: Preserve upstream behavior after refactor rebase
- **Shortcuts**: Disable capture section auto-expansion and fix row title fallback

## [3.4.2-d.1] - 2026-10-22

### Added
- **Island**: Offer feature-gated open in editor drop targets
- **Island**: Crossfade between capture history and preview pages
- **Island**: Navigate capture history with deliberate trackpad gestures
- **History**: Scroll recent captures without replacing the island session
- **Editor**: Reveal drag and place guidance on the proxy icon
- **Editor**: Condense style controls and crop ratio menus
- **Editor**: Support grouped selection and constrained shape resizing
- **Watermark**: Combine composition and style in a live tool
- **Watermark**: Retain image presets without collecting text
- **Watermark**: Model live changes and explicit reset behavior
- **Editor**: Draw compact selection rings and corner handles
- **Media**: Accept editor file drops on the menu bar icon
- **Media**: Open supported files in their installed editors
- **Media**: Declare supported image and video document types
- **Preview**: Share image and video window placement settings
- **Recorder**: Centralize preview keyboard actions
- **Editor**: Persist and render rounded annotation corners
- **Recorder**: Refine selection chrome, hover feedback, pip snapping, and capture responsiveness
  - Render L-bracket corner handles, edge pills, and crisp 1pt white border without blue glow for recording draft selection
  - Add interactive hover styles and click scaling to recorder waiting action buttons and input toggles
  - Remove blue fill tint from window selection highlight, stroking 2pt light blue border with 10pt corner radius
  - Smooth camera PiP snapping animation curve with 5pt edge inset padding
  - Present recording indicator immediately and trigger begin_record sound prior to audio capture to prevent bleed
  - Parallelize multi-display screenshot capture and reorder overlay presentation to eliminate live desktop flash
- **Editor**: Implement reversible Done workflow, shortcuts, text double-click, and geometry refinements
- **Editor**: Reorder tools, update shortcuts, move style bar to top and show logical px
- **Notch**: Fix island preview focus and redesign recent captures UI
- **Capture**: Support floating window selection and matching corner radius
- **Recorder**: Refine selection tabs, camera overlay and waiting button feedback
- **Capture**: Refine editor interactions and preview experience
- **Recorder**: Refine selection controls and camera overlays
- **Capture**: Improve scrolling previews and recording overlays (#6)
  - Improve scrolling capture stitching, selection, preview layout, and
  - Open quick previews in native Quick Look with Escape dismissal,
  - Add pinned-image zoom and opacity presets, focused keyboard actions,
  - Add composited camera PiP and individual-keystroke overlays to
  - Preserve Features scroll/navigation state while retaining the latest
  - 10,096 checks passed across screenshot-pins, screenshots, recorder,
  - Development build passed: ./build.sh --dev.
  - App health check passed: ./build/LatticeDeveloper --selftest.
  - Diff checks passed and working tree is clean. Full test suite was not
  - Coverage includes native pin/Quick Look checks, synthetic gestures,
  - Physical camera and Continuity devices, real trackpad behavior, and
  - No release published or installed application replaced.
- **Settings**: Consolidate pages and harden permission reset
  - Give controls one Settings owner with capability-aware lifecycle and preference migration.
  - Remove retired onboarding, bundle presets, WhatsApp cleanup and orphan resources.
  - Keep event taps and global shortcuts suspended through permission reset, and unregister Launch at login with observable failure.
  - Use a fixed 230-point grey sidebar, detail-side page header and floating glass-style search.
  - Separate audio input and output settings and update all 15 language catalogs.
  - Cover runtime transitions, reset safety, native geometry, consumer routing and keyboard layouts.
- **Settings**: Organize preferences around dedicated tool pages
- **Settings**: Redesign permission cards and data management actions
- **Updates**: Present balanced status actions and dismissible release notes
- **Settings**: Consolidate data and permissions
- **Shortcuts**: Unify shortcut setters
- **Ci**: Parse commit body bullet points as nested changelog sub-bullets
- **Screenshot**: Revamp tool shortcut setter, prevent duplicate reset conflicts, and trim dead order logic
- **Screenshot**: Improve tool ordering ergonomics, support 10 tool slots (1-9, 0), and play sound on OCR copy
- **Recorder**: Add delayed start mode, discard button, and sound effects
- **Quick Preview**: Revamp preview layout with stacked actions, instant shortcuts, and dual text/qr ocr
- **Selection**: Overhaul capture selection with persistent crosshair, multi-window shift capture, and loupe hud
- **Settings**: Redesign screenshot and screen recorder settings with native grouped sections
- **Shortcuts**: Add compact single-row shortcut recorder with inline reset and conflict handling
- **Recorder**: Keep screen live (unfrozen) during recording selection
- **Recorder**: Stash raw video in recent captures and align editor buttons
- **Capture**: Store screenshots directly in Application Support with date subfolders
- **Ci**: Support personal Apple Development signing and add verification workflow
- **Release**: Support automated ad-hoc self-signed releases for Lattice
- **Downstream**: Support allowSnapshotRelease for one-time release before next upstream cycle
- **Downstream**: Rebrand app identity, bundle identifier, and stage configuration to Lattice
- **Downstream**: Sync upstream with conflict stops and atomic leases
- **Downstream**: Brand Lattice and isolate update trust and app data
- **Screenshot**: Add floating pin controls and file dragging
- **Screenshot**: Add zoom and opacity gestures to pinned captures

### Changed
- **Settings**: Streamline feature toggles, consolidate display ownership, and prune dead code (#8)
  - **Lattice Switcher**: Renamed from "Window Switcher" across
  - **Window Management**: Added dedicated "Enable Window Management"
  - **Dock Preview**: Hooked the main Dock Preview toggle to act as the
  - **Screenshot & Screen Recording**: Made screenshot and screen
  - **DisplaySettings**: Consolidated display brightness, XDR extra
  - **Wallpaper Extraction**: Removed the standalone wallpaper feature and
  - **Pruned Stubs**: Deleted `WallpaperSettings.swift` (view routes
  - **Profile Shortcut List**: In Shortcuts Settings, converted radial
  - **Title Case**: Standardized all sidebar item and category titles to
  - **Dynamic Island**: Added localization for the "Dynamic Island" label
  - **Wallpaper Management**: Added localization for "Enable Wallpaper
  - **Menu Bar Column Sizing Subsystem**: Removed orphaned dead sizing
  - **Dead Functions & Methods**: Pruned `featureGroupRows`, `setShown`,
  - **Dead Properties & Observables**: Pruned `baseColor`,
  - **Obsolete Types & Imports**: Pruned `typealias EnergySettings` and
  - **Full Test Harness**: `./build.sh --test` passes with **115,981
  - **Developer Build**: `./build.sh --dev --install` builds, signs, and
  - **New Features**
  - Added enable/disable controls for audio, microphone, screenshots,
  - Added sound-output device switching controls and Music app
  - Added editable radial-menu shortcuts with conflict detection.
  - Reorganized Settings into clearer card-based pages, including combined
  - **Bug Fixes**
  - Improved unavailable-device messaging, control dimming, preference
  - Updated localization and settings search/navigation labels.
  - **Changes**
  - Removed several legacy wallpaper, dock, capture, and menu presentation
- **Recorder**: Separate preview presentation and context menus
- **I18n**: Remove retired feature and permission copy
- **Finder**: Remove custom file actions and settings
- **Features**: Move system actions to their owning features
- **Capture**: Trim obsolete capture settings, dead screens, and legacy tool order remnants

### Fixed
- **Recorder**: Import preview edits without blocking the UI
- **Recorder**: Synchronize camera snapping and label waiting actions
- **History**: Format capture timestamps in the selected language
- **Capture**: Guard suspect window display fallbacks
- **Pins**: Preserve image aspect ratio and use public resize cursors
- **Editor**: Restore censor samples and creation hit testing
- **Capture**: Restore focus through shared activation handoff
- **Recorder**: Declare selection draft initializer explicitly
- **Island**: Dismiss capture previews for outside clicks and settings
- **Editor**: Soften light appearance and prevent clipped shadows
- **Editor**: Stabilize inline text teardown and rapid re-editing
- **Editor**: Unify native pointer tracking and immediate text targeting
- **Editor**: Keep font palette tracking and keyboard focus stable
- **Capture**: Claim crosshair ownership without raising editors
- **Capture**: Compose selected Expose windows without unrelated pixels
- **Capture**: Recover blank GPU viewports and reject compositor chrome
- **Video Editor**: Respect appearance and improve overlay contrast
- **Recorder**: Animate camera snapping without layout races
- **Editor**: Preserve modal and pinned window ordering
- **Pin**: Stabilize zoom opacity and native gesture handling
- **Quick Look**: Keep previews above capture surfaces
- **Preview**: Defer Mission Control presentation and protect menu dismissal
- **Recorder**: Reject stale preview thumbnail completions
- **Recorder**: Copy exported recordings atomically
- **History**: Persist edit generations before completing editor sessions
- **Preview**: Present edited pixels without flattening capture sources
- **History**: Store editable captures in an atomic document
- **Editor**: Provide RecentCaptureEntry anchor arguments and remove unused variable
- **Editor**: Elevate dialog levels and adjust window traffic light position
- **Preview**: Address review findings and auto-save on reveal in finder
- **Settings**: Correct detail viewport and scroll-aware toolbar
- **Settings**: Correct panel visibility and shortcut hints
- **Settings**: Preserve control and shortcut state
- **Shortcuts**: Streamline inline recording and preserve global key capture
- **Shortcuts**: Replace redundant toggles with inline controls
- **Shortcuts**: Enforce single shortcut monitor, observe exits on resign/outside click, and isolate layout test
- **Build**: Add Carbon.HIToolbox import to ScreenshotToolOrderControls
- **Capture**: Unclip independent window stream and verify composite layer coverage
- **Capture**: Harden capture store file deletion and add downstream release notes tests
- **Screenshot**: Use fixed tool order, allow single key bindings, and set OCR sound to acknowledgment_sent
- **Capture**: Address review findings and add recording retention
- **Capture**: Harden recording import, editor close safety, export snapshot, text editing, and delayed start
  - Transactional history import: serialize recording import and index persistence on history queue with rollback on failure.
  - Safe editor closing: require preserved original or export before unprompted discard/close, and keep take alive during stashing.
  - Export snapshot saved state: mark only the captured snapshot saved upon export completion so in-flight edits remain modified.
  - Native annotation updates: refresh text editor bindings, callbacks, frame size, and wrapping container dynamically.
  - Delayed recorder lifecycle: track waiting state, reject stale start callbacks, and ensure proper cancellation.
  - Pin and text OCR polish: fix gesture targeting during drag-hide and direct barcode payload reading.
- **Editor**: Fix text undo crash, enable multiline wrapping, dynamic sizing, and bounded drag boxes
- **Pin**: Enable immediate first-try pinch zoom, native drag-to-move, and double-click preview
- **Screenshot**: Disable window opening zoom animation on overlay panel
- **Tests**: Adapt pin window visibility assertions for headless test runner
- **Release**: Leave DMG container unsigned without notarization to prevent Gatekeeper mount modal
- **Tests**: Adapt settle timeouts in DockPreview and Switcher scroll tests
- **Tests**: Guard KVC on NSGlassEffectView and align gesture test initial frame
- **Tests**: Disambiguate buttons and descendants with Self in ScreenshotPinChromeTests
- **Tests**: Provide contextual types for nil in convert and performClick for Swift 6
- **Ci**: Simplify protectedWindowIDs for Swift 6 type-check and enforce exact base in release test
- **Downstream**: Align workflows and update endpoints with sam32j/lattice
- **Screenshot**: Center liquid glass scale-up bloom, direct pinch tracking, and drag hiding
- **Screenshot**: Keep glass pin controls unclipped and legible
- **Screenshot**: Polish pin controls and preserve gentle pinch zoom

## [3.4.1-d.6] - 2026-10-21

### Changed
- **Settings**: Streamline feature toggles, consolidate display ownership, and prune dead code (#8)
  - **Lattice Switcher**: Renamed from "Window Switcher" across
  - **Window Management**: Added dedicated "Enable Window Management"
  - **Dock Preview**: Hooked the main Dock Preview toggle to act as the
  - **Screenshot & Screen Recording**: Made screenshot and screen
  - **DisplaySettings**: Consolidated display brightness, XDR extra
  - **Wallpaper Extraction**: Removed the standalone wallpaper feature and
  - **Pruned Stubs**: Deleted `WallpaperSettings.swift` (view routes
  - **Profile Shortcut List**: In Shortcuts Settings, converted radial
  - **Title Case**: Standardized all sidebar item and category titles to
  - **Dynamic Island**: Added localization for the "Dynamic Island" label
  - **Wallpaper Management**: Added localization for "Enable Wallpaper
  - **Menu Bar Column Sizing Subsystem**: Removed orphaned dead sizing
  - **Dead Functions & Methods**: Pruned `featureGroupRows`, `setShown`,
  - **Dead Properties & Observables**: Pruned `baseColor`,
  - **Obsolete Types & Imports**: Pruned `typealias EnergySettings` and
  - **Full Test Harness**: `./build.sh --test` passes with **115,981
  - **Developer Build**: `./build.sh --dev --install` builds, signs, and
  - **New Features**
  - Added enable/disable controls for audio, microphone, screenshots,
  - Added sound-output device switching controls and Music app
  - Added editable radial-menu shortcuts with conflict detection.
  - Reorganized Settings into clearer card-based pages, including combined
  - **Bug Fixes**
  - Improved unavailable-device messaging, control dimming, preference
  - Updated localization and settings search/navigation labels.
  - **Changes**
  - Removed several legacy wallpaper, dock, capture, and menu presentation

## [3.4.1-d.5] - 2026-10-21

### Added
- **Island**: Offer feature-gated open in editor drop targets
- **Island**: Crossfade between capture history and preview pages
- **Island**: Navigate capture history with deliberate trackpad gestures
- **History**: Scroll recent captures without replacing the island session
- **Editor**: Reveal drag and place guidance on the proxy icon
- **Editor**: Condense style controls and crop ratio menus
- **Editor**: Support grouped selection and constrained shape resizing
- **Watermark**: Combine composition and style in a live tool
- **Watermark**: Retain image presets without collecting text
- **Watermark**: Model live changes and explicit reset behavior
- **Editor**: Draw compact selection rings and corner handles
- **Media**: Accept editor file drops on the menu bar icon
- **Media**: Open supported files in their installed editors
- **Media**: Declare supported image and video document types
- **Preview**: Share image and video window placement settings
- **Recorder**: Centralize preview keyboard actions
- **Editor**: Persist and render rounded annotation corners
- **Recorder**: Refine selection chrome, hover feedback, pip snapping, and capture responsiveness
  - Render L-bracket corner handles, edge pills, and crisp 1pt white border without blue glow for recording draft selection
  - Add interactive hover styles and click scaling to recorder waiting action buttons and input toggles
  - Remove blue fill tint from window selection highlight, stroking 2pt light blue border with 10pt corner radius
  - Smooth camera PiP snapping animation curve with 5pt edge inset padding
  - Present recording indicator immediately and trigger begin_record sound prior to audio capture to prevent bleed
  - Parallelize multi-display screenshot capture and reorder overlay presentation to eliminate live desktop flash
- **Editor**: Implement reversible Done workflow, shortcuts, text double-click, and geometry refinements
- **Editor**: Reorder tools, update shortcuts, move style bar to top and show logical px
- **Notch**: Fix island preview focus and redesign recent captures UI
- **Capture**: Support floating window selection and matching corner radius
- **Recorder**: Refine selection tabs, camera overlay and waiting button feedback
- **Capture**: Refine editor interactions and preview experience
- **Recorder**: Refine selection controls and camera overlays

### Changed
- **Recorder**: Separate preview presentation and context menus
- **I18n**: Remove retired feature and permission copy
- **Finder**: Remove custom file actions and settings

### Fixed
- **Recorder**: Import preview edits without blocking the UI
- **Recorder**: Synchronize camera snapping and label waiting actions
- **History**: Format capture timestamps in the selected language
- **Capture**: Guard suspect window display fallbacks
- **Pins**: Preserve image aspect ratio and use public resize cursors
- **Editor**: Restore censor samples and creation hit testing
- **Capture**: Restore focus through shared activation handoff
- **Recorder**: Declare selection draft initializer explicitly
- **Island**: Dismiss capture previews for outside clicks and settings
- **Editor**: Soften light appearance and prevent clipped shadows
- **Editor**: Stabilize inline text teardown and rapid re-editing
- **Editor**: Unify native pointer tracking and immediate text targeting
- **Editor**: Keep font palette tracking and keyboard focus stable
- **Capture**: Claim crosshair ownership without raising editors
- **Capture**: Compose selected Expose windows without unrelated pixels
- **Capture**: Recover blank GPU viewports and reject compositor chrome
- **Video Editor**: Respect appearance and improve overlay contrast
- **Recorder**: Animate camera snapping without layout races
- **Editor**: Preserve modal and pinned window ordering
- **Pin**: Stabilize zoom opacity and native gesture handling
- **Quick Look**: Keep previews above capture surfaces
- **Preview**: Defer Mission Control presentation and protect menu dismissal
- **Recorder**: Reject stale preview thumbnail completions
- **Recorder**: Copy exported recordings atomically
- **History**: Persist edit generations before completing editor sessions
- **Preview**: Present edited pixels without flattening capture sources
- **History**: Store editable captures in an atomic document
- **Editor**: Provide RecentCaptureEntry anchor arguments and remove unused variable
- **Editor**: Elevate dialog levels and adjust window traffic light position
- **Preview**: Address review findings and auto-save on reveal in finder

## [3.4.1-d.4] - 2026-10-19

### Added
- **Capture**: Improve scrolling previews and recording overlays (#6)
  - Improve scrolling capture stitching, selection, preview layout, and
  - Open quick previews in native Quick Look with Escape dismissal,
  - Add pinned-image zoom and opacity presets, focused keyboard actions,
  - Add composited camera PiP and individual-keystroke overlays to
  - Preserve Features scroll/navigation state while retaining the latest
  - 10,096 checks passed across screenshot-pins, screenshots, recorder,
  - Development build passed: ./build.sh --dev.
  - App health check passed: ./build/LatticeDeveloper --selftest.
  - Diff checks passed and working tree is clean. Full test suite was not
  - Coverage includes native pin/Quick Look checks, synthetic gestures,
  - Physical camera and Continuity devices, real trackpad behavior, and
  - No release published or installed application replaced.

## [3.4.1-d.3] - 2026-10-19

### Added
- **Settings**: Consolidate pages and harden permission reset
  - Give controls one Settings owner with capability-aware lifecycle and preference migration.
  - Remove retired onboarding, bundle presets, WhatsApp cleanup and orphan resources.
  - Keep event taps and global shortcuts suspended through permission reset, and unregister Launch at login with observable failure.
  - Use a fixed 230-point grey sidebar, detail-side page header and floating glass-style search.
  - Separate audio input and output settings and update all 15 language catalogs.
  - Cover runtime transitions, reset safety, native geometry, consumer routing and keyboard layouts.
- **Settings**: Organize preferences around dedicated tool pages
- **Settings**: Redesign permission cards and data management actions
- **Updates**: Present balanced status actions and dismissible release notes
- **Settings**: Consolidate data and permissions
- **Shortcuts**: Unify shortcut setters

### Changed
- **Features**: Move system actions to their owning features

### Fixed
- **Settings**: Correct detail viewport and scroll-aware toolbar
- **Settings**: Correct panel visibility and shortcut hints
- **Settings**: Preserve control and shortcut state
- **Shortcuts**: Streamline inline recording and preserve global key capture
- **Shortcuts**: Replace redundant toggles with inline controls

### Added
- **Ci**: Parse commit body bullet points as nested changelog sub-bullets
- **Screenshot**: Revamp tool shortcut setter, prevent duplicate reset conflicts, and trim dead order logic
- **Screenshot**: Improve tool ordering ergonomics, support 10 tool slots (1-9, 0), and play sound on OCR copy
- **Recorder**: Add delayed start mode, discard button, and sound effects
- **Quick Preview**: Revamp preview layout with stacked actions, instant shortcuts, and dual text/qr ocr
- **Selection**: Overhaul capture selection with persistent crosshair, multi-window shift capture, and loupe hud
- **Settings**: Redesign screenshot and screen recorder settings with native grouped sections
- **Shortcuts**: Add compact single-row shortcut recorder with inline reset and conflict handling
- **Recorder**: Keep screen live (unfrozen) during recording selection
- **Recorder**: Stash raw video in recent captures and align editor buttons
- **Capture**: Store screenshots directly in Application Support with date subfolders

### Changed
- **Capture**: Trim obsolete capture settings, dead screens, and legacy tool order remnants

### Fixed
- **Shortcuts**: Enforce single shortcut monitor, observe exits on resign/outside click, and isolate layout test
- **Build**: Add Carbon.HIToolbox import to ScreenshotToolOrderControls
- **Capture**: Unclip independent window stream and verify composite layer coverage
- **Capture**: Harden capture store file deletion and add downstream release notes tests
- **Screenshot**: Use fixed tool order, allow single key bindings, and set OCR sound to acknowledgment_sent
- **Capture**: Address review findings and add recording retention
- **Capture**: Harden recording import, editor close safety, export snapshot, text editing, and delayed start
  - Transactional history import: serialize recording import and index persistence on history queue with rollback on failure.
  - Safe editor closing: require preserved original or export before unprompted discard/close, and keep take alive during stashing.
  - Export snapshot saved state: mark only the captured snapshot saved upon export completion so in-flight edits remain modified.
  - Native annotation updates: refresh text editor bindings, callbacks, frame size, and wrapping container dynamically.
  - Delayed recorder lifecycle: track waiting state, reject stale start callbacks, and ensure proper cancellation.
  - Pin and text OCR polish: fix gesture targeting during drag-hide and direct barcode payload reading.
- **Editor**: Fix text undo crash, enable multiline wrapping, dynamic sizing, and bounded drag boxes
- **Pin**: Enable immediate first-try pinch zoom, native drag-to-move, and double-click preview
- **Screenshot**: Disable window opening zoom animation on overlay panel
- **Tests**: Adapt pin window visibility assertions for headless test runner
- **Release**: Leave DMG container unsigned without notarization to prevent Gatekeeper mount modal

# Changelog

All notable changes to the Lattice downstream distribution are documented here.
For base changes from upstream Vorssaint, see the upstream release notes.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to downstream release versioning (`vX.Y.Z-d.N`).

## [3.4.1-d.1] - 2026-10-16

### Added
- Independent downstream release cadence and provenance verification tooling.
