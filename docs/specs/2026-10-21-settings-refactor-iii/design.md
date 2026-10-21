# Settings Refactor III

Approved October 21, 2026. Start from settings-refactor-II (689edf39).

Use one fixed-size reusable App List Sheet with scrolling, app icons, add/remove actions, and protected mandatory auto-quit exceptions. Dock Preview contains window thumbnails after a divider, flat experimental options, and an information accessory. Dock Tiles owns all Dock click actions.

Window Management has Windows & Spaces first: Maximize Windows, Quit Inactive Apps, Disable Space Reorder. Descriptions sit directly under titles. Window Snapping is one grouped card with its feature gate first, drag/edge controls, layout sizing, actions and exclusions.

Dynamic Island Content opens a single-column list of icon/title/chevron rows. Each row opens its own preview and settings page with the install/uninstall enable gate. Companion joins this list and uses its existing settings page. Existing deep links must still reach their detail page.

Use Liquid Glass automatically on supported macOS versions, respecting Reduce Transparency. Remove the appearance selections and obsolete preference gates. Always use translucent Dynamic Island background on every supported OS.

Rename Quick Panel to Launcher Grid. Standardize requested feature switches and remove capture installation badges. Preserve service synchronization, permissions, stored exclusions and keyboard shortcut semantics.

Verification: affected existing feature, preferences, settings/navigation/localization and window-layout suites; development build and selftest; whole-diff independent review. UI presentation changes are verified through build and available presentation probes, avoiding tests that mirror view implementation.
