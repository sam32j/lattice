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

Design and test boundaries approved. Implementation starting. Real permissions and hardware remain untouched.
