# Radial Menu settings redesign

Date: 2026-11-22
Status: design approved in dialogue, implementation on feat/radial-menu
Scope: Settings > Radial Menu page, the radial menu's opening and in-menu behavior, and the
Middle Click rows of Settings > Mouse & Trackpad that share the four-finger gestures.

## 1. Why

The page grew control by control and now reads as a form of unrelated switches:

- Help text sits everywhere: under the main switch (the feature description, shown twice),
  under Opening behavior, under the canvas, under the mouse button picker, in the section
  footer, and in several conditional captions.
- Three settings describe how the menu opens (Opening behavior, Opens at, per-profile
  triggers), and the user has to combine them in their head. "Opening behavior" names
  ("Press or hold", "Press to open", "Hold to select") need a caption to be understood.
- Each profile owns its own shortcut, mouse button and four-finger tap. Picking a profile
  in the editor only edits it, which needs a caption ("Picking a profile here only edits
  it…") to explain. Profile management is a picker plus three icon buttons on one line.
- The canvas, a list view of the same items, a separate Add button, and a Try it button
  all edit or preview the same wheel.
- Middle Click silently wins the four-finger tap, so turning the radial tap on can do
  nothing, with an amber caption as the only clue.

## 2. Goals and non-goals

Goals

- One way to open the menu per input device, with one shared model of quick press vs hold.
- Profiles switched inside the menu itself; Settings picks which one is primary.
- Every piece of text lives inside a card. No always-visible help paragraphs; longer
  explanations go to a popover. Rows are one line and truncate.
- The editor (the interactive wheel) is the only place items are added, edited, moved
  and removed, and is fully operable by keyboard and VoiceOver.
- The page matches the redesigned Settings pages (URL Sanitizer, Dynamic Island):
  header + `SettingsCard`s in a scroll view.
- All 15 shipped languages updated in the same change.

Non-goals

- No change to the item editor sheet (`RadialItemEditor`) beyond the strings it shares.
- No change to item kinds, the 12-item limit, submenus (one level), or the live wheel's
  geometry and dead zone.
- No hold-and-release for trackpad gestures (decision 3.1).
- No per-profile triggers of any kind.

## 3. Decisions made in the dialogue

1. **Trackpad gestures open only.** Lattice reads trackpad contacts but cannot suppress
   macOS gestures, so any four-finger slide to preselect would also fire Mission Control,
   App Exposé or Spaces wherever those use four fingers. Alternatives considered: lift to
   one finger and point with it, slide only when macOS leaves four fingers free, twist to
   dial. Chosen: the four-finger tap and click open a menu that stays open until a
   choice, Esc, a click outside, or the same gesture again. Hold-and-release belongs to
   the keyboard shortcut and the mouse button.
2. **Mouse button stays, as one menu-wide trigger, set with a recorder** that waits for
   the user to press the button, instead of a picker of button numbers.
3. **In-menu profile switching: tabs on an arc above the wheel.** Click, Tab / Shift-Tab,
   scroll, or a short dwell while holding.
4. **Settings profile management: the same tabs in the editor's top bar,** with "+" (add
   from a starter set) and "…" (profile actions). No separate profiles card.
5. **The primary profile is the first tab.** "Make primary" moves a profile to the front.
6. **The Radial Menu takes precedence over Middle Click** for the four-finger gesture it
   uses, with a confirmation when that changes a working Middle Click setup.

## 4. Page structure, top to bottom

Layout follows `URLSanitizerSettings`: `ScrollView` > `VStack(alignment: .leading,
spacing: 20)`, `.frame(maxWidth: 760)`, centered, `.padding(22)`. Conditional cards
appear with `.transition(.settingsReveal)` keyed by one page-level
`.settingsExpansionAnimation(value:)` over (permission card shown, feature on).

### 4.1 Header

| Element | Spec |
|---|---|
| Icon tile | `LatticeSymbol(AppFeature.radialMenu.symbolName)`, 26 × 26, accent tint on 12 % accent, radius 7 (same as `URLSanitizerHeader`). Hidden from accessibility. |
| Title | `pageTitle` ("Radial Menu"), `.title3.weight(.semibold)`, one line, `.isHeader` trait. |
| Main switch | `FeatureActivationControl(feature: .radialMenu)` styled as a trailing switch, label hidden, accessibility label = page title. |

Nothing below the header row. The current `hubDescription` caption and the duplicate in
the footer are removed from this page (the string stays; the Hub and feature pages use it).

### 4.2 Permission card (conditional)

Shown only when `RadialMenuSupport.needsAccessibility(profiles, mouseButton:)` and
Accessibility is not granted. A `SettingsCard` containing the existing `PermissionRow(kind:
.accessibility)` with the reason as the row's caption (`permissionCaption`, updated copy,
§9). The separate window-layout caption is folded into the same sentence.

### 4.3 "Open the menu" card

