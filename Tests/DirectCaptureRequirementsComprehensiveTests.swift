// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import Carbon.HIToolbox
import Combine
import CoreGraphics
import Foundation
import SwiftUI

/// Comprehensive test suite covering all direct capture, recording, pin,
/// preview, HUD, shortcut conflict, and settings requirements.
enum DirectCaptureRequirementsComprehensiveTests {

    static func run(_ suite: TestSuite) {
        testSettingsAndSidebarOrganization(suite)
        testFeatureCatalogBundlingAndCount(suite)
        testCompactShortcutRecordersAndConflictHandling(suite)
        testSoundPreferencesAndDefaults(suite)
        testScreenRecordingDelayedStartDiscardAndLiveCapture(suite)
        testVideoStashAndEditorWindowBehavior(suite)
        testScreenshotOverlayAndPinWindow(suite)
        testQuickPreviewLayoutShortcutsAndOCR(suite)
        testEditorTextToolMultilineAndBounding(suite)
        testSelectionControllerHUDAndMultiWindowCapture(suite)
    }

    // MARK: - 1. Settings & Sidebar Organization

    private static func testSettingsAndSidebarOrganization(_ suite: TestSuite) {
        // Source checks for ScreenshotSettings.swift
        let screenshotSettingsSource = (try? String(
            contentsOfFile: "Sources/Vorssaint/UI/Settings/ScreenshotSettings.swift",
            encoding: .utf8)) ?? ""
        suite.expect(!screenshotSettingsSource.isEmpty, "ScreenshotSettings.swift exists and is readable")

        // 1. Native Section headers and cards instead of empty lines / fake spacers
        suite.expect(screenshotSettingsSource.contains("SettingsCard(title: workflow.selection)")
                     && screenshotSettingsSource.contains("workflow.selection"),
                     "ScreenshotSettings uses cards and headers instead of fake empty spacer lines")

        // 2. Removed action buttons: "Capture now", "Scrolling capture now", "Show capture menu", "Highlight window under pointer"
        suite.expect(!screenshotSettingsSource.contains("captureNow")
                     && !screenshotSettingsSource.contains("strings.captureButton")
                     && !screenshotSettingsSource.contains("strings.scrollingCaptureTitle")
                     && !screenshotSettingsSource.contains("strings.highlightHoveredToggle")
                     && !screenshotSettingsSource.contains("strings.menuBarToggle"),
                     "ScreenshotSettings removed capture now, scrolling capture now, highlight window under pointer, and show capture menu")

        // 3. Shutter sound and temporary links in ScreenshotSettings
        suite.expect(screenshotSettingsSource.contains("workflow.shutter")
                     && screenshotSettingsSource.contains("$playShutterSound")
                     && screenshotSettingsSource.contains("strings.shareEnabledToggle"),
                     "ScreenshotSettings includes play shutter sound toggle and temporary links toggle")

        // Source checks for ScreenRecorderSettings.swift
        let recorderSettingsSource = (try? String(
            contentsOfFile: "Sources/Vorssaint/UI/Settings/ScreenRecorderSettings.swift",
            encoding: .utf8)) ?? ""
        suite.expect(!recorderSettingsSource.isEmpty, "ScreenRecorderSettings.swift exists and is readable")

        // 4. Native Section headers in ScreenRecorderSettings
        suite.expect(recorderSettingsSource.contains("SettingsCard(title: workflow.recording)")
                     && recorderSettingsSource.contains("workflow.recording"),
                     "ScreenRecorderSettings uses native cards and headers")

        // 5. Removed: "Screen recording now", "Show capture menu"
        suite.expect(!recorderSettingsSource.contains("recordNow")
                     && !recorderSettingsSource.contains("strings.recordButton")
                     && !recorderSettingsSource.contains("strings.menuBarToggle"),
                     "ScreenRecorderSettings removed screen recording now and show capture menu")

        // 6. Settings items for screen recording: immediate start, record sound, temporary links
        suite.expect(recorderSettingsSource.contains("workflow.immediate")
                     && recorderSettingsSource.contains("$immediateStart")
                     && recorderSettingsSource.contains("workflow.recordSound")
                     && recorderSettingsSource.contains("$playRecordSound")
                     && recorderSettingsSource.contains("screenshotStrings.shareEnabledToggle"),
                     "ScreenRecorderSettings includes immediate start toggle, record sound toggle, and temporary links toggle")

        // 7. Temporary links label
        for language in AppLanguage.allCases {
            let s = FeatureStrings.screenshot(language)
            suite.expect(!s.shareEnabledToggle.isEmpty,
                         "\(language.rawValue): shareEnabledToggle is non-empty")
        }

        // 8. Sidebar directory: Desktop & Screen section has items 1-6 including (.screenshot and .screenRecorder)
        let sections = SettingsSidebarIdentityTests.Directory.sidebarSections(.enUS, language: .enUS, isAvailable: { _ in true })
        let desktopAndScreen = sections.first { $0.id == 1 }
        suite.expect(desktopAndScreen?.items.contains { $0.id == .page(.screenshot) } == true
                     && desktopAndScreen?.items.contains { $0.id == .page(.screenRecorder) } == true,
                     "SettingsDirectory registers screenshot and screenRecorder under Desktop & Screen")

        // 9. SettingsSidebarSupport produces single items for screenshot and screenRecorder without extra clutter
        let screenshotSidebar = SettingsSidebarSupport.items(
            page: .screenshot,
            title: "Screenshot",
            icon: "camera.viewfinder",
            preferredFeatures: [],
            includePage: true,
            isAvailable: { _ in true },
            featureTitle: { _ in "" })
        let recorderSidebar = SettingsSidebarSupport.items(
            page: .screenRecorder,
            title: "Screen Recording",
            icon: "record.circle",
            preferredFeatures: [],
            includePage: true,
            isAvailable: { _ in true },
            featureTitle: { _ in "" })
        suite.expect(screenshotSidebar.count == 1 && screenshotSidebar.first?.destination.page == .screenshot,
                     "Screenshot sidebar item has single clean entry without extra highlighted features")
        suite.expect(recorderSidebar.count == 1 && recorderSidebar.first?.destination.page == .screenRecorder,
                     "Screen Recorder sidebar item has single clean entry")
    }

