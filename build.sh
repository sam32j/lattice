#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint

# Builds Lattice, assembles the .app bundle, signs it and (with --install)
# installs it into /Applications.
#
# The bundle is staged in a temporary directory outside ~/Documents: folders synced
# by File Provider gain xattrs (com.apple.provenance etc.) that invalidate codesign.
set -euo pipefail
cd "$(dirname "$0")"
unset TZ

# The icon catalog and the bundle are staged in temp dirs; sweep both however
# the script ends.
ICON_TMP=""
STAGE_TMP=""

cleanup() {
    [[ -n "$ICON_TMP" ]] && rm -rf "$ICON_TMP"
    [[ -n "$STAGE_TMP" ]] && rm -rf "$STAGE_TMP"
    return 0
}
trap cleanup EXIT
# zsh runs the EXIT trap when the script is hung up, but not when it is
# interrupted or terminated; route those through exit so a Ctrl-C partway
# into the build sweeps like any other ending.
trap 'exit 1' INT TERM HUP

# Flags: --dev builds the local-only "Lattice (Developer)" variant (its own
# bundle id, so it coexists with the official app); --install puts it in /Applications.
DEV=0
INSTALL=0
TEST=0
TEST_ARGS=()
for arg in "$@"; do
    case "$arg" in
        --dev)     DEV=1 ;;
        --install) INSTALL=1 ;;
        --test)    TEST=1 ;;
        --test-suite=*) TEST=1; TEST_ARGS+=("--suite=${arg#*=}") ;;
        --list-tests) TEST=1; TEST_ARGS+=(--list) ;;
    esac
done

if (( DEV )); then
    APP_NAME="Lattice (Developer)"
    EXECUTABLE="LatticeDeveloper"
    APP_BUNDLE_ID="io.github.sam32j.lattice.dev"
    BUILD_VARIANT_FLAGS=(-D LATTICE_DEVELOPMENT)
    APP_OPTIMIZATION_FLAGS=(-Onone)
    BUILD_CONFIGURATION="debug"
else
    APP_NAME="Lattice"
    EXECUTABLE="Lattice"
    APP_BUNDLE_ID="io.github.sam32j.lattice"
    BUILD_VARIANT_FLAGS=()
    APP_OPTIMIZATION_FLAGS=(-O)
    BUILD_CONFIGURATION="release"
fi
FAN_HELPER_ID="$APP_BUNDLE_ID.fan-control"
# Now Playing is read through /usr/bin/perl loading this library; see
# Sources/NowPlayingAdapter. Staged under Contents/Frameworks, signed on its own.
NOW_PLAYING_ADAPTER_ID="$APP_BUNDLE_ID.now-playing"
NOW_PLAYING_ADAPTER="libLatticeNowPlaying.dylib"
TARGET="arm64-apple-macosx14.0"
ENTITLEMENTS="Resources/Lattice.entitlements"
LEGACY_IDENTITY="Lattice Local Signing"

developer_id_identity() {
    local team
    team="$(sed -n 's/.*static let signingTeamID = "\([A-Z0-9]*\)".*/\1/p' Sources/Lattice/Core/DownstreamIdentity.swift)"
    [[ "$team" =~ '^[A-Z0-9]{10}$' && "$team" != '3D485NHW29' ]] || return 0
    security find-identity -v -p codesigning 2>/dev/null \
        | grep 'Developer ID Application' | grep -F "($team)" | head -1 \
        | sed -E 's/.*"(.*)".*/\1/' || true
}

apple_development_identity() {
    security find-identity -v -p codesigning 2>/dev/null \
        | grep 'Apple Development:' | head -1 \
        | sed -E 's/.*"(.*)".*/\1/' || true
}

# A find-identity listing also names certificates codesign then rejects (an
# expired one fails the build with errSecInternalComponent), and -v excludes
# every self-signed one; ask codesign itself with a throwaway copy of /bin/echo.
legacy_identity_installed() {
    local probe signed=1
    security unlock-keychain -p lattice-signing \
        "$HOME/Library/Keychains/lattice-signing.keychain-db" 2>/dev/null || true
    # Probe only the separately named Lattice local identity.
    probe="$(mktemp)"
    cp /bin/echo "$probe"
    /usr/bin/codesign --force --strip-disallowed-xattrs --sign "$LEGACY_IDENTITY" "$probe" \
        >/dev/null 2>&1 && signed=0
    rm -f "$probe"
    return $signed
}

resolved_signing_identity() {
    local id
    id="$(developer_id_identity)"
    if [[ -n "$id" ]]; then
        print -r -- "$id"
        return 0
    fi
    id="$(apple_development_identity)"
    if [[ -n "$id" ]]; then
        print -r -- "$id"
        return 0
    fi
    if legacy_identity_installed; then
        print -r -- "$LEGACY_IDENTITY"
        return 0
    fi
    return 1
}

# Any build that lands in /Applications or runs under --dev benefits from a stable
# signature, so macOS retains Accessibility and Screen Recording permissions
# across rebuilds without re-prompting.
if (( DEV || INSTALL )) && [[ -z "$(resolved_signing_identity || true)" ]]; then
    echo "▸ No signing identity installed; creating stable local signing identity…"
    if ! ./Tools/setup-signing.sh; then
        echo "  ⚠ Tools/setup-signing.sh failed; falling back to ad-hoc signing." >&2
    fi
fi

codesign_with_timestamp_retry() {
    local attempt
    for attempt in 1 2 3; do
        if /usr/bin/codesign "$@"; then
            return 0
        fi
        if (( attempt < 3 )); then
            echo "  Developer ID signing failed; retrying ($((attempt + 1))/3)"
            sleep "$attempt"
        fi
    done
    return 1
}

write_swift_output_file_map() {
    local output_file="$1"
    local object_dir="$2"
    shift 2
    local source artifact

    {
        print -r -- "{"
        print -r -- "  \"\": {"
        print -r -- "    \"swift-dependencies\": \"$object_dir/master.swiftdeps\""
        print -r -- "  }"
        for source in "$@"; do
            artifact="${source//\//__}"
            artifact="${artifact%.swift}"
            print -r -- ","
            print -r -- "  \"$source\": {"
            print -r -- "    \"object\": \"$object_dir/$artifact.o\","
            print -r -- "    \"swift-dependencies\": \"$object_dir/$artifact.swiftdeps\""
            print -r -- "  }"
        done
        print -r -- "}"
    } > "$output_file"
}

finalize_installed_bundle_after_child() {
    local bundle="$1"
    local helper="$bundle/Contents/Library/LaunchServices/$FAN_HELPER_ID"
    local adapter="$bundle/Contents/Frameworks/$NOW_PLAYING_ADAPTER"
    local identity
    identity="$(resolved_signing_identity || true)"

    echo "▸ Finalizing installed signature…"
    sleep 3
    if [[ -n "$identity" ]]; then
        if [[ "$identity" == "$LEGACY_IDENTITY" ]]; then
            [[ -f "$helper" ]] && /usr/bin/codesign --force --strip-disallowed-xattrs \
                --identifier "$FAN_HELPER_ID" --sign "$identity" "$helper"
            [[ -f "$adapter" ]] && /usr/bin/codesign --force --strip-disallowed-xattrs \
                --identifier "$NOW_PLAYING_ADAPTER_ID" --sign "$identity" "$adapter"
            /usr/bin/codesign --force --strip-disallowed-xattrs --sign "$identity" "$bundle"
        else
            [[ -f "$helper" ]] && codesign_with_timestamp_retry --force --strip-disallowed-xattrs \
                --options runtime --timestamp --identifier "$FAN_HELPER_ID" --sign "$identity" "$helper"
            [[ -f "$adapter" ]] && codesign_with_timestamp_retry --force --strip-disallowed-xattrs \
                --options runtime --timestamp --identifier "$NOW_PLAYING_ADAPTER_ID" --sign "$identity" "$adapter"
            codesign_with_timestamp_retry --force --strip-disallowed-xattrs --options runtime --timestamp \
                --entitlements "$ENTITLEMENTS" --sign "$identity" "$bundle"
        fi
    else
        [[ -f "$helper" ]] && /usr/bin/codesign --force --strip-disallowed-xattrs \
            --identifier "$FAN_HELPER_ID" --sign - "$helper"
        [[ -f "$adapter" ]] && /usr/bin/codesign --force --strip-disallowed-xattrs \
            --identifier "$NOW_PLAYING_ADAPTER_ID" --sign - "$adapter"
        /usr/bin/codesign --force --strip-disallowed-xattrs --sign - "$bundle"
    fi
    [[ -f "$helper" ]] && /usr/bin/codesign --verify --strict "$helper"
    [[ -f "$adapter" ]] && /usr/bin/codesign --verify --strict "$adapter"
    /usr/bin/codesign --verify --deep --strict "$bundle"
    echo "✓ Signature ready: $bundle"
}

