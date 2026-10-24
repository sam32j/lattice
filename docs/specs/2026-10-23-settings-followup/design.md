# Capture and settings follow-up

User approved the recommended design and isolated verification. Baseline:
5bc0d3909e05a01984db691683118c08f6dbe663. Reuse the clean attached worktree;
final branch remains refactor/settings-refactor-III. Commit by topic and push,
without PR work or changes to lattice/main.

## Approved behavior

- Capture panels gain readable contrast and a near-opaque backing when overlapping
  the selection. Eligible system dialogs become window-selection candidates and
  selection overlays stay above them. Do not bypass protected macOS surfaces or
  promise capturability where the OS denies pixels.
- Pins, editors and editor dialogs stay above ordinary app windows but below
  Liftoff's full-size window. Read-only diagnostics showed its full-size layer is
  26; its layer-1000 window is only 2 by 2 pixels, not the launcher surface.
- Critical permission loss clears the activation preference immediately so both
  the switch and dependent details agree. Later permission restoration does not
  silently re-enable the feature. Retain the approved contextual audio exception.
- Remove the unnecessary keyboard-light permission row if neither direct control
  nor its shortcut path requires it. Keep genuine input-interception gates.
- Duplicate-key overrides retain first-added order through edits, removal and
  restart. Quick Snippets also follows Enable Text Snippets.
- App-menu selection reflects the saved rendering destination immediately.
- Camera Preview and Launcher Grid expose existing shortcut setters and the same
  combined route/widget island switch used by the other dedicated utilities.
  Hide that switch while the island is disabled. Place Launcher Grid above
  Command Bar.
- Menu Bar uses Show the menu bar icon, with its icon picker as an indented child
  visible only when shown. Preserve stored inverse-key compatibility.
- Replace user-facing Peripherals wording with Accessory wording, preserving
  framework names and saved data keys. Simplify the Bluetooth privacy prompt and
  add truthful Bluetooth status/request/Settings actions to Permissions.

## Verification boundaries

Use isolated settings/rendering, preference/service, window-policy, permission
state and shortcut seams. No real permission grants/revocations, remapping,
brightness or Bluetooth changes, app installation or main-app restart. Live window
metadata may be inspected read-only. Record protected-dialog and third-party
stacking limitations accurately. Independent source review is required.
