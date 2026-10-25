# Unsolicited Permissions Implementation Plan

**Goal:** Remove unnecessary media-library filesystem reads and prevent background Bluetooth permission prompts.

**Architecture:** Put pre-read exclusions at the Cleaner filesystem boundary. Reuse the shared permission activation/revocation model for Bluetooth and guard native clients independently of preferences.

**Tech Stack:** Swift, AppKit, CoreBluetooth, IOBluetooth, generated production-method fixtures.
---

## 1. Cleaner read boundary

- Create focused ownership/scan helpers under Sources/Vorssaint/Services/Cleaner; extract scoped responsibilities from JunkCleaner.swift before extending them.
- Add a regression proving Apple/media container metadata is not opened and protected cache contents are not traversed. Observe RED with ./build.sh --test-suite=cleaner.
- Apply pre-read exclusions; retain third-party owner matching and cache semantics. Re-run cleaner regressions.

## 2. Bluetooth activation

- Extend Core/PermissionActivationSupport.swift, PermissionPreflight.swift, BluetoothPermissionAccess.swift and UI/Settings/SettingsPermissionAccess.swift with verified, cancellable explicit Bluetooth requests.
- Add isolated authorization/reset tests before implementation. Add .bluetooth revocation for notchAccessoriesEnabled, not unrelated battery settings.
- Introduce a focused accessory settings card using the existing permission activation lifetime. Keep the same editor-card appearance.
- Gate Services/Notch/NotchAccessoryService.swift before IOBluetooth use. Extract the Bluetooth reader from Metrics/PeripheralBatterySampler.swift, gate profiler/client startup and preserve HID sampling. Test authorization loss and recovery without real clients.

## 3. Verification and review

- Run focused permission, accessory, metrics and cleaner suites; ./build.sh --dev; ./build.sh --test; git diff --check.
- Request independent review of all changes since 0e46b506, fix substantive findings and rerun affected checks.
- Record exact results, evidence limits and branch state. No PR or merge. Publishing follows explicit authority.

## Status

Implemented and verified. Real permissions and hardware remain untouched; no actual cleanup or permission reset was performed.

Follow-up: the user requested removal of the Don't restore button. Removed the button, its exclusive localized copy and native-button probe. Destination restoration and the existing explicit Don't show picker option remain unchanged. Earlier button-related verification below records the prior revision, not the current UI.

Follow-up: removed the Media & Music permission row, its exclusive view file/MusicKit import and rendering probe at the user's request. No music playback or other permission behavior changes. Earlier permission-row rendering results below refer to the prior revision.

Current follow-up: fix Camera permission-loss visibility and order the five utility child rows as Open Feature shortcut, then Show on Dynamic Island. Both rows hide when their enablement is off; Camera uses verified permission as well as the stored preference. Baseline ef7efbf7, preserving all prior uncommitted requested removals/copy changes. Root cause: the generic uninstall path refuses page-owned toggles, while the toggle and child rows read different effective states. Add a failing isolated revocation regression, fix page-owned activation at the revocation boundary, verify hosted Camera permission-loss rendering and all five layouts, run affected suites/build and independent review. No real permission changes.

Additional requirement: editing shortcuts must never install/enable these five utilities; only page toggles control activation. Hide their central Keyboard Shortcuts entries while unloaded. Existing recorders write dedicated shortcut flags, not page gates; verify that boundary and narrow the central inventory's use of always-visible Settings-page policy for these five roles. Keep Cleaning Mode and unrelated shortcut behavior unchanged.

Layout/copy follow-up: center shared shortcut labels against their setters and center shortcut icons against the title/status block. Rename the quick snippet action to Search snippets and omit its redundant central feature context. Move Dock Preview exclusions directly under enablement (user clarified keep and indent), indent Windows & Spaces and snapping exclusions/utility controls, and disable/dim Maximize Windows exclusions while off. Remove keyboard-backlight explanatory copy and its exclusive localized field; update output cycling and Cleaning Mode shortcut labels. Remove four duplicate Where things open rows while retaining shared routing preferences and dedicated-page/widget consumers; remove the now-exclusive quickPanel editor storage/watch. Focused settings (795 checks) and features (1,167 checks) passed. Developer build/signing and isolated follow-up rendering passed, including centered row snapshots. Preserve all edits locally and uncommitted per the user's selected outcome.

Dock click follow-up: replace the separate three-toggle card with Click Dock Tile and three icon tiles beneath Minimal previews in the first container, separated by a divider. Labels are Toggle Windows, Hide/Unhide Apps and Cycle Windows, without descriptions. Preserve exclusive action selection and the all-off state by clicking the selected tile again. Dock click controls remain independent of Dock Preview enablement. The existing cancellable permission coordinator verifies Accessibility before applying selection; its callback captures preference bindings instead of retaining the view's coordinator state. Isolated native button presses verify each action, deselection and denied permission with stale activation, without starting an input tap. Settings suite passed 795 checks; initial developer build/signing and rendering passed at `/tmp/lattice-dock-tiles-render`. Final callback-lifetime verification follows below. Keep local and uncommitted.

