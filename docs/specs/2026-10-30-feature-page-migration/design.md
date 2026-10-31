# Feature page migration on current main

Implement the previously approved page-ownership design on refactor/feature-page-migration, based on ddba7332. The ref/feature-page-migration worktree is reference material only; preserve its uncommitted work.

Retire the Features destination. Every owning settings page stays reachable while disabled, including search and legacy links. Preserve availability keys, saved configuration and existing default activation. Activation changes runtime behavior, not installed files.

Migrate the remaining ten owners: Stay Awake, Media Tools, Cleaner, Uninstaller, Homebrew, App Updates, Radial Menu, Command Bar, Kill Process and Port Manager. Utility workspaces keep an activation switch in the toolbar while off and on. Disabled content is centered, scrollable in short windows, and constructed without service-backed workspace content. App Updates and Kill Process show options only while enabled, immediately left of the activation switch in the same toolbar group. Options icons have no backdrop, including on hover. Command Bar and Radial Menu use grouped Form rows for activation. Stay Awake activation stays separate from starting a session.

Disabling stops owned background work, input registrations and stale actions. Owned reads cancel and reject late results, including across disable/re-enable. Shared Homebrew jobs retain requesting-owner isolation. Accepted mutations finish before disablement is allowed. Recovery of previously applied system overrides remains possible while disabled.

Current-main integration constraints:
- Video Downloader remains a registered AppFeature with the same raw value, opt-in default, enable preference, dedicated settings page, Hub action, Dynamic Island routing and backup behavior. The reference implementation predates its registration and cannot replace current feature tables wholesale.
- Preserve current Hub navigation and availability refresh. Extend lifecycle behavior to the current Hub as well as app-menu utility surfaces.
- Preserve fixed amber Stay Awake appearance, session/assertion failure handling, Hub timing controls and lock pause/recovery.
- Preserve all Dynamic Island lock transitions, physical input and first-swipe haptic fixes.

Approved verification seams are settings reachability/activation ownership, persisted availability/configuration compatibility, runtime launch/disable transitions, service cancellation/mutation boundaries and native page rendering. Use isolated defaults and injected process/filesystem/package boundaries; no real hardware, permissions, cleanup, process termination, installed app or package changes.
