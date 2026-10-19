# Compact updates and permission cards

Approved design: keep update status and actions on one horizontal row at the
reported width. Permit status and timestamp truncation before moving actions;
keep errors readable and download progress visible.

Permissions retain their name, status, explanation, and existing request/settings
actions. Give each row equal top and bottom padding. An accessible icon-only
information button beside its name opens a native details sheet containing its
active feature usage and unused-permission warning, with Done/Escape dismissal.
Remove the Settings intro only; onboarding still uses that localized copy.

Place red Clear all permissions at the end of the first Permissions section,
with its explanation and result in the same grouped block. Keep confirmation
and reset behavior unchanged. Group export/import buttons, explanation and
feedback inside one Lattice Data form row. Rename the last section Uninstall
Lattice, group its button and explanation, and use a red outlined button.

Verification seams: hosted production layout and permission-details sheet,
native app interactions at the reported width, existing localization and
permission/reset contracts. Do not request, reset, import, or uninstall during QA.