Final Dock tile verification: developer build and strict signing passed; isolated native selection/denial checks and follow-up rendering passed again at `/tmp/lattice-dock-tiles-verified` after the callback capture adjustment. Whitespace check passed. No real permission or input configuration changes, commit or push.

Standalone padlock sounds: move the switch to a Sound card immediately below General's Appearance card, labeled exactly “Play a padlock sound on lock or unlock.” with no description. Retain the existing stored choice. Extract notification ownership and system sound playback into LockSoundService/PadlockSound; start the opt-in service at app launch independently of feature installation and resync on preference changes. Stop all session listeners when disabled. Remove island playback, exclusive sound policy/resource helpers, unused sound-specific session property, island toggle/storage and its localized labels/description; move settings search ownership to General. Isolated notification-center tests collect playback requests without playing sound, changing grants or locking the Mac. Focused settings suite passed 805 checks, developer build and strict signing passed. Full regression and page rendering results follow after completion. Keep all work local and uncommitted.

Standalone sound full regression: `./build.sh --test` passed 102,674 checks plus preference cleanup, uninstall-spaces and developer-install isolation. Tests cover app-wide startup with the island unavailable, sound transitions with the island disabled, duplicates, dark displays, switched-away sessions, disabled service, and enable-while-locked. Island transition tests now verify it never plays the sound itself. No real sounds played or permissions changed.

Standalone sound rendering passed at `/tmp/lattice-standalone-sounds-render`; inspected `general-app-menu.png` confirms Sound immediately below Appearance, the exact label including its period, and no description. All edits remain local and uncommitted.

Current follow-up verification: Camera revocation regression reproduced two failures before the policy fix; central shortcut inventory reproduced five unloaded-entry failures before correction. Native hosted controls reproduced all five order/off-state failures and stale Camera permission visibility before correction. Final full suite passed 102,664 checks, preference cleanup, uninstall-spaces and developer-install isolation. Developer build, strict deep signing verification and isolated selftest passed. Isolated rendering/AX visibility and order checks passed at `/tmp/lattice-utility-children.HzjgRl/green`; permission-request spy remained unused. Recorder assignment/clear regressions preserve each master toggle. Independent source review found no actionable issues. User selected keeping all current changes local and uncommitted on refactor/settings-refactor-III, with no push, PR or merge.

- Cleaner: RED confirmed missing ownership guard, then protected-cache and hidden-cache regressions. New ownership boundary rejects protected Apple/media names before metadata access. Foundation enumeration now receives no prefetched keys; explicit property reads occur only after exclusion. Native filesystem-listing spy and isolated protected-content fixture reproduced the prefetch issue before the fix.
- Bluetooth: RED confirmed missing authorization boundary and missing Bluetooth revocation. Live checks guard IOBluetooth startup, the shared profiler and native CoreBluetooth clients; checks are repeated after queued/profiler work. Explicit accessory enable uses the shared cancellable coordinator. Revocation clears only island accessory activation and preserves HID battery demand and unrelated settings.
- UI additions: drag-only area fade; consistent permission colors; Permissions Cleared. title; canonical Camera Preview/Clipboard History names; enable-row icons and indented Open Feature shortcuts. Menu destination restoration preserves explicit None and replacement choices, with localized hints and a Don't restore action even while the picker is disabled.
- Final full suite: `./build.sh --test` passed **102,627 checks**, plus preference cleanup, uninstall-spaces and developer-install-isolation checks. Earlier full runs surfaced old Clipboard naming expectations and one unrelated native Window Layout timing failure; the updated title/structural-identity expectations and subsequent full run passed without changing window behavior.
- Final developer build passed. Strict deep signature verification and isolated selftest passed. Isolated rendering passed at `/tmp/lattice-unsolicited-render.Lkk4lx/pages-final`, including all five utility page states, drag/no-drag overlap, permission styling/reset states, actual native picker availability restoration and hosted Don't restore button activation. The build was not installed over the running application.
- Independent source review found two P2 issues: metadata prefetch before exclusions, and no cancellation affordance when both menu targets were absent. Both were fixed and re-reviewed ready, with no remaining actionable findings. Initial review capacity was temporarily unavailable; it recovered, so final verification includes independent source review as well as whole-diff self-review.
- Evidence limit: log/schedule/completion correlation strongly identifies scheduled Cleaner as the P6 trigger; live protected-library access was deliberately not reproduced. Tests verify removed read paths and activation behavior without changing real TCC grants.
- User authorized topic commits and push of refactor/settings-refactor-III only. No PR or merge. Remote verification follows publishing.
