# Shortcut Setting System Overhaul

## Summary

Standardize every editable shortcut in Lattice on the compact inline interaction introduced for screenshot shortcuts. The shared system must preserve each feature's storage, enablement, conflict rules, macOS takeover behavior, and special capture semantics while presenting one stable recorder experience throughout Settings and the mixer panel.

The screenshot editor tool setter keeps its narrower field. When an editor shortcut cannot be assigned, its English inline error changes from `Shortcut Unavailable` to `Unavailable`; every supported locale receives an equivalently compact label.

## Scope

The migration includes:

- ordinary app-wide shortcuts backed by `GlobalShortcutRole`;
- window-layout action and modifier-only directional shortcuts;
- radial-menu profile and item shortcuts;
- command-bar app-entry shortcuts;
- mouse-button mappings;
- screenshot and screen-recording shortcuts;
- screenshot editor tool shortcuts; and
- the sound-output shortcut exposed in the mixer panel.

Existing row labels, descriptions, toggles, status indicators, feature-specific controls, persisted keys, and migration behavior remain unchanged. The project does not add a new shortcut model or force dynamic shortcut owners into `GlobalShortcutRole`.

## Chosen Architecture

Use one shared compact recorder engine with storage and validation adapters.

The shared presentation owns the fixed-height field, visual states, hover treatment, active-recorder coordination, keyboard capture bridge, inline reset and clear affordances, shake feedback, beep, and two-second error lifetime. Feature adapters provide the current value, whether clearing and resetting are available, validation and save decisions, and feature-specific recording modes.

`GlobalShortcutRole` keeps a convenience adapter for the common case. Dynamic models such as radial profiles, command-bar entries, mouse mappings, and window-layout actions use closures or small typed adapters so their existing services remain authoritative. Screenshot editor tools reuse the shared presentation at their narrower width while retaining their dedicated conflict source and binding storage.

This avoids two rejected designs:

1. Migrating only `ShortcutPreferenceRow` would leave custom setters inconsistent and would not cover the entire app.
2. Converting all shortcut owners to `GlobalShortcutRole` would couple dynamic and local bindings to the wrong persistence and identity model.

## Interaction Model

- Only one shortcut field records at a time across every supported surface.
- Clicking an idle field starts recording and clears stale transient feedback.
- Escape cancels without changing the stored shortcut.
- Delete or Backspace clears only when that shortcut owner supports clearing.
- Reset validates the default before writing it and never rewrites another feature's shortcut.
- Recording, shortcut display, empty, hover, disabled, and error states keep a stable 26-point control height and fixed configured width.
- Clear and reset actions remain inside the field where the owner supports them.
- A rejected shortcut stays unchanged, beeps, shakes, and shows a compact inline error for two seconds.
- Leaving the app, closing the window, clicking outside, or removing the view stops recording and restores normal shortcut handling.
- Existing macOS takeover offers remain available where supported. A shared presentation must not reduce an offer to a generic error.

## Validation and Data Flow

The recorder converts keyboard events into a `GlobalShortcut` or modifier-only trigger, then delegates validation to the owner adapter. Validation remains ordered:

1. structural validity;
2. conflicts with other Lattice shortcut owners, excluding the current owner;
3. feature-specific conflicts such as window layouts, radial profiles, or tool bindings;
4. live macOS conflicts; and
5. the existing takeover decision when the owner supports it.

A successful save writes through the existing owner and runs its current refresh callback. A failure changes only transient presentation state. Clear and reset follow the same owner-specific persistence path and preserve unrelated enablement or takeover state.

## Localization

Reuse the general shortcut strings wherever the field has room for a specific validation message. The screenshot editor tool field uses the feature-local compact unavailable label because it is narrower. English becomes `Unavailable`; every `AppLanguage` case receives a short localized equivalent. No row may expand to accommodate an error string.

## Testing and Verification

Behavioral coverage will verify:

- capture, cancellation, clear, and reset;
- internal conflicts and self-conflict exclusion;
- feature-specific and macOS conflicts;
- supported takeover offers and decisions;
- dynamic shortcut entries and modifier-only capture;
- one active recorder across roles and tools;
- cleanup on resign, close, outside click, and disappearance;
- stable compact field dimensions and embedded actions; and
- `Unavailable` in the screenshot editor tool field.

Focused test suites will run during TDD. Final verification will include all affected shortcut suites, the app build, selftest, and the repository's broader test command when practical. A whole-diff review will check scope and consistency before completion.
