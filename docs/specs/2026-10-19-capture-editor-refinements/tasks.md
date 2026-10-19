# Capture, Editor, and Recorder Refinements Implementation Plan

**Goal:** Implement UI/UX refinements across screenshot editing, recording controls, dynamic island previews, and window selection while resolving CodeRabbit PR review findings.

**Architecture:** Refine AppKit/SwiftUI capture components: update `FinderBridge` and `ScreenshotPreviewContextMenu` for robust IPC and menu actions; improve `ScreenshotSelectionController` chrome with edge/corner tabs and rounded window punching; refine `ScreenshotEditorController`, `ScreenshotEditorView`, and `ScreenshotCropAspect` for the "Done" workflow, reversible annotation persistence, and exact geometry; adjust camera overlay dragging and dynamic island recent captures.

**Tech Stack:** Swift 5.10, AppKit, SwiftUI, CoreGraphics, Vision, ScreenCaptureKit.
---

### Task 1: CodeRabbit PR findings & quick preview menu fixes

**Files:**
- Modify: `Sources/Vorssaint/Services/Finder/FinderBridge.swift`
- Modify: `Sources/Vorssaint/UI/Screenshot/ScreenshotPreviewContextMenu.swift`
- Modify: `Sources/Vorssaint/Services/QuickTools/ScreenshotQuickPreviewController.swift`
- Test: `Tests/FinderRemovalTests.swift`
- Test: `Tests/ScreenshotPreviewTransformTests.swift`

**Step 1: Write the failing test**
Add test in `Tests/ScreenshotPreviewTransformTests.swift` verifying menu action strings and that reveal in finder works even when the file is not yet saved (invokes auto-save).

**Step 2: Run test to verify it fails**
Run: `./build.sh --test --test-suite=transient-paste` (or targeted suite)

**Step 3: Write feature implementation**
- In `FinderBridge.swift`: delimit output with `character id 0` in AppleScript and split by `\0` in Swift.
- In `ScreenshotPreviewContextMenu.swift`: change `.extractText` label to `screenshot.copyTextButton`; remove `.disabled(!canReveal)`.
- In `ScreenshotQuickPreviewController.swift`: on `.reveal`, if `savedFile()` is nil, call `saveToDefaultFolder()` and reveal the saved file in Finder.

**Step 4: Run test to verify it passes**
Run: `./build.sh --test --test-suite=transient-paste`

**Step 5: Commit**
Run: `git commit -m "fix(preview): address review findings and auto-save on reveal in finder"`

---

### Task 2: Screen recording area selection, camera overlay, & waiting controls

**Files:**
- Modify: `Sources/Vorssaint/Services/QuickTools/ScreenshotSelectionController.swift`
- Modify: `Sources/Vorssaint/Services/Recorder/RecorderCameraOverlayView.swift`
- Modify: `Sources/Vorssaint/Services/Recorder/RecorderCameraLayout.swift`
- Modify: `Sources/Vorssaint/Services/Recorder/RecorderOverlayController.swift`
- Modify: `Sources/Vorssaint/UI/Recorder/RecorderWaitingControls.swift`
- Test: `Tests/RecorderOverlayTests.swift`
- Test: `Tests/RecorderWaitingFlowTests.swift`

**Step 1: Write the failing test**
Update `Tests/RecorderOverlayTests.swift` for linear PiP dragging and nearest-edge snapping on release.

**Step 2: Run test to verify it fails**
Run: `./build.sh --test --test-suite=recorder`

**Step 3: Write feature implementation**
- In `ScreenshotSelectionController.swift`: draw prominent pill-shaped tabs on 4 edges (24x6 pt) and rounded corner tabs (10x10 pt) for recording area selection.
- In `RecorderCameraOverlayView.swift`: omit the "Starting camera…" string text when waiting for first camera frame.
- In `RecorderCameraLayout.swift` & `RecorderOverlayController.swift`: remove non-linear 18px magnet jump during drag; add `snapCameraToNearestEdge(animated: true)` on mouse up.
- In `RecorderWaitingControls.swift`: add press-state click feedback (`PressFeedbackStyle` with opacity/scale feedback) to play and cancel buttons.

**Step 4: Run test to verify it passes**
Run: `./build.sh --test --test-suite=recorder`

**Step 5: Commit**
Run: `git commit -m "feat(recorder): refine selection tabs, camera overlay and waiting button feedback"`

---

### Task 3: Floating window selector recognition & matching corner radius

**Files:**
- Modify: `Sources/Vorssaint/Services/QuickTools/ScreenshotCaptureEngine.swift`
- Modify: `Sources/Vorssaint/Services/QuickTools/ScreenshotSelectionController.swift`
- Test: `Tests/ScreenshotSelectionRefreshTests.swift`
- Test: `Tests/ScreenshotFeatureTests.swift`

