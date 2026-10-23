# Media HUD Implementation Plan

**Goal:** Add the approved Clop-inspired optimizer HUD and Option-switched shared standalone File Cache window.

**Architecture:** Keep drag-preview state, file processing and platform presentation separate. Extend the existing native encoder and MediaService for explicit output formats and source-adjacent copies. Reuse the existing File Cache panel and native island Files surface, preserving File Cache state.

**Tech Stack:** Swift, SwiftUI, AppKit, AVFoundation, ImageIO, existing image helpers and isolated test runner.
---

## 1. Interaction policy

- Create `Sources/Vorssaint/Services/Media/FileUtilitySession.swift` and `Tests/FileUtilitySessionTests.swift`.
- RED: begin shared drag, press/release Option, commit optimizer drop, release Option and require optimizer to remain selected. Verify no preview outside shared standalone drag or when MO is unavailable.
- Run `./build.sh --test-suite=media`, then implement `beginDrag`, `updateDrag`, `commitDrop`, `endDrag` and explicit selection until green.

## 2. Native format bar and publication

- Create `MediaOutputFormat.swift`; modify `MediaOptimizerClient`, `NativeMediaOptimizer`, `NativeVideoOptimizer`, `MediaService`; test in `NativeMediaOptimizerTests`, `NativeVideoOptimizerTests` and `MediaOptimizerTests`.
- RED: request PNG from a JPEG and require actual PNG output even if larger. Implement native conversion, reject GIF flattening and incompatible media formats. Add H.264 export and verify the actual codec.
- Add source-adjacent destinations, preserving unique output naming and originals. Test two different source folders, cancellation and no-savings behavior. Run media suite per slice.

## 3. HUD model and views

- Create `MediaHUDModel.swift`, `MediaHUDView.swift` and small preview/action components. Model APIs: `receive`, `run`, `convert`, `chooseDestination`, result selection and cancellation. Read-only inputs remain original sources for every re-encode.
- Test valid/invalid/mixed drops, permission fallback and state preservation through an injected encoder boundary. UI includes input/drop, per-file results, progress, savings, supported formats and Copy/Reveal/drag actions. No automatic clipboard reads.

## 4. Shared window and island routing

- Extract existing classic panel construction and keyable panel class from `ShelfService.swift` into focused files before extending presentation. Create `FileUtilityPresentation.swift`, `FileUtilityStandaloneView.swift` and a native drop receiver.
- Route only drag-and-shake through Option preview. Keep hotkey registration and shortcut behavior unchanged. Reuse the exact existing NSPanel, preserve File Cache contents, refit without repositioning, and keep active MO jobs open.
- Add MO location preference/settings. Integrate HUD into island Files content and direct media entry points while retaining advanced workspace and archive tools. Keep shared preference/feature teardown behavior explicit.
- Run media, shelf, notch and settings suites. Add real view/window integration coverage and isolated rendering, without sending system input.

## 5. Review and publish

- Run `./build.sh --test`, `./build.sh --dev`, strict deep signature check, isolated selftest and HUD rendering/motion checks.
- Request independent review of diff since 8fca5ae2 and resolve substantiated findings with regression tests.
- Update this record with exact results. Commit subfeatures, push feat/media-optimizer and verify remote HEAD. No merge or PR.

## Status

Design approved; initial checkout clean at 8fca5ae2. Implementation complete.

- Interaction policy: transient Option mode applies only to the shared standalone drag session. Drop-time modifier resolution prevents a stale optimizer preview from swallowing a File Cache drop. Keyboard shortcut registration is unchanged.
- Encoding/publication: real JPEG-to-PNG and H.264 codec checks pass, with explicit larger conversion, source-adjacent copies, original preservation, EXIF orientation and transparent-to-white JPEG coverage.
- HUD: batch/result selection, native format bar, progress/cancellation, size savings, stronger compression, explicit Copy/Reveal/drag-out and original preview implemented. Pending file dialogs cannot restart after disable/re-enable because their intent tickets are invalidated.
- Presentation: shared classic NSPanel retains identity, File Cache contents and completed jobs across Option release and explicit mode switching. Docked File Cache remains cache-only. MO supports Follow File Cache, standalone and available island Files presentation, with a standalone fallback.
- Review: independent whole-diff source review completed with no remaining actionable blockers. Two findings (stale child-drop modifiers and stale dialog completion) were fixed with regressions and re-reviewed. Unfinished batch selections now return no result instead of another file's output.
- Focused media suite: `./build.sh --test-suite=media`, 60 checks passed. Expected RED was observed for the selection fallback regression before correcting it.
- Developer build: `./build.sh --dev` passed. Strict deep signature verification passed, including bundled media tools. Isolated `--selftest` passed; `--media-layout` reported `MEDIA MOTION OK`.
- Isolated `--settings-refactor-rendering --media-hud-only` passed: actual native child receiver, immediate Option release, shared NSPanel identity, cache/result preservation, valid geometry, and five rendered light/island/shared states. Fixtures used a test-only bundle identity and unique pasteboard, without posting input or changing real settings, permissions or clipboard.
- An initial full run exposed the new renderer's availability writes in the production-writer audit. Fixture setup now lives in the existing test-identity-guarded renderer, preserving that audit rather than widening its allowlist. Final `./build.sh --test`: **102304 checks passed**, including media (60), File Cache (473), island (56127), settings (780), repository (320), preference cleanup, uninstall Spaces and developer-install isolation checks.
- Runtime boundary: the drag fixture exercises native destination callbacks without generating a live Finder shake. Image renders validate HUD content; the existing native island geometry/motion probe checks the production host separately. No claim of end-to-end physical drag automation is made.
- Ready for the authorized push: topic commits cover encoding/publication, HUD state, shared-window/island presentation, native integration checks and documentation. Push target is `feat/media-optimizer` only. No merge or PR; downloader/refactor branches remain untouched.
