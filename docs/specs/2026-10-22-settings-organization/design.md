# Settings organization

Approved October 22, 2026.

- Mouse and Trackpad: order cards by scrolling, pointer/focus, then buttons/gestures. All titles belong inside cards, with concise captions and no standalone headings.
- Keyboard: order cards by key behavior, input protection, keyboard backlight and Cleaning Mode. All titles belong inside cards, with no standalone headings.
- Cleaning Mode: trailing Activate Cleaning Mode button; on-demand activation requires no persistent installation. A configured shortcut owns persistent registration. Keep screen visible is a trailing switch above an always-reachable shortcut recorder. Removing a shortcut must not terminate an active cleaning session.
- Displays: Appearance, Display Controls, Wallpaper. Dark Mode is a label and switch. No More Options disclosure. Display options stay visible and disabled when control is off.
- Activity Monitor: always reachable; Modules owns CPU, GPU, memory, network, disk, power, connected devices and fan-control installation. Remove those switches from Features. Follow with Menu Bar, Panel, Readings and Alerts, preserving service teardown and saved presentation choices.
- Dynamic Island: Where things open owns capture preview/history placement; the Captures widget owns its live capture toolbar. Remove the duplicate Captures choice from Indicators, including its availability/selection logic. Preserve both preview placement and rich live capture UI.
- Follow-up revisions: no icon on Keep screen visible; no blue destination highlight on Displays or Bluetooth; Audio Input uses a headline for Mute Audio Input, mute-status menu-bar option before the centered shortcut row, and the label Show mute status in menu bar.
- Remove the optional standalone brightness overlay, its controls in Settings and the menu panel, its preference, window, exclusive formatting helper, write-queue bookkeeping and tests. Preserve Dynamic Island brightness notices, shared percentage formatting and native key behavior.
- Preserve preceding uncommitted Refactor III work. No commit, push or merge requested.

## Input-page refinement, approved October 22
- Mouse Scrolling contains direction, sideways modifier, smooth/linear scrolling and pointer acceleration controls. Mouse Clicks contains focus-following and extra-click filtering. Mouse Buttons contains side-button navigation, button shortcuts and button-drag gestures. Trackpad middle-click keeps its own card.
- Side-button help identifies the usual Back/Forward thumb buttons without assuming a device layout. Drag labels become Hold a mouse button to switch Spaces and Reverse horizontal drag direction.
- Per-feature app exclusions use Disable in these apps plus a trailing Edit button and the existing fixed App List Sheet. Preserve each feature's independent exclusion scope.
- Flatten enabled smooth-scroll settings. All input-page controls align to the trailing edge. Native sliders have no tick marks or permanent readout; show the value during dragging and on hover. Preserve each setting's existing range and quantization.
- Super Key uses Enable super key and an indented Super Key selector, with an adjacent accessible runtime-status dot. Duplicate-key filtering also uses a dot instead of a separate status block.
- Green means active; red with the requested conflict text means an actual foreign key mapping; off, excluded, permission-pending and other failures use neutral status with an accurate explanation. No service lifecycle behavior changes.
- Additional requested adjustment: Danger Zone uses matching native bordered text-only buttons, centered labels and a shared trailing edge. Retain destructive roles, confirmation dialogs and all reset/uninstall behavior.
