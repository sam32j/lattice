# media-optimizer MVP

User delegated design and plan approval while unavailable. No approval dialogs are required.

## Goal

Replace the old media workspace with safe local Clop SDK image/GIF and video optimization.

## Design

Use the official pinned MIT ClopSDK as a separately compiled module. Preserve originals by staging copies, validate responses and publish unique outputs. Shared image/OCR/archive helpers move out of the removed media engine. Keep feature identity and island entry points, but expose only Images and Videos.

## Alternatives

Prefer the requested local integration over a cloud service, which adds uploads and credentials. Prefer a focused MVP over retaining the old multi-tool/editor surface. Dependencies are not installed on the developer's Mac by verification. The app requires explicit user action for installation or launching Clop.

## Verification seams

Selected under delegated discretion: actual command/request construction, decoding and filesystem publication; subprocess fixtures for timeout/cancellation/errors; isolated service state; existing settings navigation tests and developer-only rendering. No real downloads, installs, credentials or user files during tests. Report real engine/site limitations separately.

## Acceptance

Usable consistent card-based utility, visible prerequisite status, actionable errors, cancellation, no original-file changes, no silent failure. Local execution is not a promise that a video site will permit download. Only download content the user is authorized to save.

