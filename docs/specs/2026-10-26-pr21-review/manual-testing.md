# Manual test plan for PRs 20 and 21 review fixes

Use the latest `fix/settings-followups` build. These checks are for you to perform; automated verification did not change your permissions, shortcuts, hardware or playback. Record pass/fail, selected language and build commit. Restore any settings you change afterward.

For quit/close checks, use a disposable app window without unsaved work. Do not reset all permissions or uninstall Lattice for this review.

## Keyboard and shortcut conflicts

| Check | Steps | Broken before | Expected now |
| --- | --- | --- | --- |
| Assigned shortcut on the central page | In Keyboard Shortcuts, record a shortcut already assigned to another Window Management action. | Only an inline error appeared, without the standard conflict dialog. | The standard dialog names the attempted shortcut and its assigned action. The old binding remains unchanged. |
| Assigned shortcut on the feature page | Repeat from Window Management's action shortcut controls. | Conflict handling differed between the two pages. | The same dialog and assignment protection apply. |
| Invalid shortcut | Attempt a bare letter without the required modifiers on either surface. | A rejected shortcut could be described as assigned to “another action.” | Invalid-shortcut guidance appears, without inventing an assigned action. Some invalid input is rejected directly by the recorder. |
| Declined macOS takeover | If the recorder offers takeover for a system shortcut, dismiss that offer. | The central page returned to an inline conflict message. | It uses the shared conflict dialog identifying macOS; dismissal does not replace the old shortcut. |
| Translated presets | Switch app language to German, then French. Open Keyboard → Quit & close protection → Hold to confirm. | Hold preset names stayed in English. | German includes “Kurz”; French includes “Par défaut.” Other preset names follow the app language. |
| Hold preset limit, intentionally unchanged | Inspect both ⌘Q and ⌘W hold-duration menus without a saved custom value. | CodeRabbit requested adding a permanent 2,000 ms option. | The five intentional presets remain 250, 600, 800, 1,200 and 1,500 ms. No permanent 2,000 ms option is offered. An existing saved custom duration may still appear until you choose another value. |
| Existing custom hold duration | If your configuration already contains a non-preset value such as 700 or 1,800 ms, open the settings, leave, and return. | The menu showed the nearest preset while the service used the custom value. | The exact custom duration appears. Merely opening the page does not change it. If you have no legacy custom value, skip this case; isolated tests cover saved values. |
| Turkish recording hint | Switch to Turkish and begin recording a shortcut. | The Esc caption used unnatural word order. | It reads “İptal etmek için esc.” Escape cancels recording. |

## Quit/close HUD and responsiveness

| Check | Steps | Broken before | Expected now |
| --- | --- | --- | --- |
| Normal confirmation | Enable visual feedback and hold-to-confirm for ⌘Q or ⌘W. Hold the shortcut in the disposable app. | Window enumeration happened inside the input callback and could delay keyboard input. | Input remains responsive; feedback appears near the target window and completes only after the hold duration. |
| Cancel before confirmation | Press briefly and release before the threshold. Also try Escape while holding the shortcut. | A delayed lookup could risk stale feedback after cancellation. | No quit/close occurs. The HUD disappears and does not reappear later. |
| Rapid repeated attempts | Start and cancel several holds, then complete one. Repeat in double-press mode. | Delayed work could refer to an earlier, otherwise identical press. | Only the current confirmation owns the HUD. No stale HUD appears and no extra action fires. |
| Change target or switcher ownership | Begin a hold, then switch apps or open Command-Tab before it completes. | A deferred lookup needs explicit ownership protection. | The old confirmation is canceled and cannot act on the prior app or draw over the new session. |
| Busy desktop | With several existing windows open, repeat short canceled holds and type afterward. | A slow WindowServer response could block the tap callback. | No keyboard freeze or revived HUD. This is a real-world stress check, not a guaranteed latency benchmark. |

## Dock Preview and sliders

| Check | Steps | Broken before | Expected now |
| --- | --- | --- | --- |
| Custom hover delay | If you already have a custom Dock Preview delay such as 900 ms, open Dock settings and inspect the delay menu. Hover a Dock tile to compare. | The menu displayed “Longer” (350 ms) while previews still waited 900 ms. | The menu displays `900 ms`; opening settings does not rewrite it. Choosing a standard preset updates the delay. Skip this legacy case if no custom value exists. |
| Brightness readout, intentionally unchanged | Drag the extra-brightness slider, then release it. | CodeRabbit requested a permanent percentage label. | Keep the approved design: the value appears while sliding; no standalone idle percentage is added. |

## Feedback

Open Send Feedback. Stop before submitting an issue on GitHub; opening the draft does not submit it.

