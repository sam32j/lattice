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

- Cleaner: RED confirmed missing ownership guard, then protected-cache and hidden-cache regressions. New ownership boundary rejects protected Apple/media names before metadata access. Foundation enumeration now receives no prefetched keys; explicit property reads occur only after exclusion. Native filesystem-listing spy and isolated protected-content fixture reproduced the prefetch issue before the fix.
- Bluetooth: RED confirmed missing authorization boundary and missing Bluetooth revocation. Live checks guard IOBluetooth startup, the shared profiler and native CoreBluetooth clients; checks are repeated after queued/profiler work. Explicit accessory enable uses the shared cancellable coordinator. Revocation clears only island accessory activation and preserves HID battery demand and unrelated settings.
- UI additions: drag-only area fade; consistent permission colors; Permissions Cleared. title; canonical Camera Preview/Clipboard History names; enable-row icons and indented Open Feature shortcuts. Menu destination restoration preserves explicit None and replacement choices, with localized hints and a Don't restore action even while the picker is disabled.
- Final full suite: `./build.sh --test` passed **102,627 checks**, plus preference cleanup, uninstall-spaces and developer-install-isolation checks. Earlier full runs surfaced old Clipboard naming expectations and one unrelated native Window Layout timing failure; the updated title/structural-identity expectations and subsequent full run passed without changing window behavior.
- Final developer build passed. Strict deep signature verification and isolated selftest passed. Isolated rendering passed at `/tmp/lattice-unsolicited-render.Lkk4lx/pages-final`, including all five utility page states, drag/no-drag overlap, permission styling/reset states, actual native picker availability restoration and hosted Don't restore button activation. The build was not installed over the running application.
- Independent source review found two P2 issues: metadata prefetch before exclusions, and no cancellation affordance when both menu targets were absent. Both were fixed and re-reviewed ready, with no remaining actionable findings. Initial review capacity was temporarily unavailable; it recovered, so final verification includes independent source review as well as whole-diff self-review.
- Evidence limit: log/schedule/completion correlation strongly identifies scheduled Cleaner as the P6 trigger; live protected-library access was deliberately not reproduced. Tests verify removed read paths and activation behavior without changing real TCC grants.
- User authorized topic commits and push of refactor/settings-refactor-III only. No PR or merge. Remote verification follows publishing.
