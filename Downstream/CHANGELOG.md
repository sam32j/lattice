# Lattice Changelog

## [3.4.1-d.2] - 2026-10-17

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