**Step 1: Write the failing test**
Add test in `Tests/ScreenshotFeatureTests.swift` verifying that pickable windows include floating windows (layers 0..25, non-WindowServer) and rounded window punch-out paths.

**Step 2: Run test to verify it fails**
Run: `./build.sh --test --test-suite=screenshots`

**Step 3: Write feature implementation**
- In `ScreenshotCaptureEngine.swift`: allow window layers `layer >= 0 && layer <= 25` when owner is not "Window Server".
- In `ScreenshotSelectionController.swift`: punch out hovered/selected window rects using `CGPath(roundedRect: ... cornerWidth: 10, cornerHeight: 10)`.

**Step 4: Run test to verify it passes**
Run: `./build.sh --test --test-suite=screenshots`

**Step 5: Commit**
Run: `git commit -m "feat(capture): support floating window selection and matching corner radius"`

---

### Task 4: Dynamic Island preview focus & recent captures UI redesign

**Files:**
- Modify: `Sources/Vorssaint/Services/QuickTools/ScreenshotQuickPreviewController.swift`
- Modify: `Sources/Vorssaint/Services/Notch/NotchService.swift`
- Modify: `Sources/Vorssaint/UI/MenuPanel/PanelRecentCapturesView.swift`
- Test: `Tests/ScreenshotFeatureTests.swift`

**Step 1: Write the failing test**
Update `Tests/ScreenshotFeatureTests.swift` to verify preview focus activation behavior and timestamp formatting without seconds.

**Step 2: Run test to verify it fails**
Run: `./build.sh --test --test-suite=screenshots`

**Step 3: Write feature implementation**
- In `ScreenshotQuickPreviewController.swift` & `NotchService.swift`: activate `NSApp` and focus Notch window when capture preview opens with `takeFocus: true`.
- In `PanelRecentCapturesView.swift`: redesign recent captures card layout for dynamic island; format capture time without seconds (e.g. `HH:mm` or relative minutes).

**Step 4: Run test to verify it passes**
Run: `./build.sh --test --test-suite=screenshots`

**Step 5: Commit**
Run: `git commit -m "feat(notch): fix island preview focus and redesign recent captures UI"`

---

### Task 5: Editor window layering & traffic light repositioning

**Files:**
- Modify: `Sources/Vorssaint/Services/QuickTools/ScreenshotWindowLayering.swift`
- Modify: `Sources/Vorssaint/Services/QuickTools/ScreenshotEditorController.swift`
- Modify: `Sources/Vorssaint/UI/Screenshot/ScreenshotBackdropPopover.swift`
- Modify: `Sources/Vorssaint/UI/Screenshot/ScreenshotWatermarkPopover.swift`
- Test: `Tests/ScreenshotPreviewTransformTests.swift`

**Step 1: Write the failing test**
Add test in `Tests/ScreenshotPreviewTransformTests.swift` verifying dialog window levels sit strictly above editor window level.

**Step 2: Run test to verify it fails**
Run: `./build.sh --test --test-suite=screenshots`

**Step 3: Write feature implementation**
- In `ScreenshotWindowLayering.swift`: add helper `dialogLevel(above:)`.
- In `ScreenshotEditorController.swift`: define `ScreenshotEditorWindow: NSWindow` shifting traffic light buttons down 13px and right 5px; set alerts and `NSSavePanel` levels above the editor window.
- In `ScreenshotBackdropPopover.swift` & `ScreenshotWatermarkPopover.swift`: ensure `NSOpenPanel` level is above the editor window.

**Step 4: Run test to verify it passes**
Run: `./build.sh --test --test-suite=screenshots`

**Step 5: Commit**
Run: `git commit -m "fix(editor): elevate dialog levels and adjust window traffic light position"`

---

### Task 6: Editor tools, default focus, shortcuts & layout reordering

**Files:**
- Modify: `Sources/Vorssaint/Services/QuickTools/ScreenshotSupport.swift`
- Modify: `Sources/Vorssaint/Services/QuickTools/ScreenshotEditorController.swift`
- Modify: `Sources/Vorssaint/UI/Screenshot/ScreenshotEditorView.swift`
- Test: `Tests/ScreenshotEditorGeometryTests.swift`
- Test: `Tests/ScreenshotEditorSelectionTests.swift`

