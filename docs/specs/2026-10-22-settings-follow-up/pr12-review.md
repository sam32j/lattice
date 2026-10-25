# PR 12 review resolution

Baseline: `e73c20394c8b683c7b7bf6b28401b4f061faffbb` on
`refactor/settings-refactor-III-part-3`. Review covers all twelve inline
CodeRabbit threads and the Clipboard label nitpick in the review summary.

## Decisions

| Finding | Resolution |
| --- | --- |
| Missing installation policy in test build | Add the production policy to `TEST_SOURCES`. Include the permission coordinator and radial activation helper used by this part's tests. |
| Notarization wording | Distinguish local builds from releases that can notarize the app and DMG with configured credentials. Preserve the trust warning. |
| Missing app-menu destination declaration | Defer the two premature destination guard/reconciliation calls to the stack part that supplies its selector. Restoring only the helper introduces an opt-out preference that this part's old controls cannot clear. Existing part-3 routing remains intact. |
| Unsupported keyboard-light roles | Use keyboard-light hardware support for editor availability, active roles, and conflict checks, independently of display installation. Tests simulate support. |
| App-list row title | Keep the caller's row title; sheet-specific naming remains inside the editor. |
| Missing utility settings declarations | Restore existing ownership strings, island destination support, and destination controls from the established later stack implementation. |
| Spaces switch disabled while saved on | Decline the suggested change. The approved “Error-gated controls” contract in `keyboard-light-status.md` explicitly disables unreachable commands even for a saved-on preference, without resetting it. |
| Three-finger drag hint | Localize the conflict explanation in all fifteen languages. |
| Radial master permission gate | Require Accessibility only when current actions or profile input triggers need it. |
| Recorder extension access and duplicates | Expose only the shared members needed by the existing extension and remove duplicate header/shortcut implementations. |
| Screenshot extension access and duplicates | Same repair, preserving the existing OCR and Color Picker shortcut rows and cards. Remove only their two stale section-anchor modifiers: those enum cases were already retired by this stack part. |
| Neutral permission status indicator | Preserve the explicitly approved error-only icon design. Address the valid stale-on concern by using verified activation for the Super Key master toggle, rather than adding a neutral icon. |
| Clipboard enable-label nitpick | Use the shared localized enable-label builder for every language. |

## Stack integrity

A clean generated-test build reproduced missing installation-policy members.
The developer build reproduced missing `AppMenuDestination`. Further compilation
exposed missing permission source entries and lifecycle fixtures. Restore only
those existing prerequisites and the small catalog filter required by this
part's already-included ownership tests. Register the relevant permission and
service lifecycle tests so that they execute, rather than merely compile.

Part 4 must explicitly include both the `AppDelegate` destination guard and the
`FeatureRuntime` destination reconciliation together with its destination
selector. When integrating this amended part 3 into the existing part-4 branch,
verify those calls: its old base already contained them, so a merge can carry
this part's deletion forward.

## Verification

- The exact production keyboard-role availability predicate failed an isolated
  unsupported-hardware check before the fix and passed afterward.
- Independent source review identified the menu-helper recovery problem and an
  over-imported generated snippet insertion fixture. Both were corrected.
- Independent re-review of the merged tree found no remaining source blockers.
- Developer build (`./build.sh --dev`), strict deep bundle signature verification,
  and selftest in a disposable app identity pass.
- All 33 isolated settings rendering fixtures pass. Trackpad, Super Key and
  Bluetooth layouts were visually inspected. Final output:
  `/tmp/lattice-pr12-final-validation.xQsFqb/rendered`.
- Release/workflow tests: 13 pass, zero failures, 48 expectations.
- Final full suite on the latest combined revision: `TESTS OK (112772 checks)`.
  Preference cleanup, uninstall Spaces and developer-install isolation checks
  also pass. Native capture tests and settings rendering ran serially.
- An unchanged pin-window centering assertion once differed by half a point;
  its isolated rerun and subsequent full runs passed without changing that test
  or its production code.
- Regression fixtures now use actual owner toggles and dedicated settings
  destinations. The shorter Hub catalog needs a compact inert viewport; the
  layout test now explicitly verifies that its changing offer is offscreen,
  while preserving the original row-visibility and position-stability checks.
- No real permission prompts, brightness changes, Bluetooth changes, key mapping
  changes, installation into the user’s Applications folder or PR merge are part of this verification.

## Final base integration

The base advanced during review. Normal merges include part 2 through
`cf31fb326ad78a5d644326998b63d120325aae4a`, preserving its latest music-swipe
behavior. Its updated Bluetooth contract supersedes the earlier either-toggle
rule: the extracted installation policy follows sleep handling alone. A pending
restore still synchronizes independently without enabling monitoring. Both the
new base tests and the page-owned regression suite pass together.

GitHub CI is separate from these local results. No PR merge was performed.

## New security-policy review

The 2026-10-25 04:33 UTC CodeRabbit review adds one outside-diff finding at
SECURITY.md:15-18. Accepted: the follow-on request for details was ambiguous
after the public contact fallback. The policy now explicitly restricts those
details to a private report after a private channel is established. Public
issues remain limited to requesting private contact. Checked the surrounding
guidance and the complete diff; application tests are unnecessary for this
documentation-only correction. Baseline 60ab04f8; no application code changed.
