# UI audit: upstream v3.4.4 and v3.4.5 ports

Companion to [plan.md](plan.md). It lists every visible change the ports bring in, where each one goes in Lattice's current UI,
which existing component it uses, and what to check before the port counts as done. Upstream placements (`SettingsDirectory`,
`EnergySettings`, `AdvancedSettings`, menu panel sections, `QuickLauncher`) are never revived.

## Fit rules every item must meet

Taken from the approved Lattice settings specs (`2026-10-22-settings-organization`, `2026-10-25-settings-expansion`,
`2026-10-30-feature-page-migration`, `2026-10-23-unsolicited-permissions`) and the current code.

- **Cards:** titles and captions sit inside `SettingsCard`, with no standalone headings. Rows are `SettingsControlRow`/`SettingsRow`, and their controls align to the trailing edge.
- **Follow-up rows:** shown only while the parent is on, revealed with `.transition(.settingsReveal)` inside the page's animation, and indented by `settingsRowTextInset` when the card indents.
- **Pickers:** `.pickerStyle(.menu)` with a fixed width that matches neighbouring rows (220 pt for modifier pickers, 130 pt for preset rows). Named presets go through `presetRow`/`nearestPreset`, so a value from an old build or an XDG file shows as its nearest stop and is not rewritten until someone picks one.
- **Sliders:** no tick marks and no permanent readout. The value shows while dragging and on hover.
- **Permissions:** a row that needs a permission uses `PermissionGatedToggle(..., requiring:)` and never prompts at launch or on page open. A missing grant shows `PermissionRow`, revealed under the row.
- **Status colours:** green means active and red means a real failure. Off, pending and excluded states are neutral, with an exact explanation.
- **Disabled features:** an owning page stays reachable while its feature is off. Its rows stay visible and disabled, and no service is created to draw them.
- **Settings Search:** each new row gets a keyword in `SettingsDirectoryPages`, with `keywordRequirements` set to the parent preference for follow-up rows and `keywordAnchors` when the row sits outside the feature's usual section. Aliases cover non-obvious words (for example "xdg", "dotfiles", "config file").
- **Copy:** Lattice tone (short, sentence case, no trailing period on titles), "Lattice" instead of "Vorssaint", "Dynamic Island" only where Lattice already says it, and every shipped locale. Check German and French lengths at the minimum Settings width.
- **Island and Hub:** fits the compact island width and the floating Hub's inherited height without truncation or a second scroll region, and behaves the same in the island, the floating Hub and Settings where the surface is shared.
- **Appearance:** light, dark, Increase Contrast, Reduce Motion (no expansion animation, no state lost), and Liquid Glass where the surface already uses it.

Each item below lists: version · surfaces · component · copy (upstream English, to be rewritten in Lattice tone) · checks.

---

## A. New controls

**U1 · Scroll faster while holding a key** · 3.4.4 (375c57b10)
- Surface: Settings › Mouse › Mouse Scrolling card, between the sideways-scrolling rows and Smooth Scrolling.
- Component: a `SettingsControlRow` with `PermissionGatedToggle` (Accessibility). Its follow-ups: a modifier picker styled like `modifierKeys` (glyph and name, 220 pt), and a Speed `presetRow` (130 pt) with named stops, e.g. 2×/4×/8×/15×, in place of the 2×–15× slider.
- Copy: "Scroll faster while holding a key"; caption "Hold only the selected modifier while scrolling the mouse wheel to multiply scroll distance. The trackpad is not affected."
- Checks: a modifier already used by sideways scrolling is disabled in the other picker with the reason shown; no Pinch Zoom wording; if upstream honours per-app exceptions, use Lattice's "Disable in these apps" + Edit row; search keyword requires the toggle.

**U2 · Ignore hover selection** · 3.4.4 (c9bb2c543)
- Surface: Settings › Window Switcher card, a row under Appearance delay. Show it only for layouts that select by pointer.
- Component: a `SettingsControlRow` with `Toggle`.
- Copy: "Ignore hover selection"; caption "Moving the pointer over apps and windows leaves the highlight where it is. Clicking still opens one." Add that hovering the ends of the icon row still pages, because Lattice's `iconRowEdgeHoverDelta` paging stays on.
- Checks: with the toggle on, hovering the icon row's ends still pages without moving the highlight; Settings Search finds it.

