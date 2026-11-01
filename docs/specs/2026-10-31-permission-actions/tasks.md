# Permission Actions Implementation Plan

**Goal:** Show Request for actionable permission requests, Settings for denied/manual-only access, and remove the floating permission guide everywhere.

**Architecture:** Keep rendered permission status separate from request availability. A shared request route connects each Request action to a real native entry point; opaque audio access can be explicitly requested without pretending its grant is readable. Existing raw Camera, Microphone, Calendar, Bluetooth, Notification and Automation authorization states decide whether another prompt is possible. Remove the guide window, its call sites, dead reset helper and unused strings while preserving native dialogs and existing Settings flows.

**Tech Stack:** Swift, SwiftUI, native permission APIs, existing Swift regression harness.
---

1. Update the existing permission-row policy tests and observe failures for requestable rows and explicitly requestable opaque states.
2. Implement shared request routing and state-based request availability; test the dispatched action with inert native doubles.
3. Remove PermissionGuideOverlay, PermissionGuideStrings and the unused startOver helper; update affected source lists and overlay checks.
4. Run settings/overlay checks, compile, request independent review, and inspect the task diff. Do not trigger real permission requests, install, commit or push.

## Completion

- Updated action policy and typed native routes. Camera, Microphone, Bluetooth, Notifications, Calendar and Automation use their actual requestable states; known denied/manual-only access remains Settings. Explicit system-audio requests are available even while the grant is opaque, without enabling a feature.
- Reused native SettingsPermissionAccess, system-audio probe, Calendar and Full Disk Access entry points. Notification requests have a completion callback; Automation requests run off-main with explicit consent, while passive checks remain non-prompting.
- Removed the guide window, all call sites, dead start-over reset helper, unused translations and test/build references. macOS-native prompts remain.
- Policy regression: 19 expected failures before correction. Dispatcher fixture reproduced missing request routes and pending-click/status-refresh failures before correction.
- Independent review found an out-of-order Automation refresh race. The production refresh-method fixture reproduced stale undetermined results overwriting a newer grant. UUID matching and visibility guards now reject stale/hidden refreshes.
- Final settings and overlay suites passed: 1,242 checks. Final developer compilation passed; whitespace checks pass. Independent re-review has no remaining actionable findings.
- No real permissions were requested/reset, and no install, commit or push was performed. Native granted/denied dialog behavior remains a manual verification step.

## Reset completion and native request navigation refinement

User requested an immediate, required restart dialog after confirmed permission reset, using the former restart row's title/help, and investigation of duplicated Open Settings prompts/navigation. The reset row now retains its Clear presentation; after completion an app-modal NSAlert has only Restart. Success reuses restartTitle/restartDescription; partial failure uses the existing localized incomplete-reset explanation instead of claiming success. A surviving process receives a scheduled restart reminder so failed helper spawn or vetoed termination cannot strand a disabled row. Reset remains cancellable before confirmation. No reset state or real permission grant was changed during verification.

Root cause of duplicated Accessibility/Screen Recording navigation: SettingsPermissionAccess invoked the native consent request, then separately opened Settings when the immediate verification was false. Removed those two redundant open calls while retaining native requests, grant verification, needsSettings recovery and explicit portal Settings buttons. Other permission routes were not changed.

Independent review caught missing retry after failed relaunch and real dialogs in existing rendering fixtures. Both were fixed: restart reminder scheduling is injectable; DataPermissionsRenderingProbe and RefactorUtilityRenderingProbe explicitly suppress dialog presentation for simulated reset states. Review then approved with no remaining actionable findings.

Verification: two native-request behavior checks failed before removal of redundant navigation; three reset retry/rendering-isolation checks failed before their correction. Final settings and uninstaller suites passed 1,330 checks (1,232 settings plus 98 uninstaller), including extracted production request/dialog paths with inert system boundaries. Complete developer compilation and git diff --check passed. Actual macOS dialogs, real permission reset and app restart were not exercised. All changes remain uncommitted on ui/settings-refinements in /Users/samuel/Developer/Lattice.

### Final restart copy correction

User explicitly replaced the prior reset-result copy. Both successful and incomplete reset outcomes now use title "Restart Lattice" and help "Restart Lattice to finish permission reset." The restart dialog no longer references advancedClearFailed or claims permissions were cleared. Updated localized restart titles to the same meaning and updated the existing dialog checks. Restart enforcement, retry scheduling and actual reset behavior are unchanged.

