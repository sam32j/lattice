// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum NotchSettingsStrings {
    static func widgetWord(_ language: AppLanguage) -> String {
        switch language {
        case .enUS, .ptBR, .es, .sk, .de, .fr, .it:
            return "Widget"
        case .ru:
            return "Виджет"
        case .tr:
            return "Araç takımı"
        case .ja:
            return "ウィジェット"
        case .ko:
            return "위젯"
        case .zhHans:
            return "小组件"
        case .zhTW, .zhHK:
            return "小工具"
        case .uk:
            return "Віджет"
        }
    }

    static func widgetTitle(_ module: NotchModule, language: AppLanguage) -> String {
        let title = module == .music ? FeatureStrings.notch(language).music : module.title(language)
        let word = widgetWord(language)
        switch language {
        case .zhHans, .zhTW, .zhHK, .ja:
            return "\(title)\(word)"
        default:
            return "\(title) \(word)"
        }
    }
}
