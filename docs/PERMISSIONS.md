# Permissions

Lattice’s permission controls are in **Settings → Data & Permissions**. Permissions are optional for the app as a whole, but individual features require particular grants. There is no first-run permission walkthrough.

When you enable a feature that requires verified access, Lattice requests that access before enabling it. If the request is denied or left unanswered, the switch stays off. If an essential permission is revoked later, affected features switch off while their saved configuration remains. Granting access again does not automatically re-enable them; return to their settings and turn them on.

System audio is an exception: macOS does not expose an equivalent reliable preflight check for audio taps. Access is handled when an audio feature starts, rather than treating silence as proof of a denied grant. Permissions for individual files and folders also depend on the operation and location.

## Permission reference

| Permission | Used by |
|---|---|
| Accessibility | Keyboard and mouse input features, Window Management, Lattice Switcher, Dock Preview and Dock clicks, automatic paste, supported Command Bar and Radial Menu actions, Dynamic Island notification mirroring and other optional input controls. |
| Screen Recording | Screenshots, screen recordings, window previews, screenshot text recognition and Dynamic Island’s screen-watching tool. |
| System Audio Recording | The Volume Mixer, live music waveform and recording Mac sound. |
| Microphone | Microphone audio in a recording you start with that option enabled. |
| Camera | Camera Preview and the camera overlay when enabled for a recording. |
| Calendars | Upcoming appointments in Dynamic Island. |
| Bluetooth | Accessory battery readings that require Bluetooth, accessory alerts and Bluetooth Control where macOS requires authorization. |
| Files & Folders | Selected download-folder monitoring, file tools, saving captures and Cleaner’s old-screenshot review. |
| Notifications | Alerts from Stay Awake, Activity Monitor, Cleaner, app updates and other notification features you enable. |
| Full Disk Access | More complete Cleaner and app-uninstaller scans. |
| Automation | Finder operations, Homebrew’s Terminal handoff and supported player-specific playback controls. |
| App Management | Installing, replacing or removing other apps through Homebrew, App Updates or DMG Installer. |
| Administrator authorization | Optional closed-lid setup and privileged hardware operations such as fan control. This is separate from macOS privacy grants. |

## Accessibility and Screen Recording

Accessibility allows input interception or simulation and control of other apps’ windows. For example, Filter duplicate keys, Super Key, Text Snippets, Cleaning Mode, mouse scrolling rules and window actions need it. A plain shortcut assignment does not itself grant permission or install an unloaded feature.

Screen Recording allows Lattice to capture screen content. Screenshots and recordings use the area, window or display you choose. Text recognition in capture tools uses Apple’s Vision framework locally. The standalone Color Picker and OCR screens are no longer offered; shared capture and recognition functionality remains available where used by other tools.

App-only switcher mode can work without window thumbnails. Window previews and capture tools require their respective grants. Lattice does not automatically enable them after you restore permission in System Settings.

Captured content stays local unless you explicitly share it. Creating a temporary screenshot or recording link uploads that content to an upstream-operated service; see [Privacy](PRIVACY.md).

## Audio, microphone and camera

System Audio Recording is used to control per-app volume, show a live music waveform and include Mac sound in a recording. It is separate from Screen Recording and Microphone. Denying it does not mute your Mac’s ordinary playback. Audio features cannot assume access merely because their preference is on.

Microphone capture is used only when enabled for a recording. Camera Preview displays local camera frames; the recording camera overlay can save camera video as part of a recording when you enable it. Camera Preview does not start just because a shortcut is configured. Revoking Camera permission switches Camera Preview off; grant access and enable it again to resume.

## Calendar and Bluetooth

Dynamic Island’s calendar requests access from its permission control. It reads appointments without changing them. Calendar content remains on this Mac.

Some accessory batteries are available from existing system readings; others require a Bluetooth connection. Lattice does not start Bluetooth clients just because Dynamic Island opens while access is missing. Enable the accessory feature or use an explicit permission Request action to authorize it. Revoking or resetting Bluetooth access turns the accessory feature off. Bluetooth Control has its own behavior switches; permission still depends on macOS and the operation.

Music playback controls may request **Automation** for the selected player. That is different from Apple Music’s **Media & Music** library permission. Lattice has no intended Music Library authorization flow. Cleaner avoids protected media containers, and Dock Preview and Switcher use system app icons without reading other apps’ preferences. If a Music Library prompt appears unexpectedly, report what action preceded it; it is not a required setup step.

## Files, Cleaner and Full Disk Access

Download monitoring watches the folder you choose in the system picker. Its local access bookmark is not included in settings backups. If access is lost, choose the folder again. Other file tools use the files or save destinations you select.

Cleaner can review old screenshots in the configured screenshot locations. It does not organize or clean WhatsApp downloads; that feature was removed. Scheduled cleanup follows the categories and schedule you enable. Protected Apple and media containers are excluded from Cleaner scans to avoid unrelated permission prompts.

Cleaner and the app uninstaller can scan more locations with Full Disk Access. Without it, protected locations may be unavailable or a scan incomplete. Lattice cannot grant this access itself; manage it in System Settings → Privacy & Security → Full Disk Access.

## Automation and App Management

Automation is granted separately for each target app. Finder file operations, Homebrew’s Terminal handoff and player-specific playback commands can require it. A denied player grant does not stop ordinary playback in that player. An explicit permission action does not replay a previously blocked command.

App Management protects installed application bundles. Installing or replacing an app can trigger a request. Lattice cannot reliably determine this permission’s status beforehand; it is not the same as Accessibility or administrator authorization.

## Administrator authorization

Closed-lid mode uses `pmset disablesleep`. Optional setup installs a narrowly scoped sudoers rule for that command, so you do not need to enter an administrator password for each toggle. Without the rule, the operation can request administrator authorization each time.

Fan control uses a separately authenticated privileged helper. Neither the closed-lid rule nor the helper replaces macOS privacy permissions or gives unrelated tools unrestricted access.

## Resetting permissions

Use **Settings → Data & Permissions → Clear all permissions**. After confirmation, Lattice resets its macOS grants and disables Launch at login. Saved shortcuts, tuning and layout remain; features that lose essential permission switch off. Restart Lattice with **Restart now**, then grant access and enable the features you want.

This is not a factory reset or uninstall. Production Lattice (`io.github.sam32j.lattice`) and Lattice (Developer) (`io.github.sam32j.lattice.dev`) have separate grants. See [Troubleshooting](TROUBLESHOOTING.md#resetting-permissions) for app-specific Terminal reset commands.
