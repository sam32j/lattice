# Security Policy

Thanks for helping keep Lattice and the people who use it safe. This policy
applies to [sam32j/lattice](https://github.com/sam32j/lattice), not the upstream
Vorssaint project.

## Reporting a vulnerability

Please report security vulnerabilities in private. Do not open a public issue, pull request or discussion for them.

Use GitHub's private vulnerability reporting when it is available for this repository:

- **[Report a vulnerability privately](https://github.com/sam32j/lattice/security/advisories/new)**

Private reporting is currently disabled. Until it is enabled, open a
[Lattice issue](https://github.com/sam32j/lattice/issues/new) asking only for a
private security contact. Do not include vulnerability details, affected
components, reproduction steps, logs or exploit code in that public request.
Do not use the in-app feedback form for security reports: it opens a public
GitHub issue draft, not a private security report.

Once a private reporting channel is established, include the following details
only in your private report:

- A description of the issue and the impact it could have.
- Steps to reproduce, or a proof of concept.
- The Lattice version from Settings under About and your macOS version.

## What to expect

- This is a community project looked after on a best effort basis, so please allow reasonable time for a reply and a fix.
- Please give the maintainer a chance to ship a fix before you talk about the issue in public. That is what coordinated disclosure means.
- Credit goes gladly to reporters who want it.

## Supported versions

Security fixes target the latest Lattice release. Include the affected version
and, if you can safely do so, whether the issue also affects the latest release.
Do not delay reporting a serious vulnerability just to upgrade or reproduce it.

## Scope

Lattice is a local-first macOS app with optional network features. Local builds
are not notarized by Apple. The release workflow can notarize the app and DMG
before publication when the required credentials are configured. Local-first
operation and local signing
are not guarantees of safety; see the [first-launch guide](TROUBLESHOOTING.md).

Relevant reports include misuse of macOS permissions, exposure of clipboard or
capture content, unsafe file handling, and weaknesses in downloads or the update
verification flow. Issues in external services should be reported to their
operators, but report any unsafe handling of those services by Lattice here.
