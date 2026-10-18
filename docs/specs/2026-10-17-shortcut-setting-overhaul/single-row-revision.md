# Single-row shortcut revision

The October 18 revision replaces the toggle-plus-setter pattern with one label and one compact setter throughout shortcut settings. The setter stays editable when unassigned. Recording or resetting enables its shortcut; clearing disables it. Reset and clear actions live inside the field.

Dedicated shortcut enable preferences remain compatible with existing installations. For paired bindings that share an enable flag, an explicitly empty stored binding represents an unassigned shortcut. Missing preferences still resolve to their original defaults. Global hotkey registration ignores unassigned bindings, switcher routing receives no matching key, and the shortcut overview excludes cleared bindings from active roles.

Window-layout and screenshot-editor shortcut controls follow the same interaction. Actual feature switches, permissions, system takeover preferences, and shortcut-dependent behaviors remain separate controls.

Regression coverage checks missing preferences, explicit clear, and recording after clear through the persisted shortcut resolver. The affected shortcut suites and the full app build verify integration.
