// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

extension SnippetFeatureStrings {
    /// Copy feedback belongs to the snippet action, in both help and VoiceOver.
    static func copyLabels(for language: AppLanguage) -> (copyExpansion: String, copied: String) {
        switch language {
        case .enUS: return ("Copy expansion", "Copied")
        case .ptBR: return ("Copiar expansão", "Copiado")
        case .es: return ("Copiar expansión", "Copiado")
        case .sk: return ("Kopírovať rozšírený text", "Skopírované")
        case .de: return ("Erweiterten Text kopieren", "Kopiert")
        case .fr: return ("Copier le texte développé", "Copié")
        case .it: return ("Copia testo espanso", "Copiato")
        case .ru: return ("Копировать развёрнутый текст", "Скопировано")
        case .tr: return ("Genişletilmiş metni kopyala", "Kopyalandı")
        case .ja: return ("展開したテキストをコピー", "コピーしました")
        case .ko: return ("확장된 텍스트 복사", "복사됨")
        case .zhHans: return ("拷贝展开文本", "已拷贝")
        case .zhTW: return ("拷貝展開文字", "已拷貝")
        case .zhHK: return ("複製展開文字", "已複製")
        case .uk: return ("Копіювати розгорнутий текст", "Скопійовано")
        }
    }
}
