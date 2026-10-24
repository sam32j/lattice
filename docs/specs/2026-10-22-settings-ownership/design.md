# Settings ownership and permission-gated activation

Approved by the user after the complete requirements and interpretations were
presented. Baseline: f41011d03ef91acfc2b041c4f3193ec1bf7ca5a8, clean checkout.
Isolated worktree: settings-ownership-permissions. Final branch remains
refactor/settings-refactor-III. No push or real permission/hardware mutation.

## Decisions

1. A shared permission gate requests missing required capabilities before an
   enable preference becomes true. Denied, unresolved, cancelled or obsolete
   requests leave it false. No persistent queued activation. Disabling never
   requires permission. Optional capture microphone/camera permissions gate
   their own options, not unrelated capture capabilities. The feature toggle
   remains clickable to request access; screenshot/recording lose dedicated
   Grant Access rows. Permission revocation must stop gated runtime behavior.
   Audio-only capture and the live equalizer retain contextual access handling,
   as approved separately: macOS provides no reliable public preflight and silence
   must not be interpreted as denial or permission approval.
2. Text Snippets, Clean URL, Camera Preview, DMG Installer, Launcher Grid,
   Clipboard History, File Cache and Scratchpad own their installation state on
   their dedicated pages. Hide them from Features, keep sidebar/search reachable
   while off, and synchronize running services immediately on either transition.
3. Interface adds Launcher Grid; Command Bar uses chevron.right.square. Utilities
   replaces Clipboard & Files and orders Clean URL, Clipboard, Text Snippets,
   Scratchpad, Media, Camera Preview, DMG Installer, File Cache. Rebrand Shelf to
   File Cache across user-facing copy, retaining internal identifiers where that
   prevents unnecessary data loss. Remove Lattice Switcher selection highlighting.
4. Clipboard/File Cache/Scratchpad get consistent Enable rows and a separated
   Show on Dynamic Island row, visible only when the island is on. That switch
   updates both destination and widget state. File Cache drop-target and Clipboard
   activity/display-style children appear only under an enabled island route.
   Display style uses Compact and Regular. Keep other settings intact.
5. Move app-menu destination to General under Language, after a divider, with a
   hamburger icon and menu picker. Options: Dynamic Island when enabled, Menu Bar
   when visible, Don't show always. Invalid targets become Don't show, not a
   silently chosen alternative. With no valid target disable the picker and show
   the requested red error explanation. Move Hide menu bar icon to Menu Bar with
   no description. Rename island Tools references to Launcher Grid.
6. Remove standalone color-picker/OCR UI and all entry points to those screens,
   including persisted radial items that would otherwise still launch them.
   Preserve shared color/OCR functions used by capture/editor operations.
7. Remove the active capture indicator and Dynamic Island capture-controls code,
   including exclusive preferences/copy/tests. Preserve preview/history widgets.
   Capture selection and recording always use on-screen controls directly. Remove
   Hide Lattice windows selection/capture setting and its exclusive logic; no
   preference migration or backward-compatibility routing. Adjust the current
   running session only through the requested on-screen code path, not hardcoded
   preference overrides. Do not lose captures/history.
8. Inspect Liftoff's actual window level before selecting a common pin/editor/
   dialog layer. Keep those windows above ordinary apps and below Liftoff where
   the platform permits; do not claim priority over macOS security surfaces.
9. Input refinements: unavailable Spaces hint at one second, no duplicate-key row
   container except the keycap, exclude configured keys from Add picker, hide
   Super Key/duplicate-key details while off, Show visual feedback before
   confirmation mode, and stable tap-info hints. Preserve recovery controls.
10. Audio output rows use a pin-only action when pinning is the sole action, with
    a blue active pin. Shortcut active-state labels must update immediately when
    bindings change. All new descriptive copy has appropriate trailing punctuation
    in every supported language.

## Validation boundaries approved

Isolated permission request state, preference/service installation transitions,
settings rendering, sidebar/search routing, capture lifecycle, native hints and
shortcut changes. Do not grant/revoke real permissions, remap real keys, change
brightness or Bluetooth, submit feedback, or install/restart the main app during
tests. Distinguish source/unit/render evidence from live Liftoff verification.
