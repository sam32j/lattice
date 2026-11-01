# Visualizer Permission Implementation Plan

**Goal:** Request system audio access when Show audio visualizer is explicitly enabled, and leave it off after permission reset.

**Architecture:** Use a cancellable activation owner and a short-lived Core Audio tap/aggregate device that actually starts input, independent of music playback. Keep system audio separate from Screen Recording checks. Permission reset disables the visualizer and cancels its deferred recovery; restoring parents or screen access cannot activate it.

**Tech Stack:** Swift, SwiftUI, Core Audio; existing Swift test runner with disposable preferences and a fake HAL boundary.
---

### Task 1: Activation and reset
- Add `Core/NotchVisualizerActivation.swift`, test in `Tests/NotchVisualizerActivationTests.swift`.
- Observe failing checks for pending activation, denial, cancelled callbacks and reset.
- Implement request identity, pending-off state, reset preference clearing and deferred-recovery rejection.
- Run focused settings checks. No commits requested.

### Task 2: Immediate native audio request
- Add `Core/SystemAudioPermissionProbe.swift` and `Services/SystemAudioRecordingAccess.swift`.
- Test actual input-start orchestration and cleanup with a fake HAL boundary, including silence and setup failures.
- Replace the create/destroy-only prompt in `NotchAudioLevelService.swift`; never depend on a playing process.

### Task 3: Wire UI and reset
- Add `UI/Settings/NotchAudioVisualizerToggle.swift`; move the music options into their own cohesive view as needed.
- Integrate the gated toggle into Now Playing options and turn the visualizer off before resetting permissions.
- Preserve all unrelated UI work and other deferred feature activations.

### Task 4: Verify
- Run settings and affected Now Playing checks, developer compilation, independent review and final diff inspection.
- Do not invoke real permission dialogs, record real audio, install, commit or push.

## Completion evidence

- Activation/reset: 5 expected failures observed before implementation; settings checks passed afterward.
- Audio input request: 6 expected failures for missing input start and cleanup; corrected fake-HAL checks passed.
- Cancellation: 2 expected failures proved queued native setup could survive disable/reset; corrected checks passed.
- Parent/system-audio separation: 5 expected failures for parent restoration and screen-only revocation; corrected checks passed.
- Independent review found parent reconciliation behind Island early returns. A production-entry fixture failed before correction, then passed after moving reconciliation before every guard. Normal audio startup remains behind existing suspension/screen guards.
- Settings, Island/Now Playing, and feature suites passed: 49,816 checks before the final entry fix; the final settings suite passed 1,159 checks (49,817 distinct covered checks across these focused runs).
- Final developer compilation passed, including the new native audio backend, without installing or launching the app. Core Audio CFString ownership follows the SDK's retained-object contract; final compile has no new warnings.
- Final independent review: no remaining actionable findings. Whitespace diff checks pass.
- Native macOS permission prompts and granted/denied system behavior were not exercised. AudioDeviceStart success is treated as operation success, not a cached or independently queried TCC grant.
- All work remains uncommitted on the requested ui/settings-refinements branch alongside its preserved existing edits.

Apple API reference: https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps

## Denial regression reported by user

User reproduced Deny leaving the visualizer on. AudioDeviceStart noErr was incorrectly used as consent. Replace that inference with a typed, dynamically loaded TCC authorization backend, following the existing WindowServerCaptureQueue precedent. Preflight runs off-main and only known authorized values/native grant callbacks enable the child. Unknown/missing APIs fail closed. A denied retry opens System Settings and keeps a one-return explicit intent; a fresh passive verification on return decides activation. Stored-on preferences must also be passively validated before starting the reader. No implicit tccutil resets, microphone requests, or Screen Recording substitutions.

Reference implementation: https://raw.githubusercontent.com/insidegui/AudioCap/main/AudioCap/ProcessTap/AudioRecordingPermission.swift . This uses private TCC SPI; ABI failure must never fall back to an assumed grant.

### Denial regression resolution

The earlier HAL-probe activation path is superseded. SystemAudioRecordingAccess now reads real authorization through dynamic TCC preflight and requests through its native grant/deny callback, without creating an audio device. A first denial leaves both visualizer preferences off. An explicit retry after denial opens Settings; only a fresh granted reading on the next return can complete that explicit intent. Disable, reset, parent disable and disappearance invalidate recovery. Passive startup verification clears invalid retained-on state and never re-enables an off preference. Permission portal status uses the same off-main authorization reading with generation/cancellation guards.

Validation: seven new authorization tests failed before implementation, then passed. Final settings suite passed 1,225 checks (including native-response denial, unavailable APIs, stale callbacks, cancellation, Settings return and stored-on rejection). Native adapter typecheck and complete developer compilation passed. Independent implementation review found no actionable defects. Whitespace checks passed. Real macOS permission prompts, private SPI runtime behavior and native denial/retry remain unverified; no permission state was changed, and the app was not installed or launched. Work remains uncommitted on ui/settings-refinements as requested.

### Explicit Settings navigation refinement

User rejected automatic Settings navigation after denial. The visualizer now stays off and exposes its existing recovery button after either a native denial or a previously denied retry. Only clicking that button opens Settings and arms fresh one-return verification. Switching apps without clicking cannot complete recovery. The permission portal audio-request completion also no longer opens Settings automatically; its Settings row action remains explicit. Other permission routes are unchanged.

Research: Apple's Core Audio forum documents a first-use native prompt; the Core Audio tap library author at https://github.com/sbetko/catap#permissions documents Settings recovery after prior denial. No supported force-reprompt API was found. This is source research, not a native denial/re-prompt experiment. No real permission state was changed or reset.

Three regression checks failed before the change: visualizer retry navigation, unrequested return activation and portal retry navigation. Final settings suite passed 1,228 checks. Complete developer compilation passed without install or launch. Independent incremental review approved with no actionable findings; diff whitespace check passed. Keep current checkout and uncommitted work as requested.

### Permission dialog only

User requested removing the extra Settings button beneath the visualizer control. Its failure recovery is now presented solely inside a toggle-triggered permission information alert, using existing localized copy and explicit Open System Settings / Cancel actions. Settings still opens only after the alert's action is clicked; core authorization and recovery checks are unchanged. The prior view had only the inline button, so the alert keeps recovery reachable after removing it. Independent UI review found no material interaction defects; it caught an incorrect localization accessor, which was corrected to FeatureStrings.hub. No additional logic tests were added for this presentation-only edit; developer compilation is the verification gate. Native permission dialogs were not exercised.

Final developer compilation passed after the localization correction; whitespace checks passed. No install, restart, commit or permission reset was performed.