**U3 · Restore size when dragging a snapped window away** · 3.4.4 (b0cafdd3b, 7415c09f9)
- Surface: Settings › Window Layout › Edge snapping follow-ups, under the zone picker and hint.
- Component: a `SettingsControlRow` with `Toggle`, revealed only while edge snapping is on.
- Checks: the row lives inside the `edgeSnapControls` VStack, so the reveal animates together with the zone picker; a single click leaves the window snapped (7415c09f9); no change to `WindowSnapPreviewOverlay`; ignored apps are respected; search keyword requires `edgeSnapEnabled`.

**U4 · Edge snapping and macOS tiling warning copy** · 3.4.5 (a2998ce07)
- Surface: the existing `edgeSnapSystemConflict` / `edgeSnapWaitingForSystem` block in `WindowSnappingControls`.
- Change: the orange warning appears only when macOS's drag-to-edge tiling conflicts. macOS Option-drag tiling alone does not trigger it. When both are on, explain that holding Option hands the drag to macOS.
- Checks: the warning hides and shows with the right setting; the "Open Desktop & Dock settings" button stays small.

**U5 · Settings file (XDG)** · 3.4.4 load (a4c0b18ad, cb8ba92a7) · 3.4.5 save (8c783a35b, 5437017b4)
- Surface: Settings › Data & Permissions › Data section, a third `DataPermissionsRow` after Export, with a `DataSettingsDivider` before it.
- Component: symbol `doc.badge.gearshape`, title "Save to settings file…", action "Save". The description shows `~/.config/lattice/settings.plist` (`lattice-dev` in the Developer build). After a launch that loaded the file, it also says the file was read and that keys it doesn't list stay local.
- Confirmation: an alert names the path and says the file is readable only by its owner. The Import confirmation adds "On relaunch, settings in your settings file take precedence over the imported values." when the file exists.
- Checks: success and failure feedback uses the same `exported` / `descriptionIsError` pattern as Export; no Vorssaint strings; search aliases "xdg", "config file", "dotfiles", "settings file".

**U6 · Uninstaller: Select all** · 3.4.4 (91d4421b1)
- Surface: both results footers: `AppUninstallerTab.resultsFooter` (`AppManagerDockedFooter`, Settings) and the compact `PanelUninstallerView.footer` (island and Hub).
- Component: a mixed-state checkbox at the leading edge of "N of M selected". It reads checked, mixed or empty, and toggles every row in all categories. Removing still needs the armed button or the Homebrew confirmation.
- Copy: "Select all", as its accessibility label. The visible text stays "N of M selected".
- Checks: fits the compact footer at the island's All Tools height and the floating Hub height; disabled while a removal or Homebrew job runs; VoiceOver announces the mixed state.
- The Finder-trash cleanup offer (cfe4e89d0) is **not ported** (decided 2026-11-25).

**U7 · Stay Awake: delay after unplugging power** · 3.4.5 (0e390bc58)
- Surface: Settings › Stay Awake › Start automatically card. A follow-up row appears under the condition tiles while the Power tile is chosen, placed like `StayAwakeAppsList`.
- Component: `SettingsControlRow` "Delay after unplugging power", menu picker (Off, 10 s, 30 s, 60 s, formatted with `Duration.units` in the app language), `.fixedSize()`, `.settingsReveal`.
- Live state: the Power tile's state text reads "Waiting for power to return…" during the delay. The Hub Stay Awake control keeps its fixed amber with a tooltip saying it is waiting. The menu bar status item and the island Stay Awake strip show the same state (upstream's `waitingForPower`).
- Checks: choosing a second condition still doesn't grow the card header (the match picker stays in the header); the countdown path animation is not restarted by the waiting state; search keyword requires Power.

**U8 · Cursor in AI Agents** · 3.4.5 (72a56c809, 2a8b8ddac, then the partial-cost commits)
- Settings: a `providerRow(.cursor)` after GitHub Copilot in `NotchAgentsSettings`, animated like the others. Update the provider lists in the description, Hub description and empty-state copy.
- Island and Hub: Cursor's mark in the provider chips and strip (`NotchAgentStrip`, `NotchAgentsView`), with the active project, new turns and the finish notice.
- Partial costs: a single consistent marker (for example "≈" or "partial") wherever a figure lacks usage or price data: trend caption, activity rows and the strip. The trend chart draws "not measured" gaps differently from measured zero.
- Checks: the strip stays one line at compact width with five providers; the marker is announced by VoiceOver; light/dark contrast of the gap style.

