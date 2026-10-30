# Dynamic Island Preset Sizes Implementation Plan

**Goal:** Offer only Compact and Spacious, and remove the obsolete display compatibility shortcut.

**Architecture:** Remove custom geometry and its unused editor. Migrate saved custom sizes to Spacious, discard obsolete dimensions, and preserve the existing display selector and physical-notch handling.

**Tech Stack:** Swift, SwiftUI, UserDefaults, existing generated test fixtures.
---

1. Add regression coverage at the existing size/defaults migration and backup seams. Observe the unsupported custom case and retained dimensions fail.
2. Remove custom dimensions and sizing branches from geometry, Hub rendering, defaults and unused editing controls. Remove the redundant display button, exclusive helper methods and copy.
3. Replace obsolete custom-layout tests with coverage for supported presets. Preserve screen fitting, camera clearance, content and keyboard-navigation assertions.
4. Run focused tests and developer compilation; request independent review. Resolve findings and verify the final diff.

Acceptance: only two size cases, old custom preferences become Spacious, obsolete dimension keys neither affect geometry nor export/import, the normal display selector remains available, and Quick Actions contains only its editor control.

Progress: seven expected migration/default assertions failed before implementation. The preset-only notch suite subsequently passed 47,589 checks, and the developer executable compiled. Final full-suite verification follows the unused-copy cleanup. Independent review found no blocking migration or preset regression.

Final lower-branch verification: all 96,406 checks passed, plus preference cleanup, uninstall-space and developer-install isolation checks. Final developer executable compilation passed after removing unused string fields. No app installation, relaunch, hardware or permission changes were performed.
