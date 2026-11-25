# Upstream v3.4.4 and v3.4.5 adoption plan

Source review: the first-round adopt/reject list (gemini-code-1795597526915.md).
Base: `feat/app-management` @ bbeff9672, with upstream fetched to `v3.4.5` (0f0fdd91e).

## How this was checked

- Every non-docs upstream commit in `v3.4.3..v3.4.4` (72) and `v3.4.4..v3.4.5` (110) was trial-merged onto HEAD with
  `git merge-tree --merge-base=<c>^ HEAD <c>` (renames at 50%). 14 apply cleanly. The rest conflict, usually because
  Lattice split or retired the file (menu panel, `EnergySettings`, `AdvancedSettings`, `QuickToolsSettings`,
  `BrightnessSection`, `AudioPrioritySection`, `FeatureHubSettings`) or rewrote it (Settings pages, switcher UI,
  window snapping, Stay Awake, uninstaller/cleaner on this branch).
- Each adopted changelog line was traced to its commits, and each commit's diff was searched for symbols from features
  that were rejected now or not adopted in 3.4.3 (monitor speakers, call-app unmute, All windows, Pinch Zoom, full-screen split).

## Method (same as 3.4.3, commit 9f0990a54)

1. Land or commit `feat/app-management` first. The working tree has uncommitted changes in `CleanerPolicy`,
   `CleanerSupport`, `UninstallerSupport`, Homebrew, `NotchService` and the Hub, and the cleaner/uninstaller ports below touch those same files.
2. For each version, on a branch from `lattice/main`: port each accepted change as its own commit onto Lattice's
   implementation (`git cherry-pick -x` where it applies, otherwise a hand port that cites the upstream hash).
3. Close the version with `git merge -s ours vX.Y.Z` ("chore(downstream): merge upstream vX.Y.Z", listing what was ported and what was not),
   then a rebrand commit for identifiers carried in by the ports, then record the upstream history in `CHANGELOG.md` and add Lattice entries in `Downstream/CHANGELOG.md`.
4. `Downstream/release.json`: `upstreamTag`/`upstreamCommit`/`baseCommit` move to the tag's commit, and `revision` goes back to 1.
   v3.4.4 = `d9c7f4a77…`, v3.4.5 = `60f2b37f9…` (run `git rev-parse vX.Y.Z^{commit}` for the full SHAs).
5. Skip upstream docs/README/SPONSORS, `Defaults.releaseVersion`/`seenVersion` bumps (85ad9ad49, d9c7f4a77, 60f2b37f9) and the update-intro flow.

General adaptation rules for every port:
- New settings go onto the Lattice page that owns the feature, use `PermissionGatedToggle`/preset pickers where Lattice does, and get a Settings Search alias. Never revive `SettingsDirectory` rows or menu panel sections.
- Strings: English plus every locale Lattice ships. Say "Lattice", never "Vorssaint".
- Tests: port the upstream test into Lattice's suites and register it in `Tests/generate_sources.py` and `build.sh`.
- **UI fit:** every port with a visible effect has an ID in [ui-audit.md](ui-audit.md) (U1–U34). The port is done only when its placement, component, copy and checks there are met. Nothing on the audit's "must not appear" list may arrive through a port.

---

## Conflicts with the first-round review