if (( INSTALL && ! TEST )) && [[ "${LATTICE_INSTALL_CHILD:-0}" != "1" ]]; then
    LATTICE_INSTALL_CHILD=1 "$0" "$@"
    child_status=$?
    if (( child_status != 0 )); then
        exit "$child_status"
    fi
    finalize_installed_bundle_after_child "/Applications/$APP_NAME.app"
    exit 0
fi

# Prefer the macOS 26 SDK when present: the 27 SDK turns SwiftUI property wrappers
# into macros (SwiftUIMacros plugin) that the Command Line Tools cannot load yet.
PINNED_SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk"
if [[ -n "${DEVELOPER_DIR:-}" ]]; then
    SDK="$(xcrun --show-sdk-path)"
elif [[ -d "$PINNED_SDK" ]]; then
    SDK="$PINNED_SDK"
else
    SDK="$(xcrun --show-sdk-path)"
fi
SDK_COMPAT_FLAGS=()
VM_STATISTICS_COMPAT_FLAGS=(-I Sources/VMStatisticsCompat)
HID_EVENT_SYSTEM_FLAGS=(-I Sources/HIDEventSystem)
if [[ "$SDK" == "$PINNED_SDK" ]]; then
    # Swift 6.4 can read the SDK 26 interfaces when given their compiler version.
    SDK_COMPAT_FLAGS=(-Xfrontend -interface-compiler-version -Xfrontend 6.3.2)
fi

