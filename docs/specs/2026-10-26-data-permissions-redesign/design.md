# Data & Permissions consistent rows

Approved: use the supplied light reference and implementation spec; retain Settings for unknown states, put Open System Settings in each permission info popover, use the supplied Import copy, preserve confirmations and reset/restart behavior, and provide an adaptive dark palette. Use the latest current branch in the primary workspace; no worktree.

Layout: 28-point page inset; uppercase 12-point section headers; Data, Permissions, Danger Zone order. Cards use 16-point corners, 18-point horizontal insets and full-row dividers. One shared row uses 40-point icon tiles, 14-point gaps and one fixed 112-by-34 action. Titles use 15-point semibold; secondary text uses 12.5 points. Permission title/info line remains 20 points high with a 28-point info hit target; status lives below it.

Behavior: show Request only for missing Full Disk Access, Microphone or Calendar when that request path is available. Retain the existing manual Full Disk Access setup action. Denied microphone/calendar paths use Settings; granted/unknown states use quiet Settings. Popover explains the permission, retains active-feature context and always includes Open System Settings. Opening details never requests access.

Data and destructive rows reuse the same row/action geometry and keep their existing import/export/uninstall/reset actions, alerts and error reporting. Successful reset retains the existing inline cleared/restart state and exact English title without a trailing period.

Keyboard: disable the sidebar table's native type selection and keyboard focus, scoped to the sidebar only. Preserve click selection, programmatic routing, search editing/result navigation, text fields, shortcut recording and normal control focus.

Validation: isolated action-policy and native keyboard/layout tests; representative light/dark, long-label and reset-state rendering; affected tests and Developer build. No real permission prompts, reset, uninstall, clipboard writes, playback, hardware or ordinary application launch.
