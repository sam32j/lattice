// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

extension SettingsDirectory {
    static func utilityPages(_ s: Strings, language: AppLanguage) -> [SettingsDirectoryItem] {
        [
                SettingsDirectoryItem(page: .urlCleaner, title: s.urlCleanerName, icon: "link"),
                SettingsDirectoryItem(page: .clipboard, title: FeatureStrings.clipboard(language).title,
                                      icon: "doc.on.clipboard",
                                      featureKeywords: [
                                        (.clipboardHistory, [FeatureStrings.clipboard(language).limit,
                                                             FeatureStrings.clipboard(language).historyLayout,
                                                             FeatureStrings.clipboard(language).skipSensitive,
                                                             FeatureStrings.clipboard(language).autoClearEnable,
                                                             FeatureStrings.clipboard(language).autoClearOnSleep,
                                                             FeatureStrings.clipboard(language)
                                                                .autoClearOnDisplaySleep,
                                                             FeatureStrings.clipboard(language)
                                                                .autoClearOnScreenLock,
                                                             FeatureStrings.clipboardIgnoredApps(language)
                                                                .listTitle]),
                                        (.pastePlain, [s.pastePlainName]),
                                      ]),
                SettingsDirectoryItem(page: .textSnippets,
                                      title: FeatureStrings.snippets(language).pageTitle,
                                      icon: "text.append",
                                      keywords: [FeatureStrings.snippets(language).triggerLabel,
                                                 FeatureStrings.snippets(language).addButton,
                                                 FeatureStrings.snippets(language).soundPickerLabel,
                                                 FeatureStrings.snippets(language).soundToggle]),
                SettingsDirectoryItem(page: .videoDownloader, title: VideoDownloaderStrings.pageTitle, icon: "arrow.down.square",
                                      keywords: ["yt-dlp", "download video", "quality", "ffmpeg"]),
                SettingsDirectoryItem(page: .scratchpad,
                                      title: FeatureStrings.scratchpad(language).pageTitle,
                                      icon: "note.text",
                                      featureKeywords: [
                                        (.scratchpad, [FeatureStrings.scratchpad(language).pageTitle]),
                                      ]),
                SettingsDirectoryItem(page: .media, title: s.mediaName, icon: "photo.on.rectangle.angled",
                                      keywords: ["PDF", "GIF", "PNG", "JPEG", "convert", "resize", "watermark",
                                                 "rename", "profile", "fit", "fill", "crop",
                                                 s.mediaStartConvertPDF, s.ocrName]),
                SettingsDirectoryItem(page: .cameraPreview, title: FeatureStrings.cameraPreview(language).pageTitle, icon: "web.camera"),
                SettingsDirectoryItem(page: .diskImageInstaller, title: SettingsOwnershipStrings.text(.dmgInstaller, language), icon: "externaldrive.badge.plus"),
                SettingsDirectoryItem(page: .shelf, title: SettingsOwnershipStrings.text(.fileCache, language), icon: "tray.full",
                                      keywords: [s.shelfEnable, s.shelfDropZoneToggle, s.shelfEdgeToggle,
                                                 s.shelfClearOnClose, s.shelfShortcutFinderSelection,
                                                 FeatureStrings.notch(language).title,
                                                 FeatureStrings.notchEditor(language).separate]),
        ]
    }
}