| # | Line | Problem | Recommendation |
|---|------|---------|----------------|
| C1 | 3.4.5 Fixes, monitor speakers unmuting at zero (adopted) | All 10 commits (7ef0b3c7c, 2a55c0e05, 53e68295e, bdbbb473b, 603f5d47d, 0c46688aa, 6cc598ae4, 02f826648, d113fe7ff, the speaker half of d9680ca32) patch the monitor-speaker feature from ab9f01cfb/49ffe9283. That feature was rejected in 3.4.4, and Lattice has no `SpeakerTarget`/`routeMonitorVolume` code. | **Rejected (confirmed 2026-11-25).** It cannot be adopted without the speaker feature. |
| C2 | 3.4.5 HDMI converter (adopted) | bf4836db0 covers brightness and speakers (42 speaker references). | Port the brightness/DDC address part only, plus 3120d3789. |
| C3 | 3.4.5 USB volume keys (adopted) | 82bf78d35 rewrites `routeMonitorVolume` into a shared `routeVolumeKey`, so the speaker path is interleaved with the USB fix. | Hand-port the native-key drain and the USB step/confirm logic onto Lattice's 3.4.3 USB volume-key port. Drop the monitor branches. |
| C4 | 3.4.5 Mic Mute (adopted) | 8 of the 10 commits (9884a5220, 804c6e70e, 3af97042e, 56f290dc5, 3305f8291, 2836b29e4, 75f2e3be5, 1ca3fdde8) are written on top of the call-app unmute engine from 17dba59a6, which was rejected (line 99). | **Decided 2026-11-25: port 17dba59a6 in full, switch shown and off by default.** `micMuteFollowCallApps` defaults to false. While it's off, call-app detection never runs and Mic Mute behaves as it does today. The switch becomes one opt-in row on the Audio Input page ([U34](ui-audit.md)). Then port the 10 fixes nearly as written. |
| C5 | 3.4.5 AirPlay priority, note "I think we already have this?" | No. Lattice's 51ac1159d fixed AirPlay *routes* in the mixer. `AudioPriorityService.mergeAvailableDevicesIntoPriorityLists` still appends a reconnecting AirPlay device with a new session UID as a new entry, and there is no per-entry remove. | **Adopted (confirmed 2026-11-25).** Port 6b4ebcb35 (`MixerRoutingSupport` + `AudioPriorityService`, UI into Lattice's audio priority list). |
| C6 | 3.4.5 screenshot editor memory, note "find a methodology" | The memory work is self-contained. | Port 1d4520378 (bound undo/redo image memory, drop the full capture after a smaller crop) and 0f474e4b2 (release display pixels after a window crop). Skip the caption/undo/close-prompt UI (499c6f394, 22382c86d) and the resize prompt (811b8a3b6). |
| C7 | 3.4.4 window switcher and secure input (adopted) | The line mentions the "All windows" shortcut, which Lattice did not adopt in 3.4.3. ab7e57131 has 17 All-windows references. | Port it without the All-windows parts. |
| C8 | 3.4.5 switcher follows the focused window (adopted) | ddcedcabc ("refresh all-window selection") and e07d76ec4 ("before individual switching") only matter in All-windows mode. | Skip both. Adopt the rest of the switcher chain. |
| C9 | 3.4.5 games and ⌘Tab (adopted) | 653826ec4 calls `NotchAppFullscreen.onScreenWindows` and `coveredDisplays(windows:…confirmed:)` from c5930bfc6, which was rejected (line 39, also "full-screen hiding split", not adopted in 3.4.3). | Port only the `NotchAppFullscreen` window-list helper from c5930bfc6 without changing island behavior, then 653826ec4. |
| C10 | 3.4.4 modifier + wheel acceleration (adopted) | 375c57b10 has 38 references to Pinch Zoom (`scrollZoom`), which was not adopted in 3.4.3. Its 2×–15× slider also goes against Lattice's preset pickers. | Strip the Pinch Zoom references and modifier arbitration. Expose speed as a preset picker (e.g. 2×/4×/8×/15×) in `MouseScrollingSettings`. Keep horizontal-scroll modifier arbitration. |
| C11 | 3.4.4 Stay Awake restores manual sessions (adopted) | 15bd02d30 is interleaved with start-at-launch (`SessionTrigger.launch`, `launchActivationPending`), which Lattice removed. | Port the saved manual session (end date, restore at recovery) only. Drop the launch trigger. |
| C12 | 3.4.4 XDG file, note "lattice" | Upstream hard-codes `vorssaint`. | `~/.config/lattice/settings.plist` (`$XDG_CONFIG_HOME/lattice/`), Developer build `lattice-dev`. Use the same path for the 3.4.5 Save action. Rewrite the docs in `docs/PRIVACY.md`/`TROUBLESHOOTING.md` for Lattice. |
| C13 | 3.4.4 uninstaller offer after Finder trash (adopted) | cfe4e89d0 needs Full Disk Access to watch `~/.Trash`. | **Dropped (decided 2026-11-25):** the Finder-trash offer is not ported (cfe4e89d0, and b023c7707, which only makes that offer's setup section scroll). Select all (91d4421b1) is still ported. It came earlier upstream and doesn't depend on the offer. |
| C14 | 3.4.4 smooth scrolling (partial) | Matches your split. | Adopt 0adc546fc. Skip 4a53492e9, which only touches the retired menu panel. |
| C15 | 3.4.5 startup (adopted) | 10b160914 creates Shelf, Command Bar and Display services lazily. The Hub and island hosts may reach `ShelfService.shared`/`CommandBarService.shared` directly. | Port it, then audit every Hub/island entry point so it goes through `AppFeature.*.isAvailable`. Drop the `PreciseVolumeRoller` speaker line. |

Lines that need only the price list: 3.4.4 "GPT-6.1 Terra / Rosalind Discovery" comes from **a5da7633e** (a `chore` commit). 3.4.5 GPT-6.2 also needs **89d262608**. Lattice has never edited `Resources/agent-prices.json`, so these apply cleanly.

---

## v3.4.4 — port order

Port in this order. Clean means `merge-tree` applied it without conflicts.

**A. Foundations**
1. f06190ceb Sonoma launch crash: add the `CoreAudioTapCompat` target to `Package.swift`, update the three tap users (`AppVolumeMixer`, `NotchAudioLevelService`, `RecorderSystemAudioTap`; Lattice has no others), add `Tests/AudioTapImports.awk` and its `build.sh` check.
2. a5da7633e price list (clean).

**B. Audio and input**
3. b1ffc9d90 mixer slide (clean). 86f84be10 mixer tap resume.
4. 5b0a8b44b, 5b321192a Mic Mute zero gain and channel levels, ported into Lattice's Mic Mute UX. [U10]
5. b891ebd46, b36c30107, 83ec5e772 Super Key Caps Lock, recording and HID client (tests and `SuperKeyService` only).
6. d257dfd20, 2806d2bcc focus follows mouse (clean).
7. 375c57b10 modifier wheel speed (C10). [U1] 0adc546fc panel wheel distance (C14). [U31]

**C. Display**
8. da971fd4b DDC checksum and range (clean).
9. debddfccb, a83b4eaee software dimming for DDC. The UI goes to `DisplaySettings`/Device Controls, not `BrightnessSection`. [U32]
10. 181d0d5c3 built-in panel waits for unlock (tests only).

**D. Stay Awake**
11. 1fca805c2 docked lid-sleep restore, onto `KeepAwakeManager+Clamshell`.
12. 15bd02d30 restore manual sessions (C11), onto `KeepAwakeManager+Recovery`/`+Sessions`. [U28]

**E. Window switcher and layout**
13. 73b4846f5 quick-switch latency, ab7e57131 secure input (C7), c3877576b label reuse. [U27]
14. c9bb2c543 hover selection off: toggle in `SwitcherSettings`. Lattice already has edge-hover paging (`iconRowEdgeHoverDelta`). [U2]
15. b0cafdd3b, 7415c09f9 restore size on drag-away, onto Lattice's snapping session and preview overlay. Respect `WindowLayoutIgnoredApps`. [U3]

**F. Island**
16. 39230975a, 49281eed5, ad1aa8575 (clean). 16afaf7db, 7c5a34f62 mirrored banners and Notification Center. [U13, U18]
17. 7980161d0, b4d9318aa, c69bc12c4 click cancel, horizontal swipe, slider to the ends. [U17]

**G. Recorder and media**
18. 3afcd0222 GPU program reuse (clean). 561a94658 compact media scroll, into Lattice's `MediaWorkspaceView`. [U21]
19. 041753ad1 → d01ea2c6b → d461c2edd GIF: add the `RecorderGIFCodec` target (vendored cgif, keep its LICENSE). Merge the fps/scale control into Lattice's export controls next to the export-speed control without dropping speed. Update `docs/recorder-export-speed.md`. [U9]

**H. Utilities**
20. eccdb2de6 clipboard window position (clean). b2f67d416 Claude timer reset (clean). da1e5d523 (clean), 03a0761d9 Command Bar. [U19, U20, U29]
21. 4158fb4a2 cleaner domain-named folders → `CleanerPolicy`.
22. a4c0b18ad, cb8ba92a7, 772c8918c XDG load (C12). [U5]
23. 91d4421b1 uninstaller Select all, into the App Manager uninstaller views (both footers). [U6]

**Not adopted in 3.4.4:** ab9f01cfb, 49ffe9283, a3f776d61 (monitor speakers); ec25fc0b9 (scrolling capture); 811b8a3b6 (clipboard resize);
2a9d6b9c9 (clear shortcuts); cfe4e89d0, b023c7707 (Finder-trash cleanup offer, C13); c5930bfc6 (island full screen, except the helper in C9, ported in 3.4.5); b9f4ccea6 (WebKit player);
d110b626f, 4baad5513 (settings search, rejected; add Lattice aliases for new controls instead); 4632b3a88 (remote desktop paste);
4a53492e9 (panel smooth scroll toggle); c8cc63ee8 (Homebrew log); docs, test-only and chore commits not listed above.

Close: `merge -s ours v3.4.4`, rebrand commit, `release.json` → v3.4.4 revision 1, changelogs.

---

## v3.4.5 — port order

**A. Price list and agents**
1. 89d262608, 16ec70ce4, b974acbf5 prices and GPT-6.2 estimates.
2. 72a56c809, 2a8b8ddac Cursor in AI Agents. The settings go into Lattice's `NotchAgentsSettings` next to the Claude/Codex accounts. [U8]
3. e58896311, 6f404b858, dfb5d6041, 2a6e0f08b, 2a2636bc0, 232ee3029 Cursor counters and partial costs. [U8]

**B. Startup and window layout**
4. 10b160914 lazy services (C15).
5. 84b5755db one pointer tap for layout, gestures and edge snapping. **This is the largest hand port.** Rebase it onto Lattice's `WindowGestureApplySession` and snap preview, then confirm the 3.4.4 restore-on-drag still works.
6. a2998ce07 Option-drag tiling. [U4]

**C. Window switcher (in upstream order)**
7. d87419383 background inventory (adds `SwitcherWindowInventory`), edabe3d5e tap rearm, 653826ec4 games (C9), 0a77c4cff, 825523d97, 076d1bbe8, 98e24a5a7, 5f5fd12ec, 2a9297b39, 37efb959b, 4663095bc, and the switcher half of d9680ca32. Skip ddcedcabc and e07d76ec4 (C8). [U27]

**D. Audio**
8. Mic Mute (C4): 17dba59a6 (engine and opt-in switch, off by default) [U34] → c149f58b9, c7141c329, 9884a5220, 804c6e70e, 3af97042e, 56f290dc5, 3305f8291, 2836b29e4, 75f2e3be5, 1ca3fdde8 (its UI goes to Lattice's Audio Input page, Hub and island, not QuickLauncher or QuickToggles), with the bc362dd69 tests. [U10]
9. 4976d85aa mixer real pid (drop its one speaker line). 82bf78d35 USB volume keys (C3). [U24, U25]
10. 6b4ebcb35 AirPlay priority (C5), if accepted. [U11]

**E. Display, fan, keyboard**
11. bf4836db0 (brightness only), 3120d3789 (C2).
12. e2e61044b → 7390bbcba → ba68e1fb8 → 9af3c477a → 675cb674f, then 1a9d543df fan control. [U12]
13. 3f0008332 backlight (clean). c12fe416d Super Key waits for a keyboard. [U26]

**F. Stay Awake and settings**
14. 0e390bc58 power-loss delay: a field in Lattice's Power rule (`KeepAwakeAutomationView`), status in `StatusItemController` and the island strip. [U7]
15. 8c783a35b, 5437017b4, and the `SettingsBackup` half of d9680ca32: Save to XDG file in Lattice's Backup section, files only the owner can read. [U5, U15]

**G. Utilities, island, media**
16. fa2577f30 → db2b22308 → e61e04148 → e6c19658a → e15752b5e calculator (adds `CommandBarExpressions`). [U20]
17. 36767574b clipboard search (clean). 7c1f829c4 spreadsheet cells. [U30]
18. 6c9ed174c disk alert throttle → `MonitorAlertsControls`. [U14]
19. dd14fcb22 (`build.sh` only), 0bdd40d94 island on macOS 27. ced9bf540 media drop, also into the Hub-hosted Media page. [U22, U23]
20. e0d110e36, 6cdd3be0d Shelf.
21. c446b3f0f symlink siblings. 130ad975e, 121221a1b, 3e00c617d, 3d9b1a8b5, 21682edaa cleaner audio plugins and login items → `CleanerPolicy`/`CleanerSupport`.
22. 1d4520378, 0f474e4b2 screenshot editor memory (C6). [U33]

**Not adopted in 3.4.5:** monitor speaker set (C1: 7ef0b3c7c, 2a55c0e05, 53e68295e, bdbbb473b, 603f5d47d, 0c46688aa, 6cc598ae4, 02f826648, d113fe7ff, speaker half of d9680ca32);
ae8572cf2 (camera crop); e38ae98a9, e7d6d5359 (Homebrew filter); a8ec238b9 (Explore query); ef97c3c93 (disk images); 10a32ecb3 (menu panel clicks);
1dca33396 (window capture); 499c6f394, 22382c86d (caption undo/close); ddcedcabc, e07d76ec4 (All windows);
85ad9ad49, 7b0c8fd46 and docs commits.

Close: `merge -s ours v3.4.5`, rebrand commit, `release.json` → v3.4.5 revision 1, changelogs.

---

## Verification for each version

- `./build.sh --test`, `./build.sh --dev`, `./build/LatticeDeveloper --selftest`, `bun test Tests/downstream-sync.test.ts Tests/lattice-release.test.ts`.
- UI gate: everything in section E of [ui-audit.md](ui-audit.md) for the IDs this version touched (3.4.4: U1–U3, U5, U6, U9, U10, U13, U17–U19, U21, U28, U29, U31, U32; 3.4.5: U4, U5, U7, U8, U10–U12, U34, U14, U15, U20, U22–U27, U30, U33), plus its section D walk-through.
- Tap-import check (from f06190ceb) passes on the linked binary.
- `grep -rn -i vorssaint Sources/Lattice` shows only copyright attribution.
- Manual: XDG load and save at the `lattice` path; uninstaller Select all in Settings, island and Hub;
  restore size after drag-away with 84b5755db in place; GIF export at 12/15 fps × export speed; switcher under secure input and with a full-screen game.
