# Settings Expansion Implementation Plan

**Goal:** Animate every conditional follow-up setting using the same native expansion as the shortcuts list, starting from d00e732d in the existing checkout.

**Architecture:** Keep ordinary SwiftUI conditionals and layout containers. Apply the existing 0.18 second ease-in-out animation at page boundaries so card backgrounds and subsequent rows share the transaction. Shared nested controls use animated bindings when their private state must animate ancestors. Clip rounded cards and respect Reduce Motion. No retained content, progress state, custom Layout, or completion bookkeeping.

**Tech Stack:** SwiftUI animation transactions, existing Forms/VStacks/SettingsCard, isolated AppKit rendering probe.
---

1. Reset the current branch to d00e732d and remove the previous custom implementation. Done; the checkout was clean after reset. Previous edits are backed up outside the repository in /tmp/lattice-expansion-reimplementation/previous.
2. Audit conditional follow-up settings across all pages and embedded controls. Record controlling values and animation boundaries below. Exclude page navigation, picker options, static hardware checks, live telemetry and unrelated loading/search results.
3. Add the small shared animation helper and card clipping. Verify card growth/collapse and following-row movement using an isolated host; compare against the unanimated baseline.
4. Apply page modifiers and animated bindings at the audited boundaries, preserving predicates, preferences, service actions and native view lifetimes.
5. Run the hosted probe, focused settings tests, development build and independent coverage/code review. Resolve findings, then leave the implementation uncommitted in this checkout.

Status: complete, with changes left uncommitted in the requested checkout.

## Coverage audit

Each boundary retains the original predicates and uses the shared native animation. Existing disclosures remain ordinary conditional lists.

| Area | Conditional follow-up settings covered |
| --- | --- |
| Mouse | Horizontal-scroll modifier; Smooth Scrolling sliders/exceptions; linear-scroll lines; Focus Follows Mouse delay/raise/wait/exceptions; navigation exceptions; click-filter interval; middle-click controls/exceptions; button mappings, Spaces drag options, capture configuration and saved-mapping exceptions |
| Keyboard | Super Key options; debounce interval/per-key controls and added/removed keys; quit/close protection mode-specific controls and app scopes |
| Dock and switcher | Preview background opacity; permission follow-ups; quit-on-close exceptions/disabled placeholder; shortcut replacement guidance; layout-specific shortcut hints; minimized-app and windowless-app follow-ups |
| Displays and Keep Awake | Bluetooth restore-on-wake; brightness-key permission guidance; mouse-jiggle interval/permission; clamshell display dimming; automation match mode and running-app list |
| General and menu bar | Login approval/error follow-ups; custom menu icon picker |
| Utilities | Camera Preview/Launcher shortcut and Island destination controls; clipboard/File Cache/Scratchpad enable follow-ups; Island destination drag/style controls; plain-paste permissions; snippets permission/sound picker; URL rule disclosure |
| Audio | Mixer Options disclosure; headphone-disconnect target volume; precise-volume permission guidance; output-switcher device checklist; Music App Blocker replacement/play options |
| Capture and download | Magnifier default zoom; automatic confirmation preview/duration; sharing expiry/links; screenshot numbering options; recorder sharing links; downloader enable follow-ups |
| Dynamic Island layout | Custom size sliders/hint; capsule-fit controls; display placement guidance |
| Dynamic Island behavior/activity | Hover/hidden-hover controls; hover/close delays; global shortcut; resting battery thresholds/early warning; lyrics online option; file drag reveal; clipboard sizing; permission and feedback descriptions |
| Companion | Minimal-style shape options; camera-side options; visit frequency; Command Bar presentation styles |
| Agents/watch | Codex account controls; Claude limits section; reset-card help; live readout/sample; finish-alert minimum and usage-alert threshold; Watch sound/permission controls |
| Monitor | Bars/value appearance options; module-dependent rows; panel block options; alert thresholds and shared interval controls |
| Option editors | Command Bar link kind; radial action kind/payload; snippet date style locale/custom pattern |
| Media tools | Video/GIF sizing controls; image resize kind; metadata eligibility by format; watermark text/logo/placement controls; existing More Options disclosure |

Page navigation, static hardware checks, picker/menu option availability, live telemetry, search/loading states and unchanged disabled-only controls are not expansion settings. They keep their existing behavior.

## Verification

- Unanimated baseline: the isolated probe fails its intermediate-opening-height assertion, as intended.
- Native animation probe: SETTINGS_EXPANSION_OK (10 checks). Observes native SwiftUI shape drawing geometry for opening/collapse intermediate heights, natural control height, nested expansion and spacing, rapid reversal and disabled transactions. Uses an invisible NSHostingView with inert controls and no user preferences.
- The probe follows the current Reduce Motion setting (false during verification). Its enabled path was reviewed; the system preference was not changed to force both modes.
- ./build.sh --test-suite=settings: TESTS OK (913 checks). The inert AudioSettingsOwnershipTests.OutputPage fixture was updated for the production body's output-switcher state dependency. The suite emitted NSTableView reentrancy warnings, with no failures.
- Independent code/coverage review: all identified omissions fixed and re-reviewed. No remaining actionable findings.
- git diff --check: passed.
- ./build.sh --dev: passed on the final source; signed bundle assembled at build/stage.noindex/Lattice (Developer).app.
- Full test suite, actual hardware/permissions, installation and production-app interaction were not run. Changes remain local and uncommitted on fix/settings-followups with HEAD at d00e732d.