**U9 · Recorder: GIF size and frame rate** · 3.4.4 (041753ad1, d01ea2c6b, d461c2edd)
- Editor: no new toolbar items. The existing quality `Menu` next to `RecorderExportSpeedControl` gains inline sections: Format (Video/GIF), then, for GIF only, GIF size (Original, Large, Medium, Small, Custom…) and Frame rate. The Speed control is unchanged.
- Settings › Screen Recorder › Video export format card (**decided 2026-11-25: keep defaults**): keep the GIF size picker, now the default for new recordings, and add a default GIF frame rate row beside Export frame rate, using the same menu pickers. A new recording starts from these defaults. A change in the editor applies only to that recording.
- Checks: the menu label stays short at the editor's minimum width with a cut selected; "Copy as GIF" cancel during preparation keeps the clipboard; captions scale with a small GIF; update `docs/recorder-export-speed.md`.

**U10 · Mic Mute verification states** · 3.4.4 (5b0a8b44b, 5b321192a) · 3.4.5 (the C4 chain, 1ca3fdde8)
- New states: "couldn't confirm mute", "couldn't confirm restore", "automatic restore exhausted", and a manual-restore notice with an acknowledgement ("I've checked the microphone").
- Surfaces: menu bar mute icon; island notice and capsule (`NotchNoticeView`, `NotchCapsuleViews`, `AnimatedMicMuteSymbol`, which needs a warning variant that fits its animation); Hub control tile (`LatticeHubControls`); Device Controls (`DeviceControlsMainView`, `AudioInputDeviceControls`); Settings › Audio › Audio Input card caption; Command Bar mute action.
- Rules: the warning uses neutral or attention styling per the status-colour rule, not success green. The acknowledgement sits in the Audio Input card and in the island notice, not in a modal. The only call-app control is the U34 row.
- Checks: "Show mute status in menu bar" still works; the symbol width doesn't jump between states; long German strings in the island notice.