# The defaults migrations under test need a real UserDefaults suite, and every
# suite leaves an empty plist in ~/Library/Preferences. The tests already clear
# the domains, but cfprefsd writes the emptied file back out around the time the
# process that owned it exits, so only a caller that outlives the run can remove
# them. `PreferenceNamespaceTests` scans every compiled Swift test file against
# these namespaces, which keeps this sweep complete without a second list.
discard_test_preferences() {
    local preferences="${1:-$HOME/Library/Preferences}" name attempt
    local survivors=0 quiet_passes=0
    # cfprefsd can recreate an emptied domain after the first removal. Require
    # two quiet checks, but keep a hard limit so persistent failures still fail CI.
    for attempt in {1..10}; do
        for name in "vorss.tests." "io.github.sam32j.lattice.tests."; do
            rm -f "$preferences"/$name*.plist(N)
        done
        rm -f "$preferences/metrics-tests.plist"
        sleep 0.2
        survivors=$(find "$preferences" -maxdepth 1 \
            \( -name "vorss.tests.*.plist" -o -name "io.github.sam32j.lattice.tests.*.plist" \
               -o -name "metrics-tests.plist" \) 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$survivors" == "0" ]]; then
            quiet_passes=$((quiet_passes + 1))
            if (( quiet_passes == 2 )); then return 0; fi
        else
            quiet_passes=0
        fi
    done
    echo "✗ test preferences did not settle in $preferences ($survivors remaining)" >&2
    return 1
}

# Standalone automated tests: pure contracts plus isolated disk, subprocess,
# keyboard-data and media fixtures. No application windows or device capture.
if (( TEST )); then
    if command -v uv >/dev/null 2>&1; then
        uv run --no-project --quiet --python "$(command -v python3)" python3 Tests/generate_sources.py
    else
        python3 Tests/generate_sources.py
    fi
    TEST_OBJECT_DIR="build/objects/tests"
    mkdir -p "$TEST_OBJECT_DIR"
    TEST_SOURCES=(
        Sources/Lattice/Services/InputEventTap.swift
        Sources/Lattice/Services/ActivationHandoff.swift
        Sources/Lattice/Services/Media/MediaSupport.swift
        Sources/Lattice/Services/VideoDownloader/VideoDownloaderStrings.swift
        Sources/Lattice/Services/VideoDownloader/VideoDownloadRequest.swift
        Sources/Lattice/Services/VideoDownloader/VideoDownloadProcess.swift
        Sources/Lattice/Services/VideoDownloader/VideoDownloadDependencies.swift
        Sources/Lattice/Services/VideoDownloader/DownloadHistoryStore.swift
        Sources/Lattice/Services/VideoDownloader/ToolchainManager.swift
        Sources/Lattice/Services/VideoDownloader/VideoDownloader.swift
        Sources/Lattice/Services/VideoDownloader/VideoWebsiteSessions.swift
        Sources/Lattice/Services/VideoDownloader/VideoDownloaderWebsiteSessions.swift
        Sources/Lattice/UI/Notch/VideoDownloaderSearchBar.swift
        Sources/Lattice/Services/VideoDownloader/VideoDownloadInfo.swift
        Sources/Lattice/Services/VideoDownloader/VideoDownloadProgressTracker.swift
        Sources/Lattice/Services/VideoDownloader/VideoDownloaderInspection.swift
        Sources/Lattice/Services/VideoDownloader/VideoDownloaderDownload.swift
        Sources/Lattice/Services/VideoDownloader/VideoDownloaderJob.swift
        Sources/Lattice/Core/QuitProtectionSupport.swift
        Sources/Lattice/Core/QuitProtectionStrings.swift
        Sources/Lattice/Core/LiquidGlassSupport.swift
        Sources/Lattice/Core/ShortcutConflictAlert.swift
        Sources/Lattice/Core/Defaults.swift
        Sources/Lattice/Core/LauncherShortcutTarget.swift
        Sources/Lattice/Core/PermanentInputMigration.swift
        Sources/Lattice/Core/PageOwnedControlsMigration.swift
        Sources/Lattice/Core/AudioControlsMigration.swift
        Sources/Lattice/UI/Settings/SettingsHostingController.swift
        Sources/Lattice/Core/PermissionRowActionPolicy.swift
        Sources/Lattice/Core/DataPermissionsPageCopy.swift
        Sources/Lattice/UI/Settings/DataPermissionsStyle.swift
        Sources/Lattice/UI/Settings/DataPermissionsRow.swift
        Sources/Lattice/UI/Settings/SettingsExpansionAnimation.swift
        Sources/Lattice/Core/WindowLayoutShortcutEditor.swift
        Sources/Lattice/Core/NotchStrings.swift
        Sources/Lattice/Core/NotchEditorStrings.swift
        Sources/Lattice/Core/NotchWidgetTitleSupport.swift
        Sources/Lattice/Core/NotchLiveActivitySettingsStrings.swift
        Sources/Lattice/Core/NotchOpeningStrings.swift
        Sources/Lattice/Services/Notch/NotchDelayPreset.swift
        Sources/Lattice/UI/Settings/NotchSettingsTabRow.swift
        Sources/Lattice/Core/NotchActivityStrings.swift
        Sources/Lattice/Services/Notch/NotchSizePreferences.swift
        Sources/Lattice/Services/Notch/NotchToolRailLayout.swift
        Sources/Lattice/Services/Notch/NotchTimerSupport.swift
        Sources/Lattice/Services/Notch/NotchPomodoroDecoding.swift
        Sources/Lattice/Services/Notch/NotchTimerAlert.swift
        Sources/Lattice/Services/Notch/NotchTimerToneData.swift
        Sources/Lattice/Services/Notch/NotchTimerCache.swift
        Sources/Lattice/UI/Notch/NotchIslandAlert.swift
        Sources/Lattice/Services/Notch/NotchAccessorySupport.swift
        Sources/Lattice/Services/QuickTools/CameraPreviewSupport.swift
        Sources/Lattice/Core/NotchMusicExtrasStrings.swift
        Sources/Lattice/Core/NotchClipboardSizeStrings.swift
        Sources/Lattice/Services/Notch/NotchLyricsSupport.swift
        Sources/Lattice/Services/Notch/NotchQueueSupport.swift
        Sources/Lattice/Services/Notch/NotchPreferredPlayer.swift
        Sources/Lattice/Core/NotchFilesStrings.swift
        Sources/Lattice/Core/NotchWatchStrings.swift
        Sources/Lattice/Services/Notch/NotchWatchSupport.swift
        Sources/Lattice/Core/NotchMascotStrings.swift
        Sources/Lattice/Services/Notch/NotchMascotSupport.swift
        Sources/Lattice/Services/CommandBar/CommandBarDropletMotion.swift
        Sources/Lattice/Services/Notch/NotchFileToolsSupport.swift
        Sources/Lattice/Services/Notch/NotchDownloadSupport.swift
        Sources/Lattice/Services/Notch/NotchDownloadProgressObserver.swift
        Sources/Lattice/Core/NotchCalendarStrings.swift
        Sources/Lattice/Core/NotchNotificationStrings.swift
        Sources/Lattice/Core/NotchGestureStrings.swift
        Sources/Lattice/Core/NotchAgentStrings.swift
        Sources/Lattice/Core/CodexAccountStrings.swift
        Sources/Lattice/Services/Notch/NotchAgentSupport.swift
        Sources/Lattice/Core/NotchLockScreenStrings.swift
        Sources/Lattice/Services/Notch/NotchLockScreenSupport.swift
        Sources/Lattice/Services/LockSoundService.swift
        Sources/Lattice/Services/PadlockSound.swift
        Sources/Lattice/Services/QuickTools/VisionTextRecognition.swift
        Sources/Lattice/Core/OCRRecoveryCopy.swift
        Sources/Lattice/Services/QuickTools/TextRecognitionRecovery.swift
        Sources/Lattice/Services/Notch/NotchMusicMouseSwipeController.swift
        Sources/Lattice/Services/Notch/NotchMusicMouseSwipe.swift
        Sources/Lattice/Core/DockClickMode.swift
        Sources/Lattice/Core/DockClickStrings.swift
        Sources/Lattice/Core/SettingsFollowupLabels.swift
        Sources/Lattice/Core/GeneralSoundCopy.swift
        Sources/Lattice/Services/AgentUsage/AgentUsageModels.swift
        Sources/Lattice/Services/AgentUsage/AgentPricing.swift
        Sources/Lattice/Services/AgentUsage/AgentLogObject.swift
        Sources/Lattice/Services/AgentUsage/AgentLogParser.swift
        Sources/Lattice/Services/AgentUsage/Harness/AgentHarnessReader.swift
        Sources/Lattice/Services/AgentUsage/Harness/ClaudeReader.swift
        Sources/Lattice/Services/AgentUsage/Harness/CodexReader.swift
        Sources/Lattice/Services/AgentUsage/Harness/OpenCodeReader.swift
        Sources/Lattice/Services/AgentUsage/Harness/CopilotReader.swift
        Sources/Lattice/Services/AgentUsage/AgentUsageSummary.swift
        Sources/Lattice/Services/AgentUsage/AgentUsageStore.swift
        Sources/Lattice/Services/AgentUsage/AgentUsageArchive.swift
        Sources/Lattice/Services/AgentUsage/AgentClaudeAppUsage.swift
        Sources/Lattice/Services/AgentUsage/AgentCLIConversation.swift
        Sources/Lattice/Services/AgentUsage/AgentClaudeServer.swift
        Sources/Lattice/Services/AgentUsage/AgentCodexServer.swift
        Sources/Lattice/Services/AgentUsage/CodexAccountLimits.swift
        Sources/Lattice/Services/AgentUsage/CodexProfileLimitsService.swift
        Sources/Lattice/Services/AgentUsage/AgentOpenCodeReader.swift
        Sources/Lattice/Services/Notch/NotchMusicNoticeLayout.swift
        Sources/Lattice/Services/Notch/NotchMusicSwipeState.swift
        Sources/Lattice/Services/Notch/NotchMusicSwipeHaptics.swift
        Sources/Lattice/Services/Notch/NotchMusicSwipeController.swift
        Sources/Lattice/Services/Notch/NotchMusicTrackSwipe.swift
        Sources/Lattice/Services/Notch/NotchGestureSupport.swift
        Sources/Lattice/Services/Notch/NotchCaptureTrackpadGesture.swift
        Sources/Lattice/Services/Notch/NotchSectionPaging.swift
        Sources/Lattice/Services/Notch/NotchSliderEditing.swift
        Sources/Lattice/Services/Notch/NotchNotificationSupport.swift
        Sources/Lattice/Services/Notch/NotchNotificationReaderCore.swift
        Sources/Lattice/Services/Notch/NotchCalendarSupport.swift
        Sources/Lattice/Services/Notch/NotchKeepAwakeSupport.swift
        Sources/Lattice/Services/Notch/NotchSupport.swift
        Sources/Lattice/Services/Notch/NotchCaptureRouting.swift
        Sources/Lattice/Services/Notch/NotchAudioLevelSupport.swift
        Sources/Lattice/Services/Notch/NotchVolumeKeyGate.swift
        Sources/Lattice/Services/Notch/NotchMusicSupport.swift
        Sources/Lattice/UI/Notch/NotchDecorativeClock.swift
        Sources/Lattice/Services/Notch/NotchBrowserArtworkSupport.swift
        Sources/Lattice/UI/Notch/NotchEqualizerBars.swift
        Sources/Lattice/UI/Notch/NotchScrollEdgeFade.swift
        Sources/Lattice/UI/Notch/NotchAgentAnimationView.swift
        Sources/Lattice/UI/WindowVisibilityReader.swift
        Sources/Lattice/Services/Notch/NotchMusicAutomationSupport.swift
        Sources/Lattice/Services/Notch/NotchMusicAutomation.swift
        Sources/Lattice/Services/Notch/NotchPlaybackSource.swift
        Sources/Lattice/Services/Notch/NotchPlaybackCommand.swift
        Sources/Lattice/Services/Notch/NotchMusicCommandWriter.swift
        Sources/Lattice/Core/FeatureCatalog.swift
        Sources/Lattice/Core/FeatureInstallationPolicy.swift
        Sources/Lattice/Core/IslandDestinationSupport.swift
        Sources/Lattice/Core/SettingsOwnershipStrings.swift
        Sources/Lattice/Core/FeatureEnergyProfile.swift
        Sources/Lattice/Core/FeatureHubStrings.swift
        Sources/Lattice/Core/ShortcutSettingsStrings.swift
        Sources/Lattice/Core/SettingsBackupSupport.swift
        Sources/Lattice/Core/SettingsBackupSupport+MouseExceptions.swift
        Sources/Lattice/Core/BackupStrings.swift
        Sources/Lattice/Core/DataPermissionsStrings.swift
        Sources/Lattice/Core/SnippetStrings.swift
        Sources/Lattice/Core/AlertSoundStrings.swift
        Sources/Lattice/Core/BrightnessStrings.swift
        Sources/Lattice/Core/MediaImageStrings.swift
        Sources/Lattice/Core/QuickToggleStrings.swift
        Sources/Lattice/Core/CaptureWorkflowStrings.swift
        Sources/Lattice/Core/ScreenshotStrings.swift
        Sources/Lattice/Core/RecentCaptureStrings.swift
        Sources/Lattice/Core/RecorderStrings.swift
        Sources/Lattice/Core/RecorderShareStrings.swift
        Sources/Lattice/Core/CameraPreviewStrings.swift
        Sources/Lattice/Core/WallpaperStrings.swift
        Sources/Lattice/Services/Wallpaper/WallpaperSupport.swift
        Sources/Lattice/Core/ScratchpadStrings.swift
        Sources/Lattice/Core/CommandBarStrings.swift
        Sources/Lattice/Core/FeedbackStrings.swift
        Sources/Lattice/Core/FeedbackDraftStrings.swift
        Sources/Lattice/Core/PermissionActivationSupport.swift
        Sources/Lattice/Core/PermissionRevocationPolicy.swift
        Sources/Lattice/Core/PermissionRevocationTracker.swift
        Sources/Lattice/Core/BrightnessKeyStepActivation.swift
        Sources/Lattice/Core/PermissionPreflight.swift
        Sources/Lattice/Core/BluetoothPermissionAccess.swift
        Sources/Lattice/Core/SettingsFollowupStrings.swift
        Sources/Lattice/Core/AppMenuDestination.swift
        Sources/Lattice/Core/AppMenuReopenCoordinator.swift
        Sources/Lattice/Core/PermissionResetState.swift
        Sources/Lattice/UI/Settings/ShortcutSettingsObserver.swift
        Sources/Lattice/Core/RadialMenuStrings.swift
        Sources/Lattice/Core/MenuBarAppearanceStrings.swift
        Sources/Lattice/Core/AppAppearance.swift
        Sources/Lattice/Core/AppearanceStrings.swift
        Sources/Lattice/Core/GeneralSettingsStrings.swift
        Sources/Lattice/Core/SettingsPageStrings.swift
        Sources/Lattice/Core/BatteryTimeStrings.swift
        Sources/Lattice/Core/CPUCoreStrings.swift
        Sources/Lattice/Core/MonitorLayoutStrings.swift
        Sources/Lattice/Core/KeepAwakeStrings.swift
        Sources/Lattice/Core/BluetoothSleepStrings.swift
        Sources/Lattice/Core/PermissionGuideStrings.swift
        Sources/Lattice/Core/FanControlStrings.swift
        Sources/Lattice/Core/ConnectedDevicesStrings.swift
        Sources/Lattice/Services/FanControl/FanControlSupport.swift
        Sources/Lattice/Services/FanControl/FanControlResumeSupport.swift
        Sources/Lattice/Services/Snippets/TextSnippetSupport.swift
        Sources/Lattice/Services/RadialMenu/RadialMenuSupport.swift
        Sources/Lattice/Services/RadialMenu/RadialProfileActivation.swift
        Sources/Lattice/Services/QuickTools/ScratchpadSupport.swift
        Sources/Lattice/Services/QuickTools/ScratchpadStore.swift
        Sources/Lattice/Services/KillProcess/KillProcessSupport.swift
        Sources/Lattice/Services/Recorder/RecorderSupport.swift
        Sources/Lattice/Services/Recorder/RecorderSampleTiming.swift
        Sources/Lattice/Services/Recorder/RecorderWriter.swift
        Sources/Lattice/Services/Recorder/RecorderCaptureEngine.swift
        Sources/Lattice/Core/RecorderExportStrings.swift
        Sources/Lattice/Services/Recorder/RecorderComposer.swift
        Sources/Lattice/Services/Recorder/RecorderComposerPlan.swift
        Sources/Lattice/Services/Recorder/RecorderCursorSprite.swift
        Sources/Lattice/Services/Recorder/RecorderTextRenderer.swift
        Sources/Lattice/Services/Recorder/RecorderImageRenderer.swift
        Sources/Lattice/Services/Recorder/RecorderExporter.swift
        Sources/Lattice/Services/Recorder/RecorderGIFClipboard.swift
        Sources/Lattice/Services/Recorder/RecorderGIFWriter.swift
        Sources/Lattice/Services/Recorder/RecorderGIFWorkspace.swift
        Sources/Lattice/Services/Recorder/RecorderComposition.swift
        Sources/Lattice/Services/Recorder/RecordingSharingSupport.swift
        Sources/Lattice/Services/PrivateFileStore.swift
        Sources/Lattice/Services/Recorder/RecorderTakeStore.swift
        Sources/Lattice/Services/Recorder/RecorderPresetImageStore.swift
        Sources/Lattice/Services/Recorder/RecorderMotion.swift
        Sources/Lattice/Services/Recorder/RecorderPointerTrack.swift
        Sources/Lattice/Services/Recorder/RecorderTypingTrack.swift
        Sources/Lattice/Services/Recorder/RecorderCameraLayout.swift
        Sources/Lattice/Core/RecorderOverlayStrings.swift
        Sources/Lattice/Services/Recorder/RecorderSelectionDraft.swift
        Sources/Lattice/Services/Recorder/RecorderSelectionAudioOptions.swift
        Sources/Lattice/Services/Recorder/RecorderOverlayCompositor.swift
        Sources/Lattice/Services/Recorder/RecorderCameraCapture.swift
        Sources/Lattice/Services/Recorder/RecorderNativeCameraSource.swift
        Sources/Lattice/Services/Recorder/RecorderKeystrokeOverlay.swift
        Sources/Lattice/Services/Recorder/RecorderOverlayController.swift
        Sources/Lattice/Services/Recorder/RecorderCameraOverlayView.swift
        Sources/Lattice/Services/Recorder/RecorderIndicator.swift
        Sources/Lattice/UI/Recorder/RecorderCaptureInputControls.swift
        Sources/Lattice/UI/Recorder/RecorderWaitingControls.swift
        Sources/Lattice/Services/Recorder/RecorderTimeline.swift
        Sources/Lattice/Services/Recorder/RecorderTextOverlay.swift
        Sources/Lattice/Services/Recorder/RecorderImageOverlay.swift
        Sources/Lattice/Services/Recorder/RecorderBlurRegion.swift
        Sources/Lattice/Services/Recorder/RecorderEditDocument.swift
        Sources/Lattice/Core/AppInfo.swift
        Sources/Lattice/Core/DownstreamIdentity.swift
        Sources/Lattice/Core/GlobalShortcut.swift
        Sources/Lattice/Core/SymbolicHotKeys.swift
        Sources/Lattice/Services/SystemShortcutTakeoverSupport.swift
        Sources/Lattice/Core/Localization.swift
        Sources/Lattice/Core/Localizations/Strings+*.swift
        Sources/Lattice/Core/FeatureStrings.swift
        Sources/Lattice/Core/KillProcessStrings.swift
        Sources/Lattice/Core/PortManagerStrings.swift
        Sources/Lattice/Core/ReleaseNotes.swift
        Sources/Lattice/Core/ReleaseDigest.swift
        Sources/Lattice/Core/ReleaseChangeAliases.swift
        Sources/Lattice/Core/WhatsNewStrings.swift
        Sources/Lattice/Core/URLCleaning.swift
        Sources/Lattice/Services/GeneralPasteboardAccess.swift
        Sources/Lattice/Services/Clipboard/ClipboardHistoryWrite.swift
        Sources/Lattice/Services/Audio/AirPlayRouteManager.swift
        Sources/Lattice/Services/Audio/MixerRoutingSupport.swift
        Sources/Lattice/Services/Audio/AudioPriorityPresentation.swift
        Sources/Lattice/Services/Feedback/FeedbackDraft.swift
        Sources/Lattice/UI/Feedback/FeedbackWindowPresentation.swift
        Sources/Lattice/Services/Audio/MusicLaunchSupport.swift
        Sources/Lattice/Services/Bluetooth/BluetoothSleepSupport.swift
        Sources/Lattice/UI/MenuPanel/MixerPercentNativeTextField.swift
        Sources/Lattice/UI/MenuPanel/MixerAppDragSource.swift
        Sources/Lattice/Services/Audio/BoostLimiter.swift
        Sources/Lattice/Services/Audio/MixerRender.swift
        Sources/Lattice/Services/Audio/PreciseVolumeRollerSupport.swift
        Sources/Lattice/Services/DockPreview/DockPreviewSupport.swift
        Sources/Lattice/Services/DockPreview/DockPreviewExclusions.swift
        Sources/Lattice/Core/SettingsAppListDescriptions.swift
        Sources/Lattice/Core/SettingsAppListStrings.swift
        Sources/Lattice/UI/Settings/QuitProtectionAppListStrings.swift
        Sources/Lattice/Services/DockPreview/DockAutohideHold.swift
        Sources/Lattice/Services/SpacesOrder/SpacesOrderHold.swift
        Sources/Lattice/Services/Homebrew/HomebrewSupport.swift
        Sources/Lattice/Services/Homebrew/HomebrewEnvironment.swift
        Sources/Lattice/Services/AppUpdates/AppUpdatesSupport.swift
        Sources/Lattice/Services/AppUpdates/AppUpdateFeedSupport.swift
        Sources/Lattice/Core/AppUpdateStrings.swift
        Sources/Lattice/Core/DiskImageInstallerStrings.swift
        Sources/Lattice/Services/DiskImageInstaller/DiskImageInstallerSupport.swift
        Sources/Lattice/UI/NonModalAlert.swift
        Sources/Lattice/Services/Clipboard/ClipboardHistorySupport.swift
        Sources/Lattice/Core/ColorValue.swift
        Sources/Lattice/Services/Clipboard/ClipboardAutoClearSupport.swift
        Sources/Lattice/Services/AutoQuit/AutoQuitSupport.swift
        Sources/Lattice/Services/Shelf/ShelfSupport.swift
        Sources/Lattice/Services/Shelf/ShelfFilePromiseTransfer.swift
        Sources/Lattice/Core/ShelfPromiseDeliveryStrings.swift
        Sources/Lattice/Services/Update/UpdateInstallerSupport.swift
        Sources/Lattice/Services/Update/UpdateServiceSupport.swift
        Sources/Lattice/Services/Update/UpdateCheckResponse.swift
        Sources/Lattice/Core/UpdateSettingsPresentation.swift
        Sources/Lattice/Core/UpdateSettingsStrings.swift
        Sources/Lattice/Services/InstalledApps.swift
        Sources/Lattice/Services/LaunchAtLoginSupport.swift
        Sources/Lattice/UI/Settings/SettingsSearchSupport.swift
        Sources/Lattice/UI/Settings/SettingsSidebarSupport.swift
        Sources/Lattice/UI/Settings/FeatureVisibilitySupport.swift
        Sources/Lattice/UI/Onboarding/WhatsNewSupport.swift
        Sources/Lattice/UI/Settings/SettingsWindow.swift
        Sources/Lattice/UI/Settings/SettingsDetailViewport.swift
        Sources/Lattice/UI/Settings/ReleaseNotesSettings.swift
        Sources/Lattice/UI/Settings/UpdateSettingsStatusRow.swift
        Sources/Lattice/UI/PermissionDetailsSheet.swift
        Sources/Lattice/Core/SettingsNavigationStrings.swift
        Sources/Lattice/App/MenuBarSpacingSupport.swift
        Sources/Lattice/App/MenuBarAllowanceSupport.swift
        Sources/Lattice/App/ReopenRequestSupport.swift
        Sources/Lattice/App/StatusItemAnchorSupport.swift
        Sources/Lattice/Services/DockClick/DockClickSupport.swift
        Sources/Lattice/Services/MiddleClick/MiddleClickSupport.swift
        Sources/Lattice/Services/MouseNavigation/MouseNavigationSupport.swift
        Sources/Lattice/Services/MouseNavigation/MouseNavigationKeys.swift
        Sources/Lattice/Services/MouseButtons/MouseButtonShortcutSupport.swift
        Sources/Lattice/Services/MouseButtons/MouseSpacesGestureSupport.swift
        Sources/Lattice/Services/MouseClickDebounce/MouseClickDebounceSupport.swift
        Sources/Lattice/Services/MouseExceptions/MouseAppExceptionSupport.swift
        Sources/Lattice/Services/MouseExceptions/MouseAppExceptions.swift
        Sources/Lattice/Services/MouseButtons/MouseShortcutExceptions.swift
        Sources/Lattice/Services/WindowServerSupport.swift
        Sources/Lattice/Services/WindowMaximizerSupport.swift
        Sources/Lattice/Core/MouseButtonStrings.swift
        Sources/Lattice/Core/MouseClickDebounceStrings.swift
        Sources/Lattice/Core/MouseExceptionStrings.swift
        Sources/Lattice/Core/ClipboardIgnoredAppsStrings.swift
        Sources/Lattice/Core/ClipboardRetentionStrings.swift
        Sources/Lattice/Core/DiskExclusionStrings.swift
        Sources/Lattice/Core/WindowLayoutIgnoredAppsStrings.swift
        Sources/Lattice/Services/WindowLayout/WindowLayoutIgnoredApps.swift
        Sources/Lattice/Core/WindowPreviewExclusionStrings.swift
        Sources/Lattice/Core/WindowMaximizerExclusionStrings.swift
        Sources/Lattice/Core/SwitcherAppRulesStrings.swift
        Sources/Lattice/Services/QuickTools/QuickToolsSupport.swift
        Sources/Lattice/Services/CommandBar/CommandBarSupport.swift
        Sources/Lattice/Services/CommandBar/CommandBarPreferences.swift
        Sources/Lattice/Services/CommandBar/CommandBarMath.swift
        Sources/Lattice/Services/CommandBar/CommandBarUnits.swift
        Sources/Lattice/Services/CommandBar/CommandBarColors.swift
        Sources/Lattice/Services/CommandBar/CommandBarEmoji.swift
        Sources/Lattice/Services/CommandBar/CommandBarLinks.swift
        Sources/Lattice/Services/CommandBar/CommandBarDates.swift
        Sources/Lattice/Services/CommandBar/CommandBarRowShortcuts.swift
        Sources/Lattice/Services/CommandBar/CommandBarSystemSettingsSupport.swift
        Sources/Lattice/Services/CommandBar/CommandBarFileSearchSupport.swift
        Sources/Lattice/Services/CommandBar/CommandBarQueryMemory.swift
        Sources/Lattice/Services/SpotlightNamesSupport.swift
        Sources/Lattice/Services/QuickTools/MicMuteSupport.swift
        Sources/Lattice/Services/QuickTools/QuickTogglesSupport.swift
        Sources/Lattice/Services/QuickTools/ScreenshotCapturePolicy.swift
        Sources/Lattice/Services/QuickTools/CapturePresentationPolicy.swift
        Sources/Lattice/Services/QuickTools/ScreenshotDialogGeometry.swift
        Sources/Lattice/App/MediaEditorFileSupport.swift
        Sources/Lattice/Core/MediaEditorFileStrings.swift
        Sources/Lattice/Services/QuickTools/ScreenshotCapturePanel.swift
        Sources/Lattice/Services/QuickTools/ScreenshotCaptureFocusSession.swift
        Sources/Lattice/Services/QuickTools/ScreenshotMultiWindowShiftMonitor.swift
        Sources/Lattice/Services/QuickTools/CapturePresentationDeferral.swift
        Sources/Lattice/Services/QuickTools/ScreenshotSupport.swift
        Sources/Lattice/Services/QuickTools/ScreenshotWindowFallback.swift
        Sources/Lattice/Services/QuickTools/ScreenshotEditorGeometry.swift
        Sources/Lattice/Services/QuickTools/ScreenshotCropAspect.swift
        Sources/Lattice/Core/ScreenshotEditorRefinementStrings.swift
        Sources/Lattice/Core/ScreenshotWatermarkDraft.swift
        Sources/Lattice/Services/QuickTools/ScreenshotPinPinchTracker.swift
        Sources/Lattice/Services/QuickTools/ScreenshotPinGestureView.swift
        Sources/Lattice/Services/QuickTools/ScreenshotPinFeedbackView.swift
        Sources/Lattice/Services/QuickTools/ScreenshotPinWindow.swift
        Sources/Lattice/Services/QuickTools/ScreenshotQuickLookController.swift
        Sources/Lattice/Services/QuickTools/ScreenshotWindowLayering.swift
        Sources/Lattice/Services/QuickTools/ScreenshotPreviewImageActions.swift
        Sources/Lattice/UI/Screenshot/ScreenshotPreviewContextMenu.swift
        Sources/Lattice/UI/Screenshot/ScreenshotEditorControlFeedback.swift
        Sources/Lattice/UI/Screenshot/ScreenshotFontSizeControl.swift
        Sources/Lattice/UI/Screenshot/ScreenshotFontSizePalette.swift
        Sources/Lattice/UI/Screenshot/ScreenshotCanvasInput.swift
        Sources/Lattice/UI/Screenshot/ScreenshotFontSizeSlider.swift
        Sources/Lattice/UI/Screenshot/ScreenshotFontSizeField.swift
        Sources/Lattice/UI/Screenshot/ScreenshotSelectionChrome.swift
        Sources/Lattice/Services/QuickTools/ScreenshotPinContentView.swift
        Sources/Lattice/Services/QuickTools/ScreenshotPinChrome.swift
        Sources/Lattice/Services/QuickTools/ScreenshotPinFilePromise.swift
        Sources/Lattice/Services/QuickTools/ScreenshotPinDragView.swift
        Sources/Lattice/Core/ScreenshotPinPreferences.swift
        Sources/Lattice/Core/ScreenshotPinStrings.swift
        Sources/Lattice/UI/Settings/MonitorToken.swift
        Sources/Lattice/Services/QuickTools/ScreenshotRenderer.swift
        Sources/Lattice/UI/Screenshot/ScreenshotEditorResizeCursor.swift
        Sources/Lattice/Services/QuickTools/RecentCaptureRetention.swift
        Sources/Lattice/Services/QuickTools/RecentCaptureStore.swift
        Sources/Lattice/Services/QuickTools/RecentCaptureEditableImage.swift
        Sources/Lattice/Services/Recorder/RecorderFileCopy.swift
        Sources/Lattice/Services/Recorder/RecorderQuickPreviewModel.swift
        Sources/Lattice/Services/Recorder/RecorderPreviewShortcut.swift
        Sources/Lattice/Services/QuickTools/ScreenshotSharingSupport.swift
        Sources/Lattice/Services/QuickTools/WindowActivationPolicy.swift
        Sources/Lattice/Services/KeyboardDebounce/KeyboardDebounceSupport.swift
        Sources/Lattice/Services/KeyboardDebounce/KeyboardDebounceOverrides.swift
        Sources/Lattice/Services/SuperKey/SuperKeySupport.swift
        Sources/Lattice/Services/SuperKey/SuperKeyMappingGuard.swift
        Sources/Lattice/Core/SuperKeyStrings.swift
        Sources/Lattice/Core/InputSourceSelection.swift
        Sources/Lattice/Services/SessionActivity.swift
        Sources/Lattice/Services/SessionActivitySupport.swift
        Sources/Lattice/Services/EventTimestamp.swift
        Sources/Lattice/Services/OwnKeyEvent.swift
        Sources/Lattice/Services/ScrollWheelSupport.swift
        Sources/Lattice/Services/HorizontalWheelScrolling.swift
        Sources/Lattice/Services/SmoothScrollSupport.swift
        Sources/Lattice/Services/MouseAcceleration/MouseAccelerationSupport.swift
        Sources/Lattice/Services/FocusFollowsMouse/FocusFollowsMouseSupport.swift
        Sources/Lattice/Services/AssistiveKeyboard.swift
        Sources/Lattice/Services/Switcher/SwitcherModels.swift
        Sources/Lattice/Services/Switcher/WindowServerCaptureQueue.swift
        Sources/Lattice/Services/Switcher/SwitcherSupport.swift
        Sources/Lattice/Services/Switcher/SpaceHopSupport.swift
        Sources/Lattice/Services/Switcher/WindowUseOrder.swift
        Sources/Lattice/Services/Metrics/MetricFormat.swift
        Sources/Lattice/Services/Metrics/VMStatisticsDecoder.swift
        Sources/Lattice/Services/KeepAwakeAutomationSupport.swift
        Sources/Lattice/Services/SudoersSupport.swift
        Sources/Lattice/Services/Metrics/BatteryTimeSupport.swift
        Sources/Lattice/Services/Metrics/BatteryPowerSupport.swift
        Sources/Lattice/Services/BoundedProcessRunner.swift
        Sources/Lattice/Services/DetachedProcess.swift
        Sources/Lattice/Services/ShellSupport.swift
        Sources/Lattice/Services/PortManager/PortManagerSupport.swift
        Sources/Lattice/Services/Metrics/NetworkProcessSupport.swift
        Sources/Lattice/Services/Metrics/NetworkSampler.swift
        Sources/Lattice/Services/Metrics/NetworkAddressService.swift
        Sources/Lattice/Services/Metrics/SpeedTest.swift
        Sources/Lattice/Services/Metrics/PeripheralBatterySampler.swift
        Sources/Lattice/Services/Metrics/BluetoothBatteryRead.swift
        Sources/Lattice/Services/Metrics/PeripheralBatterySupport.swift
        Sources/Lattice/Services/Metrics/DiskSupport.swift
        Sources/Lattice/Services/Metrics/MonitorSamplingPolicy.swift
        Sources/Lattice/Services/Metrics/USBDeviceSampler.swift
        Sources/Lattice/Services/Metrics/CPUCoreSampler.swift
        Sources/Lattice/Services/Metrics/MaxCapacityProbe.swift
        Sources/Lattice/Services/Metrics/TemperatureSensorSelector.swift
        Sources/Lattice/Services/Metrics/SustainedAlertGate.swift
        Sources/Lattice/Services/WindowLayout/WindowLayoutSupport.swift
        Sources/Lattice/Services/WindowLayout/WindowGestureSupport.swift
        Sources/Lattice/Core/WindowDirectionalStrings.swift
        Sources/Lattice/Core/PointerDisplayStrings.swift
        Sources/Lattice/Core/GraphScaleStrings.swift
        Sources/Lattice/Core/NotchLowBatteryStrings.swift
        Sources/Lattice/Services/CleaningMode/CleaningUnlockCounter.swift
        Sources/Lattice/Services/CleaningMode/CleaningMouseReleaseGate.swift
        Sources/Lattice/Services/Display/ExtraBrightnessSupport.swift
        Sources/Lattice/Services/Display/BrightnessSupport.swift
        Sources/Lattice/Services/Display/LidDimmingSupport.swift
        Sources/Lattice/Services/Cleaner/CleanerSupport.swift
        Sources/Lattice/Services/Cleaner/CleanerPolicy.swift
        Sources/Lattice/Services/Cleaner/CleanerOwnership.swift
        Sources/Lattice/Services/Cleaner/CleanerScanPrivacy.swift
        Sources/Lattice/Services/Cleaner/CleanerSchedule.swift
        Sources/Lattice/Services/Uninstall/UninstallerSupport.swift
        Sources/Lattice/Core/SecureInputSupport.swift
        Tests/*.swift
        build/generated-tests/*.swift
    )
    TEST_OUTPUT_FILE_MAP="$TEST_OBJECT_DIR/output-file-map.json"
    write_swift_output_file_map "$TEST_OUTPUT_FILE_MAP" "$TEST_OBJECT_DIR" "${TEST_SOURCES[@]}"
    echo "▸ Building & running tests against $(basename "$SDK")…"
    swiftc -Onone -incremental -enable-batch-mode -j "$(sysctl -n hw.logicalcpu)" \
        -module-name LatticeTests -output-file-map "$TEST_OUTPUT_FILE_MAP" \
        -target "$TARGET" -sdk "$SDK" "${SDK_COMPAT_FLAGS[@]}" \
        "${VM_STATISTICS_COMPAT_FLAGS[@]}" "${TEST_SOURCES[@]}" -o build/metrics-tests
    test_status=0
    ./build/metrics-tests "${TEST_ARGS[@]}" || test_status=$?
    if (( ${#TEST_ARGS} == 0 )); then
        ./Tests/PreferenceCleanupTests.sh || test_status=1
        ./Tests/UninstallSpacesTests.sh || test_status=1
        ./Tests/DeveloperInstallIsolationTests.sh || test_status=1
    fi
    discard_test_preferences || test_status=1
    exit $test_status
fi

echo "▸ Compiling ($BUILD_CONFIGURATION) against $(basename "$SDK")…"
APP_SOURCES=(Sources/Lattice/**/*.swift)
if (( ! DEV )); then
    # A release starts from an empty build directory, so nothing an earlier
    # build left behind (an old icon catalog, a staged bundle) can reach it.
    # Only the compiler's incremental records stay: they rebuild whatever
    # changed since, and a fresh checkout has none.
    find build -mindepth 1 -maxdepth 1 ! -name objects -exec rm -rf {} + 2>/dev/null || true
fi
APP_OBJECT_DIR="build/objects/$EXECUTABLE"
mkdir -p build "$APP_OBJECT_DIR"
APP_OUTPUT_FILE_MAP="$APP_OBJECT_DIR/output-file-map.json"
write_swift_output_file_map "$APP_OUTPUT_FILE_MAP" "$APP_OBJECT_DIR" "${APP_SOURCES[@]}"
# Without -j the driver compiles one file at a time, and without batch mode
# each file's compiler parses the whole module again: a clean release took a
# quarter of an hour. Batches share that work and run on every core, and the
# optimization stays per file, as before.
swiftc "${APP_OPTIMIZATION_FLAGS[@]}" -incremental -enable-batch-mode -j "$(sysctl -n hw.logicalcpu)" \
    -output-file-map "$APP_OUTPUT_FILE_MAP" \
    -target "$TARGET" -sdk "$SDK" "${SDK_COMPAT_FLAGS[@]}" "${VM_STATISTICS_COMPAT_FLAGS[@]}" "${HID_EVENT_SYSTEM_FLAGS[@]}" \
    "${BUILD_VARIANT_FLAGS[@]}" \
    "${APP_SOURCES[@]}" -o "build/$EXECUTABLE"

echo "▸ Compiling protected fan helper…"
swiftc -O -target "$TARGET" -sdk "$SDK" "${SDK_COMPAT_FLAGS[@]}" "${BUILD_VARIANT_FLAGS[@]}" \
    Sources/Lattice/Core/DownstreamIdentity.swift \
    Sources/Lattice/Services/FanControl/FanControlSupport.swift \
    Sources/Lattice/Services/FanControl/FanControlXPC.swift \
    Sources/Lattice/Services/SystemMonitor/SMCClient.swift \
    Sources/Lattice/Services/Metrics/TemperatureSensorSelector.swift \
    Sources/Lattice/Services/FanControl/FanControlHardware.swift \
    Sources/FanControlHelper/main.swift \
    -o "build/$FAN_HELPER_ID"
"build/$FAN_HELPER_ID" --selftest

echo "▸ Compiling Now Playing adapter…"
swiftc -O -target "$TARGET" -sdk "$SDK" "${SDK_COMPAT_FLAGS[@]}" -emit-library \
    -module-name LatticeNowPlaying \
    Sources/NowPlayingAdapter/NowPlayingAdapter.swift \
    Sources/NowPlayingAdapter/NowPlayingQueue.swift \
    Sources/NowPlayingAdapter/NowPlayingSelection.swift \
    Sources/Lattice/Services/Notch/NotchPlaybackSource.swift \
    Sources/Lattice/Services/Notch/NotchPlaybackCommand.swift \
    -o "build/$NOW_PLAYING_ADAPTER"

echo "▸ Generating app icon…"
ICON_FLAGS=()
(( DEV )) && ICON_FLAGS+=(--dev)
swift Tools/MakeLatticeIcon.swift build "${ICON_FLAGS[@]}"
xattr -c -r build/AppIcon.icns build/MenuBarIcon.png build/MenuBarIcon@2x.png build/BrandMark.png 2>/dev/null || true
ACTOOL_BIN="$(xcrun --find actool 2>/dev/null || true)"
ICON_TMP="$(mktemp -d)"
ADAPTIVE_SKIP=""
ICON_SOURCE="Resources/Brand/Lattice.icon"
if [[ -z "$ACTOOL_BIN" ]]; then
    ADAPTIVE_SKIP="actool not found (adaptive icons need Xcode 26+)"
else
    echo "▸ Compiling adaptive icon catalog…"
    # actool crashes on File Provider-synced paths, so compile a local copy.
    ditto "$ICON_SOURCE" "$ICON_TMP/AppIcon.icon"
    # Xcode 27 beta actool requires the --compile target directory to already exist.
    mkdir -p "$ICON_TMP/catalog"
    if "$ACTOOL_BIN" "$ICON_TMP/AppIcon.icon" \
            --compile "$ICON_TMP/catalog" \
            --app-icon AppIcon \
            --platform macosx \
            --target-device mac \
            --minimum-deployment-target 14.0 \
            --enable-on-demand-resources NO \
            --output-partial-info-plist "$ICON_TMP/partial-info.plist" \
            >"$ICON_TMP/actool.log" 2>&1 && [[ -s "$ICON_TMP/catalog/Assets.car" && -s "$ICON_TMP/catalog/AppIcon.icns" ]]; then
        mv "$ICON_TMP/catalog/Assets.car" build/Assets.car
        cp "$ICON_TMP/catalog/AppIcon.icns" build/AppIcon.icns
    else
        ADAPTIVE_SKIP="actool could not compile the catalog"
    fi
fi
if [[ -n "$ADAPTIVE_SKIP" ]]; then
    # Never package a stale catalog that disagrees with the current fallback.
    rm -f build/Assets.car
    cp "$ICON_TMP/actool.log" build/actool-failure.log 2>/dev/null || true
    echo "  adaptive icon skipped: $ADAPTIVE_SKIP (Dock falls back to AppIcon.icns)"
fi
echo "▸ Assembling and signing bundle…"
STAGE_TMP="$(mktemp -d)"
STAGE="$STAGE_TMP/$APP_NAME.app"
mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources" \
    "$STAGE/Contents/Library/LaunchDaemons" "$STAGE/Contents/Library/LaunchServices"
cp "build/$EXECUTABLE" "$STAGE/Contents/MacOS/$EXECUTABLE"
cp "build/$FAN_HELPER_ID" "$STAGE/Contents/Library/LaunchServices/$FAN_HELPER_ID"
mkdir -p "$STAGE/Contents/Frameworks"
cp "build/$NOW_PLAYING_ADAPTER" "$STAGE/Contents/Frameworks/$NOW_PLAYING_ADAPTER"
cp Resources/now-playing.pl "$STAGE/Contents/Resources/now-playing.pl"
cp Resources/agent-prices.json "$STAGE/Contents/Resources/agent-prices.json"
cp Resources/io.github.sam32j.lattice.fan-control.plist \
    "$STAGE/Contents/Library/LaunchDaemons/$FAN_HELPER_ID.plist"
cp Resources/Info.plist "$STAGE/Contents/Info.plist"
cp CHANGELOG.md "$STAGE/Contents/Resources/CHANGELOG.md"
if [[ -f Downstream/CHANGELOG.md ]]; then
    cp Downstream/CHANGELOG.md "$STAGE/Contents/Resources/LatticeChangelog.md"
fi
for lproj in Resources/*.lproj(N); do
    cp -R "$lproj" "$STAGE/Contents/Resources/"
done
./Tools/lattice-bundle-metadata.sh "$STAGE"
if true; then
    # A distinct identity so the Developer build installs and runs next to the
    # official app, with its own permissions, preferences and login item.
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $APP_BUNDLE_ID" "$STAGE/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$STAGE/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$STAGE/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $EXECUTABLE" "$STAGE/Contents/Info.plist"
    FAN_PLIST="$STAGE/Contents/Library/LaunchDaemons/$FAN_HELPER_ID.plist"
    /usr/libexec/PlistBuddy -c "Set :Label $FAN_HELPER_ID" "$FAN_PLIST"
    /usr/libexec/PlistBuddy -c "Set :BundleProgram Contents/Library/LaunchServices/$FAN_HELPER_ID" "$FAN_PLIST"
    /usr/libexec/PlistBuddy -c "Delete :MachServices:io.github.sam32j.lattice.fan-control" "$FAN_PLIST"
    /usr/libexec/PlistBuddy -c "Add :MachServices:$FAN_HELPER_ID bool true" "$FAN_PLIST"
    # Stamp the source commit + build time so the running dev app shows (in About)
    # exactly which code it was compiled from. Lets you verify it matches HEAD before
    # testing, instead of unknowingly running a stale build. Dev-only; never shipped.
    SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
    [[ -n "$(git status --porcelain 2>/dev/null)" ]] && SHA="$SHA-dirty"
    /usr/libexec/PlistBuddy -c "Add :LatticeBuildCommit string '$SHA · $(date '+%Y-%m-%d %H:%M')'" "$STAGE/Contents/Info.plist"
    echo "  stamped dev build: $SHA"
fi
FAN_HELPER_VERSION="$(
    export LC_ALL=C
    /usr/bin/shasum -a 256 \
        "$STAGE/Contents/Library/LaunchServices/$FAN_HELPER_ID" \
        "$STAGE/Contents/Library/LaunchDaemons/$FAN_HELPER_ID.plist" \
        | /usr/bin/awk '{print $1}' | /usr/bin/shasum -a 256 \
        | /usr/bin/awk '{print $1}'
)"
/usr/libexec/PlistBuddy -c "Add :LatticeFanControlHelperVersion string '$FAN_HELPER_VERSION'" \
    "$STAGE/Contents/Info.plist"
printf 'APPL????' > "$STAGE/Contents/PkgInfo"
cp build/AppIcon.icns "$STAGE/Contents/Resources/AppIcon.icns"
cp build/MenuBarIcon.png build/MenuBarIcon@2x.png build/BrandMark.png "$STAGE/Contents/Resources/"
if [[ -f build/Assets.car ]]; then
    cp build/Assets.car "$STAGE/Contents/Resources/Assets.car"
fi
if [[ -d Resources/Gifs ]]; then
    mkdir -p "$STAGE/Contents/Resources/Gifs"
    cp Resources/Gifs/*.gif "$STAGE/Contents/Resources/Gifs/"
fi
if [[ -d Resources/Images ]]; then
    mkdir -p "$STAGE/Contents/Resources/Images"
    cp Resources/Images/* "$STAGE/Contents/Resources/Images/"
fi
xattr -c -r "$STAGE" 2>/dev/null || true

# Signing, in order of preference:
#   1. Developer ID Application — the real, Apple-issued identity used for
#      notarized releases. Signed with the hardened runtime (required for
#      notarization), the app's entitlements and a secure timestamp. Gives a
#      stable, team-based designated requirement, so permissions persist across
#      updates AND Gatekeeper shows no "unverified developer" warning.
#   2. "Lattice Local Signing" — the legacy stable self-signed identity, kept
#      as a fallback so contributors without a Developer ID still get a constant
#      designated requirement across their local builds.
#   3. Ad-hoc — fresh clone with no identity at all.
SIGN_IDENTITY="$(resolved_signing_identity || true)"
sign_target() {
    local target="$1"
    local id_arg="${2:-}"
    if [[ -n "$SIGN_IDENTITY" ]]; then
        if [[ "$SIGN_IDENTITY" == "$LEGACY_IDENTITY" ]]; then
            /usr/bin/codesign --force --strip-disallowed-xattrs ${=id_arg} --sign "$SIGN_IDENTITY" "$target"
        else
            codesign_with_timestamp_retry --force --strip-disallowed-xattrs --options runtime --timestamp \
                ${=id_arg} --sign "$SIGN_IDENTITY" "$target" 2>/dev/null \
                || /usr/bin/codesign --force --strip-disallowed-xattrs --options runtime \
                    ${=id_arg} --sign "$SIGN_IDENTITY" "$target"
        fi
    else
        /usr/bin/codesign --force --strip-disallowed-xattrs ${=id_arg} --sign - "$target"
    fi
}

codesign_app() {
    sign_target "$1" "--entitlements $ENTITLEMENTS"
}

codesign_fan_helper() {
    sign_target "$1" "--identifier $FAN_HELPER_ID"
}

codesign_now_playing_adapter() {
    sign_target "$1" "--identifier $NOW_PLAYING_ADAPTER_ID"
}

sign_bundle() {
    local bundle="$1"
    local executable="$bundle/Contents/MacOS/$EXECUTABLE"
    local helper="$bundle/Contents/Library/LaunchServices/$FAN_HELPER_ID"
    local adapter="$bundle/Contents/Frameworks/$NOW_PLAYING_ADAPTER"

    local devid
    devid="$(developer_id_identity)"
    if [[ -n "$devid" ]]; then
        echo "  signing with Developer ID (hardened runtime): $devid"
    elif [[ -n "$SIGN_IDENTITY" && "$SIGN_IDENTITY" != "$LEGACY_IDENTITY" ]]; then
        echo "  signing with Apple Development identity (hardened runtime): $SIGN_IDENTITY"
    elif [[ "$SIGN_IDENTITY" == "$LEGACY_IDENTITY" ]]; then
        echo "  signing with legacy self-signed identity: $LEGACY_IDENTITY"
    else
        echo "  signing ad-hoc (no configured Lattice Developer ID or local identity)"
    fi
    [[ -f "$helper" ]] && codesign_fan_helper "$helper"
    [[ -f "$adapter" ]] && codesign_now_playing_adapter "$adapter"
    codesign_app "$bundle"

    # If local filesystem metadata invalidates the first signature, sign once
    # more. The installed Developer bundle is signed again after the final copy.
    if ! codesign --verify --deep --strict "$bundle" >/dev/null 2>&1; then
        echo "  re-signing after filesystem metadata settled"
        xattr -c -r "$bundle" 2>/dev/null || true
        [[ -f "$helper" ]] && codesign_fan_helper "$helper"
        [[ -f "$adapter" ]] && codesign_now_playing_adapter "$adapter"
        codesign_app "$bundle"
    fi
    [[ -f "$executable" ]] && codesign --verify --strict "$executable"
    [[ -f "$helper" ]] && codesign --verify --strict "$helper"
    [[ -f "$adapter" ]] && codesign --verify --strict "$adapter"
    codesign --verify --deep --strict "$bundle"
}

sign_installed_bundle() {
    local bundle="$1"
    wait_for_install_metadata "$bundle"
    sign_bundle "$bundle"
}

sign_bundle "$STAGE"

process_is_running() {
    local proc="$1"
    if (( ${#proc} > 15 )); then
        pgrep -f "/Contents/MacOS/$proc" >/dev/null 2>&1
    else
        pgrep -x "$proc" >/dev/null 2>&1
    fi
}

stop_process() {
    local proc="$1"
    if (( ${#proc} > 15 )); then
        pkill -f "/Contents/MacOS/$proc" 2>/dev/null || true
    else
        pkill -x "$proc" 2>/dev/null || true
    fi
    for _ in {1..50}; do
        if ! process_is_running "$proc"; then
            return 0
        fi
        sleep 0.1
    done
    echo "✗ $proc is still running — quit it and retry" >&2
    return 1
}

wait_for_install_metadata() {
    local bundle="$1"
    local missing
    for _ in {1..50}; do
        missing=0
        while IFS= read -r file; do
            if ! xattr -p com.apple.provenance "$file" >/dev/null 2>&1; then
                missing=1
                break
            fi
        done < <(find "$bundle/Contents" -type f ! -path "*/_CodeSignature/*")
        if (( missing == 0 )); then
            return 0
        fi
        sleep 0.1
    done
}

# Installed development builds only need the copy in /Applications. Retaining
# another app in each checkout pollutes application search with stale builds.
if (( DEV )); then
    for old_bundle in "build/stage/$APP_NAME.app" "build/stage.noindex/$APP_NAME.app"; do
        if [[ -d "$old_bundle" ]]; then
            /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
                -u "$PWD/$old_bundle" >/dev/null 2>&1 || true
            rm -rf "$old_bundle"
        fi
    done
fi

if (( !DEV || !INSTALL )); then
    STAGE_DIRECTORY="build/stage"
    (( DEV )) && STAGE_DIRECTORY="build/stage.noindex"
    mkdir -p "$STAGE_DIRECTORY"
    BUILD_STAGE="$STAGE_DIRECTORY/$APP_NAME.app"
    rm -rf "$BUILD_STAGE"
    ditto --noextattr --noqtn "$STAGE" "$BUILD_STAGE"
    xattr -c -r "$BUILD_STAGE" 2>/dev/null || true
    if ! codesign --verify --deep --strict "$BUILD_STAGE" >/dev/null 2>&1; then
        if xattr -lr "$BUILD_STAGE" 2>/dev/null | grep -Eq 'com\.apple\.(FinderInfo|ResourceFork|provenance|fileprovider)'; then
            echo "  staging copy has local filesystem metadata; temp bundle was verified"
        else
            codesign --verify --deep --strict "$BUILD_STAGE"
        fi
    fi
    echo "✓ Bundle ready: $BUILD_STAGE"
fi

if (( INSTALL )); then
    echo "▸ Installing into /Applications…"
    stop_process "$EXECUTABLE"
    # Lattice and its Developer variant replace only their own bundles.
    INSTALL_DEST="/Applications/$APP_NAME.app"
    rm -rf "$INSTALL_DEST"
    ditto --noextattr --noqtn "$STAGE" "$INSTALL_DEST"
    sign_installed_bundle "$INSTALL_DEST"
    echo "✓ Installed: $INSTALL_DEST"
fi