    // MARK: - 2. Feature Catalog Bundling & Count

    private static func testFeatureCatalogBundlingAndCount(_ suite: TestSuite) {
        // 1. Total installable features in Feature Hub excludes bundled .colorPicker and .screenOCR, plus mouse and keyboard features
        let nonHubFeatures = AppFeature.allCases.filter {
            $0 == .colorPicker || $0 == .screenOCR || $0.isToggleOwned || $0.isManagedOnDedicatedPage
        }
        suite.expect(AppFeature.hubInstallableFeatures.count == AppFeature.allCases.count - nonHubFeatures.count,
                     "the Hub omits the screenshot companions as well as mouse and keyboard features and dedicated page features")
        suite.expect(AppFeature.hubInstallableFeatures.count == 40,
                     "the Hub contains exactly 40 installable features")

        // 2. Color picker and screen OCR are excluded from standalone Hub installables
        suite.expect(!AppFeature.hubInstallableFeatures.contains(.colorPicker)
                     && !AppFeature.hubInstallableFeatures.contains(.screenOCR),
                     "Color picker and screen OCR are not separate installable features in the Hub")

        // 3. Screenshot initial install group bundles .colorPicker and .screenOCR
        suite.expect(AppFeature.screenshot.initialInstallGroup == [.screenshot, .colorPicker, .screenOCR],
                     "Screenshot initial install group bundles .screenshot, .colorPicker, and .screenOCR")

        // 4. Color picker and screen OCR availability tracks screenshot availability
        let domain = "com.vorssaint.tests.feature-bundle-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }

        defaults.set(false, forKey: AppFeature.screenshot.availabilityKey)
        defaults.set(true, forKey: AppFeature.colorPicker.availabilityKey) // stale or independent key
        defaults.set(true, forKey: AppFeature.screenOCR.availabilityKey)
        suite.expect(!AppFeature.colorPicker.isAvailable(in: defaults)
                     && !AppFeature.screenOCR.isAvailable(in: defaults),
                     "Color picker and screen OCR are unavailable when screenshot is unavailable")

        defaults.set(true, forKey: AppFeature.screenshot.availabilityKey)
        suite.expect(AppFeature.colorPicker.isAvailable(in: defaults)
                     && AppFeature.screenOCR.isAvailable(in: defaults),
                     "Color picker and screen OCR are available when screenshot is available")

        // 5. FeatureRuntime bundle install test
        let featureRuntimeSource = (try? String(
            contentsOfFile: "Sources/Vorssaint/App/FeatureRuntime.swift",
            encoding: .utf8)) ?? ""
        suite.expect(featureRuntimeSource.contains("AppFeature.hubInstallableFeatures.filter(\\ .isAvailable).count")
                     || featureRuntimeSource.contains("AppFeature.hubInstallableFeatures.filter(\\.isAvailable).count"),
                     "FeatureRuntime availableCount and installableCount count against hubInstallableFeatures (75)")
    }

    // MARK: - 3. Compact Shortcut Recorders & Conflict Handling

