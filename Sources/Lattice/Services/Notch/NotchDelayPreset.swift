// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum NotchDelayPreset: String, CaseIterable, Identifiable {
    case instant
    case short
    case normal
    case long
    case veryLong

    var id: String { rawValue }

    var hoverDelay: Double {
        switch self {
        case .instant: return 0.10
        case .short: return 0.18
        case .normal: return 0.25
        case .long: return 0.50
        case .veryLong: return 1.00
        }
    }

    var closeDelay: Double {
        switch self {
        case .instant: return 0.10
        case .short: return 0.15
        case .normal: return 0.20
        case .long: return 0.50
        case .veryLong: return 1.00
        }
    }

    static func closestHoverPreset(for delay: Double) -> NotchDelayPreset {
        allCases.min(by: { abs($0.hoverDelay - delay) < abs($1.hoverDelay - delay) }) ?? .normal
    }

    static func closestClosePreset(for delay: Double) -> NotchDelayPreset {
        allCases.min(by: { abs($0.closeDelay - delay) < abs($1.closeDelay - delay) }) ?? .normal
    }

    func title(_ language: AppLanguage) -> String {
        switch language {
        case .enUS:
            switch self {
            case .instant: return "Instant"
            case .short: return "Short"
            case .normal: return "Normal"
            case .long: return "Long"
            case .veryLong: return "Very Long"
            }
        case .ptBR:
            switch self {
            case .instant: return "Instantâneo"
            case .short: return "Curto"
            case .normal: return "Normal"
            case .long: return "Longo"
            case .veryLong: return "Muito longo"
            }
        case .es:
            switch self {
            case .instant: return "Instantáneo"
            case .short: return "Corto"
            case .normal: return "Normal"
            case .long: return "Largo"
            case .veryLong: return "Muy largo"
            }
        case .sk:
            switch self {
            case .instant: return "Okamžité"
            case .short: return "Krátke"
            case .normal: return "Normálne"
            case .long: return "Dlhé"
            case .veryLong: return "Veľmi dlhé"
            }
        case .de:
            switch self {
            case .instant: return "Sofort"
            case .short: return "Kurz"
            case .normal: return "Normal"
            case .long: return "Lang"
            case .veryLong: return "Sehr lang"
            }
        case .fr:
            switch self {
            case .instant: return "Instantané"
            case .short: return "Court"
            case .normal: return "Normal"
            case .long: return "Long"
            case .veryLong: return "Très long"
            }
        case .it:
            switch self {
            case .instant: return "Istantaneo"
            case .short: return "Breve"
            case .normal: return "Normale"
            case .long: return "Lungo"
            case .veryLong: return "Molto lungo"
            }
        case .ru:
            switch self {
            case .instant: return "Мгновенно"
            case .short: return "Быстро"
            case .normal: return "Обычно"
            case .long: return "Долго"
            case .veryLong: return "Очень долго"
            }
        case .tr:
            switch self {
            case .instant: return "Anında"
            case .short: return "Kısa"
            case .normal: return "Normal"
            case .long: return "Uzun"
            case .veryLong: return "Çok uzun"
            }
        case .ja:
            switch self {
            case .instant: return "即時"
            case .short: return "短い"
            case .normal: return "標準"
            case .long: return "長い"
            case .veryLong: return "非常に長い"
            }
        case .ko:
            switch self {
            case .instant: return "즉시"
            case .short: return "짧게"
            case .normal: return "보통"
            case .long: return "길게"
            case .veryLong: return "매우 길게"
            }
        case .zhHans:
            switch self {
            case .instant: return "即时"
            case .short: return "较短"
            case .normal: return "标准"
            case .long: return "较长"
            case .veryLong: return "极长"
            }
        case .zhTW, .zhHK:
            switch self {
            case .instant: return "即時"
            case .short: return "較短"
            case .normal: return "標準"
            case .long: return "較長"
            case .veryLong: return "極長"
            }
        case .uk:
            switch self {
            case .instant: return "Миттєво"
            case .short: return "Швидко"
            case .normal: return "Звичайно"
            case .long: return "Довго"
            case .veryLong: return "Дуже довго"
            }
        }
    }
}
