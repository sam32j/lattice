# Settings consolidation

Approved by the user on 2026-10-19. Continue in the existing isolated Settings worktree on `feat/settings-shortcut-overhaul`; leave the main capture checkout untouched.

## Window and navigation

Settings content width is fixed at 772 points; height remains resizable. Sidebar width is fixed at 180 points, cannot collapse or hide, and its category groups do not collapse. Enforce constraints in AppKit as well as SwiftUI, following the inspected Capsol implementation without changing that project. Remove sidebar toggle commands and resize affordances. Keep Back/Forward and the current page title together above the detail, matching the supplied System Settings reference. Remove redundant page titles where the shared header supplies them. Preserve search, navigation history, section targeting, and long-page scrolling.

Use localized Desktop & Dock and ampersands in sidebar category headings. Rename Window Layout to Window Management. Move Wallpaper to Desktop & Dock. Remove standalone Dock Clicks, Spaces Order, maximizer, and Paste as Plain Text sidebar/hub entries. Dock owns compact Quit on Close settings. Finder owns Cut & Paste and Rename. Paste as Plain Text belongs to Clipboard History. Remove the global-shortcuts introductory sentence.

## Lifecycle and hardware

Use one consistent capability/lifecycle policy, not independent per-page guards. Hardware detection must not construct the feature service. Unsupported hardware controls are hidden. Supported off controls remain discoverable so they can be enabled, but off/unsupported features do not start feature-specific services, hooks, observers, timers, overlays, or privileged integrations. Enabling starts supported functionality; disabling or losing capability safely tears it down. Safety restoration for existing fan/helper state runs before teardown and must never be skipped merely because the feature is now off.

Fan control and XDR use capability plus their own toggle instead of independent installation. Audit other machine-dependent controls, including keyboard backlight, against the same resource rule. Dock clicks, fixed Spaces order, maximizer, and compact Quit on Close use their own toggles rather than independent hub installation. Preserve stable internal identifiers only where needed for shortcuts, navigation and migration, not as independent install gates. Paste as Plain Text follows its Clipboard History owner plus its own enable state. Migrate prior effective off/uninstalled choices without silently enabling behavior. Bulk install/uninstall must not reset toggle-owned controls.

XDR Extra Brightness moves into Displays > More Options, without a standalone page/hub entry. Detect support without constructing its overlay controller.

## Audio ownership

Audio Output owns output-device priority and output/mixer controls. Audio Input owns microphone priority, input-device selection and microphone level. Share cohesive controls where the live menu panel still needs both, without leaving input-specific settings owned by output files. Preserve saved device priorities and selection semantics.

## Permission reset

Investigate reset failures through controlled tests. Separate permission reset from uninstall-only cleanup: do not unregister login items, remove fan helpers or remove sudoers rules as a prerequisite to clearing permissions. Suspend relevant active integrations safely, reset only this application's permissions, refresh/reconcile state, and distinguish complete success, failure and restart-required/stale OS state. Do not claim unsupported permission revocation succeeded. Tests must not revoke real permissions or modify live hardware/system configuration.

## Removal

Remove first-run onboarding and tours, the Review Onboarding button, and Start with a Bundle presets. Remove orphan startup state, routes, components, assets, strings, defaults, tests and build registrations that serve only those flows. Retain ordinary updates, release notes/changelog and normal in-page permission actions.

Remove WhatsApp cleaning UI, organizer/controller/scheduler, notifications, preferences and sole-use dependencies. Preserve generic download monitoring, unrelated cleanup functionality, and all existing user files.

## Quality and verification

All copy changes update the 15 language catalogs and search labels. Keep new handwritten modules/tests under 300 lines; scoped edits in existing oversized files are approved. Verify preference migrations, lazy startup/teardown and capability transitions; reset failure paths; actual sidebar/hub/search consumers; audio input/output ownership; native fixed-width and unhideable sidebar behavior; removed-reference/dependency audits; rendering at the approved width; and full tests, developer build, self-test and whitespace checks. Independent review follows implementation. Clearly distinguish mocked system boundaries from real UI verification.