| Check | Steps | Broken before | Expected now |
| --- | --- | --- | --- |
| Presentation from Settings | Open Settings → About → Send Feedback. Compare with Changelog. Cancel or press Escape, then reopen. | Feedback popped in as a regular child window without native sheet presentation. | Feedback uses a native modal sheet with the system entrance/dimming behavior, then restores Settings on dismissal. Opening Feedback again while it is visible preserves the current draft rather than creating another sheet. |
| Standalone presentation | Open Feedback from an entry point while Settings is closed. Close it and then open Feedback from Settings. | Standalone and child-window presentation shared manual positioning. | The no-Settings entry point retains its centered standalone window. From visible Settings, it uses the native sheet. Both dismiss and reopen normally. |
| Subject-only draft | Enter a short subject, leaving the message blank. | This valid use case already worked. | Continue on GitHub stays enabled and the subject becomes the issue title. |
| Encoded subject overflow | Paste roughly 1,000 Chinese characters into the subject, leaving the message blank and diagnostics off. | Continue remained enabled until the browser handoff rejected the oversized URL. | Continue is disabled immediately and guidance says to shorten the subject or message. Your text remains editable. |
| Recovery and combined budget | Shorten that subject until valid. Then add text and toggle technical details near the size limit. | Form validation did not account for the entire encoded URL. | Continue re-enables as soon as the complete draft fits. Subject, message and selected diagnostics share one limit. |
| Localization | Repeat overflow in your preferred non-English language. | Guidance could omit the subject, offering no useful correction for a subject-only draft. | Guidance includes shortening the subject. |
| Accessible names | With VoiceOver, focus the subject field and diagnostics switch. | Empty control titles could omit their names. | VoiceOver announces Subject and Include technical details in the selected language. |
| Browser handoff | Use a short subject/message containing `+`, `&` and non-English text. Continue and inspect the GitHub draft without submitting. | Existing URL escaping must stay intact. | The destination is sam32j/lattice; punctuation and text survive. Diagnostics appear only when enabled. |

Browser-opening failure and exact URL boundary cases are covered with an injected browser result in automated tests; there is no need to break your default browser setup.

## Updates

These checks require a regular Lattice build. Developer builds intentionally bypass release-network checks and report up to date, so they cannot demonstrate the production failure/relaunch path.

| Check | Steps | Broken before | Expected now |
| --- | --- | --- | --- |
| Failed check followed by relaunch | On a regular build, disable automatic checks. While offline, manually check for updates, then quit and relaunch Lattice. | A recent failed-check timestamp became “Up to date” on relaunch. | No success is claimed from the timestamp. The last-attempt time remains visible; status is unchecked/idle until another actual check. |
| Available update followed by relaunch | When testing a regular older build with a genuine update available, check once with automatic checks disabled, then relaunch. | A recent available-update result could be misreported as “Up to date.” | Startup does not claim success from the timestamp. Check again to obtain the current offer; this change does not persist an update offer across launches. |
| Successful recheck | Restore connectivity and check manually. | The correction must not block ordinary checking. | The real response determines Up to date, available version, or failure. |

## Data & Permissions and rendering

| Check | Steps | Broken before or review concern | Expected now |
| --- | --- | --- | --- |
| Compact appearance | Open Data & Permissions in light and dark appearance. Narrow the settings window and optionally switch to German. | The initial reference-based styling was oversized; previews could mix a forced-light renderer with dark content. | Compact native rows, readable native colors, one aligned trailing action per row, and an info button beside each permission title. |
| Requestable permissions | Inspect missing Full Disk Access, Microphone and Calendar rows when those requests are available. Open each info popover without pressing Request. | Review questioned the intentionally limited request list. | These are the spec's three Request categories. Details alone never request access and include Open System Settings. Denied/non-requestable states use Settings. No grant reset is needed to test existing states. |
| Settings-only permissions, intentionally unchanged | Inspect Accessibility, Screen Recording, Notifications, Camera and Bluetooth rows. | CodeRabbit requested restoring their old Request buttons. | Keep Settings per section 7 of the supplied spec. Feature-specific permission prompts are unaffected. |
| Native Settings buttons, intentionally unchanged | Compare a missing Settings-only permission with a granted/unknown row. | `.outline` was a redundant alias for the native quiet style. | Both use the compact native bordered style; status text, dot and tile still distinguish permission state. The unused style alias is removed. |
| Developer screenshot probe | Run the disposable-identity Data & Permissions rendering probe and compare `data-permissions-light.png` with `data-permissions-dark.png`. | The helper forced light preferred appearance and did not set NSWindow appearance. | The supplied scheme reaches SwiftUI, the hosting view and the native window. Native backgrounds, controls and materials agree with that scheme. This is a tooling fix, not a new permission behavior. |

Import/export, reset confirmations, uninstall and native sidebar keyboard navigation were preserved. Do not perform a destructive reset or uninstall merely to validate these review fixes.

The test preference namespace and session-source guard corrections are CI-only fixes. They have no manual UI steps; automated harness and pointer-input checks verify them without changing real permissions or installing an input tap.
