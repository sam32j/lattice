# Capture preview, pins, and recording overlays

## Approved design

Work in the main checkout on `feat/scroll-capture-preview`, starting at `8b640653`. Preserve unrelated local Settings audit notes. Do not create a worktree.

### Preview and pins

- Double-click the quick preview opens native Quick Look, not Preview.app. Escape dismisses it.
- Double-click a pin has no action.
- Pin context menu: zoom 0.5x, 0.8x, 1x, 2x; opacity 10%, 50%, 100%; Close (Command-W), Edit (Command-E), Copy (Command-C), Save to default folder (Command-S).
- Copy and save use the existing top-screen HUD, and errors must remain observable.
- Pins and their chrome sit above ordinary application floating panels, without attempting to supersede system security surfaces.
- Option blocks every zoom path while retaining opacity adjustment.
- Investigate raw-touch/magnification ownership and delivery before fixing intermittent pinch failure.

### Recording

- Add a camera toggle next to Microphone. C toggles it without a visible shortcut label. K toggles keystrokes, off by default.
- Right-click the camera or microphone button selects an available input, including Continuity devices exposed by macOS.
- PiP right-click menu includes camera, size, mask, and flip. Shapes: circle, square, rectangle 1.47:1, vertical 1:1.47.
- Sizes use longest-side targets of 192, 320, 480 output pixels. Medium defaults. Sizes that cannot fit the selection are disabled; Small dynamically shrinks. PiP never exceeds 500 output pixels on its longest side.
- PiP is constrained to the selection and soft-snaps to its edges. Clicking toggles full-area camera; dragging does not toggle. Full-area mode is exempt from the PiP size cap and restores prior PiP geometry on exit.
- Composite overlays into recorded frames. Do not depend on capturing preview windows, and exclude their chrome from recording.
- Display transient individual keys and shortcuts, never accumulating typed text. Suppress collection during Secure Input. Do not persist a typed-text log.
- Camera stops on disable, cancel, failure, or end. Device loss is visible, not silently successful. Update localized camera permission descriptions to acknowledge recording.
- When awaiting the first start, show centered Play and red Cancel. Mid-recording pause retains the top control with Resume, Stop, Trash.

## Architecture and verification

Keep pin interaction in pin modules. Add recorder-owned input configuration, camera lifecycle, geometry policy, overlay preview, key display, and frame composition modules rather than attaching recording behavior to the standalone camera mirror.

Verify behavior at native preview/window actions and gesture delivery, recording layout/input state, captured output frames and timing, permission/device failure and resource cleanup, and initial-wait versus paused controls. Use synthetic media for deterministic exported-frame checks and report any real-device validation gaps.

## Decisions

The user approved native Quick Look, transient individual keys plus shortcuts, and composited overlays. Main-checkout use explicitly overrides the design skill's normal worktree step.
