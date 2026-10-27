# Video Website Sessions Implementation Plan

**Goal:** Allow explicit, per-website browser sessions for video metadata and downloads without storing cookie exports.

**Architecture:** A local preferences store maps normalized website hosts to a supported browser and optional profile. Metadata and download commands receive the same captured session arguments. A Settings sheet manages choices; authentication errors offer an explicit recovery action from Settings and Dynamic Island.

**Tech Stack:** SwiftUI, Foundation, UserDefaults, yt-dlp.

## Tasks

1. Add `VideoWebsiteSessions.swift`: validated browser/profile selection, exact normalized host matching, local persistence, safe error classification. No password, cookie, or account-token storage.
2. Integrate `VideoDownloaderInspection.swift`, `VideoDownloaderDownload.swift`, `VideoDownloaderJob.swift`, and `VideoDownloader.swift`: capture selection per search, reuse during download, clear stale metadata on selection change, show actionable sanitized errors. Never automatically read cookies without a saved selection.
3. Add `VideoWebsiteSessionsSheet.swift` and session controls to Settings and island error recovery. Keep the prior quality-selector experiment intact. Explain browser-wide cookie access, local handling, website transmission, and possible account restrictions before Save.
4. Verify compilation and review the diff. User explicitly requested no tests. Do not access real cookies, Keychain, signed-in websites, hardware or permissions. Leave local and uncommitted.

## Acceptance and review

- Default anonymous; separate host choices; persistent browser/profile settings only.
- Add/edit/forget sessions; optional profile name/path validated before execution.
- Metadata and download share authentication. Selection changes invalidate stale metadata.
- Sign-in and browser-access errors produce distinct recovery copy without raw tool output.
- No cookie export argument, telemetry, or cookie logging.
- Premium formats are only those returned by the extractor; no entitlement or DRM bypass promise.

## Status

Implementation in progress. Automated tests waived by the user; build and static review pending.

## Review and verification

Independent review found and resolved two issues: download-time authentication failures now remain visible in Dynamic Island alongside metadata; generic filesystem errors no longer receive a browser-access diagnosis. Follow-up static review: ready.

User waived automated tests. No real cookies, browser profiles, Keychain, signed-in requests, or permission grants were accessed. Developer compilation and bundle signing passed; final rebuild after review fixes pending. Changes stay local and uncommitted on fix/settings-followups.

## Manual verification for the user

1. Open Video Downloader Settings → Website Sessions → Manage.
2. Enter the website and choose the browser where you are signed in. Optionally enter a browser profile name/folder. Save alone does not inspect browser cookies; it authorizes using that selection on future matching requests.
3. Search a matching video, or use Save and Retry with the current URL. Handle any macOS access request yourself. Actual authentication remains subject to the website, account, cookies, and yt-dlp support.
4. Confirm the available qualities and download. Metadata and download use the same captured browser selection.
5. Forget the site, then search again. Subsequent requests for that site run without browser cookies. Other saved sites are unaffected.
6. A failed or expired session should show an actionable message and Choose Browser Session in Settings and Dynamic Island, including after metadata already loaded.

Browser sessions are matched by normalized host, with explicit YouTube aliases. No generic suffix matching or cross-site default is used. The browser cookie database may be read broadly by yt-dlp, while its cookie jar applies matching-domain rules to network requests; Lattice does not export a cookie file.
