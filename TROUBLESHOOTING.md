# Opening Lattice for the first time

Lattice is not currently notarized by Apple. macOS may block a downloaded build because it cannot verify the developer or check the app for malicious software. This does not by itself mean malware was found, but it is not proof that the app is safe either.

Only continue if you trust the source and the download. Get Lattice from this project's releases, not a mirror or a message attachment:

https://github.com/sam32j/lattice/releases

## Try this first: Open Anyway

1. Drag Lattice into Applications, then try opening it from there.
2. If macOS blocks it, open System Settings > Privacy & Security.
3. Scroll to the security notice for Lattice and choose Open Anyway.
4. Confirm that you want to open Lattice and authenticate if prompted.

This creates an exception for this app, not every downloaded app. Lattice lives in the menu bar, so look for its icon there once it opens.

Apple explains this process and the different warnings here:
https://support.apple.com/en-us/102445

## If the trusted download is still blocked

Do not bypass a warning that the app will damage your computer or contains malware. If macOS says the app is damaged, delete that copy and download it again from the project releases first. A damaged-app warning can also mean corruption or tampering, not just missing notarization. If the warning persists, report it before proceeding.

If the issue is only Gatekeeper blocking an unnotarized download, Open Anyway is unavailable or does not work, and you have verified and trust your copy, you can remove the quarantine attribute from just the installed Lattice app. Open Terminal and run:

```sh
xattr -dr com.apple.quarantine "/Applications/Lattice.app"
```

Then open Lattice from Applications again. If you installed it somewhere else, replace the quoted path with that app's exact path.

This removes the downloaded-file quarantine marker from Lattice and its bundled files. It bypasses the quarantine-based first-launch check for that copy; it does not notarize the app, verify its contents or make it safer. It does not disable Gatekeeper globally or grant Accessibility, Screen Recording or other permissions. Do not run this command against an entire folder of apps, add `sudo`, or disable Gatekeeper system-wide. If it fails or your Mac is managed by an organization, ask for help rather than weakening system protections.

## Privacy and safety

Lattice's core utilities run locally. Settings and clipboard history stay on your Mac, and the app has no account requirement or automatic telemetry. That is a privacy choice, not a promise of zero risk: any app with permissions such as Accessibility or Screen Recording deserves care.

Not every feature is offline. Update checks, speed tests, Homebrew actions, optional lyrics and artwork lookups, AI price and account-limit checks, capture-link sharing and feedback can use online services. AirPlay sends the selected audio to a speaker on your local network. Captures are not uploaded automatically; creating a temporary sharing link uploads the content you choose.

Read the full privacy and permissions details before enabling features:

- Privacy: https://github.com/sam32j/lattice/blob/lattice/main/docs/PRIVACY.md
- Permissions: https://github.com/sam32j/lattice/blob/lattice/main/docs/PERMISSIONS.md
- Other troubleshooting (includes upstream Vorssaint instructions): https://github.com/sam32j/lattice/blob/lattice/main/docs/TROUBLESHOOTING.md
- Report a problem: https://github.com/sam32j/lattice/issues

The upstream permission-reset commands target Vorssaint's `com.vorssaint.utils` bundle identifier. For Lattice, substitute `io.github.sam32j.lattice`, or `io.github.sam32j.lattice.dev` for a Developer build. For permission prompts, look for Lattice in System Settings.
