# Mixed music input recovery

Observed: Magic Mouse works after launch, trackpad feedback works, then mouse stops after trackpad use.

Investigation: the outer music controller passes `!awaitingBegin || blockedUntilLift` as physical-touch evidence to the mouse recognizer. Partial lift and cancellation deliberately retain `blockedUntilLift` to stop a canceled trackpad stroke resuming. A missing final touch snapshot leaves that historical flag latched, including after inactivity cancellation. Separately, a raw mayBegin marker in the mouse recognizer has no expiry unless tracking actually starts. Neither historical flag proves that fingers still touch the trackpad.

Plan: reproduce mixed-device sequences at the outer controller's event boundary. Preserve trackpad recognition, contact handling, physical thresholds, start/arm feedback and event receiver ordering. Bound mouse-only touch exclusion by observed touch timestamps, retire it at raw terminal input, and expire an abandoned mayBegin marker using the existing three-second recovery policy. Verify trackpad tails cannot become mouse skips and that fresh trackpad strokes still produce both haptics without opening Now Playing.

Validation: explicit input/time/native-tracker fixtures, existing mouse acceptance/cancellation cases, physical trackpad and cold-start haptic suites, full island regressions, developer compilation and independent review. No real device event posting, permissions or installed app changes. Physical device validation remains separate.

## Implementation and evidence

- Added `receiveMouseInput` at the actual outer controller boundary, moving the existing NSEvent-to-native-tracker adapter there without changing its options or acceptance rules.
- New mixed-device tests reproduced eight failures before the touch-evidence fix: lost final touch snapshots, partial lift, cancellation and inactivity could keep Magic Mouse excluded indefinitely. Existing music tests still passed.
- Mouse-only touch exclusion now uses recent observed contact timestamps and retires at raw Ended/Cancelled. Actual nonresting contact evidence is recorded even when recognition is blocked; historical trackpad lift guards remain unchanged. If both terminal streams disappear, the existing three-second inactivity policy bounds exclusion.
- A standalone production-controller regression also reproduced an abandoned `mayBegin` marker for both native and fallback mouse modes. Exclusion now renews while the classified stream delivers input and expires on inactivity, using the existing mouse watchdog.
- Independent review found that blocked-but-still-present physical contacts must refresh the evidence before early returns. Reproduced two failures first, moved observation before recognition gates, and verified continued contacts cannot become a mouse skip. This does not resume the canceled trackpad recognizer.
- Direct actual-source fixtures passed 89 checks covering native acceptance/cancellation/recovery, missing terminals, continuous blocked contacts, both first-stroke haptics, and mouse -> trackpad -> mouse -> trackpad sequences. A dedicated launch sequence drives the mouse routing boundary before the first trackpad touch and verifies zero native capture, haptics at 18/54 physical points, one track change, then immediate mouse navigation.
- The preceding complete combined run passed 97,047 checks and required preference/uninstall/install-isolation checks. Final full verification after the live-contact safety case and launch-sequence additions passed: 97,057 checks (/tmp/lattice-final-verified-tests.log), plus preference cleanup, uninstall paths with spaces and temporary developer-install isolation checks.
- Final developer executable compilation passed (/tmp/lattice-final-verified-build.log). Independent source review found no remaining actionable issues.
- Physical trackpad recognizer, haptic provider, touch receivers, NotchService and lock-transition implementations remain byte-identical to the merged main baseline. No real input events were posted, no permissions or hardware settings changed, and the installed app was not restarted or replaced. Actual Magic Mouse/trackpad validation remains a separate hardware check.

## Outcome

Complete locally, independently reviewed, and committed by topic on refactor/feature-page-migration. The final developer build and real-runtime migration probe both passed. User-visible explanation: a stale trackpad lift/cancellation flag was treated as live contact, and an abandoned mayBegin marker could also survive indefinitely. Mouse exclusion now follows live evidence and bounded stream lifetime; the original physical trackpad recognizer and haptic stages are preserved. Native hardware behavior still requires a real Magic Mouse/trackpad session and is not claimed as verified by fixtures.
