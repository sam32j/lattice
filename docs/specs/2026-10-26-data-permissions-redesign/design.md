# Data & Permissions consistent rows

Approved: use the supplied layout and behavior reference, refined to the existing compact native visual style; retain Settings for unknown states, put Open System Settings in each permission info popover, use the supplied Import copy, preserve confirmations and reset/restart behavior, and provide an adaptive dark palette. Use the latest current branch in the primary workspace; no worktree.

Visual refinement approved by the user: the reference governs row structure and behavior, not a pixel-for-pixel visual replacement. Retain Lattice’s existing compact native Settings appearance.

Layout: standard 22-point page inset and compact title-case section labels. Use the existing adaptive quaternary card surface, 16-point corners/insets, standard dividers, 30-point status tiles with 13-point icons, native body/caption text and 12-point column gaps. One shared row keeps all trailing actions aligned. Native bordered buttons share a fixed label width; Request uses native prominence. Info is beside the title in a compact fixed-height title line, with status below it. No custom monochrome button skin or hard-coded light/dark palette.

Behavior: show Request only for missing Full Disk Access, Microphone or Calendar when that request path is available. Retain the existing manual Full Disk Access setup action. Denied microphone/calendar paths use Settings; granted/unknown states use quiet Settings. Popover explains the permission, retains active-feature context and always includes Open System Settings. Opening details never requests access.

Data and destructive rows reuse the same row/action geometry and keep their existing import/export/uninstall/reset actions, alerts and error reporting. Successful reset retains the existing inline cleared/restart state and exact English title without a trailing period.

Keyboard: retain the existing native sidebar navigation. The user explicitly withdrew the keyboard-navigation change before delivery; no sidebar or Settings-hosting edits remain.

Validation: isolated action-policy and native layout tests; representative light/dark, long-label and reset-state rendering; affected tests and Developer build. No real permission prompts, reset, uninstall, clipboard writes, playback, hardware or ordinary application launch.

Scope correction: the user withdrew the sidebar keyboard-navigation request. All sidebar implementation/test edits were removed; retain native keyboard navigation and focus behavior.
