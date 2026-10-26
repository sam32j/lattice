# Data & Permissions Implementation Plan

**Goal:** Rebuild the consolidated page to the supplied consistent-row design.

**Architecture:** Share a presentation row, card and fixed-size action across data, permission and destructive controls. Keep permission status/request handlers and destructive workflows in their existing owners; isolate permission action selection as a pure policy. Retain native sidebar keyboard behavior, per the user’s correction.

**Tech Stack:** SwiftUI, AppKit, existing preference/service models, native rendering and isolated generated tests.
---

Baseline: /Users/samuel/Developer/Lattice, fix/settings-followups, 2679fc3f. Clean; latest branch contains settings-followup. User approved interpretations and requested no worktree.

### Task 1: Baseline and permission policy
- Files: new Core/PermissionRowActionPolicy.swift and Tests/PermissionRowActionPolicyTests.swift; UI/PermissionsPortalSections.swift; build.sh/Tests/SettingsReviewRegressionTests.swift wiring.
- Run existing settings checks before changes. Add failing policy cases for unknown/granted, missing/requestable, denied/restricted, and unsupported requests. Implement only the three approved requestable categories.
- Run focused checks after each behavioral slice.

### Task 2: Shared presentation and page
- Files: new UI/Settings/DataPermissionsRow.swift, DataPermissionsStyle.swift and Core/DataPermissionsPageCopy.swift; update UI/Settings/DataPermissionsSettings.swift and PermissionResetSettingsRow.swift.
- Use the existing compact native styling and reuse the row across all three cards; preserve confirmations, backup validation, failure notices, restart transition and one action per row.
- Keep every new handwritten file below 300 lines. Use existing localized copy where appropriate and localize added strings. Test native alignment and two-line growth with inert actions.

### Task 3: Permission rows/popovers
- Files: UI/PermissionPortalRow.swift, UI/PermissionsPortalSections.swift, UI/PermissionDetailsSheet.swift.
- Move info next to title with fixed title-line height, state-colored tile/status, and policy-selected single action. Preserve existing request/open-settings handlers. Pass changing request availability from observed permission state; denial must refresh the action without shifting geometry.
- Add optional System Settings action to details content; use it in the popover without affecting other existing details-sheet users. Verify opening details does not request access.

### Task 4: Withdrawn keyboard request
- The user clarified that native keyboard navigation is expected. Removed this task’s sidebar edits and temporary keyboard tests. Verified SettingsView.swift and SettingsHostingController.swift have no diff.

### Task 5: Visual verification and review
- Files: isolated rendering probe/test fixtures and affected page-order tests.
- Render light/dark and long-label pages using disposable preferences and injected permission content/actions; inspect real images. Verify one button per row, column alignment, visible info targets and preserved reset states.
- Run ./build.sh --test-suite=settings and ./build.sh --dev serially; verify signature. Broaden only for a demonstrated shared regression.
- Independent source/spec review, fix applicable findings, reconcile verification and working tree. No external publishing without an authorized branch outcome.

Scope correction: the user withdrew the sidebar keyboard-navigation request. All sidebar implementation/test edits were removed; retain native keyboard navigation and focus behavior.

Implementation verification so far:
- Baseline settings suite passed: 953 checks.
- Pure action policy covers all 14 permission states/categories, supported requests and denial transitions. No requests or real grants are used.
- Native shared-row checks caught focus decoration expanding the first action’s accessible bounds. Moving the visible ring inside the fixed button resolved it; all action targets are 112×34 and share the same right edge.
- Native permission-details checks verify opening does not invoke the supplied Settings action, the link exists after presentation settles, and an explicit press invokes that action once.
- Settings suite passed: 1,003 checks. Removed the old source-text page-order assertion; section order is checked in the rendered real page rather than by searching implementation strings.
- Independent source/spec review: ready, no actionable findings. Developer build and rendered light/dark/narrow/localized pages pending.

Visual correction: user clarified that the reference should supply layout/behavior only and looked too large. Replaced the 40-point tiles, 15-point titles, 112×34 custom buttons and hex palette with the existing 30-point permission tiles, native body/caption fonts, semantic status colors, native bordered/prominent buttons, standard dividers and the existing Settings card surface. Shared alignment, info popovers, action policy and confirmations are retained. Expanded native alignment coverage to include the prominent Request variant. Earlier 1:1 rendering is superseded; compact rendering pending.

Final compact verification:
- Settings suite: 1,004 checks passed, including equal native action bounds and right-edge alignment across ordinary, prominent and destructive variants.
- Developer build and strict bundle signature verification passed.
- Disposable-bundle rendering completed successfully in light, dark, narrow and German layouts, plus reset states and permission details. Light, dark, narrow and German renders were visually inspected for compact styling, aligned actions and readable copy.
- Independent compact source review: ready, no actionable findings. Native sidebar source remains unchanged.
- No real permission requests, resets, uninstall, hardware or playback actions were performed. Unrelated suites were not rerun.
- User selected commit, push and update PR #20 on fix/settings-followups. PR #20 is closed and unmerged; update its description without reopening it.