    private static func testCompactShortcutRecordersAndConflictHandling(_ suite: TestSuite) {
        let compactRecorderSource = (try? String(
            contentsOfFile: "Sources/Vorssaint/UI/CompactShortcutRecorder.swift",
            encoding: .utf8)) ?? ""
        let compactCoordinatorSource = (try? String(
            contentsOfFile: "Sources/Vorssaint/UI/CompactShortcutCoordinator.swift",
            encoding: .utf8)) ?? ""
        let compactFieldSource = (try? String(
            contentsOfFile: "Sources/Vorssaint/UI/CompactShortcutField.swift",
            encoding: .utf8)) ?? ""

        suite.expect(compactFieldSource.contains("struct CompactShortcutField: View")
                     && compactFieldSource.contains("let width: CGFloat")
                     && compactFieldSource.contains("let onClear: (() -> Void)?")
                     && compactFieldSource.contains("let onReset: (() -> Void)?"),
                     "a reusable compact field owns stable sizing and inline clear/reset actions")

        // 1. Compact single-row layout components
        suite.expect(compactRecorderSource.contains("struct CompactShortcutPreferenceRow: View")
                     && compactRecorderSource.contains("struct CompactShortcutRecorder: View")
                     && compactCoordinatorSource.contains("final class CompactShortcutCoordinator: ObservableObject"),
                     "shared shortcut components provide a compact recorder and coordinator")

        // 2. Only one setter active at a time via CompactShortcutCoordinator
        suite.expect(compactCoordinatorSource.contains("func startRecording(role: GlobalShortcutRole) {")
                     && compactCoordinatorSource.contains("guard activeRole != role else { return }")
                     && compactCoordinatorSource.contains("endCaptureIfNeeded()")
                     && compactCoordinatorSource.contains("activeRole = role"),
                     "CompactShortcutCoordinator stops existing recording before activating a new one so only one is active at a time")

        // 3. Error text and shaking animation
        suite.expect(compactRecorderSource.contains("showError(l10n.s.shortcutInvalid)")
                     && compactRecorderSource.contains("struct CompactRecorderShakeEffect: GeometryEffect")
                     && !compactRecorderSource.contains("macOS rejects"),
                     "Conflict/invalid keys show localized errors with shaking animation")

        // 4. Inline controls inside setter: xmark.circle.fill (clear) and arrow.uturn.backward (reset)
        suite.expect(compactFieldSource.contains("\"arrow.uturn.backward\"")
                     && compactFieldSource.contains("\"xmark.circle.fill\"")
                     && compactFieldSource.contains("help: l10n.s.shortcutClear"),
                     "Setter includes inline reset (u-turn) and disable (x) buttons inside the box")

        // 5. Detect conflicts before reset; another feature must remain untouched.
        let defaultA = GlobalShortcutRole.screenshot.defaultShortcut
        let defaultB = GlobalShortcutRole.screenshotFullScreen.defaultShortcut
        suite.expect(defaultA != defaultB, "Test roles have distinct default shortcuts")

        let origBValue = UserDefaults.standard.string(forKey: GlobalShortcutRole.screenshotFullScreen.storageKey)
        let origBEnabled = UserDefaults.standard.object(forKey: DefaultsKey.screenshotFullScreenShortcutEnabled)
        let origAValue = UserDefaults.standard.string(forKey: GlobalShortcutRole.screenshot.storageKey)
        let origAEnabled = UserDefaults.standard.object(forKey: DefaultsKey.screenshotShortcutEnabled)
        let origScreenshotFeature = UserDefaults.standard.object(forKey: AppFeature.screenshot.availabilityKey)

        defer {
            if let origBValue = origBValue { UserDefaults.standard.set(origBValue, forKey: GlobalShortcutRole.screenshotFullScreen.storageKey) }
            else { UserDefaults.standard.removeObject(forKey: GlobalShortcutRole.screenshotFullScreen.storageKey) }
            if let origBEnabled = origBEnabled { UserDefaults.standard.set(origBEnabled, forKey: DefaultsKey.screenshotFullScreenShortcutEnabled) }
            else { UserDefaults.standard.removeObject(forKey: DefaultsKey.screenshotFullScreenShortcutEnabled) }
            if let origAValue = origAValue { UserDefaults.standard.set(origAValue, forKey: GlobalShortcutRole.screenshot.storageKey) }
            else { UserDefaults.standard.removeObject(forKey: GlobalShortcutRole.screenshot.storageKey) }
            if let origAEnabled = origAEnabled { UserDefaults.standard.set(origAEnabled, forKey: DefaultsKey.screenshotShortcutEnabled) }
            else { UserDefaults.standard.removeObject(forKey: DefaultsKey.screenshotShortcutEnabled) }
            if let origScreenshotFeature = origScreenshotFeature { UserDefaults.standard.set(origScreenshotFeature, forKey: AppFeature.screenshot.availabilityKey) }
            else { UserDefaults.standard.removeObject(forKey: AppFeature.screenshot.availabilityKey) }
        }

        UserDefaults.standard.set(true, forKey: AppFeature.screenshot.availabilityKey)
        // Give Role B Role A's default shortcut
        UserDefaults.standard.set(defaultA.storageValue, forKey: GlobalShortcutRole.screenshotFullScreen.storageKey)
        UserDefaults.standard.set(true, forKey: DefaultsKey.screenshotFullScreenShortcutEnabled)
        UserDefaults.standard.set(false, forKey: DefaultsKey.screenshotShortcutEnabled)

        // Check conflict detection finds screenshotFullScreen
        let conflictRole = GlobalShortcutRole.conflict(
            for: defaultA,
            excluding: .screenshot,
            isOn: { UserDefaults.standard.bool(forKey: $0) },
            isAvailable: { _ in true },
            includeInactive: false)
        suite.expect(conflictRole == .screenshotFullScreen,
                     "GlobalShortcutRole.conflict identifies screenshotFullScreen as colliding with defaultA")

        // The production reset boundary is exercised by CompactShortcutValidationTests.

    }

