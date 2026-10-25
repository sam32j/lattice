# Settings UI failure follow-up

Final handoff: all follow-up changes were committed by topic on
`refactor/settings-refactor-III` at the user's request. Final full-suite run passes
112696 checks, plus preference cleanup, uninstall Spaces and developer-install
isolation checks. No push or merge was performed. Earlier uncommitted-state notes
below describe the state when those individual checks were recorded.

Starting revision: e46d7ef14. Worktree was clean. User approved native-control, isolated rendering and preference/service test boundaries; no live hardware state changes.

## Scope
- Fix the screenshot's unstructured registered-key label and centered key selector. Preserve per-key edit/remove behavior and list-before-editor order.
- Verify one-second hover presentation, cancellation, view detachment and status freshness; shared ALS punctuation; scrolling modifier visibility and shared exclusion layout.
- Rerun affected suites, developer build, signature/selftest and isolated populated/empty/disabled rendering. Preserve current branch and leave changes uncommitted unless separately authorized.

## Investigation
- Existing key picker uses a 160-point frame with default centering; its intrinsic menu width leaves an unintended leading gap. Key labels have no container.
- Existing seven-suite baseline passes 31084 checks. Existing input probe only rendered an empty per-key list, missing the screenshot state.
- Added a populated rendering fixture and native hover lifecycle regression coverage. Both now pass.

## Additional approved scope
- Audio priority: user approved hiding unnamed disconnected technical-ID entries while retaining connected and friendly-named disconnected devices. Saved priority storage must remain intact, including hidden positions during visible reordering.
- Replace quit/close protection inline app lists with ALS. Whitelist mode says Enable in these apps, blacklist mode says Disable in these apps; sheet title, empty state and localized descriptions must match. Remove the obsolete picker state/sheet.
- Full-suite validation uncovered 16 failures in 112595 checks. Investigated rather than waiving: stale installation/copy/count fixtures, retired monitor placement in Hub layout fixtures, plus a real dependency of keyboard-light notices/shortcuts on Control displays. Keyboard-light availability and shared-service resynchronization are being decoupled without installing or starting display controls.
- Independent review confirmed the keyboard-light coupling and reviewed the earlier hover/key-row fixes. The initial hover lifecycle test failed on stale open content, then passed after dismissal on message changes; native tooltip competition was removed.

## Final verification
- Full `./build.sh --test`: TESTS OK (112652 checks). Preference cleanup, uninstall Spaces and developer-install isolation checks also passed.
- Developer build, strict code-signature verification and selftest passed after production changes.
- Isolated settings rendering: SETTINGS_RENDERING_OK, 31 fixtures in `/tmp/lattice-ui-audio-als.CVabPn/rendered`. Visually checked populated keycaps and left-aligned editor, audio filtering, and whitelist/blacklist sheets. Empty, disabled and German long-key variants are included.
- Independent review found no remaining blockers. Added interleaved hidden-device reorder coverage from its final suggestion.
- Keyboard-light shortcuts, routing and shared-service refresh no longer depend on display-control installation; display hardware monitoring remains gated by Control displays.
- No real key mappings, mouse bindings, Bluetooth power or display brightness were changed. Rendering used isolated preferences; live hardware behavior was not exercised.
- Changes remain local and uncommitted on `refactor/settings-refactor-III`.
