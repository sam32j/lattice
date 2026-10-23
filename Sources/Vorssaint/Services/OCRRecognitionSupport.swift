import Foundation

enum OCRRecognitionSupport {
    static func recognitionLanguages(for languageRawValue: String) -> [String] {
        switch languageRawValue {
        case "pt-BR": return ["pt-BR", "en-US"]
        case "tr": return ["tr-TR", "en-US"]
        case "ru": return ["ru-RU", "en-US"]
        case "es": return ["es-ES", "en-US"]
        case "de": return ["de-DE", "en-US"]
        case "fr": return ["fr-FR", "en-US"]
        case "it": return ["it-IT", "en-US"]
        case "ja": return ["ja-JP", "en-US"]
        case "ko": return ["ko-KR", "en-US"]
        case "uk": return ["uk-UA", "en-US"]
        case "zh-Hans": return ["zh-Hans", "en-US"]
        case "zh-TW", "zh-HK": return ["zh-Hant", "en-US"]
        default: return ["en-US"]
        }
    }


}
