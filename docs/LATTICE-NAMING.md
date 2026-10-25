# Lattice naming and compatibility

The technical rebrand on October 25, 2026 renames the active source tree to `Sources/Lattice`, the Swift package to `Lattice`, the build flag to `LATTICE_DEVELOPMENT`, and the Now Playing adapter library and its private C exports to Lattice names. Developer builds remain a separate installation.

Production remains `io.github.sam32j.lattice`; Developer remains `io.github.sam32j.lattice.dev`. No app-data or preference-domain migration is part of the naming change. Existing signing identities, helper installation identifiers and permission identities stay stable.

The original GPL-3.0-or-later license, copyright notices and upstream attribution remain. Genuine upstream service addresses and compatibility values are retained where still used. Historical changelogs/specifications describe their original revisions, not a current Lattice feature catalog. Current product links, support destinations and permission explanations must describe Lattice; references to the upstream product must name Vorssaint. The upstream-only release workflow retains its original repository/signing guards; Lattice uses its dedicated release workflow.

Some compatibility wire values intentionally retain their original spelling:

- Settings backup format keys: `vorssaintBackupVersion` and `vorssaintBackupAppVersion`.
- The saved Keep Awake icon raw value `vorssaint` (the Swift case and visible label are Lattice).
- Saved AirPlay choice IDs and Scratchpad task-link scheme.
- `VORSSAINT_RESOLVING_ENVIRONMENT` is still exported alongside `LATTICE_RESOLVING_ENVIRONMENT` so existing shell startup files keep their permission-safe early-return behavior.
- The privileged fan-helper lock/active file names, so old/new and production/Developer helpers still coordinate access safely.
- Historical bundle migration names and conservative cleanup/uninstall protection domains.

These values must not be replaced blindly: changing them can invalidate old backups, saved selections or shell safeguards. All active metadata readers/writers and helper-library consumers use the new technical names together. This does not move user content, reset permissions, replace signing certificates or modify other feature branches.

## Corrective content audit

The first naming pass missed semantic errors in upstream attribution and retained stale feature/permission copy. The corrective audit distinguishes product identity, upstream attribution, compatibility values and historical records instead of treating every old name as replaceable. It checks the base Info.plist and every localized InfoPlist.strings, current documentation, support links and active request metadata. Removed WhatsApp cleanup must not appear as a permission purpose. Permission documentation follows the current toggle-owned activation and permission-loss model. Historical release notes retain their original statements and do not establish signing, notarization or feature availability for current Lattice builds.