**Step 1: Write the failing test**
Update `Tests/ScreenshotEditorSelectionTests.swift` for new tool ordering (Crop first, Cursor second; Text selector bottom) and default shortcuts (Crop = `, Pixelate = 0, Numbering = N, Emoji = E, Text selector = T).

**Step 2: Run test to verify it fails**
Run: `./build.sh --test --test-suite=screenshots`

**Step 3: Write feature implementation**
- In `ScreenshotSupport.swift`: update `defaultShortcut` for tools.
- In `ScreenshotEditorView.swift`:
  - Reorder tool rail: Crop at top, Cursor second; text selection enclosed in standard button icon frame at bottom under emoji stamp tool.
  - History button in action cluster does not grab default focus; cursor button is focused.
  - Move contextual color/style bar to the top center as a standalone bar.
  - Increase share temp link icon size.
  - Update `dimensionsLabel` to display logical px (`pointSize`) instead of physical pixels.

**Step 4: Run test to verify it passes**
Run: `./build.sh --test --test-suite=screenshots`

**Step 5: Commit**
Run: `git commit -m "feat(editor): reorder tools, update shortcuts, move style bar to top and show logical px"`

---

### Task 7: Editor "Done" workflow, persistence & reversibility

**Files:**
- Modify: `Sources/Vorssaint/Services/QuickTools/ScreenshotSupport.swift`
- Modify: `Sources/Vorssaint/Services/QuickTools/RecentCaptureStore.swift`
- Modify: `Sources/Vorssaint/Services/QuickTools/RecentCaptureService.swift`
- Modify: `Sources/Vorssaint/Services/QuickTools/ScreenshotPinWindow.swift`
- Modify: `Sources/Vorssaint/Services/QuickTools/ScreenshotEditorController.swift`
- Modify: `Sources/Vorssaint/UI/Screenshot/ScreenshotEditorView.swift`
- Test: `Tests/ScreenshotEditorSelectionTests.swift`

**Step 1: Write the failing test**
Add test in `Tests/ScreenshotEditorSelectionTests.swift` verifying that `controller.done()` persists reversible annotations, updates pinned window/recent cache, and handles `Cmd+S`, `Cmd+Shift+S`, and `S`.

**Step 2: Run test to verify it fails**
Run: `./build.sh --test --test-suite=screenshots`

**Step 3: Write feature implementation**
- Make `ScreenshotSupport.Annotation` and related enums `Codable`.
- In `RecentCaptureStore.swift` / `RecentCaptureService.swift`: save and load annotations alongside cached captures.
- In `ScreenshotPinWindow.swift`: support updating displayed image and annotations from editor.
- In `ScreenshotEditorController.swift`: implement `done()`; configure key handling: `Cmd+S` and `Enter` invoke `done()`, `Cmd+Shift+S` invokes `save()`, single key `S` invokes `saveAs()`.
- In `ScreenshotEditorView.swift`: update top-right action button to "Done" (`.borderedProminent`).

**Step 4: Run test to verify it passes**
Run: `./build.sh --test --test-suite=screenshots`

**Step 5: Commit**
Run: `git commit -m "feat(editor): implement reversible Done workflow and shortcut overhaul"`

---

### Task 8: Text double-click editing, highlight tool, perfect shape & cropper math

**Files:**
- Modify: `Sources/Vorssaint/Services/QuickTools/ScreenshotEditorGeometry.swift`
- Modify: `Sources/Vorssaint/Services/QuickTools/ScreenshotCropAspect.swift`
- Modify: `Sources/Vorssaint/Services/QuickTools/ScreenshotEditorController.swift`
- Modify: `Sources/Vorssaint/UI/Screenshot/ScreenshotEditorView.swift`
- Test: `Tests/ScreenshotEditorGeometryTests.swift`
- Test: `Tests/ScreenshotTextEditorTests.swift`

**Step 1: Write the failing test**
Add tests for:
- Double click opening text editor without selection drag clearing `editingTextID`.
- `.redact` perfect shape constraining to square in `shapeEnd`.
- Highlight tool discarding when no text runs exist and using I-beam cursor.
- Aspect ratio cropper orthogonal projection tracking mouse.

**Step 2: Run test to verify it fails**
Run: `./build.sh --test --test-suite=screenshots`

**Step 3: Write feature implementation**
- In `ScreenshotEditorView.swift` and `ScreenshotEditorController.swift`: serialize double-click with `finishSelectDrag` preserving `editingTextID`.
- In `ScreenshotEditorGeometry.swift`: add `.redact` to `shapeEnd` for perfect shape; update `aspectRect` with orthogonal projection.
- In `ScreenshotCropAspect.swift`: update corner resize calculation to follow mouse projection.
- In `ScreenshotEditorController.swift`: highlight tool only creates annotations when text runs are matched; cursor for highlight set to `NSCursor.iBeam`.

**Step 4: Run test to verify it passes**
Run: `./build.sh --test --test-suite=screenshots`

**Step 5: Commit**
Run: `git commit -m "fix(editor): fix text double-click, filled rect perfect shape, cropper tracking, and highlight cursor"`
