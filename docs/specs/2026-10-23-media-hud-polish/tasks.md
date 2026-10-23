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

Design approved. Baseline clean at 7d4bc437 with existing renders inspected. Implementation pending.
