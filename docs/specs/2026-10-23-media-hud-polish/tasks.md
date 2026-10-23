# Media HUD Polish Implementation Plan

**Goal:** Make the approved shared Media Optimizer surface clearer and visually consistent without changing its processing behavior.

**Architecture:** Keep one presentation shell and reusable mode selector. File Cache gets an embedded-chrome option; the HUD changes only its visible controls/copy. Use existing model and native presentation boundaries for regression checks.

**Tech Stack:** SwiftUI, AppKit, existing isolated media test runner and developer rendering probe.
---

## 1. Shared shell

- Files: `UI/Shelf/ShelfView.swift`, new `UI/Shelf/ShelfBrandWatermark.swift`, new `UI/Media/FileUtilityModeBar.swift`, `UI/Media/FileUtilityStandaloneView.swift`, `UI/Notch/NotchFilesView.swift` under `Sources/Vorssaint`.
- Preserve the baseline renders as visual RED evidence: nested rounded File Cache card and unexplained Option symbol.
- Extract the existing watermark drawing before editing the oversized ShelfView. Add `embeddedInSharedSurface = false`; skip only backdrop/border when embedded, retaining drag-target feedback.
- Reuse an explicit selected-state mode bar. Explain Option only for shared standalone routes. Do not change session or routing policy.
- Render shared cache/optimizer and confirm one container, clear selection, unchanged docked behavior. Run `./build.sh --test-suite=shelf`.

## 2. HUD clarity

- File: `Sources/Vorssaint/UI/Media/MediaHUDView.swift`.
- Label Copy/Reveal, retain drag-out, rename preview control clearly, add Convert to and batch scope, and remove file(s) copy.
- Keep controls disabled during work exactly as before. Preserve immediate conversion and output/original pairing.
- Render first, then visually verify light/dark, standalone/island, busy/error/destination and batch states. This slice is presentation-only, so image and geometry inspection are the new acceptance checks, not source-shape assertions or new mocked business logic.

## 3. Rendering and final verification

- Files: `Sources/Vorssaint/Support/MediaHUDRenderingProbe.swift`, new state-render fixture as needed, `Sources/Vorssaint/Support/SettingsRefactorProbe.swift` only if color-scheme injection is needed.
- Build real fixture states through `MediaHUDModel` and an injected encoder boundary, never mutable test-only service state. Keep each handwritten file below 300 lines.
- Run `./build.sh --test-suite=media`, affected File Cache/island/settings suites and `./build.sh --dev`. Run isolated `--settings-refactor-rendering --media-hud-only`, `--media-layout`, `--selftest` and strict deep codesign verification. Inspect rendered PNGs; fix material layout issues before completion.
- Request independent review of all changes since 7d4bc437, resolve actionable findings and rerun affected checks.
- Commit shared-shell and HUD/verification topics; push `feat/media-optimizer`, verify remote HEAD and clean working tree. No PR or merge.

## Status

Complete. Baseline clean at 7d4bc437; baseline renders inspected before implementation.

- Shared shell: File Cache's embedded mode omits its own backdrop/border; default/docked chrome, watermark and drag-target feedback are preserved. A common selected-state mode bar serves the standalone and island views. The hint explicitly describes drag and shake, then Option.
- HUD clarity: visible Copy/Reveal labels, explicit original-preview help, accessible drag action, natural file-count/result copy, full-width progress, conversion scope and shorter footer. No encoder, model, routing or saving-policy changes.
- Visual verification: isolated native probe passed 15 rendered cases, including light/dark empty/completed, original preview, batch, running, failure, destination, unsupported drop, shared modes, island and original File Cache chrome. Images were inspected; measured heights stayed within the fixture bounds. Native immediate-Option-release, panel identity, cache items and result-preservation assertions passed.
- Regression verification: focused media/File Cache/island/settings run passed 57440 checks. Full `./build.sh --test` passed **102304 checks**, plus preference cleanup, uninstall Spaces and developer-install isolation checks. Media 60, File Cache 473, island 56127, settings 780, repository 320.
- Final developer build passed; strict deep codesign verification, isolated selftest and `--media-layout` motion checks passed. Final post-review copy/chrome renders used the final developer build.
- Independent source review identified one P2 hint-copy issue: Option was described too broadly. Corrected to qualify drag and shake; re-review found no remaining actionable blockers. No live Finder input was generated; the native destination fixture checks the callback boundary instead.
- Commits separated into design/plan, shared chrome/mode selector, HUD clarity and rendering verification topics. Publish only `feat/media-optimizer`; no PR or merge and no changes to downloader or settings-refactor branches.
