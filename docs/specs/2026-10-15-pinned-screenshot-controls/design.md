# Pinned screenshot controls

Approved by Samuel on 2026-10-15. Builds on ea225d27 and preserves scroll zoom, Option-scroll opacity, and pinch zoom.

## Interaction

- A persistent Screenshot setting enables fixed 10-point rounded pin corners, on by default. Changes update open pins; exported pixels remain unchanged.
- One opaque centered feedback pill displays original-display-size zoom (one decimal, x suffix) or chosen image opacity (10–100%). New changes replace the old value immediately, restart a one-second idle delay, then fade over 0.2 seconds.
- Hover reveals a glassy circular Close control at top left, separate Lock and click-through controls at top right, and a bottom-center file drag pill. Controls retain full opacity independently of the image.
- Lock freezes movement and size through dragging, edges, arrows, wheel and pinch. Opacity, file dragging and close remain available.
- Click-through applies to the image; controls remain interactive. Hover dims the image to min(chosen opacity, 25%); exit restores chosen opacity. The cursor button disables this mode. Existing Option-click recovery remains available.
- Dragging the image moves an unlocked pin. Dragging the file pill offers the original full-resolution PNG to destination apps. Successful ordinary drops close the pin; Option-drops and cancelled/rejected drops retain it.
- Geometry and rounded clipping affect display only. A file promise creates exports only on demand; close must not invalidate an in-flight destination request.

## Architecture and alternatives

Use AppKit: an image panel with small native child panels for controls and feedback. Separate input surfaces keep controls functional when the image ignores events and prevent UI opacity from following image opacity. Extract the current nested content/window responsibilities into focused modules. Reuse current image rendering, copy/save helpers, localization and preference conventions. No dependencies or new permission requirements.

Rejected alternatives: ignoring mouse events for the entire pin requires a recovery-only shortcut; a detached toolbar diverges from the requested corner controls. A full-size interactive overlay would intercept underlying clicks and defeat click-through.

Hover tracking exists only while pins exist and must also work over a click-through panel. Close removes child windows, pending feedback work, observers and monitoring. Lock and click-through are independent per-pin state; only rounded corners persist globally and participate in settings backup.

## Reference and verification

CleanShot official features: https://cleanshot.com/features
CleanShot changelog documents Lock Mode, Drag me and Option-drag retention: https://cleanshot.com/changelog
User explicitly chose separate movement lock and click-through buttons. Radius, dim cap and timings are approved design choices, not claims about CleanShot internals. The installed CleanShot could not expose a pinned reference window through the inspected UI/API; do not claim live parity from that attempt.

Approved verification seams: production AppKit gesture/window actions and resulting geometry, opacity and visible feedback; real PNG file promise output/drop completion; preference persistence and backup inclusion; actual built UI for visual and click-through verification. Native event fixtures do not prove physical trackpad behavior. Multiple displays and Spaces require explicit evidence or a documented gap.
