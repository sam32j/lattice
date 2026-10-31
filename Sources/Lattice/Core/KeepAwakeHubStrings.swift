// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// Visible controls and spoken feedback share the same app-language copy.
struct KeepAwakeHubStrings {
    let stop: String
    let startHour: String
    let options: String
    let open: String
    let closed: String
    let hide: String
    let restoreFailed: String
    let activationFailed: String
    let updateFailed: String
    let paused: String
    let on: String
    let off: String
    let stayOn: String
    let setEndTime: String
    let endTime: String
    let tomorrow: String
    let preventLidSleep: String
    let unsupportedLid: String
    let stopStatus: String
    let onUntil: String
}

extension FeatureStrings {
    static func keepAwakeHub(_ language: AppLanguage) -> KeepAwakeHubStrings {
        switch language {
        case .enUS: return KeepAwakeHubStrings(
            stop: "Stop Stay Awake", startHour: "Start Stay Awake for 1 hour",
            options: "Stay Awake options", open: "Open",
            closed: "Closed", hide: "Hide Stay Awake",
            restoreFailed: "Couldn’t restore normal sleep. Try Stop again.", activationFailed: "Couldn’t update sleep prevention. Please try again.",
            updateFailed: "Couldn’t update Stay Awake", paused: "Paused while the screen is locked",
            on: "On", off: "Off",
            stayOn: "Stay On", setEndTime: "Set End Time...",
            endTime: "End time", tomorrow: "Tomorrow",
            preventLidSleep: "Prevent sleep with lid closed", unsupportedLid: "This Mac does not have a supported built-in lid.",
            stopStatus: "Stop Stay Awake: %@", onUntil: "On until %@"
        )
        case .ptBR: return KeepAwakeHubStrings(
            stop: "Parar Ficar acordado", startHour: "Ativar Ficar acordado por 1 hora",
            options: "Opções de Ficar acordado", open: "Aberto",
            closed: "Fechado", hide: "Ocultar Ficar acordado",
            restoreFailed: "Não foi possível restaurar o repouso normal. Tente Parar novamente.", activationFailed: "Não foi possível atualizar a prevenção de repouso. Tente novamente.",
            updateFailed: "Não foi possível atualizar Ficar acordado", paused: "Pausado enquanto a tela está bloqueada",
            on: "Ativado", off: "Desativado",
            stayOn: "Manter ativado", setEndTime: "Definir horário de término...",
            endTime: "Horário de término", tomorrow: "Amanhã",
            preventLidSleep: "Impedir repouso com a tampa fechada", unsupportedLid: "Este Mac não tem uma tampa integrada compatível.",
            stopStatus: "Parar Ficar acordado: %@", onUntil: "Ativo até %@"
        )
        case .es: return KeepAwakeHubStrings(
            stop: "Detener Mantener despierto", startHour: "Activar Mantener despierto durante 1 hora",
            options: "Opciones de Mantener despierto", open: "Abierto",
            closed: "Cerrado", hide: "Ocultar Mantener despierto",
            restoreFailed: "No se pudo restaurar el reposo normal. Vuelve a pulsar Detener.", activationFailed: "No se pudo actualizar la prevención del reposo. Inténtalo de nuevo.",
            updateFailed: "No se pudo actualizar Mantener despierto", paused: "En pausa mientras la pantalla está bloqueada",
            on: "Activado", off: "Desactivado",
            stayOn: "Mantener activado", setEndTime: "Establecer hora de fin...",
            endTime: "Hora de fin", tomorrow: "Mañana",
            preventLidSleep: "Evitar reposo con la tapa cerrada", unsupportedLid: "Este Mac no tiene una tapa integrada compatible.",
            stopStatus: "Detener Mantener despierto: %@", onUntil: "Activo hasta %@"
        )
        case .fr: return KeepAwakeHubStrings(
            stop: "Arrêter Rester éveillé", startHour: "Activer Rester éveillé pendant 1 heure",
            options: "Options de Rester éveillé", open: "Ouvert",
            closed: "Fermé", hide: "Masquer Rester éveillé",
            restoreFailed: "Impossible de rétablir la veille normale. Réessayez Arrêter.", activationFailed: "Impossible de modifier la prévention de veille. Réessayez.",
            updateFailed: "Impossible de modifier Rester éveillé", paused: "En pause lorsque l’écran est verrouillé",
            on: "Activé", off: "Désactivé",
            stayOn: "Rester activé", setEndTime: "Définir l’heure de fin...",
            endTime: "Heure de fin", tomorrow: "Demain",
            preventLidSleep: "Empêcher la veille avec le couvercle fermé", unsupportedLid: "Ce Mac ne possède pas de couvercle intégré compatible.",
            stopStatus: "Arrêter Rester éveillé : %@", onUntil: "Actif jusqu’à %@"
        )
        case .de: return KeepAwakeHubStrings(
            stop: "Wach bleiben beenden", startHour: "Wach bleiben für 1 Stunde starten",
            options: "Optionen für Wach bleiben", open: "Geöffnet",
            closed: "Geschlossen", hide: "Wach bleiben ausblenden",
            restoreFailed: "Der normale Ruhezustand konnte nicht wiederhergestellt werden. Erneut stoppen.", activationFailed: "Die Ruhezustandsverhinderung konnte nicht aktualisiert werden. Erneut versuchen.",
            updateFailed: "Wach bleiben konnte nicht aktualisiert werden", paused: "Pausiert, während der Bildschirm gesperrt ist",
            on: "Ein", off: "Aus",
            stayOn: "Dauerhaft an", setEndTime: "Endzeit festlegen...",
            endTime: "Endzeit", tomorrow: "Morgen",
            preventLidSleep: "Ruhezustand bei geschlossenem Deckel verhindern", unsupportedLid: "Dieser Mac hat keinen unterstützten integrierten Deckel.",
            stopStatus: "Wach bleiben beenden: %@", onUntil: "Aktiv bis %@"
        )
        case .it: return KeepAwakeHubStrings(
            stop: "Interrompi Rimani attivo", startHour: "Avvia Rimani attivo per 1 ora",
            options: "Opzioni di Rimani attivo", open: "Aperto",
            closed: "Chiuso", hide: "Nascondi Rimani attivo",
            restoreFailed: "Impossibile ripristinare lo stop normale. Riprova a interrompere.", activationFailed: "Impossibile aggiornare la prevenzione dello stop. Riprova.",
            updateFailed: "Impossibile aggiornare Rimani attivo", paused: "In pausa mentre lo schermo è bloccato",
            on: "Attivo", off: "Disattivo",
            stayOn: "Rimani attivo", setEndTime: "Imposta ora di fine...",
            endTime: "Ora di fine", tomorrow: "Domani",
            preventLidSleep: "Impedisci lo stop con il coperchio chiuso", unsupportedLid: "Questo Mac non ha un coperchio integrato supportato.",
            stopStatus: "Interrompi Rimani attivo: %@", onUntil: "Attivo fino alle %@"
        )
        case .sk: return KeepAwakeHubStrings(
            stop: "Zastaviť bdelý režim", startHour: "Spustiť bdelý režim na 1 hodinu",
            options: "Možnosti bdelého režimu", open: "Otvorené",
            closed: "Zatvorené", hide: "Skryť bdelý režim",
            restoreFailed: "Normálne uspávanie sa nepodarilo obnoviť. Skúste znova zastaviť.", activationFailed: "Zabránenie uspávaniu sa nepodarilo aktualizovať. Skúste to znova.",
            updateFailed: "Bdelý režim sa nepodarilo aktualizovať", paused: "Pozastavené, kým je obrazovka zamknutá",
            on: "Zapnuté", off: "Vypnuté",
            stayOn: "Ponechať zapnuté", setEndTime: "Nastaviť čas ukončenia...",
            endTime: "Čas ukončenia", tomorrow: "Zajtra",
            preventLidSleep: "Zabrániť uspatiu so zatvoreným vekom", unsupportedLid: "Tento Mac nemá podporované vstavané veko.",
            stopStatus: "Zastaviť bdelý režim: %@", onUntil: "Aktívne do %@"
        )
        case .ru: return KeepAwakeHubStrings(
            stop: "Остановить бодрствование", startHour: "Включить бодрствование на 1 час",
            options: "Параметры бодрствования", open: "Открыто",
            closed: "Закрыто", hide: "Скрыть бодрствование",
            restoreFailed: "Не удалось восстановить обычный сон. Попробуйте остановить ещё раз.", activationFailed: "Не удалось изменить предотвращение сна. Повторите попытку.",
            updateFailed: "Не удалось обновить бодрствование", paused: "Приостановлено, пока экран заблокирован",
            on: "Вкл.", off: "Выкл.",
            stayOn: "Оставить включённым", setEndTime: "Задать время окончания...",
            endTime: "Время окончания", tomorrow: "Завтра",
            preventLidSleep: "Предотвращать сон при закрытой крышке", unsupportedLid: "У этого Mac нет поддерживаемой встроенной крышки.",
            stopStatus: "Остановить бодрствование: %@", onUntil: "Активно до %@"
        )
        case .uk: return KeepAwakeHubStrings(
            stop: "Зупинити режим неспання", startHour: "Увімкнути режим неспання на 1 годину",
            options: "Параметри режиму неспання", open: "Відкрито",
            closed: "Закрито", hide: "Приховати режим неспання",
            restoreFailed: "Не вдалося відновити звичайний сон. Спробуйте зупинити ще раз.", activationFailed: "Не вдалося змінити запобігання сну. Спробуйте ще раз.",
            updateFailed: "Не вдалося оновити режим неспання", paused: "Призупинено, поки екран заблоковано",
            on: "Увімкнено", off: "Вимкнено",
            stayOn: "Залишити ввімкненим", setEndTime: "Задати час завершення...",
            endTime: "Час завершення", tomorrow: "Завтра",
            preventLidSleep: "Запобігати сну із закритою кришкою", unsupportedLid: "Цей Mac не має підтримуваної вбудованої кришки.",
            stopStatus: "Зупинити режим неспання: %@", onUntil: "Активно до %@"
        )
        case .tr: return KeepAwakeHubStrings(
            stop: "Uyanık Tut’u durdur", startHour: "Uyanık Tut’u 1 saatliğine başlat",
            options: "Uyanık Tut seçenekleri", open: "Açık",
            closed: "Kapalı", hide: "Uyanık Tut’u gizle",
            restoreFailed: "Normal uyku geri yüklenemedi. Durdur’u yeniden deneyin.", activationFailed: "Uyku engelleme güncellenemedi. Lütfen yeniden deneyin.",
            updateFailed: "Uyanık Tut güncellenemedi", paused: "Ekran kilitliyken duraklatıldı",
            on: "Açık", off: "Kapalı",
            stayOn: "Açık tut", setEndTime: "Bitiş saatini ayarla...",
            endTime: "Bitiş saati", tomorrow: "Yarın",
            preventLidSleep: "Kapak kapalıyken uykuyu engelle", unsupportedLid: "Bu Mac’te desteklenen yerleşik kapak yok.",
            stopStatus: "Uyanık Tut’u durdur: %@", onUntil: "%@ saatine kadar açık"
        )
        case .ja: return KeepAwakeHubStrings(
            stop: "スリープ防止を停止", startHour: "スリープ防止を1時間開始",
            options: "スリープ防止のオプション", open: "開いています",
            closed: "閉じています", hide: "スリープ防止を非表示",
            restoreFailed: "通常のスリープに戻せませんでした。もう一度停止してください。", activationFailed: "スリープ防止を更新できませんでした。もう一度お試しください。",
            updateFailed: "スリープ防止を更新できませんでした", paused: "画面のロック中は一時停止",
            on: "オン", off: "オフ",
            stayOn: "オンのままにする", setEndTime: "終了時刻を設定...",
            endTime: "終了時刻", tomorrow: "明日",
            preventLidSleep: "ふたを閉じてもスリープさせない", unsupportedLid: "このMacには対応する内蔵のふたがありません。",
            stopStatus: "スリープ防止を停止：%@", onUntil: "%@までオン"
        )
        case .ko: return KeepAwakeHubStrings(
            stop: "잠자기 방지 중지", startHour: "잠자기 방지를 1시간 시작",
            options: "잠자기 방지 옵션", open: "열림",
            closed: "닫힘", hide: "잠자기 방지 숨기기",
            restoreFailed: "일반 잠자기로 복원할 수 없습니다. 다시 중지해 주세요.", activationFailed: "잠자기 방지를 업데이트할 수 없습니다. 다시 시도해 주세요.",
            updateFailed: "잠자기 방지를 업데이트할 수 없습니다", paused: "화면이 잠겨 있는 동안 일시 정지됨",
            on: "켬", off: "끔",
            stayOn: "계속 켜기", setEndTime: "종료 시간 설정...",
            endTime: "종료 시간", tomorrow: "내일",
            preventLidSleep: "덮개가 닫혀 있어도 잠자기 방지", unsupportedLid: "이 Mac에는 지원되는 내장 덮개가 없습니다.",
            stopStatus: "잠자기 방지 중지: %@", onUntil: "%@까지 켬"
        )
        case .zhHans: return KeepAwakeHubStrings(
            stop: "停止保持唤醒", startHour: "启动保持唤醒 1 小时",
            options: "保持唤醒选项", open: "已打开",
            closed: "已关闭", hide: "隐藏保持唤醒",
            restoreFailed: "无法恢复正常睡眠。请再次尝试停止。", activationFailed: "无法更新睡眠防止设置。请重试。",
            updateFailed: "无法更新保持唤醒", paused: "屏幕锁定时暂停",
            on: "开启", off: "关闭",
            stayOn: "持续开启", setEndTime: "设置结束时间...",
            endTime: "结束时间", tomorrow: "明天",
            preventLidSleep: "合上盖子时防止睡眠", unsupportedLid: "此 Mac 没有受支持的内置盖子。",
            stopStatus: "停止保持唤醒：%@", onUntil: "开启至 %@"
        )
        case .zhTW: return KeepAwakeHubStrings(
            stop: "停止保持喚醒", startHour: "啟動保持喚醒 1 小時",
            options: "保持喚醒選項", open: "已開啟",
            closed: "已關閉", hide: "隱藏保持喚醒",
            restoreFailed: "無法恢復正常睡眠。請再次嘗試停止。", activationFailed: "無法更新防止睡眠設定。請再試一次。",
            updateFailed: "無法更新保持喚醒", paused: "螢幕鎖定時暫停",
            on: "開啟", off: "關閉",
            stayOn: "持續開啟", setEndTime: "設定結束時間...",
            endTime: "結束時間", tomorrow: "明天",
            preventLidSleep: "闔上蓋子時防止睡眠", unsupportedLid: "此 Mac 沒有支援的內建蓋子。",
            stopStatus: "停止保持喚醒：%@", onUntil: "開啟至 %@"
        )
        case .zhHK: return KeepAwakeHubStrings(
            stop: "停止保持喚醒", startHour: "啟動保持喚醒 1 小時",
            options: "保持喚醒選項", open: "已開啟",
            closed: "已關閉", hide: "隱藏保持喚醒",
            restoreFailed: "無法恢復正常睡眠。請再次嘗試停止。", activationFailed: "無法更新防止睡眠設定。請重試。",
            updateFailed: "無法更新保持喚醒", paused: "螢幕鎖定時暫停",
            on: "開啟", off: "關閉",
            stayOn: "持續開啟", setEndTime: "設定結束時間...",
            endTime: "結束時間", tomorrow: "明天",
            preventLidSleep: "合上蓋子時防止睡眠", unsupportedLid: "此 Mac 沒有支援的內置蓋子。",
            stopStatus: "停止保持喚醒：%@", onUntil: "開啟至 %@"
        )
        }
    }
}