**U11 · Audio priority: remove unavailable entries** · 3.4.5 (6b4ebcb35, adopted)
- Surface: the priority lists on Settings › Audio (input and output priority cards) and in Device Controls if it lists them.
- Component: a trailing Remove control shown on hover (or in the row's context menu) only for unavailable entries, matching Lattice's other editable app lists.
- Checks: an AirPlay speaker that reconnects keeps one row in its saved position; two devices with the same name stay separate; removal animates.

**U34 · Allow call apps to unmute the microphone** · 3.4.5 (17dba59a6, decided 2026-11-25)
- Surface: Settings › Audio › Audio Input, the microphone card, as the last follow-up after "Show mute status in menu bar" (same indent and `.settingsReveal`, shown only while microphone control is on).
- Component: `SettingsToggleRow(title:caption:isOn:)` bound to `DefaultsKey.micMuteFollowCallApps`, **off by default**. Turning it on calls `MicMuteService.shared.syncWithPreferences()`. It's one switch for the whole Mac, with no per-app list.
- Copy (rewrite in Lattice tone): "Allow call apps to unmute the microphone"; caption "If a microphone reopens while an app is recording from it, Lattice restores every microphone it muted. A call app's automatic volume adjustment can also do this." The caption must keep the automatic-gain warning.
- Behaviour to show: when a call app's unmute is followed, the menu bar icon, island, Hub tile and Device Controls all switch to unmuted together, and the normal unmute notice appears. Lattice doesn't mute again by itself.
- Checks: off by default on a new install and after importing an older backup; included in backups and the XDG settings file; Settings Search keyword with requirement `microphoneLevelControlEnabled` and anchor on the microphone card; aliases "call", "zoom", "teams"; German caption fits at the minimum Settings width; with it off, a call app raising the input volume is muted again (no regression).

**U12 · Fan control states** · 3.4.5 (ba68e1fb8, 9af3c477a, 675cb674f, 1a9d543df, e2e61044b)
- Surface: `FanControlSection` in the island (`NotchView`) and wherever the Hub hosts it.
- Changes: a "Control unconfirmed" status, a safety-stop reason line, "awaiting system control" text, and Apply disabled while recovery is pending.
- Checks: it fits compact width without truncating the reason; neutral or amber for pending and red only for a real failure; the curve editor still works when Apply is disabled.

## B. Changed copy only

- **U13 · Island banner hint** (3.4.4 ad1aa8575): the hint under the island's "hide original notification" option explains that an app's desktop alerts must stay on in macOS. Rewrite it in the simplified Dynamic Island settings tone.
- **U14 · Monitor alerts caption** (3.4.5 6c9ed174c): the `MonitorAlertsControls` caption mentions that low-disk alerts repeat at most every 6 hours, or sooner below half the threshold.
- **U15 · Backup "invalid file"** (3.4.5): "This file is not a valid Lattice backup."
- ~~U16~~: retired (the Finder-trash offer is not ported).

## C. Behaviour with visible effects (no new control; verify it looks right)

| ID | Ver | Change | Where to look |
|----|-----|--------|---------------|
| U17 | 3.4.4 | Mixer volume slides smoothly; horizontal swipes don't change levels; sliders reach both ends; a notice that changes before mouse-up cancels the click | Island mixer and Device Controls in the island and Hub |
| U18 | 3.4.4 | Mirrored banners don't flicker on macOS 26; opening Notification Center doesn't bring old items back | Island notifications |
| U19 | 3.4.4 | Command Bar selected row outlined on dark backgrounds; destructive rows stay red | Every Command Bar presentation style, light and dark |
| U20 | 3.4.5 | Calculator answers (units, rates, mixed ft/in, results reused in the next expression) | Command Bar result row: value alignment, copy hint, long results |
| U21 | 3.4.4 | Compact media panel scrolls as one page | Media in the island and Hub |
| U22 | 3.4.5 | Drop images and videos from Finder onto island Media; conversions keep running | Media drop target highlight in the island and Hub |
| U23 | 3.4.5 | Island leaves room for menu bar icons on macOS 27 with "Show over the menus" off | Notch and non-notch displays |
| U24 | 3.4.5 | USB outputs without master volume hand their keys to macOS | No island volume notice duplicating the macOS HUD |
| U25 | 3.4.5 | Per-app rows for apps launched by other apps (Steam games) | Device Controls › App volumes: icon, name, saved level |
| U26 | 3.4.5 | Keyboard backlight controls only on supported hardware | Settings › Keyboard (card hidden with no gap or divider left), Hub and Device Controls tiles, island notices |
| U27 | 3.4.4/3.4.5 | Switcher opens faster, fewer flashes restoring minimized windows, Esc cancels during discovery, ⌘Tab handed to macOS under an exclusive full-screen game | Switcher in all three layouts; no flash of an empty panel |
| U28 | 3.4.4 | Stay Awake manual session restored after relaunch with its original end | Hub countdown path resumes mid-way; menu bar countdown; island strip |
| U29 | 3.4.4 | Clipboard history window reopens where it was left and stays on screen after display changes | Standalone clipboard window only |
| U30 | 3.4.5 | Spreadsheet cells saved as text with tabs and newlines | `ClipboardTextPreview` and list row rendering of tabs |
| U31 | 3.4.4 | Native wheel distance in Lattice panels with Smooth Scrolling on | Settings, Hub and island scroll feel |
| U32 | 3.4.4 | Software dimming for readable DDC monitors | Already offered by `SoftwareDimmingButton` (extended dimming). No new UI; check the button state and that switching cancels pending brightness steps without a jump |
| U33 | 3.4.5 | Screenshot editor keeps less in memory; cancelling a drawing keeps earlier edits | Editor undo/redo still visually correct after crop |

## D. Must not appear (rejected or not adopted, may arrive through ports)

- Monitor speaker volume steps, limits or speaker rows (Display/Energy settings, mixer, volume notice).
- A call-app unmute control anywhere other than the U34 row, or one that is on by default.
- Pinch Zoom wording or modifier options in Mouse.
- An "All windows" shortcut row or All-windows hints in the switcher.
- A scrolling screenshot shortcut, tool picker entry or HUD button.
- Clear buttons for the Stay Awake / Quick Snippet shortcuts.
- The Finder-trash cleanup setting, its offer banner or its trash-unavailable note in the uninstaller.
- A Smooth Scrolling toggle in panels, the Homebrew log reopen action, camera preview crop options, a clipboard image resize prompt, screenshot caption undo or close prompts.
- Any `SettingsDirectory`, menu panel section, `QuickLauncher` or `QuickToggles` view revived by a port.

## E. UI verification gate (each version)

1. `./build.sh --test-suite=settings`, with new tests that assert: every new Settings row in U1–U5, U7–U9 and U34 has a search keyword and requirement, and U34 defaults to off; settings-ownership coverage of each new preference on its owning page (pattern: `AudioSettingsOwnershipTests`); no section D strings in shipped localizations.
2. Extend `Tools/SettingsExpansionProbe.swift` to cover the follow-ups added in U1, U3, U7, U9 and U34.
3. In the Developer build, screenshot each touched page in English and German, light and dark, at the minimum Settings width. For the island (compact) and the floating Hub, cover U6, U8, U10, U12, U17 and U22.
4. Reduce Motion pass on U1, U3 and U7. VoiceOver labels on U6 (mixed checkbox), U8 (partial marker) and U10 (warning).
5. Walk through section D and confirm nothing on it appears.
