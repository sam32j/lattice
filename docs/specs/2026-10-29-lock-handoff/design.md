# Continuous lock handoff

Approved behavior: preserve a continuous island silhouette across locking and
unlocking, changing its size and content rather than disappearing and growing a
second island. With no activity, the lock island retracts behind the physical
camera. Click behavior and the earlier gesture changes are outside this change.

## Implementation

- Stage an opaque, noninteractive native silhouette at the desktop island's
  currently visible frame before tearing the desktop presentation down.
- Keep that window in its own lock-capable overlay Space through the handoff.
  Lock content lives inside that same native window, behind a layer mask that
  shares the silhouette's paths and animation timing. There is no second lock
  strip panel on this path.
- Hide the outgoing desktop panel as soon as the replacement is staged, before
  slow service teardown. Start the morph only after the lock content is mounted;
  the wider outgoing reading cannot remain exposed beside a narrowing backdrop.
- Morph its CAShapeLayer path independently of SwiftUI layout and main-thread
  service work. Never snapshot desktop content onto the lock screen.
- Keep music, calendar, download and agent sources running when the visible lock
  screen takes ownership, instead of stopping and immediately restarting them.
- On unlock, start the silhouette transition first. Build the desktop underneath
  at zero window alpha, without a second reveal animation. Reveal it only after
  the destination is ready, then retire the shared silhouette.
- Preserve Reduce Motion and the existing no-backdrop fallback. Retire pending
  animations on shutdown, sleep, or interruption.
- Record desktop preparation and completion times in the LockHandoff log category.

## Verification

Use the existing island session seam to verify preparation occurs before desktop
teardown and retirement happens after desktop preparation. Run the notch suite
once; it includes the music suite. Build the developer app. Review interruption,
display sleep and feature-disable paths independently. Actual session transitions
and loaded-machine frame timing require a live Mac check; automated checks do not
establish their visual smoothness.

## Capture-driven correction

Phone captures showed a trailing digit from the outgoing reading and a second
displaced strip. The code previously started morphing before desktop teardown
hid the original panel, and used another window for lock content. Both app-owned
mechanisms are removed above. Island tests pass (56,896 checks) and independent
review found no code blockers. Actual WindowServer snapshot behavior and visual
alignment still require a new live recording; passing tests does not prove those
artifacts have disappeared.

## WindowServer retirement investigation

The user reproduced the remaining displaced strip on the 22:11 developer build.
Logs from four lock cycles showed AppKit `orderOut` returning while the outgoing
window remained in WindowServer's on-screen list at alpha 1, with its bounds
translated downward and scaled. The shared lock panel itself stayed fixed.

The 22:14 build additionally clears the outgoing window's alpha through the
existing WindowServer fade operation (zero duration), mirrors alpha zero in
AppKit, then orders it out. Live traces confirm retained outgoing windows now
have alpha zero. The user confirmed no overlap on that build. This is live test
evidence for the reported artifact, not a guarantee across every OS timing case.

The same test exposed an idle-return regression: absence of live activity was
incorrectly treated as an empty destination, even with Battery or AI Usage
selected. `retractsOnUnlock` now preserves idle content and a visible companion,
while respecting hide-until-hover and its separate activity policy. Six added
policy checks pass; the full notch suite passes 56,902 checks. The user confirmed
the installed 22:19 build returns directly to the idle item with no overlap.

Developer-only LockTransition diagnostics log own-process IDs, layers, alpha and
bounds for one second after locking. No screen pixels or window titles are logged.
