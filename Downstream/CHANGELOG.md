# Lattice Changelog

## [3.4.1-d.2] - 2026-10-17

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
