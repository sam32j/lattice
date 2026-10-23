# Keyboard light, status hints and Bluetooth copy

Final handoff: committed by topic at the user's subsequent request. Final full
suite passes 112696 checks and all shell integration checks. No push or merge was
performed; uncommitted-state notes below record the earlier implementation stage.

User requested zero-brightness slider recovery, red info icons instead of status
dots, clearer Bluetooth descriptions, plus fixing the Super Key tooltip position
and removing the duplicate-key indicator and tooltip. Isolated native-control,
rendering and existing behavior tests approved. No live brightness/Bluetooth writes.

## Investigation and changes

- BrightnessService correctly publishes light-enabled as level > 0. The settings
  view incorrectly disabled its own slider at zero. Extracted the production
  slider into a computed property for isolated native rendering; the test failed
  on isEnabled before removing the disable modifier. Raising it now reaches the
  binding without requiring a separate toggle.
- Shared red status uses info.circle.fill; green and neutral remain circle.fill.
  Duplicate-key status and its unused computed presentation model are removed.
- A simple hosted HStack did not reproduce the user's centered tooltip. The
  presenter now anchors to the actual hover point in stable window coordinates
  instead of the SwiftUI representable's local bounds. The native geometry test
  verifies placement next to the icon; existing delay/cancel tests remain.
- Bluetooth captions in all 15 locales state the affected devices during sleep
  and explain that already-off Bluetooth stays off after waking. No service or
  preference behavior changed.

## Verification

- Slider regression failed before the fix; it now verifies that the native
  slider remains enabled at zero and raising it updates the binding/light state.
- Tooltip geometry fixture initially allowed NSHostingView to resize its window,
  moving the icon after hover. It now uses sizingOptions = [], matching the real
  Settings window and existing rendering probes, plus an initial layout settle.
  Settings checks pass (665), including one-second delay, cancellation and
  next-to-icon placement. Combined affected suites pass: 75052 checks across
  settings, notch, utilities and localization.
- Developer build, selftest and strict deep signature verification passed.
- All 31 isolated rendering fixtures passed at
  `/tmp/lattice-status-ui.fF06W6/rendered`; visually inspected red/green/neutral
  status styles, duplicate-key indicator removal and Bluetooth captions.
- Independent source review found no remaining blockers. Tests use synthetic
  hover events and isolated light state, not physical pointer movement in the
  full Settings page or live brightness/Bluetooth changes.
- Keep changes local and uncommitted on refactor/settings-refactor-III.

## Follow-up: stable screen-space hint

User still observed a centered tooltip after the popover correction. Replaced
NSPopover with a non-activating NSPanel, explicitly positioned beside the current
icon's screen rectangle, clamped to its display and flipped above at the bottom
edge. It is a child of the source window, hides on app deactivation, ignores input,
and orders out on exit/detachment/status change. The one-second delay remains.
The test now checks actual panel geometry, with explicit negative-origin display
and bottom/right-edge cases. No live key remapping or feature toggles used.

Error presentation is now outlined orange info.circle, as requested (interpreting
"range" as orange). Green remains a dot. The indicator moves immediately before
the Super Key selector; intrinsic picker sizing avoids a large invisible gap.
Final verification: settings and localization pass 8207 checks. Developer build,
selftest and strict deep signature verification pass. All 31 rendering fixtures
pass at `/tmp/lattice-info-hint.ICB5qn/rendered`. Independent review's deactivation
finding is fixed with active-app tracking and notification-driven cancellation;
re-review found no remaining blockers. Physical pointer movement in the user's
installed app was not tested; no app installation or restart was performed.

## Final presentation adjustment

User supersedes the status styling: no off/active indicators or associated hints;
only errors get a red, non-filled exclamationmark.circle beside the selector.
Reuse the existing approved native-control test boundary and keep the anchored
error hint behavior. Regression tests failed on the previous presentation before
the change, then passed all 670 settings checks. Developer build and independent
source review passed. No installation, restart, commit or push was performed.

## Error-gated controls

Super Key red-error state disables modifier buttons, Quick tap and app exclusions.
The enable switch and source selector remain available for recovery. Extracted the
actual dependent-control predicate into the approved isolated fixture: a six-state
off/healthy/error matrix failed for enabled+error before the gating fix.

Unavailable Spaces gestures now show the same red outlined indicator immediately
before the disabled toggle. Removed the toggle's native help; the indicator owns
the one-second anchored explanation. The toggle is disabled whenever system
commands are unreachable, including a previously saved on state. Preferences are
preserved; no automatic resetting or live system changes.

Focused settings, keyboard and pointer-input suites pass 22298 checks. Developer
build and independent source review passed. No installation, restart, commit or
push was performed; all earlier uncommitted work is preserved.