## Full Disk Access action and reset-dialog consistency

Apple's public documentation requires the user to grant Full Disk Access in System Settings; there is no comparable in-app FDA grant dialog. The portal now treats FDA as manual-only and labels its action Settings. The explicit Settings action preserves the existing registration attempt and opens the FDA pane, so unlisted apps still have the same preparation as before. It never claims a native request API exists.

Reset confirmation and required restart now both use app-modal NSAlert.runModal with the same informational alert factory, replacing the SwiftUI confirmation alert. They share native icon, alignment, button rendering and placement behavior. Confirmation keeps Clear/Cancel and marks Clear destructive; reset begins only after positive confirmation. The required restart retains exactly "Restart Lattice" / "Restart Lattice to finish permission reset." and its relaunch-failure retry. Reset implementation was moved unchanged into beginReset.

Verification: FDA manual-only policy check failed before correction. Final settings/uninstaller suites passed 1,331 checks (1,231 settings, 100 uninstaller), covering manual routing, native confirmation choices and existing restart lifecycle through inert system boundaries. Complete developer compilation and whitespace checks passed. Real FDA access, reset dialogs and restart were not exercised; no permissions were modified for this task. Work remains uncommitted on the requested UI branch.

Apple reference: https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox

## Centered reset dialogs with background dimming

User requested both dialogs centered over the Settings viewport and the background dimmed. A shared PermissionDialogPresentation now lays out each native alert, centers it over its actual Settings owner, and overlays the owner's content with 28% black only during modal presentation. Native activation/resize and owner move/resize notifications maintain centering. A weak NSViewRepresentable window reference identifies the actual owning Settings window; no ownership cycle is introduced. Cleanup removes the overlay and all notification observers after every modal response. Existing Clear/Cancel, restart copy and mandatory restart/retry behavior are unchanged.

Verification: three new geometry/dimming checks failed against the prior presentation, then passed. Final settings/uninstaller suites passed 1,339 checks (1,231 settings + 108 uninstaller). New tests use hidden windows and an injected modal boundary; they verify viewport coverage/opacity, owner-relative geometry, recenter after modal key activation, observer and overlay cleanup, and response preservation without showing permission dialogs. Independent review found no actionable defects. Complete developer compilation and whitespace checks passed. Real native modal placement/Spaces/initial display have not been visually exercised. No real permission changes, app install or restart was performed. Changes remain uncommitted in the requested checkout.

## Rendered dimming failure and missing Clear report

User screenshot showed no Clear action and no dimming despite passing prior structural tests. Reproduced the dimming failure with an actual SwiftUI-hosted dummy window and the native modal loop: the AppKit overlay exists at alpha .28 in NSHostingView.subviews, yet SwiftUI paints above it and the captured window stays undimmed. A plain NSView owner did dim, proving the hosting/compositing boundary was missed by the earlier test.

Replaced that subview with a separate owned borderless, nonactivating, non-key/main child panel over the Settings window. The window server composites it above SwiftUI; it tracks owner frame, remains below the modal alert and is removed/closed after every response. Hidden test owners do not display a dimming panel. Clear now uses a normal native primary action rather than destructive-button styling. Both choices remain present, and no reset runs except on the positive response. The exact prior Clear disappearance was not reproduced reliably in the standalone baseline, so this styling change is a verified rendering mitigation rather than a proven OS-bug diagnosis.

Visual evidence: disposable probe uses an actual NSHostingView, actual NSAlert.runModal, automatic Cancel and only captures windows owned by that probe process. SwiftUI-before capture is /tmp/lattice-dialog-before-background.png; final composition of the probe's own windows is /tmp/lattice-dialog-fixed-composite.png. Final image visibly shows both Cancel and Clear, centered over a dimmed Settings-style viewport. No real permission requests, reset, notifications or Lattice lifecycle actions were executed. The earlier cached NSAlert.contentView image was not the actual glass-rendered alert; inspecting the real own-process glass window provided usable visual evidence.

Three new owned-panel regression assertions failed before replacement. Final settings/uninstaller suites passed 1,340 checks (1,231 + 109), developer compilation passed, whitespace check passed, and independent code/visual review approved with no actionable findings. Changes remain uncommitted and the installed Lattice app was not replaced or restarted.
