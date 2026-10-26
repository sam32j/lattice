# Data & Permissions Implementation Plan

**Goal:** Rebuild the consolidated page to the supplied consistent-row design and prevent incidental sidebar keyboard navigation.

**Architecture:** Share a presentation row, card and fixed-size action across data, permission and destructive controls. Keep permission status/request handlers and destructive workflows in their existing owners; isolate permission action selection as a pure policy. Configure only the native sidebar list for mouse/programmatic navigation.

**Tech Stack:** SwiftUI, AppKit, existing preference/service models, native rendering and isolated generated tests.
---

Baseline: /Users/samuel/Developer/Lattice, fix/settings-followups, 2679fc3f. Clean; latest branch contains settings-followup. User approved interpretations and requested no worktree.

### Task 1: Baseline and permission policy
- Files: new Core/PermissionRowActionPolicy.swift and Tests/PermissionRowActionPolicyTests.swift; UI/PermissionsPortalSections.swift; build.sh/Tests/SettingsReviewRegressionTests.swift wiring.
- Run existing settings checks before changes. Add failing policy cases for unknown/granted, missing/requestable, denied/restricted, and unsupported requests. Implement only the three approved requestable categories.
- Run focused checks after each behavioral slice.

### Task 2: Shared presentation and page
- Files: new UI/Settings/DataPermissionsRow.swift, DataPermissionsStyle.swift and Core/DataPermissionsPageCopy.swift; update UI/Settings/DataPermissionsSettings.swift and PermissionResetSettingsRow.swift.
- Reuse the row across all three cards; preserve confirmations, backup validation, failure notices, restart transition and one action per row.
- Keep every new handwritten file below 300 lines. Use existing localized copy where appropriate and localize added strings. Test native alignment and two-line growth with inert actions.

### Task 3: Permission rows/popovers
- Files: UI/PermissionPortalRow.swift, UI/PermissionsPortalSections.swift, UI/PermissionDetailsSheet.swift.
- Move info next to title with fixed title-line height, state-colored tile/status, and policy-selected single action. Preserve existing request/open-settings handlers. Pass changing request availability from observed permission state; denial must refresh the action without shifting geometry.
- Add optional System Settings action to details content; use it in the popover without affecting other existing details-sheet users. Verify opening details does not request access.

### Task 4: Sidebar keyboard behavior
- Files: UI/Settings/SettingsHostingController.swift and native sidebar tests.
- Reproduce incidental table typing/focus navigation. Disable type selection and first-responder acquisition only for sidebar tables. Keep search fields and detail controls eligible for focus and input.
- Run native focus/selection tests, including keyboard search and shortcuts at their existing inert boundaries.

### Task 5: Visual verification and review
- Files: isolated rendering probe/test fixtures and affected page-order tests.
- Render light/dark and long-label pages using disposable preferences and injected permission content/actions; inspect real images. Verify one button per row, column alignment, visible info targets and preserved reset states.
- Run ./build.sh --test-suite=settings and ./build.sh --dev serially; verify signature. Broaden only for a demonstrated shared regression.
- Independent source/spec review, fix applicable findings, reconcile verification and working tree. No external publishing without an authorized branch outcome.
