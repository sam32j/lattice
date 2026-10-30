# Approved Dynamic Island settings changes

Continue on `feature/dynamic-island-improvements` at `9206a7c2`, preserving the
existing uncommitted gesture and lock-handoff changes. No commit or publication
requested.

## Acceptance checklist

1. Hide sub-settings while disabled; retain the main enable switch.
2. Remove the Experimental badge from that switch's row.
3. Use the approved hover-delay and close-delay helper sentences.
4. Use “Hide Dynamic Island when idle” and its approved top-of-screen helper.
5. Remove the previous misleading live-activity caption; no replacement supplied.
6. Default-page order: Recently used, Explore, Lattice Hub, App Menu, then localized
   alphabetical module names. Preserve saved unavailable entries, disabled.
7. Remove the outer Activity heading.
8. Keep Show when idle, add its approved helper, force Nothing and disable choices
   when hide-when-idle is enabled. Suppress idle content in runtime reads as well.
9. Group three live-activity toggles under Live activity without internal dividers.
10. Keep Indicators in the same card, with a separating divider.
11. Rename the idle AI option to AI usage.
12. Rename the AI widget and its detail title to AI Usage.
13. Capitalize Volume Mixer.
14. Restore legible AI idle ring/reading sizing without modifying lock transitions.

All items implemented. English copy is exact; corresponding labels and new copy
have localized entries. AI idle rendering shares a height-aware production view
between hanging and floating islands. Its reading retains a small scaling range
for longer cost values. The activity picker's cell width rounds upward so renamed
localized labels have sufficient room.

## Evidence

- Developer build passed.
- `./build.sh --test-suite=notch --test-suite=settings`: 57,952 checks passed.
- Added idle policy regression checks at the existing NotchSupport boundary.
- Independent read-only review found no blocking issues.
- Isolated visual probe: `--settings-refactor-rendering --island-settings-only`.
  Render output is under `/tmp/lattice-island-settings-review`.
- Visual probe passed; inspected disabled-page and disabled widget-route renders,
  opening copy, grouped idle/live/indicator sections, and AI readings at 24, 32 and
  38 points with actual idle wing insets. Persisted Nothing assertion passed.
- No real preferences, permissions or lock/unlock session were used for validation.
