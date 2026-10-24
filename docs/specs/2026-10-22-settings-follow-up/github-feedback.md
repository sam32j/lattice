# GitHub feedback drafts

Final handoff: committed by topic at the user's subsequent request. Final
repository-wide validation passes 112696 checks and all shell integration checks.
No push, merge or real issue submission was performed; earlier uncommitted-state
notes below describe the implementation-stage authorization.

Approved direction: retain the feedback form, open a reviewable public issue draft
in sam32j/lattice instead of submitting to the upstream feedback server. Technical
details remain opt-in. Disclose GitHub sign-in, public posting and browser URL
history. Do not claim an issue was submitted when the browser merely opened.

Stay in refactor/settings-refactor-III and preserve existing uncommitted changes.
No commit, push, repository settings change or real issue submission is authorized.

Tests approved at the feedback URL/browser boundary: destination, encoding,
category, diagnostics opt-in, invalid input and browser failure. Then run affected
suites, developer build and independent review. No browser opens in tests.

## Results

- Removed the upstream feedback POST/session. The service now hands a bounded,
  encoded issue URL to the default browser and reports browser-opening failure.
- Retained opt-in diagnostics, localized public/account/history disclosure in all
  15 languages, and distinguished draft opening from issue submission.
- Updated About, privacy and security copy. The draft text remains available in
  the form when opening fails or the encoded URL exceeds the conservative budget.
- Red coverage first exposed the missing draft boundary. An isolated Foundation
  reproduction also failed for literal plus signs; the fix escapes them before
  URL creation and the regression test now passes.
- Final settings, features, localization and repository suites: 9672 checks pass.
  Developer build, selftest and strict deep signature verification pass.
- Independent source review: ready after the plus-encoding correction. No issue
  was submitted, browser opened, external settings changed, commit made or push
  performed. End-to-end signed-in GitHub submission was intentionally not tested.