`SettingsCard(symbol: "cursorarrow.rays", title: openCardTitle, headerAccessory:)`. The
header accessory is an ⓘ button (`info.circle`, 28 × 28 plain, `.help(openInfoButton)`)
that opens a popover (max width 320, `.callout`, padding 14) with `openInfoBody`, the
only explanatory paragraph on the page. While the feature is off the card's rows are
`.disabled(true)` and drawn at 45 % opacity (the `SettingsFeatureSwitchRow` treatment);
the ⓘ stays available.

Rows are `SettingsControlRow`s with no captions, separated by `Divider()`s, 12 pt apart.
A row's note (conflict, refusal, info) appears as a single line under the title inside
the row: `.caption`, an SF Symbol leading it (`exclamationmark.triangle.fill` for problems
in orange, `info.circle` for information in secondary), `lineLimit(2)`, truncating tail,
full text in `.help`. Never color alone.

**Row 1: Keyboard shortcut**

- Title: `shortcutLabel`.
- Control: `CompactShortcutBindingRecorder` (width 140), the one recorder the old
  `ProfileShortcutRow` wrapped, with `emptyTitle: l10n.s.shortcutNone`, clear button
  when set. Storage: `DefaultsKey.radialMenuShortcut`.
- Conflict check: `SettingsShortcutConflicts.title(for:language:)` only (no other
  wheels exist to conflict with). A conflict refuses the capture and shows the existing
  recorder error line inside the row.
- When macOS refuses the registration (`service.registrationFailed`): problem note
  `shortcutRefused`. (Today this shows `shortcutInvalid`, "Use at least Control, Option
  or Command…", which is the wrong message for a refused hotkey.)
- Empty shortcut is allowed (a mouse button or gesture may be the only trigger).

**Row 2: Trackpad**

- Title: `trackpadLabel`.
- Control: `SettingsPopUpPicker` with `trackpadOff`, `trackpadTap`, `trackpadClick`.
  Storage: new `DefaultsKey.radialMenuTrackpadGesture` (`"off" | "tap" | "click"`,
  default `"off"`), enum `RadialMenuTrackpadGesture`.
- Choosing tap or click while Middle Click is effectively using that same four-finger
  gesture shows a confirmation alert first (§7.3). Cancel leaves the picker unchanged.
- Choosing tap or click requests Accessibility the same way the old toggle did
  (`PermissionGatedPicker` semantics).
- Problem note when `MiddleClickService.shared.touchDeviceMissing` and a gesture is set:
  reuse `l10n.s.middleClickNoTrackpad`.

**Row 3: Mouse button**

- Title: `mouseButtonLabel`.
- Control: a mouse button recorder modelled on `MouseButtonSettingsCapture` (same
  listening flag on `MouseButtonShortcutService` so the two pages never capture at once):

| State | Looks like | Behavior |
|---|---|---|
| Not set | bordered button, `l10n.s.shortcutNone` | Click to record. |
| Recording | accent border, `mouseButtonRecording`, pulsing dot | Next extra button (3+) is stored. Esc or a click elsewhere cancels. Left/right click shows problem note `mouseButtonPrimaryRefused` and keeps recording. |
| Recording, nothing for 5 s | as above | Info note `mouseButtonNothingSeen` appears (replaces the old Button test row and its hint paragraph). |
| Set | button name (`mouseTriggerBack`, `mouseTriggerForward`, or `MouseButtonShortcutSupport.buttonName`) + clear (×) | Click to re-record; × clears to off. |
| Lattice can't watch the mouse (`!service.isWatchingMouseButton` while set) | set state | Problem note `mouseButtonBlind`. |

- Back or forward button set: info note `mouseButtonBackNote` / `mouseButtonForwardNote`.
- Storage: `DefaultsKey.radialMenuMouseButton` (existing key, now authoritative again;
  `RadialMenuMouseTrigger` raw value). `RadialMenuSupport.claimsMouseButton` reads it.

### 4.4 Editor card

A `SettingsCard` with no title and zero inner padding around the stage, so the stage
fills the card (16 pt continuous corner radius, clipped). Accessibility container label
`editorLabel`. The stage renders with the live menu's own pieces (`RadialMenuView`'s
chip, wedge, disc material and the new tab arc), in the current appearance, so the
editor is a faithful preview in light and dark. The hard-coded dark stage
(`Color(red: 0.08…)`) is removed.

Stage height 360 pt. Regions:

**Top bar** (44 pt, inside the stage):

- Profile tabs, leading: capsule per profile, gradient dot (10 pt) + name (`.callout`,
  one line, truncating at 140 pt). Selected tab: filled with the profile gradient, white
  semibold text, plus `.isSelected`. First tab shows `star.fill` (9 pt) before the dot,
  with `.help(primaryHelp)`. Tabs overflow into a horizontal scroll with 16 pt edge fades;
  the selected tab is scrolled into view on change.
- Tabs reorder by drag (insertion caret between tabs). Dropping a tab first makes it the
  primary.
- `+` menu button (`plus`, `.help(addProfileButton)`): starter sets
  (`presetGeneral`, `presetMedia`, `presetTools`, `presetWindowLayout`,
  `presetQuickToggles`, `presetBlank`). New profile appends at the end and is selected.
