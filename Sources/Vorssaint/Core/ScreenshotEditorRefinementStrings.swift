// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct ScreenshotEditorRefinementStrings {
    let selectText, aspectRatio, freeCrop, quickLook, rotateLeft, flipHorizontal, printImage, openInMail: String
}

extension FeatureStrings {
    static func editorRefinements(_ language: AppLanguage) -> ScreenshotEditorRefinementStrings {
        switch language {
        case .enUS:
            .init(selectText: "Select recognized text", aspectRatio: "Aspect ratio", freeCrop: "Freeform", quickLook: "Quick Look",
                  rotateLeft: "Rotate Left", flipHorizontal: "Flip Horizontal", printImage: "Print…", openInMail: "Open in Mail…")
        case .ptBR:
            .init(selectText: "Selecionar texto reconhecido", aspectRatio: "Proporção", freeCrop: "Livre", quickLook: "Visualização Rápida",
                  rotateLeft: "Girar à esquerda", flipHorizontal: "Virar horizontalmente", printImage: "Imprimir…", openInMail: "Abrir no Mail…")
        case .tr:
            .init(selectText: "Tanınan metni seç", aspectRatio: "En boy oranı", freeCrop: "Serbest", quickLook: "Göz At",
                  rotateLeft: "Sola döndür", flipHorizontal: "Yatay çevir", printImage: "Yazdır…", openInMail: "Mail’de aç…")
        case .ru:
            .init(selectText: "Выбрать распознанный текст", aspectRatio: "Соотношение сторон", freeCrop: "Произвольно", quickLook: "Быстрый просмотр",
                  rotateLeft: "Повернуть влево", flipHorizontal: "Отразить по горизонтали", printImage: "Напечатать…", openInMail: "Открыть в Почте…")
        case .es:
            .init(selectText: "Seleccionar texto reconocido", aspectRatio: "Relación de aspecto", freeCrop: "Libre", quickLook: "Vista Rápida",
                  rotateLeft: "Girar a la izquierda", flipHorizontal: "Voltear horizontalmente", printImage: "Imprimir…", openInMail: "Abrir en Mail…")
        case .sk:
            .init(selectText: "Vybrať rozpoznaný text", aspectRatio: "Pomer strán", freeCrop: "Voľný", quickLook: "Rýchly náhľad",
                  rotateLeft: "Otočiť doľava", flipHorizontal: "Prevrátiť vodorovne", printImage: "Tlačiť…", openInMail: "Otvoriť v Maile…")
        case .de:
            .init(selectText: "Erkannten Text auswählen", aspectRatio: "Seitenverhältnis", freeCrop: "Frei", quickLook: "Übersicht",
                  rotateLeft: "Nach links drehen", flipHorizontal: "Horizontal spiegeln", printImage: "Drucken…", openInMail: "In Mail öffnen…")
        case .fr:
            .init(selectText: "Sélectionner le texte reconnu", aspectRatio: "Proportions", freeCrop: "Libre", quickLook: "Coup d’œil",
                  rotateLeft: "Pivoter à gauche", flipHorizontal: "Retourner horizontalement", printImage: "Imprimer…", openInMail: "Ouvrir dans Mail…")
        case .it:
            .init(selectText: "Seleziona il testo riconosciuto", aspectRatio: "Proporzioni", freeCrop: "Libere", quickLook: "Visualizzazione rapida",
                  rotateLeft: "Ruota a sinistra", flipHorizontal: "Capovolgi orizzontalmente", printImage: "Stampa…", openInMail: "Apri in Mail…")
        case .ja:
            .init(selectText: "認識したテキストを選択", aspectRatio: "縦横比", freeCrop: "自由", quickLook: "クイックルック",
                  rotateLeft: "左に回転", flipHorizontal: "左右反転", printImage: "プリント…", openInMail: "メールで開く…")
        case .ko:
            .init(selectText: "인식된 텍스트 선택", aspectRatio: "화면 비율", freeCrop: "자유형", quickLook: "훑어보기",
                  rotateLeft: "왼쪽으로 회전", flipHorizontal: "좌우 뒤집기", printImage: "프린트…", openInMail: "Mail에서 열기…")
        case .uk:
            .init(selectText: "Вибрати розпізнаний текст", aspectRatio: "Співвідношення сторін", freeCrop: "Довільне", quickLook: "Швидкий перегляд",
                  rotateLeft: "Повернути ліворуч", flipHorizontal: "Віддзеркалити горизонтально", printImage: "Друкувати…", openInMail: "Відкрити в Пошті…")
        case .zhHans:
            .init(selectText: "选择识别的文本", aspectRatio: "纵横比", freeCrop: "自由", quickLook: "快速查看",
                  rotateLeft: "向左旋转", flipHorizontal: "水平翻转", printImage: "打印…", openInMail: "在邮件中打开…")
        case .zhTW:
            .init(selectText: "選取辨識的文字", aspectRatio: "長寬比", freeCrop: "任意", quickLook: "快速查看",
                  rotateLeft: "向左旋轉", flipHorizontal: "水平翻轉", printImage: "列印…", openInMail: "在郵件中打開…")
        case .zhHK:
            .init(selectText: "選取辨識的文字", aspectRatio: "長寬比", freeCrop: "自由", quickLook: "快速查看",
                  rotateLeft: "向左旋轉", flipHorizontal: "水平翻轉", printImage: "列印…", openInMail: "在郵件中開啟…")
        }
    }
}
