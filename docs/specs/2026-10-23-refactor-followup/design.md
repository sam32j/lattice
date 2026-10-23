# Settings Refactor III follow-up

Approved full plan, including fade-on-overlap, on 2026-10-23. Work on existing `refactor/settings-refactor-III` at `/Users/samuel/Developer/Lattice`, clean baseline 590fd058. Leave media/downloader branches untouched.

## Capture

Remove the inverted overlap treatment that makes the screenshot toolbar more opaque. Fade the entire bottom toolbar when its bounds intersect the selected/previewed capture area, restore it while the pointer is over its controls, and preserve ordinary contrast otherwise. Trace and verify system-dialog eligibility, accurate bounds, display snapshot fallback and input ordering together. Respect protected macOS surfaces. No private security bypass or blanket maximum-level escalation.

## Settings and entry paths

Apply the requested five-page hierarchy: primary enable switch; indented Show on Dynamic Island only when feature and island are enabled; deeper island-specific controls when selected; root Global keyboard shortcut; remaining settings visible but disabled when feature is off. File Cache's non-island settings remain visible off, but island rows obey the explicit hiding rules. Remove Camera/Launcher separators, File Cache how-to, and excessive menu-icon indentation. Use regular native switches. File Cache's inline information hint appears beside its enable switch only when enabled and routed standalone.

Both intentional app reopen and main menu-icon click open Settings when App Menu destination is Don't show. Preserve other destination and recovery behavior.

Permission reset retains preferences, asks for confirmation, and becomes a single neutral Restart now row only after the backend reports success. Failures stay observable; do not falsely claim success. Update Bluetooth/system-audio usage strings exactly, with trailing periods. Keep P6 system wording unchanged, trace its actual caller and expose a non-prompting Media & Music status row. Keyboard backlight already calls the system's private KeyboardBrightnessClient directly, without synthetic keys or an Accessibility requirement; explain the OS-compatibility caveat.

Clarified reset semantics: preserve saved configuration, shortcuts, layout and tuning, while switching off permission-dependent activation. A finer brightness-key step is saved tuning, not authority to rearm interception. Keep its paused state across restart and backup/restore; display the effective Standard mode until an explicit permission-gated step selection rearms it. Permission-use reporting and energy attribution must use that same effective mode.

## Verification

Approved seams: isolated permission/model/native-window/rendering tests. Never reset the user's real TCC grants or change hardware. Use tests before behavior fixes, real native fixtures for window ordering/input, focused and full suites, developer build, isolated rendering/selftest, and independent source review. Record any protected-surface or live-reproduction limitations rather than claim unsupported fixes. Descriptive/help copy ends in a period, labels remain natural, confirmation remains a question.
