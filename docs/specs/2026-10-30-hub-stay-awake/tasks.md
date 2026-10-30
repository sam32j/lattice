# Hub Stay Awake Implementation Plan

**Goal:** Integrate Stay Awake session controls into the Hub without vertical icon movement, and keep the island indicators consistent.

**Architecture:** KeepAwakeManager owns the session and persistent lid preference. The Hub uses a fixed-height split toggle and an anchored popover. Native assertion ownership and shared compact formatting are independently testable.

**Tech Stack:** SwiftUI, AppKit, IOKit, the existing generated Swift test harness.

## Completed behavior

- Clicking the bolt starts a one-hour session when inactive and stops any current session when active.
- Only clicking the chevron opens configuration. Hovering shows the localized Stay Awake text tooltip.
- The first popover row contains four text-only actions: +15min, +30min, +1hr and +4hr. Timed sessions extend from their current expiration; inactive, indefinite and end-time sessions start a fresh duration.
- Stay On starts an indefinite session. Set End Time... reveals a native time field without changing the current session. The first valid edit starts an end-time session; later edits update it immediately while retaining the editor.
- Stay On and Set End Time show selected states. Other session actions hide the editor. The header status chip includes Stop.
- A passed time means tomorrow, indicated inline. Closing the popover never ends the session.
- Prevent sleep with lid closed uses a trailing native switch without visible helper text. Its preference persists independently. Unsupported Macs disable the switch and expose an accessibility explanation.
- Native assertion acquisition failures never publish a successful active session. Failed release remains visible and retryable. Quit restores persistent lid policy even if releasing an IOKit assertion fails.
- Requested lock-screen pause reconciliation retries release and never silently reacquires assertions while pause is requested. Wake reconciliation checks the native assertion state.

## Shared presentation

- Compact remaining time uses U+2032 PRIME through 180 minutes inclusive, for example 180′. Larger values round to the nearest quarter-hour, for example 3¼hr, 3½hr or 3¾hr.
- The Hub bolt and countdown share a horizontal centerline, with a font-fit fallback that retains complete readings.
- Stay Awake uses bolt icons across its feature surfaces. The popover header uses bolt.badge.clock. Existing menu-bar tint preferences and legacy serialized icon values remain readable.
- Physical and floating island indicators follow the menu-bar tint and Battery text scale. Their bolts use 15-point and 11-point sizes respectively, matching the midpoint between the preceding two versions and matching their measured geometry.
- Camera Preview is a quick toggle rather than a workflow tile. The second row is fixed in this order: Camera Preview, Cleaning Mode, Eject Disks, Empty Trash, Lock Screen, Display Off, Screen Saver.
- Hidden or unavailable controls are omitted without rebalancing the rows. Primary toggles preserve their saved order. Legacy hidden-camera preferences migrate without losing other hidden workflow items.

## Verification

- Developer app build passed on the final implementation. No app installation or live sleep-policy changes were performed during these follow-ups.
- Focused regression run passed 57,518 checks: notch 56,904; launcher 142; switcher 307; keep-awake 165.
- Inert rendering exercised the production toggle and popover at their actual sizes. Native accessibility presses verified all four duration actions, selected states, editor dismissal, Stop, and immediate native time-field edits while the editor stayed open.
- Independent reviews approved the final changes. Review findings about quit cleanup, failed pause reporting and reconciliation were reproduced by failing tests, fixed and verified.
- Real lid behavior, administrator authorization, VoiceOver interaction and live popover placement near screen edges were not exercised by the inert fixtures.

## Delivery structure

Changes are committed by topic: camera and quick-toggle ordering; integrated Stay Awake sessions and assertion handling; consistent indicators; this specification and verification record.

The complete branch changes 104 files eligible under the repository's CodeRabbit path filters, exceeding the requested 100-file limit for a single PR. A two-PR stack separates the existing Dynamic Island work (87 reviewable files) from these Hub and Stay Awake follow-ups (27 reviewable files). The counts overlap for shared files and are calculated relative to each PR's own base.
