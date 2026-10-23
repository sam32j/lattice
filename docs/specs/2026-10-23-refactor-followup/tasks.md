# Refactor Follow-up Implementation Plan

**Goal:** Correct capture overlap/dialog behavior, app-menu entry paths and the requested permission/utility settings hierarchy.

**Architecture:** Keep presentation rules and permission lifecycle state separate from native side effects. Reuse shared island controls and native switches. Extract scoped responsibilities from oversized owners before extending them.

**Tech Stack:** SwiftUI, AppKit, CoreGraphics, ScreenCaptureKit, existing generated fixtures and native probes.
---

## 1. Settings hierarchy and copy

- Files: `Sources/Vorssaint/UI/Settings/{DedicatedUtilitySettings,IslandDestinationSettings,ClipboardSettings,ScratchpadSettings,ShelfSettings,GeneralToolSettings}.swift`, shared new utility controls and localized follow-up copy as needed; `Resources/Info.plist`.
- Implement exact hierarchy and regular switches, removal of separators/how-to, root global shortcut labels and disabled details. Preserve independent stored values while making the requested page controls read-only when disabled.
- Verify through isolated enabled/disabled/island on/off rendering, existing routing/service suites and developer build. Presentation-only checks use actual rendering, not source-shaped assertions.

## 2. Permission reset

- Extract reset row/state from `DataPermissionsSettings.swift` into a focused component. Add isolated lifecycle tests: confirmation cancel, success, failure and restart intent without invoking real TCC/login changes.
- RED: successful completion switches row to Restart now; failure never claims reset. Implement only after observed failure. Keep async working-state gating.

## 3. App-menu entry paths

- Extract scoped reopen/routing policy from oversized `AppDelegate.swift` before extending it. Test Don't show -> Settings for app reopen and icon click; retain available menu/island behavior.
- Implement path fix and run affected settings/reopen suites. No live app activation needed for unit coverage.

## 4. Capture overlap and system dialogs

- Files: `CapturePresentationPolicy.swift`, `CaptureChromeBackdrop.swift`, scoped extraction from `ScreenshotSelectionController.swift`, `ScreenshotCapturePolicy.swift`, `ScreenshotCaptureEngine.swift`, focused tests/probes.
- RED: overlap reduces whole-toolbar opacity; hover restores it; no intersection remains full strength. Remove old overlap-dependent solid plate and associated exclusive state.
- Establish native dialog metadata/ordering evidence before selecting a fix. Test eligible elevated surfaces and transparent bounds with isolated windows; preserve protected-window exclusions and safe capture fallback.

## 5. Media permission diagnosis and portal

- Trace scoped unified logs and callers without issuing new permission requests. Confirm caller where possible; report uncertainty honestly.
- Add non-prompting Media & Music status/settings access using supported API, plus isolated permission status mapping tests. Do not introduce startup requests or change P6 wording.

## 6. Verify/review/finish

- Run affected suites, full `./build.sh --test`, `./build.sh --dev`, isolated rendering, selftest and strict signing checks.
- Independent source review since 590fd058, including new files; fix substantiated findings and rerun affected checks.
- Keep one task record with exact checks and remaining live/protected-surface limits. No PR or merge. Topic commits on the existing refactor branch; confirm publishing authority before push if not established for this batch.

## Status

Approved; baseline clean at 590fd058. Settings hierarchy, reset lifecycle, reopen routing, capture fade/modal input and system-dialog geometry corrections implemented.

- Reset clarification: retain configuration, shortcuts and tuning; switch restricted feature activation off after verified permission loss. Removed the revocation policy's unrelated brightness-step reset. The isolated reset/revalidation integration test verifies tuning and shortcut preservation while duplicate-key protection turns off.
- Focused suites initially passed 2,680 checks (screenshots 1,808; settings 783; uninstaller 89). Final `./build.sh --test` passed **102,605 checks**, plus preference cleanup, uninstall-spaces and developer-install-isolation checks. Source-owner assertions follow the extracted capture views and updated exact prompt copy. The new restored-defaults fixture uses a verified swept test namespace.
- Developer builds passed. Isolated rendering passed for 20 utility page states, three reset states, four actual toolbar overlap/hover states, menu visibility and live picker updates, plus light/dark chrome. Images inspected for hierarchy, disabled controls, larger switches, fade and restart layout.
- P6 audit: scoped TCC logs identify `kTCCServiceMediaLibrary`, attributed to the main Lattice Developer process through sandboxd. The internal feature remains unconfirmed. No explicit MusicKit or MediaLibrary authorization request existed in source. The new portal row only reads current authorization; it never requests access. P6 wording is unchanged.
- Keyboard brightness uses CoreBrightness's private KeyboardBrightnessClient directly, not synthetic key presses or Accessibility. Its existing hardware interface does not require that TCC grant. Private API compatibility remains a separate risk.
- Capture boundary: native regression verifies modal-panel input capability; real CGImage fixtures verify alpha-based visible bounds and matching output crop, including empty-buffer rejection. Existing protected-surface eligibility is unchanged. No live system permission dialog was available for an end-to-end reproduction, and no real permission reset/request was performed.
- Independent review findings fixed and re-reviewed: retained custom brightness tuning initially rearmed the key tap after permission restoration. Added a separate persisted pause, used by the actual service getter and permission/energy reporting, with explicit picker selection to rearm. The production-getter regression failed before this fix. Review then found backup omission could rearm the tap; paused-Quarter export/restore regression failed before registering the new Boolean preference. Source re-review is ready with no remaining actionable findings.
- Final `./build.sh --dev` passed. Strict deep signature verification passed. The final isolated test bundle passed `--selftest` and `--settings-refactor-rendering --refactor-followup-only`, with images inspected at `/tmp/lattice-refactor-followup.sIzCvb/rendered-final`. Build output was not installed over the user's running developer application.
- User authorized topic commits and push of `refactor/settings-refactor-III` only. Topic commits cover capture, retained tuning/activation, reset/restart, app-menu entry, utility hierarchy, permission copy/status and rendering regressions. No PR or merge. Remote verification follows the push.
