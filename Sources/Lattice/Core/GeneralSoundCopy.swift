// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

enum GeneralSoundCopy {
    static func label(_ language: AppLanguage) -> String {
        switch language {
        case .enUS: return "Play padlock sound on lock or unlock."
        case .ptBR: return "Tocar um som de cadeado ao bloquear ou desbloquear."
        case .es: return "Reproducir un sonido de candado al bloquear o desbloquear."
        case .de: return "Beim Sperren oder Entsperren einen Schlosston abspielen."
        case .fr: return "Jouer un son de cadenas au verrouillage ou au déverrouillage."
        case .it: return "Riproduci un suono di lucchetto al blocco o allo sblocco."
        case .ja: return "ロックまたはロック解除時に南京錠の音を鳴らす。"
        case .ko: return "잠그거나 잠금 해제할 때 자물쇠 소리 재생."
        case .zhHans: return "锁定或解锁时播放挂锁音效。"
        case .zhTW, .zhHK: return "鎖定或解鎖時播放掛鎖音效。"
        case .ru: return "Воспроизводить звук замка при блокировке или разблокировке."
        case .uk: return "Відтворювати звук замка під час блокування або розблокування."
        case .tr: return "Kilitleme veya kilit açmada asma kilit sesi çal."
        case .sk: return "Prehrať zvuk zámky pri zamknutí alebo odomknutí."
        }
    }
}
