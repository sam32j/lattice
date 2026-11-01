# Shared hub editor

Approved: shared display/edit rail with a bounded Available Tools strip. Work stays in the main workspace on `ui/settings-refinements`, preserving existing changes.

User refinements: use two rows starting at eight apps, align incomplete rows to the leading edge, and keep the complete empty state/action visible when workflow tools are hidden, including when quick controls remain. The corner-radius question is a separate shape explanation: the current attached contour uses circular bottom arcs scaled by height and tighter inverse shoulders at the top.

The island uses the same rail, row count, item sequence and tile dimensions in both modes. Its editor adds a single horizontally scrolling Available Tools row rather than replacing the rail with a vertical grid. Height comes from the shared rail geometry plus a fixed editing strip; a bounded scroll viewport keeps controls reachable on short displays. Options have their own bounded region. When Done is pressed the editing strip collapses while the island retains its expanded editor size, then the island shrinks. Reduced Motion completes this sequence immediately.

Native drag sessions show an insertion marker and scroll at viewport edges, including while the pointer is stationary. Item positions remain stable during the drag. One successful drop writes the new order; cancellation or leaving the hub clears transient state without changing preferences. Typed local drag payloads distinguish workflow tools from quick controls. Quick controls retain their established two-row grouping and can be dragged to the hide strip.

Manage Tools considers all available tools and quick controls, including hidden controls. All new hub chrome, empty-state and drag copy goes through a typed localization bundle covering every supported app language.

Verification uses the previously approved production SwiftUI/AppKit presentation boundary, plus the actual geometry and drag/drop boundaries driving those presentations. It checks compact/wide islands, crowded catalogs, order before/after Done, drag scrolling and cancellation, quick-control-only editing, localization coverage, and floating HUD regressions. Independent review and a signed developer build precede installation and live verification.