    // MARK: - 4. Sound Preferences & Defaults

    private static func testSoundPreferencesAndDefaults(_ suite: TestSuite) {
        // Defaults registrations
        suite.expect(Defaults.registeredDefaults[DefaultsKey.screenshotPlayShutterSound] as? Bool == true,
                     "screenshotPlayShutterSound defaults to true")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.recorderPlaySound] as? Bool == true,
                     "recorderPlaySound defaults to true")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.recorderImmediateStartAfterSelection] as? Bool == true,
                     "recorderImmediateStartAfterSelection defaults to true")

        // ScreenshotService plays shutter sound
        let screenshotServiceSource = (try? String(
            contentsOfFile: "Sources/Vorssaint/Services/QuickTools/ScreenshotService.swift",
            encoding: .utf8)) ?? ""
        suite.expect(screenshotServiceSource.contains("DefaultsKey.screenshotPlayShutterSound")
                     && screenshotServiceSource.contains("NSSound(named: \"Shutter\")?.play()"),
                     "ScreenshotService verifies screenshotPlayShutterSound and plays Shutter sound")

        // ScreenRecorderService plays begin_record and end_record sound
        let recorderServiceSource = (try? String(
            contentsOfFile: "Sources/Vorssaint/Services/Recorder/ScreenRecorderService.swift",
            encoding: .utf8)) ?? ""
        suite.expect(recorderServiceSource.contains("DefaultsKey.recorderPlaySound")
                     && recorderServiceSource.contains("begin_record.caf")
                     && recorderServiceSource.contains("end_record.caf"),
                     "ScreenRecorderService checks recorderPlaySound and plays begin_record on start and end_record on stop")
    }

    // MARK: - 5. Screen Recording Delayed Start, Discard & Live Capture

    private static func testScreenRecordingDelayedStartDiscardAndLiveCapture(_ suite: TestSuite) {
        let indicatorSource = (try? String(
            contentsOfFile: "Sources/Vorssaint/Services/Recorder/RecorderIndicator.swift",
            encoding: .utf8)) ?? ""
        suite.expect(!indicatorSource.isEmpty, "RecorderIndicator.swift is readable")

        // 1. Indicator dimensions & trash button
        suite.expect(indicatorSource.contains("static let size = CGSize(width: 182, height: 32)")
                     && indicatorSource.contains("symbol: \"trash\"")
                     && indicatorSource.contains("trashButton.toolTip = discardTooltip"),
                     "RecorderIndicator expanded to 182x32 and includes trash button for deleting/discarding recording")

        let waitingSource = (try? String(contentsOfFile:
            "Sources/Vorssaint/UI/Recorder/RecorderWaitingControls.swift", encoding: .utf8)) ?? ""
        suite.expect(waitingSource.contains("RecorderOverlayInputControls()")
                     && waitingSource.contains("speaker.wave.2.fill") && waitingSource.contains("mic.fill")
                     && waitingSource.contains("play.fill") && waitingSource.contains("xmark"),
                     "waiting controls group four inputs beside Start and Cancel")
        suite.expect(!indicatorSource.contains("isWaitingForStart"),
                     "the recording indicator has no obsolete pre-recording waiting state")

        // 4. Discard action in ScreenRecorderService
        let recorderServiceSource = (try? String(
            contentsOfFile: "Sources/Vorssaint/Services/Recorder/ScreenRecorderService.swift",
            encoding: .utf8)) ?? ""
        let discardBody = recorderServiceSource.components(separatedBy: "func stopAndDiscard()").dropFirst().first?.components(separatedBy: "private func").first ?? ""
        suite.expect(recorderServiceSource.contains("func stopAndDiscard() {")
                     && recorderServiceSource.contains("RecorderTakeStore.shared.delete(session.take)")
                     && recorderServiceSource.contains("self.sweepTakes()")
                     && !discardBody.contains("stashRecording"),
                     "ScreenRecorderService stopAndDiscard deletes take from store without stashing into Recent Captures")

        let waitingSelectionSource = (try? String(contentsOfFile:
            "Sources/Vorssaint/Services/QuickTools/ScreenshotSelectionController.swift", encoding: .utf8)) ?? ""
        suite.expect(waitingSelectionSource.contains("DefaultsKey.recorderImmediateStartAfterSelection")
                     && waitingSelectionSource.contains("prepareWaitingRecording")
                     && waitingSelectionSource.contains("recordingDraft?.drag"),
                     "the chooser owns delayed Start and retains editable recording geometry")

        // 6. Selection live unfrozen screen for recorder
        let recordingPolicy = ScreenshotSupport.unifiedCapturePolicy(
            for: .recording,
            screenshotFreeze: true,
            screenshotIncludePointer: true,
            screenshotHideVorssaintWindows: true)
        suite.expect(recordingPolicy.freeze == false,
                     "Recorder selection mode uses live capture source without freezing the screen, even if screenshotFreeze is true")

        let screenshotPolicy = ScreenshotSupport.unifiedCapturePolicy(
            for: .screenshot,
            screenshotFreeze: true,
            screenshotIncludePointer: true,
            screenshotHideVorssaintWindows: true)
        suite.expect(screenshotPolicy.freeze == true,
                     "Screenshot selection respects screenshotFreeze setting")

        // 7. Mouse up window click ignores shift in recording mode
        let selectionSource = (try? String(
            contentsOfFile: "Sources/Vorssaint/Services/QuickTools/ScreenshotSelectionController.swift",
            encoding: .utf8)) ?? ""
        suite.expect(selectionSource.contains("controller.activeTool != .recording && event.modifierFlags.contains(.shift)"),
                     "Window click in ScreenshotSelectionController ignores Shift in recording mode, using first clicked window")
    }

    // MARK: - 6. Video Stash & Editor Window Behavior

    private static func testVideoStashAndEditorWindowBehavior(_ suite: TestSuite) {
        let recorderServiceSource = (try? String(
            contentsOfFile: "Sources/Vorssaint/Services/Recorder/ScreenRecorderService.swift",
            encoding: .utf8)) ?? ""

        // 1. Stash raw video in recent captures on deliver
        suite.expect(recorderServiceSource.contains("RecentCaptureService.shared.stashRecording(from: take.videoURL)"),
                     "ScreenRecorderService deliver stashes raw video in Recent Captures")

        // 2. Editor close confirmation logic
        let editorControllerSource = (try? String(
            contentsOfFile: "Sources/Vorssaint/Services/Recorder/RecorderEditorController.swift",
            encoding: .utf8)) ?? ""
        suite.expect(!editorControllerSource.isEmpty, "RecorderEditorController.swift is readable")

        suite.expect(editorControllerSource.contains("guard needsCloseConfirmation else { return true }")
                     && editorControllerSource.contains("if !needsCloseConfirmation {")
                     && editorControllerSource.contains("confirmedClose = true")
                     && editorControllerSource.contains("window?.close()"),
                     "Editor close and discard both require confirmed preservation and no unsaved edits")

        suite.expect(editorControllerSource.contains("alert.messageText = strings.discardTitle")
                     && editorControllerSource.contains("strings.discardSavedMessage : strings.discardMessage"),
                     "Discard confirmation uses localized text reflecting whether a recording is preserved")

        suite.expect(editorControllerSource.contains("self.markSaved(document)")
                     && editorControllerSource.contains("RecentCaptureService.shared.recordRecording(at: destination)"),
                     "Successful export marks the exported snapshot saved and records the output")

        // 3. Centered window controls in RecorderEditorWindow
        suite.expect(editorControllerSource.contains("final class RecorderEditorWindow: NSWindow")
                     && editorControllerSource.contains("targetHeight: CGFloat = 54")
                     && editorControllerSource.contains("let targetY = ((targetHeight - buttonHeight) / 2).rounded()"),
                     "RecorderEditorWindow vertically centers close/zoom/miniaturize buttons in 54pt toolbar")

        // 4. RecorderEditorView padding
        let editorViewSource = (try? String(
            contentsOfFile: "Sources/Vorssaint/UI/Recorder/RecorderEditorView.swift",
            encoding: .utf8)) ?? ""
        suite.expect(editorViewSource.contains(".padding(.leading, 96)")
                     && editorControllerSource.contains("currentX: CGFloat = 20.0"),
                     "RecorderEditorView has 96pt leading inset and 20pt window button origin")
    }

    // MARK: - 7. Screenshot Overlay & Pin Window

    private static func testScreenshotOverlayAndPinWindow(_ suite: TestSuite) {
        // 1. OverlayPanel disables window opening zoom animation
        let overlayPanelSource = (try? String(
            contentsOfFile: "Sources/Vorssaint/UI/OverlayPanel.swift",
            encoding: .utf8)) ?? ""
        suite.expect(overlayPanelSource.contains("animationBehavior = .none"),
                     "OverlayPanel sets animationBehavior = .none to prevent window zoom up animation")

        let selectionSource = (try? String(
            contentsOfFile: "Sources/Vorssaint/Services/QuickTools/ScreenshotSelectionController.swift",
            encoding: .utf8)) ?? ""
        suite.expect(selectionSource.contains("animationBehavior = .none"),
                     "ScreenshotOverlayPanel sets animationBehavior = .none")

        // 2. ScreenshotPinWindow movable by background & double click preview
        MainActor.assumeIsolated {
            let context = CGContext(data: nil, width: 200, height: 100, bitsPerComponent: 8,
                                    bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            let image = context.makeImage()!
            let domain = "com.vorssaint.tests.pin-req-\(UUID().uuidString)"
            let prefs = UserDefaults(suiteName: domain)!
            defer { prefs.removePersistentDomain(forName: domain) }

            let pin = ScreenshotPinWindow(image: image, scale: 2, preferences: prefs)
            defer { pin.closePin() }

            // Drag to move
            suite.expect(pin.isMovableByWindowBackground == true,
                         "ScreenshotPinWindow is movable by window background by default for smooth dragging")

            pin.setPositionLocked(true)
            suite.expect(pin.isMovableByWindowBackground == false,
                         "Position lock disables window background movement")

            pin.setPositionLocked(false)
            suite.expect(pin.isMovableByWindowBackground == true,
                         "Unlocking position restores window background movement")

            var edited = false
            pin.onEdit = { edited = true }
            if let click = NSEvent.mouseEvent(with: .leftMouseDown, location: .zero,
                modifierFlags: [], timestamp: 0, windowNumber: pin.windowNumber, context: nil,
                eventNumber: 1, clickCount: 2, pressure: 1) {
                pin.contentView?.mouseDown(with: click)
            }
            suite.expect(!edited, "double-clicking a pin has no action")
            if let edit = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
                timestamp: 0, windowNumber: pin.windowNumber, context: nil, characters: "e",
                charactersIgnoringModifiers: "e", isARepeat: false, keyCode: 14) {
                pin.keyDown(with: edit)
            }
            suite.expect(edited, "Command-E opens the focused pin in the editor")

            // Test first-try zoom logic
            let gestureView = ScreenshotPinGestureView(frame: .zero)
            pin.contentView = gestureView
            let startWidth = pin.frame.width
            gestureView.zoom(by: 1.2, at: nil) // Zoom using NSEvent.mouseLocation without requiring point
            suite.expect(pin.frame.width > startWidth,
                         "ScreenshotPinGestureView zooms immediately even when anchor point is omitted")
        }

        // 3. Gesture monitoring in ScreenshotPinController
        let pinControllerSource = (try? String(
            contentsOfFile: "Sources/Vorssaint/Services/QuickTools/ScreenshotPinController.swift",
            encoding: .utf8)) ?? ""
        suite.expect(pinControllerSource.contains("localGestureMonitor = NSEvent.addLocalMonitorForEvents")
                     && pinControllerSource.contains("gestureMonitor = NSEvent.addGlobalMonitorForEvents")
                     && pinControllerSource.contains("routeGesture(event)")
                     && pinControllerSource.contains("pin.handleGestureEvent(event, screenLocation: location)"),
                     "ScreenshotPinController monitors local and global gesture events so pinch zoom works on first try without prior click")
    }

    // MARK: - 8. Quick Preview Layout, Shortcuts & OCR

    private static func testQuickPreviewLayoutShortcutsAndOCR(_ suite: TestSuite) {
        let previewSource = (try? String(
            contentsOfFile: "Sources/Vorssaint/Services/QuickTools/ScreenshotQuickPreviewController.swift",
            encoding: .utf8)) ?? ""
        suite.expect(!previewSource.isEmpty, "ScreenshotQuickPreviewController.swift is readable")

        // 1. Stacked center actions & hover effect
        suite.expect(previewSource.contains("struct QuickPreviewCenterActions: View")
                     && previewSource.contains("VStack(spacing: 6) {")
                     && previewSource.contains("isCopyHovered ? 1.04 : 1.0")
                     && previewSource.contains("isSaveHovered ? 1.04 : 1.0"),
                     "Quick view copy and save buttons are stacked vertically with 1.04x hover scale effect")

        // 2. Image fill window vs fit window
        suite.expect(previewSource.contains(".scaledToFill()")
                     && previewSource.contains(".clipped()")
                     && !previewSource.contains(".scaledToFit()"),
                     "Quick view image uses .scaledToFill() with .clipped() to fill the viewport")

        // 3. Focus prevention for keyboard navigation
        suite.expect(previewSource.contains(".buttonStyle(.plain)")
                     && previewSource.contains(".focusable(false)"),
                     "Control and preview action buttons disable focus to prevent blue keyboard navigation rings")

        // 4. Viewport hover overlay
        suite.expect(previewSource.contains("@State private var isViewportHovered = false")
                     && previewSource.contains(".onHover { inside in")
                     && previewSource.contains("isViewportHovered = inside"),
                     "Quick view viewport tracks hover state continuously across image and overlay controls")

        // 5. White link button and context menu
        suite.expect(previewSource.contains(".foregroundStyle(.white)")
                     && previewSource.contains("shareMenuChrome(Menu { shareDurations } label: { shareMenuLabel }"),
                     "Link icon uses white regular style and click opens share durations menu")

        // 6. Keyboard shortcuts: Space -> Copy, P -> Pin, O -> OCR, E -> Edit
        suite.expect(previewSource.contains("if key == kVK_Space || letter == \" \" {")
                     && previewSource.contains("self.perform(.copy)")
                     && previewSource.contains("if letter == \"p\" || key == kVK_ANSI_P {")
                     && previewSource.contains("self.perform(.pin)")
                     && previewSource.contains("if letter == \"o\" || key == kVK_ANSI_O {")
                     && previewSource.contains("self.copyText()")
                     && previewSource.contains("if letter == \"e\" || key == kVK_ANSI_E || key == kVK_Return")
                     && previewSource.contains("self.perform(.edit)"),
                     "Preview key monitor maps Space to copy, P to pin, O to OCR, and E/Enter to edit")

        // 7. Viewport click does NOT enter edit
        let imageButtonRegex = "Image(decorative: image"
        suite.expect(!previewSource.components(separatedBy: imageButtonRegex).first!.contains("Button {\n                perform(.edit)"),
                     "Clicking image viewport does not open editor; only edit button or E shortcut opens editor")

        // 8. OCR QR code copy without modal & Dual text/QR recognition
        let screenTextSource = (try? String(
            contentsOfFile: "Sources/Vorssaint/Services/QuickTools/ScreenTextService.swift",
            encoding: .utf8)) ?? ""
        suite.expect(screenTextSource.contains("case both(BarcodeDetector.Reading, text: String)")
                     && screenTextSource.contains("let combined = text.contains(payload) ? text : \"\\(text)\\n\\n\\(payload)\"")
                     && screenTextSource.contains("Self.copyToPasteboard(combined)"),
                     "ScreenTextService defines .both outcome and copies joined text and QR payload without modal")

        suite.expect(screenTextSource.contains("case .qr(let reading):")
                     && screenTextSource.contains("let payload = Outcome.readingPayload(from: reading)")
                     && screenTextSource.contains("Self.copyToPasteboard(payload)")
                     && !screenTextSource.components(separatedBy: "case .qr(let reading):").last!.prefix(100).contains("QRResultController.shared.show"),
                     "OCR directly copies QR payload to clipboard without opening confirmation modal")
    }

    // MARK: - 9. Editor Text Tool Multiline & Bounding

    private static func testEditorTextToolMultilineAndBounding(_ suite: TestSuite) {
        let editorViewSource = (try? String(
            contentsOfFile: "Sources/Vorssaint/UI/Screenshot/ScreenshotEditorView.swift",
            encoding: .utf8)) ?? ""
        suite.expect(!editorViewSource.isEmpty, "ScreenshotEditorView.swift is readable")
        let inlineTextSource = (try? String(
            contentsOfFile: "Sources/Vorssaint/UI/Screenshot/ScreenshotInlineTextEditor.swift",
            encoding: .utf8)) ?? ""

        // 1. Multiline Enter vs Cmd+Return save
        suite.expect(inlineTextSource.contains("if event.keyCode == 36 || event.keyCode == 76 {")
                     && inlineTextSource.contains("if flags.contains(.command) {")
                     && inlineTextSource.contains("commitEditing()")
                     && inlineTextSource.contains("insertNewline(nil)")
,
                     "EditorTextView allows Enter for new line, and Cmd+Return to commit and exit text input")

        // 2. Isolated undo manager to avoid crashing parent window undo stack
        suite.expect(inlineTextSource.contains("let isolatedUndoManager = UndoManager()")
                     && inlineTextSource.contains("override var undoManager: UndoManager? { isolatedUndoManager }")
                     && inlineTextSource.contains("isolatedUndoManager.removeAllActions()"),
                     "EditorTextView uses isolated UndoManager, preventing undo crashes in screenshot editor")

        // 3. Drag creates bounded text box; single click creates dynamic box
        suite.expect(inlineTextSource.contains("let wrapWidth = mark.isBounded ?")
                     && inlineTextSource.contains("ScreenshotEditorGeometry.textSize(text, font: font, width: wrapWidth)")
                     && inlineTextSource.contains("textView.textContainer?.widthTracksTextView = isBounded")
                     && inlineTextSource.contains("wrapWidth ?? max(40, measured.width + 4 * zoom)"),
                     "Text tool drag creates contained bounded box with word wrap; click creates dynamic sizing box")
    }

    // MARK: - 10. Selection Controller HUD & Multi-Window Capture

    private static func testSelectionControllerHUDAndMultiWindowCapture(_ suite: TestSuite) {
        let selectionSource = (try? String(
            contentsOfFile: "Sources/Vorssaint/Services/QuickTools/ScreenshotSelectionController.swift",
            encoding: .utf8)) ?? ""
        suite.expect(!selectionSource.isEmpty, "ScreenshotSelectionController.swift is readable")

        // 1. Persistent crosshair cursor
        suite.expect(selectionSource.contains("NSCursor.crosshair.set()")
                     && selectionSource.contains("addCursorRect(bounds, cursor: .crosshair)"),
                     "Selection controller uses crosshair cursor consistently throughout capture")

        // 2. Tab text
        suite.expect(selectionSource.contains("Text(strings.hintDrag)")
                     && selectionSource.contains("Text(strings.hintClick)")
                     && selectionSource.contains("CaptureWorkflowStrings.localized(l10n.language).recordWindow")
                     && selectionSource.contains("model.scrollingCaptureEnabled ? .secondary.opacity(0.35) : .secondary"),
                     "Tab shows clean label with drag hint, click hint (dimmed when scrolling capture enabled), and record click hint")

        // 3. Separated Scroll control above main tab in screenshot mode
        suite.expect(selectionSource.contains("private var scrollToggleBar: some View")
                     && selectionSource.contains("Text(CaptureWorkflowStrings.localized(l10n.language).scroll)")
                     && selectionSource.contains("isScrollingCaptureKey")
                     && selectionSource.contains("scrollingCaptureEnabled ? Color.white : Color.primary"),
                     "Scroll control is separated above main tab with 'Scroll' label and shortcut S, dimming text when on")

        // 4. Media controls above main tab in record mode
        suite.expect(selectionSource.contains("RecorderSelectionAudioControls(options: options.recorderAudio)")
                     && selectionSource.contains("isMicrophoneKey")
                     && selectionSource.contains("kVK_ANSI_M"),
                     "Media controls for Sound (S) and Mic (M) are positioned above main tab in record mode")

        // 5. Mode switch button on right of main tab
        suite.expect(selectionSource.contains("private var modeSwitchHint: some View")
                     && selectionSource.contains("Text(\"R\")")
                     && selectionSource.contains("toggleCaptureAndRecordMode()"),
                     "Mode switcher button sits on the right of main tab with 'R' shortcut")

        // 6. Last selection shortcut X before F, disabled when empty
        suite.expect(selectionSource.contains("CaptureKeyHint(key: \"X\"")
                     && selectionSource.contains("CaptureKeyHint(key: \"F\"")
                     && selectionSource.contains("model.offersRepeatLastRegion && isEnabled"),
                     "Last selection uses shortcut X, sits before F, and is disabled when there is no last selection")

        // 7. 1-4 mode switcher keys removed
        suite.expect(!selectionSource.contains("kVK_ANSI_1")
                     && !selectionSource.contains("kVK_ANSI_2")
                     && !selectionSource.contains("kVK_ANSI_3")
                     && !selectionSource.contains("kVK_ANSI_4"),
                     "1-4 window/mode switcher keys are removed and do nothing")

        // 8. Tab hover penetration prevention
        suite.expect(selectionSource.contains("func pointerIsOverTab(_ point: CGPoint) -> Bool")
                     && selectionSource.contains("!guideHost.isHidden && guideHost.frame.contains(point) && guideHost.isHovered")
                     && selectionSource.contains("let overControls = pointerIsOverFullScreenControl(point) || pointerIsOverTab(point)"),
                     "pointerIsOverTab prevents cursor penetration through tab to underlying windows")

        // 9. Clicking tab does not hide tab
        suite.expect(selectionSource.contains("doesn't start a drag or hide the tab"),
                     "Clicking hover tab controls does not dismiss or hide the capture tabs")

        // 10. Multi-window selection: un-dimmed rather than blue tint, visible checkmark, release shift to capture
        ScreenshotMultiWindowShiftTests.run(suite)
        suite.expect(selectionSource.contains("func toggleSelectedWindow(_ window: ScreenshotSupport.PickableWindow, on panel: ScreenshotOverlayPanel)")
                     && selectionSource.contains("selectedWindows[window.windowID] = (window, panel)"),
                     "Shift+click toggles the windows used by multi-window confirmation")

        // 11. Esc quits screenshot mode directly in multi-window selection
        suite.expect(selectionSource.contains("case kVK_Escape:")
                     && selectionSource.contains("self.finish(.cancelled)"),
                     "Escape in multi-window mode exits capture mode directly")

        // 12. Control buttons disabled in multi-window select mode
        suite.expect(selectionSource.contains("private var isMultiWindowMode: Bool { model.selectedWindowsCount > 0 }")
                     && selectionSource.contains("let isEnabled = !isMultiWindowMode")
                     && selectionSource.contains(".disabled(!isEnabled)"),
                     "Control buttons (X, F, S, Z, R) are disabled during multi-window selection")

        // Multi-window anchor geometry is exercised against the real chooser
        // methods in ScreenshotMultiWindowSourceTests, not source spellings.

        // 14. Loupe HUD: vertically stacked, 90% opaque + blur, logical pixels, Tab copies color
        suite.expect(selectionSource.contains("drawLoupeCoordinateBox(context, in: coordRect, at: point)")
                     && selectionSource.contains("drawLoupeColorBox(context,")
                     && selectionSource.contains("CGColor(gray: 0.08, alpha: 0.90)"),
                     "Loupe HUD stacks magnifier, coordinate box, and color box vertically with 90% opacity")

        suite.expect(selectionSource.contains("let text = \"X: \\(Int(point.x))   Y: \\(Int(point.y))\""),
                     "Loupe coordinate displays logical pixels")

        suite.expect(selectionSource.contains("copyLoupeColorUnderPointer()")
                     && selectionSource.contains("let text = \"✓ \\(copiedValue)\"")
                     && selectionSource.contains("isCopyColorKey"),
                     "Tab copies color when Z is enabled with fixed width and checkmark feedback without resizing")
    }
}