- `…` menu button (`ellipsis.circle`, `.help(profileMenuButton)`), trailing, for the
  selected profile:
  1. `editProfileButton` → Edit profile sheet.
  2. `makePrimaryButton`, disabled (not hidden) when already first.
  3. `duplicateProfileButton` → copy appended after the original, selected, named
     "<name> 2".
  4. `resetActionsButton` → existing confirmation; disabled when no starter set is known
     (`canResetProfile`) or inside a submenu.
  5. Divider, `deleteProfileButton` (destructive), disabled when only one profile exists.
- `+` and `…` stay pinned; only the tabs scroll.

**Breadcrumb** (only inside a submenu, 24 pt under the top bar): `chevron.backward`
button with "<profile> › <submenu>" (`.caption`, profile-gradient tint on the chevron),
`.help(backButton)`. Clicking the hub also goes back, as today.

**Wheel** (centered in the remaining space): today's canvas behavior, kept:

- Click a slot → item editor sheet. Drag a slot onto another → swap. Right-click →
  `editActionButton`, `editActionsButton` (submenus), divider, `deleteButton`.
  (The context menu's first item reads `pageTitle` today; that is a bug fixed here.)
- Hover → slot scales 1.08, wedge highlight, hub shows name + kind.
- **Add slot:** while the level has fewer than 12 items, a dashed-outline slot with
  `plus` sits at the next position clockwise, and the wheel lays out as if it had
  `count + 1` slots so the user sees where the new action lands. Click → item editor for
  a new item (`RadialMenuItem(kind: .app)`); saving appends. Drag targets ignore it.
- Empty level: no add slot; the hub shows `plus` + `addButton` and is the add target.
- **Counter:** bottom-trailing corner of the stage, `.caption.monospacedDigit()`,
  secondary, "8 / 12"; accessibility label `actionCountFormat`. At 12 it reads
  "12 / 12" and the add slot is gone. No separate limit caption.

**Edit profile sheet** (`.sheet`, width 380):

- Title `editProfileTitle`.
- `TextField(profileNameLabel)`, prompt = preset or `presetGeneral`.
- `profileColorLabel` + a 6 × 2 grid of 28 pt gradient swatches, the selected one with a
  white `checkmark` and a 2 pt ring; each swatch has `.help` and accessibility label =
  its color name and `.isSelected` when chosen.
- Live preview: a tab capsule showing the edited name and color.
- Buttons: `l10n.s.uninstallerCancel` (Esc) and `saveButton` (Return). Save is always
  enabled: an empty name is allowed and displays as `presetGeneral`, as today.

**Delete confirmation:** existing `confirmationDialog`, title `deleteProfileConfirmFormat`,
message `deleteProfileConfirmMessage`, or `deletePrimaryConfirmMessageFormat` (naming
the next profile) when deleting the first tab.

### 4.5 Removed from the page

Opening behavior picker and caption; Opens at picker; Try it button; Show as list /
Hide list and the list (`RadialItemRow`, `RadialItemDropDelegate`, and
`RadialDragCleanupDelegate` if nothing else uses it); the separate Add action button;
the canvas hint; the limit/description footer; the profile picker row with its three
icon buttons; per-profile name/color/shortcut/mouse/tap rows; `ProfileShortcutRow`; the
Button test row; the no-trigger and tap-conflict captions.

### 4.6 Profile gradients

`RadialMenuColor` keeps its 12 cases and raw values (no migration). Add
`gradient(for scheme: ColorScheme) -> LinearGradient`: top-leading stop = base color
mixed 18 % toward white (light) / 10 % (dark), bottom-trailing stop = base mixed 22 %
toward black (light) / 30 % (dark). `accent` derives both stops from
`Color.accentColor` the same way. Graphite keeps a neutral gradient. Used by: tab dots,
selected tab fill, swatches, highlighted chip fill, wedge highlight (the wedge keeps its
existing radial opacity ramp, multiplied over the gradient). The flat `color(for:)` stays
for strokes and glows.

## 5. Interaction model

### 5.1 Shared rules (all triggers)

- **Placement:** always centered at the pointer, clamped into the pointer screen's
  visible frame (`clampedCenter`, unchanged). `radialMenuAtPointer` is gone.
- **Profile:** a session always opens on the primary (first) profile.
- **Preselection:** the pointer must travel `moveActivationDistance` from where the menu
  opened; then the slice its direction points into is preselected, including beyond the
  rim (existing geometry). The hub dead zone means nothing preselected.
- **Choosing:** click a slot; Return/Enter on the highlighted slot; digits 1–9.
- **Closing:** Esc (inside a submenu, back one level first); a click outside the wheel;
  the same trigger again (shortcut press, mouse button press, gesture); another app
  activating; Mission Control/Spaces taking over (§5.4); session resign (unchanged).
- **Submenus:** choosing a submenu opens it and the session becomes sticky (unchanged),
  with the pointer re-armed so a double click doesn't run a child.

Constants (in `RadialMenuSupport`, tested): `quickPressLimit = 0.30 s`,
`tabDwell = 0.35 s`, `profileNameFlash = 0.8 s`.

### 5.2 Keyboard shortcut

Key down reveals the menu immediately. The release decides:

| At release | Held < 0.30 s | Held ≥ 0.30 s |
|---|---|---|
| A slot preselected | Run it | Run it |
| A submenu slot preselected | Open submenu, sticky | Open submenu, sticky |
| Pointer resting on a profile tab | Switch to it, sticky | Switch to it, sticky |
| Nothing preselected | Stay open (sticky) | Close |

- In the sticky phase the release has no meaning; the shortcut pressed again closes.
- While held, arrow keys move the preselection; releasing runs what they picked (no
  longer switches to sticky). Tab / Shift-Tab switch profiles while held too.
- Release detection must work for every shortcut: modifier chords (flags monitor, as
  today), modifier-free keys such as F-keys (Carbon `kEventHotKeyReleased`, which
  `QuickToolHotkey` must start reporting), and Super/Hyper Key chords
  (`SuperKeyService.onHoldEnded`, as today). Today a shortcut without modifiers can only
  open sticky; after this change it holds like any other.
- Key autorepeat never toggles (Carbon hotkeys don't repeat; keep it that way).

Replaces `RadialMenuActivationMode`, `startsHeld` and `releaseAction` with one pure
function, `RadialMenuSupport.releaseAction(heldFor:preselection:) ->
.run | .openSubmenu | .switchProfile | .stayOpen | .close`.

### 5.3 Mouse button

Identical to §5.2 with the button's down/up from the existing session tap (`holdButton`).
The button is swallowed from apps while assigned (unchanged). A second press during a
sticky session closes.

### 5.4 Trackpad gesture (open only)

| Gesture | Recognized | Opens | While open | Never |
|---|---|---|---|---|
| Four-finger tap | Existing tap recognizer (`tapShouldFire`: ≤ 0.35 s, travel ≤ 0.03, spread change ≤ 0.04, no press, not right after typing) at 4 fingers | On lift, sticky | Another four-finger tap closes | Holding four fingers does nothing |
| Four-finger click | Physical press with 4 contacts settled ≥ 0.04 s (`actionForClick` at 4) | On press, sticky | Another four-finger click closes | Press and release reach no app; releasing does nothing |

- Swipes and pinches (Mission Control, App Exposé, Spaces, Launchpad, Show Desktop)
  never open the menu: the movement and spread limits already reject them.
- If a system gesture fires while the menu is open: Spaces/full-screen switches post
  `NSWorkspace.activeSpaceDidChangeNotification` and close the session; Mission Control
  and App Exposé change the frontmost app or are caught by the click-outside monitors.
  Any of these close the session.
- Three fingers are never used by the Radial Menu.
- The four-finger click with the press swallowed: the radial path consumes the
  `leftMouseDown`/`leftMouseUp` pair the same way Middle Click consumes it today, so no
  text selection or click lands under the wheel.

### 5.5 Profile tabs in the live menu

- **Layout:** pills on an arc centered above the wheel, 14 pt outside the rim, spanning
  at most 120°. Each pill is a gradient dot; the current one expands to dot + name
  (`.caption.weight(.semibold)`, one line, max 120 pt). The primary carries `star.fill`.
  One profile: no arc. More than 7: the current tab ±3 are shown, the outermost two fade
  to 40 %, and Tab/scroll still reach all.
- **Panel size:** `RadialMenuLayout.panelSize` grows to fit the arc; clamping uses the
  new size so tabs never leave the screen.
- **Switching:**
  - Click a pill.
  - Tab / Shift-Tab: next/previous, wrapping.
  - Scroll: one step per discrete wheel notch; for continuous (trackpad) scrolling, one
    step per 40 pt of accumulated delta (vertical or horizontal, whichever is larger),
    with a 0.25 s cooldown and momentum events ignored.
  - While a hold is in progress: the pointer resting on a pill for 0.35 s switches.
- **On switch:** chips fold into the hub and fly out with the new profile's items
  (crossfade under Reduce Motion), highlight cleared, submenu stack reset to root,
  pointer re-armed, hub shows the profile name for 0.8 s, VoiceOver announces the name.
  The hold phase (if any) continues: releasing then follows §5.2 against the new wheel.
- **Empty profiles:** a profile with no available items keeps its pill; switching to it
  shows the hub text `inMenuNoActions`. The session opens even when the primary is empty
  as long as some profile has items; it beeps and stays closed only when all are empty.
- **Keys taken:** digits run items, arrows move the highlight, so neither switches
  profiles.

### 5.6 Edge cases

| Case | Behavior |
|---|---|
| Trigger fires during the close animation | Session is taken back (existing `dismissal.cancel`). |
| Shortcut and gesture both used in one session | The second trigger closes the session (toggle), whichever opened it. |
| Settings change mid-session | The session keeps the values it opened with (as today with activation mode). |
| Primary deleted | Next profile in order becomes first/primary; dialog says so. |
| Profiles restored from a backup mid-session | Session ends; next open reads the new list. |
| Pointer on a tab at release of a quick press | Switch and stay open (same as hold). |
| Mouse button also used by Mouse Buttons shortcuts or navigation | Radial claim wins (existing `claimsMouseButton`), unchanged. |
| No trigger set at all with feature on | Allowed; the Open the menu card simply shows all three unset. No caption. |
| Feature off | Nothing registered; trackpad gesture released to Middle Click (§7). |

## 6. Data model

- `RadialMenuProfile`: drop `shortcut`, `mouseButton`, `trackpadTap` from encoding.
  Decoding keeps reading them (optional) solely for migration; `duplicate(named:)` no
  longer clears them.
- New defaults: `radialMenuTrackpadGesture` (String, default `"off"`),
  `radialMenuSettingsVersion` (Int, absent = 1).
- Authoritative existing keys: `radialMenuShortcut` (default
  `GlobalShortcut.radialMenuDefault`), `radialMenuMouseButton`.
- Removed keys: `radialMenuAtPointer`, `radialMenuActivationMode` (unregistered,
  deleted by migration, removed from `SettingsBackupSupport` keys).
- `RadialMenuService`: one `QuickToolHotkey` instead of one per profile;
  `toggleFromTrackpad()` and the mouse tap open the first profile; `presentPreview`
  removed; new `switchProfile(by:)` / `switchProfile(to:)`.
- `RadialMenuSupport`: remove `hasTrigger`, `assigning(mouseButton:)`,
  `profile(using:in:excluding:)`, per-profile `conflictTitle`; `claimedMouseButtons`
  reads the single key; `needsAccessibility` takes the mouse button and gesture.

## 7. Middle Click precedence

### 7.1 Rule

While the Radial Menu is available and on and `radialMenuTrackpadGesture` is `tap`
(or `click`), the four-finger tap (or click) belongs to the Radial Menu. Middle Click's
saved choices are never rewritten; their effective values are computed:

```
MiddleClickSupport.effectiveTapFingers(stored:, systemOwnsThreeFingerTap:, radialGesture:)
  -> 0 | 3 | 4      // 4 → 0 when radialGesture == .tap
MiddleClickSupport.effectiveClickFingers(stored:, systemDragEnabled:, radialGesture:)
  -> 0 | 3 | 4      // when radialGesture == .click: 4 → 3 if three is free, else 0
```

`radialMenuTapFingers` is replaced by `radialMenuGestureFingers(radialGesture:) -> 4 | 0`
with no dependency on Middle Click. `MiddleClickService.syncWithPreferences` and the
contact reader use only these functions; the press path learns a `0` (no press
transform) state.

### 7.2 Mouse & Trackpad page

In `middleClickCard`, with the Radial Menu holding a gesture:

| Row | Option list | Shown value | Row note |
|---|---|---|---|
| Tap with | "4 fingers" disabled (still listed, menu keeps its shape) | effective value (a saved 4 shows Off) | info: `tapTakenByRadial` + `openRadialMenu` button |
| Click with (radial uses click) | "4 fingers" disabled | effective 3, or `clickUnavailable` when three-finger drag owns three | info: `clickTakenByRadial`, or problem: `clickUnavailableNote`; + `openRadialMenu` button |

The `openRadialMenu` button (`.controlSize(.small)`) navigates to Settings > Radial
Menu. Notes follow the icon + text rule. Turning the Radial Menu's gesture off (or the
feature off) restores Middle Click's saved values with no further action.

### 7.3 Confirmation on the Radial Menu page

When the user picks tap/click and Middle Click is on and its effective value for that
gesture is currently 4, show an alert:

- Title: `takeoverTapTitle` / `takeoverClickTitle`
- Message: `takeoverMessage`
- Buttons: `takeoverConfirm` (default), `l10n.s.uninstallerCancel` (cancel).

No alert when Middle Click is off, uses three fingers, or the gesture is already the
radial menu's.

## 8. Migration

`Defaults.migrateRadialMenuTriggers(defaults:)`, run from `Defaults.register()` when
`radialMenuSettingsVersion < 2`, and again after a settings backup restore (old backups
carry per-profile triggers). Pure function over the decoded profiles and keys, unit
tested. Steps, in order:

1. Decode profiles (including the legacy single-wheel path).
2. **Shortcut owner:** the first profile (current order) with a valid shortcut; ties
   impossible (shortcuts were unique). If none, the global shortcut becomes the stored
   `radialMenuShortcut` if valid, else empty.
3. **Primary:** move the shortcut owner to index 0. If no profile had a shortcut, the
   first profile with a mouse button, else the first with the trackpad tap, else keep
   the order.
4. **Mouse button:** the primary's button if set, else the first profile's in order.
   Write `radialMenuMouseButton`.
5. **Trackpad:** `tap` if any profile had `trackpadTap`, except when Middle Click was on
   with tap fingers 4 (the radial tap never fired then): write `off`.
6. Re-encode profiles without trigger fields; write `radialMenuSettingsVersion = 2`.
7. Remove `radialMenuAtPointer` and `radialMenuActivationMode`.

What users notice:

| Before | After |
|---|---|
| Several profiles with their own shortcuts | One shortcut opens the primary; others are tabs. Their old combinations are free. |
| Press or hold: long hold, release on the center kept the wheel open | A hold released with nothing preselected closes; a quick press stays open. |
| Press to open | Quick presses unchanged; holding now supports release-to-run. |
| Hold to select | Unchanged, except a quick press now stays open. |
| Opens at screen center | Opens at the pointer. |
| Shortcut without modifiers | Can now be held. |
| Show as list | Gone (it was never saved). |

Release notes mention the first two rows.

## 9. Copy

Rules: sentence case (house style); "Radial Menu" is the feature's name in English;
"Middle-click gesture" is the Middle Click feature's own label; no text outside cards;
notes are one line where possible.

### 9.1 New strings (`RadialMenuFeatureStrings` unless noted)

| Key | en-US | pt-BR |
|---|---|---|
| openCardTitle | Open the menu | Abrir o menu |
| openInfoButton | How opening works | Como o menu abre |
| openInfoBody | Press the shortcut or mouse button quickly and the menu stays open: click an action to run it. Or hold it, point at an action and let go. Letting go without pointing at anything closes the menu.\n\nA four-finger tap or click opens the menu until you choose an action, press Esc or click outside it.\n\nSwitch profiles with the tabs above the wheel, with Tab, or by scrolling. | Pressione rapidamente o atalho ou o botão do mouse e o menu fica aberto: clique em uma ação para executá-la. Ou segure, aponte para uma ação e solte. Se soltar sem apontar para nada, o menu fecha.\n\nUm toque ou clique com quatro dedos abre o menu até você escolher uma ação, apertar Esc ou clicar fora dele.\n\nTroque de perfil pelas abas acima da roda, com Tab ou rolando. |
| shortcutLabel | Keyboard shortcut | Atalho de teclado |
| shortcutRefused | Another app is using this shortcut. | Outro app está usando este atalho. |
| trackpadLabel | Trackpad | Trackpad |
| trackpadOff | Off | Desligado |
| trackpadTap | Four-finger tap | Toque com quatro dedos |
| trackpadClick | Four-finger click | Clique com quatro dedos |
| mouseButtonLabel | Mouse button | Botão do mouse |
| mouseButtonRecording | Press a mouse button… | Aperte um botão do mouse… |
| mouseButtonClear | Clear mouse button | Limpar botão do mouse |
| mouseButtonPrimaryRefused | Use an extra button, not the left or right one. | Use um botão extra, não o esquerdo nem o direito. |
| mouseButtonNothingSeen | No button arrived. Your mouse’s own app may be changing it. | Nenhum botão chegou. O app do seu mouse pode estar alterando-o. |
| mouseButtonBlind | Lattice can’t watch the mouse right now. | O Lattice não consegue observar o mouse agora. |
| mouseButtonBackNote | No longer goes back in apps. | Deixa de voltar nos apps. |
| mouseButtonForwardNote | No longer goes forward in apps. | Deixa de avançar nos apps. |
| takeoverTapTitle | The middle-click gesture uses the four-finger tap | O gesto de clique do meio usa o toque com quatro dedos |
| takeoverClickTitle | The middle-click gesture uses the four-finger click | O gesto de clique do meio usa o clique com quatro dedos |
| takeoverMessage | Use it to open the Radial Menu instead? Middle click keeps its other settings and gets this back if you turn it off here. | Usar para abrir o menu radial? O clique do meio mantém os outros ajustes e volta a usá-lo se você desligar aqui. |
| takeoverConfirm | Use for Radial Menu | Usar no menu radial |
| editorLabel | Wheel editor | Editor da roda |
| profileMenuButton | Profile options | Opções do perfil |
| editProfileButton | Edit name and color… | Editar nome e cor… |
| editProfileTitle | Edit profile | Editar perfil |
| makePrimaryButton | Make primary | Tornar principal |
| primaryHelp | Primary profile. The menu opens on it. | Perfil principal. O menu abre nele. |
| deletePrimaryConfirmMessageFormat | Its actions will be removed and “%@” becomes the primary profile. This can’t be undone. | As ações deste perfil serão removidas e “%@” passa a ser o perfil principal. Isso não pode ser desfeito. |
| editActionButton | Edit… | Editar… |
| moveEarlierButton | Move earlier | Mover para antes |
| moveLaterButton | Move later | Mover para depois |
| moveLeftButton | Move left | Mover para a esquerda |
| moveRightButton | Move right | Mover para a direita |
| actionCountFormat | %1$d of %2$d actions | %1$d de %2$d ações |
| slotAccessibilityFormat | %1$@, %2$@, %3$d of %4$d | %1$@, %2$@, %3$d de %4$d |
| inMenuNoActions | No actions | Nenhuma ação |

Middle Click (`InputSettingsStrings.MiddleClick`):

| Key | en-US | pt-BR |
|---|---|---|
| tapTakenByRadial | 4-finger tap is used by the Radial Menu. | O toque com 4 dedos está em uso pelo menu radial. |
| clickTakenByRadial | 4-finger click is used by the Radial Menu. | O clique com 4 dedos está em uso pelo menu radial. |
| clickUnavailable | Not available | Indisponível |
| clickUnavailableNote | The Radial Menu uses four fingers and macOS three-finger drag uses three. | O menu radial usa quatro dedos e o arrastar com três dedos do macOS usa três. |
| openRadialMenu | Open Radial Menu | Abrir menu radial |

### 9.2 Changed strings

| Key | en-US (new) | pt-BR (new) |
|---|---|---|
| permissionCaption | Key actions, window layouts and the mouse button need Accessibility. | Ações de tecla, organização de janelas e o botão do mouse precisam da Acessibilidade. |
| duplicateProfileButton | Duplicate | Duplicar |
| deleteProfileButton (menu item) | Delete profile… | Excluir perfil… |
| deleteProfileConfirmButton (new, dialog button) | Delete profile | Excluir perfil |
| deleteProfileConfirmMessage | Its actions will be removed. This can’t be undone. | As ações deste perfil serão removidas. Isso não pode ser desfeito. |
| resetActionsButton | Reset actions… | Redefinir ações… |
| profileNameLabel | Name | Nome |

Kept as they are: pageTitle, hubDescription (other pages), addButton, addProfileButton,
backButton, editActionsButton, deleteButton, deleteProfileConfirmFormat,
profileColorLabel, profilesHeader (tab group label), preset*, color*, kind*, mouseTriggerBack,
mouseTriggerForward, resetActionsConfirm, resetActionsConfirmMessage, saveButton, and
every string the item editor sheet uses.

### 9.3 Removed strings (from all 15 languages at once)

positionLabel, positionPointer, positionCenter, tryButton, actionsHeader, limitCaption,
emptyCaption, showListButton, hideListButton, activationModeLabel,
activationModePressOrHold, activationModePress, activationModeHold,
activationModeCaption, profilePickerLabel, profileShortcutLabel,
profileMouseTriggerLabel, mouseTriggerLabel (replaced by mouseButtonLabel),
mouseTriggerOff, mouseTriggerWarning, mouseTriggerRequirement, buttonTestLabel,
buttonTestWaiting, buttonTestSeen, buttonTestOther, buttonTestBlind, buttonTestHint,
canvasHint, trackpadTapLabel, trackpadTapConflict, profileNoTrigger, panelCaption
(already unused). Verify each with a grep before deleting: `enableLabel`/`enableCaption`
names also exist on other string structs, so check the radial struct's own uses.

Settings search (`SettingsDirectoryPages`): replace the `mouseTriggerRequirement`
keyword with `shortcutLabel`, `trackpadTap`, `trackpadClick`, `mouseButtonLabel` and
`profilesHeader`.

## 10. Localization plan

- All radial strings live in `Sources/Lattice/Core/RadialMenuStrings.swift` (one
  `RadialMenuFeatureStrings` literal per language: enUS, ptBR, tr, ru, es, sk, de, fr,
  it, ja, ko, uk, zhHans, zhTW, zhHK). Middle Click strings live in
  `InputSettingsStrings.swift`. No changes to `Localization.swift` or the per-language
  `Strings+*.swift` files are needed, except if `shortcutRefused` is promoted to the
  shared `Strings` (not planned).
- New and changed fields are added to all 15 literals in the same commit. The memberwise
  initializer makes a missing language a compile error; removed fields are deleted from
  all literals together.
- en-US and pt-BR are authored here (§9). The other 13 are translated at implementation
  time following each file's existing terminology for "radial menu", "wheel", "profile",
  "middle click" and "four fingers" (reuse `middleClickTapFourFingers`-style wording
  already in each language).
- Format strings use positional specifiers (`%1$@`, `%1$d`) so languages can reorder.
- Length check: the pt-BR, de, ru and fr strings for `trackpadTap`, `trackpadClick`,
  `takeoverConfirm` and `makePrimaryButton` must fit their controls at the default
  window width; rows truncate with full text in `.help`.
- A test asserts every radial and Middle Click string is non-empty in every language and
  that each format string has the same placeholders as en-US.

## 11. Accessibility

The list view was the accessible way to edit; the editor must replace it fully.

- **Slots:** each is a focusable button (`.focusable()`, focus ring) labeled
  `slotAccessibilityFormat` (name, kind, position, count). Actions: default = edit;
  custom actions `editActionButton`, `moveEarlierButton`, `moveLaterButton`,
  `editActionsButton` (submenus), `deleteButton`. Keyboard: Tab enters the wheel, arrow
  keys move focus clockwise/counter-clockwise, Return/Space edits, Option-arrow moves the
  focused item, Delete removes it without a prompt (matching today's context menu).
- **Add slot:** button labeled `addButton`, last in focus order.
- **Tabs:** `.accessibilityElement(children: .contain)` with label `profilesHeader`; each
  tab is a button with `.isSelected` when current, value `primaryHelp` on the first,
  custom actions `moveLeftButton` / `moveRightButton` and `makePrimaryButton`.
- **Counter:** `actionCountFormat`.
- **Live menu:** profile switches post an announcement with the profile name; the tab
  arc's pills are accessibility elements in the panel.
- **Color is never the only signal:** selected tab = fill + bold + `.isSelected`;
  primary = star + help text; notes = icon + text; swatches = checkmark + ring + name.
- **Reduce Motion:** profile switch crossfades; slot scale-on-hover and the add-slot
  relayout animate only without Reduce Motion.
- **Contrast:** gradient stops for every color keep white tab text at ≥ 4.5:1 on the
  darker stop (Yellow and Mint use dark text if they fail; check at implementation).

## 12. Acceptance criteria

Page

- [ ] The page is a header and cards only; no `Text` exists outside a card or the header.
- [ ] No Opening behavior, Opens at, Try it, Show as list, Add action button, or
      per-profile trigger controls remain.
- [ ] The Open the menu card shows three single-line rows; the ⓘ popover is the only
      paragraph of help on the page.
- [ ] A refused shortcut shows `shortcutRefused`, not `shortcutInvalid`.
- [ ] The mouse button recorder stores the next extra button, refuses left/right, cancels
      on Esc, shows the 5 s hint, and shows the back/forward note.
- [ ] Profiles are chosen, added, reordered, renamed, recolored, duplicated, made
      primary, reset and deleted from the editor's top bar; the first tab is primary.
- [ ] The add slot appears in the next free position and disappears at 12; the counter
      reads correctly.
- [ ] Profile colors render as gradients in tabs, swatches, highlighted chips and wedges,
      in light and dark.

Behavior

- [ ] Quick press (< 0.30 s) with nothing preselected stays open; hold ≥ 0.30 s with
      nothing preselected closes; any release with a preselected slot runs it.
- [ ] The same holds for an F-key shortcut, a Hyper/Super Key shortcut, and the mouse
      button.
- [ ] The menu always opens at the pointer on the primary profile.
- [ ] Tabs switch by click, Tab/Shift-Tab, scroll (one step per notch / 40 pt) and a
      0.35 s dwell while holding; switching resets highlight and submenu.
- [ ] Four-finger tap opens on lift and closes on the next tap; four-finger click opens
      on press, nothing under the wheel is clicked, and the next click closes.
- [ ] Four-finger swipes up/down/left/right and four-finger pinches never open the menu
      and still perform their macOS gestures; a Spaces switch closes an open menu.

Middle Click

- [ ] With the radial tap (click) set, Middle Click never fires on a four-finger tap
      (click); its "4 fingers" option is disabled with a note and an Open Radial Menu
      button.
- [ ] Choosing the radial gesture while Middle Click uses it asks first; Cancel changes
      nothing.
- [ ] Turning the radial gesture or the feature off restores Middle Click's saved choice.

Migration

- [ ] Each row of the migration matrix (§8) holds, including the "Middle Click owned the
      tap" case and a restored old backup.
- [ ] `radialMenuAtPointer` and `radialMenuActivationMode` are gone from defaults,
      registration and the backup key list.

Localization and accessibility

- [ ] All 15 languages carry every new/changed string; removed strings are gone from all.
- [ ] Every editor operation is possible with the keyboard alone and with VoiceOver.

## 13. Tests

Unit (added to `build.sh`'s test sources where new files appear):

- `RadialMenuReleaseTests`: the §5.2 table for `releaseAction(heldFor:preselection:)`.
- `RadialMenuTriggerMigrationTests`: shortcut owner, primary move, mouse button pick,
  tap with and without Middle Click owning four fingers, legacy single wheel, empty
  profiles, already-migrated no-op, restored backup.
- `MiddleClickPrecedenceTests`: `effectiveTapFingers` / `effectiveClickFingers` across
  radial gesture × stored value × system three-finger ownership.
- `RadialProfileTabsTests`: wrap-around, scroll accumulation and cooldown, visible window
  of ±3, empty profiles kept in the cycle, opening when only the primary is empty,
  primary = first after reorder/delete.
- Update `RadialProfileSyncTests`, `RadialProfileActivationTests` (likely deleted with
  `RadialProfileActivation`), `SettingsFeatureTests` (backup keys),
  `ScreenshotFeatureTests` line asserting the `radialMenuAtPointer` default.
- Strings test from §10.

Manual (real trackpad, Magic Mouse/side-button mouse):

- macOS gestures at four fingers (Mission Control, App Exposé, Spaces, Launchpad pinch,
  Show Desktop spread) with each radial gesture setting.
- Three-finger drag on: Middle Click shows Not available when the radial menu takes the
  four-finger click.
- Light and dark, Reduce Motion, VoiceOver pass over the editor and the live menu.

## 14. Risks and open questions for implementation

- **Carbon key-up for modifier-free shortcuts:** `QuickToolHotkey` must register for
  `kEventHotKeyReleased`. If a key-up is ever missed (focus change mid-hold), the next
  pointer move or a 10 s safety timeout ends the hold phase as sticky, never as a run.
- **Four-finger click swallowing:** confirm the radial path consumes the press pair in
  every app, including apps on Middle Click's exception list (the exception list is
  Middle Click's, not the Radial Menu's).
- **Panel growth for the tab arc** must not make the wheel feel offset near screen edges;
  clamp on the wheel, allow the arc to shift inward.
- **Process note:** this spec was written in the main checkout as a docs-only change and
  is not committed; the design-spec skill's worktree, commit and planning steps were
  deferred at the user's instruction.
