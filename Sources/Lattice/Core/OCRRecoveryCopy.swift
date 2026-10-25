// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum OCRRecoveryCopy {
    static func unavailable(language: String) -> String {
        switch language {
        case "pt-BR": return "Não foi possível reconhecer o texto. Tente novamente."
        case "es": return "No se pudo reconocer el texto. Inténtalo de nuevo."
        case "de": return "Text konnte nicht erkannt werden. Bitte erneut versuchen."
        case "fr": return "Impossible de reconnaître le texte. Réessayez."
        case "it": return "Impossibile riconoscere il testo. Riprova."
        case "ja": return "テキストを認識できませんでした。もう一度お試しください。"
        case "ko": return "텍스트를 인식하지 못했습니다. 다시 시도해 주세요."
        case "zh-Hans": return "无法识别文字，请重试。"
        case "zh-TW", "zh-HK": return "無法辨識文字，請重試。"
        case "ru": return "Не удалось распознать текст. Повторите попытку."
        case "uk": return "Не вдалося розпізнати текст. Спробуйте ще раз."
        case "tr": return "Metin tanınamadı. Yeniden deneyin."
        case "sk": return "Text sa nepodarilo rozpoznať. Skúste to znova."
        default: return "Couldn’t recognize text. Try again."
        }
    }
}
