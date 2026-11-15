// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct ScreenshotEditorRefinementStrings {
    let selectText, aspectRatio, freeCrop, quickLook, rotateLeft, flipHorizontal, printImage, openInMail, cornerRadius: String
    let undo, redo, fitImage, actualSize, dragPlace, saveChanges: String
}

extension FeatureStrings {
    static func editorRefinements(_ language: AppLanguage) -> ScreenshotEditorRefinementStrings {
        switch language {
        case .enUS:
            .init(selectText: "Select recognized text", aspectRatio: "Aspect ratio", freeCrop: "Freeform", quickLook: "Quick Look",
                  rotateLeft: "Rotate Left", flipHorizontal: "Flip Horizontal", printImage: "Print…", openInMail: "Open in Mail…", cornerRadius: "Corner radius",
                  undo: "Undo", redo: "Redo", fitImage: "Fit image", actualSize: "Actual size", dragPlace: "Drag & place", saveChanges: "Save Changes")
        case .ptBR:
            .init(selectText: "Selecionar texto reconhecido", aspectRatio: "Proporção", freeCrop: "Livre", quickLook: "Visualização Rápida",
                  rotateLeft: "Girar à esquerda", flipHorizontal: "Virar horizontalmente", printImage: "Imprimir…", openInMail: "Abrir no Mail…", cornerRadius: "Cantos arredondados",
                  undo: "Desfazer", redo: "Refazer", fitImage: "Ajustar imagem", actualSize: "Tamanho real", dragPlace: "Arraste e solte", saveChanges: "Salvar alterações")
        case .tr:
            .init(selectText: "Tanınan metni seç", aspectRatio: "En boy oranı", freeCrop: "Serbest", quickLook: "Göz At",
                  rotateLeft: "Sola döndür", flipHorizontal: "Yatay çevir", printImage: "Yazdır…", openInMail: "Mail’de aç…", cornerRadius: "Köşe yuvarlama",
                  undo: "Geri al", redo: "Yinele", fitImage: "Görüntüyü sığdır", actualSize: "Gerçek boyut", dragPlace: "Sürükle ve yerleştir", saveChanges: "Değişiklikleri kaydet")
        case .ru:
            .init(selectText: "Выбрать распознанный текст", aspectRatio: "Соотношение сторон", freeCrop: "Произвольно", quickLook: "Быстрый просмотр",
                  rotateLeft: "Повернуть влево", flipHorizontal: "Отразить по горизонтали", printImage: "Напечатать…", openInMail: "Открыть в Почте…", cornerRadius: "Скругление углов",
                  undo: "Отменить", redo: "Повторить", fitImage: "Вписать изображение", actualSize: "Реальный размер", dragPlace: "Перетащить и разместить", saveChanges: "Сохранить изменения")
        case .es:
            .init(selectText: "Seleccionar texto reconocido", aspectRatio: "Relación de aspecto", freeCrop: "Libre", quickLook: "Vista Rápida",
                  rotateLeft: "Girar a la izquierda", flipHorizontal: "Voltear horizontalmente", printImage: "Imprimir…", openInMail: "Abrir en Mail…", cornerRadius: "Esquinas redondeadas",
                  undo: "Deshacer", redo: "Rehacer", fitImage: "Ajustar imagen", actualSize: "Tamaño real", dragPlace: "Arrastra y coloca", saveChanges: "Guardar cambios")
        case .sk:
            .init(selectText: "Vybrať rozpoznaný text", aspectRatio: "Pomer strán", freeCrop: "Voľný", quickLook: "Rýchly náhľad",
                  rotateLeft: "Otočiť doľava", flipHorizontal: "Prevrátiť vodorovne", printImage: "Tlačiť…", openInMail: "Otvoriť v Maile…", cornerRadius: "Zaoblenie rohov",
                  undo: "Späť", redo: "Znova", fitImage: "Prispôsobiť obrázok", actualSize: "Skutočná veľkosť", dragPlace: "Potiahnite a umiestnite", saveChanges: "Uložiť zmeny")
        case .de:
            .init(selectText: "Erkannten Text auswählen", aspectRatio: "Seitenverhältnis", freeCrop: "Frei", quickLook: "Übersicht",
                  rotateLeft: "Nach links drehen", flipHorizontal: "Horizontal spiegeln", printImage: "Drucken…", openInMail: "In Mail öffnen…", cornerRadius: "Ecken abrunden",
                  undo: "Rückgängig", redo: "Wiederholen", fitImage: "Bild einpassen", actualSize: "Originalgröße", dragPlace: "Ziehen & ablegen", saveChanges: "Änderungen sichern")
        case .fr:
            .init(selectText: "Sélectionner le texte reconnu", aspectRatio: "Proportions", freeCrop: "Libre", quickLook: "Coup d’œil",
                  rotateLeft: "Pivoter à gauche", flipHorizontal: "Retourner horizontalement", printImage: "Imprimer…", openInMail: "Ouvrir dans Mail…", cornerRadius: "Arrondi des angles",
                  undo: "Annuler", redo: "Rétablir", fitImage: "Adapter l’image", actualSize: "Taille réelle", dragPlace: "Glisser et déposer", saveChanges: "Enregistrer les modifications")
        case .it:
            .init(selectText: "Seleziona il testo riconosciuto", aspectRatio: "Proporzioni", freeCrop: "Libere", quickLook: "Visualizzazione rapida",
                  rotateLeft: "Ruota a sinistra", flipHorizontal: "Capovolgi orizzontalmente", printImage: "Stampa…", openInMail: "Apri in Mail…", cornerRadius: "Raggio angolo",
                  undo: "Annulla", redo: "Ripristina", fitImage: "Adatta immagine", actualSize: "Dimensioni reali", dragPlace: "Trascina e posiziona", saveChanges: "Salva modifiche")
        case .ja:
            .init(selectText: "認識したテキストを選択", aspectRatio: "縦横比", freeCrop: "自由", quickLook: "クイックルック",
                  rotateLeft: "左に回転", flipHorizontal: "左右反転", printImage: "プリント…", openInMail: "メールで開く…", cornerRadius: "角丸",
                  undo: "取り消す", redo: "やり直す", fitImage: "画像を合わせる", actualSize: "実際のサイズ", dragPlace: "ドラッグして配置", saveChanges: "変更を保存")
        case .ko:
            .init(selectText: "인식된 텍스트 선택", aspectRatio: "화면 비율", freeCrop: "자유형", quickLook: "훑어보기",
                  rotateLeft: "왼쪽으로 회전", flipHorizontal: "좌우 뒤집기", printImage: "프린트…", openInMail: "Mail에서 열기…", cornerRadius: "모서리 둥글게",
                  undo: "실행 취소", redo: "다시 실행", fitImage: "이미지 맞추기", actualSize: "실제 크기", dragPlace: "드래그하여 놓기", saveChanges: "변경 사항 저장")
        case .uk:
            .init(selectText: "Вибрати розпізнаний текст", aspectRatio: "Співвідношення сторін", freeCrop: "Довільне", quickLook: "Швидкий перегляд",
                  rotateLeft: "Повернути ліворуч", flipHorizontal: "Віддзеркалити горизонтально", printImage: "Друкувати…", openInMail: "Відкрити в Пошті…", cornerRadius: "Скруглення кутів",
                  undo: "Скасувати", redo: "Повторити", fitImage: "Вписати зображення", actualSize: "Справжній розмір", dragPlace: "Перетягнути й розмістити", saveChanges: "Зберегти зміни")
        case .zhHans:
            .init(selectText: "选择识别的文本", aspectRatio: "纵横比", freeCrop: "自由", quickLook: "快速查看",
                  rotateLeft: "向左旋转", flipHorizontal: "水平翻转", printImage: "打印…", openInMail: "在邮件中打开…", cornerRadius: "圆角",
                  undo: "撤销", redo: "重做", fitImage: "适合窗口", actualSize: "实际大小", dragPlace: "拖放到目标位置", saveChanges: "保存更改")
        case .zhTW:
            .init(selectText: "選取辨識的文字", aspectRatio: "長寬比", freeCrop: "任意", quickLook: "快速查看",
                  rotateLeft: "向左旋轉", flipHorizontal: "水平翻轉", printImage: "列印…", openInMail: "在郵件中打開…", cornerRadius: "圓角",
                  undo: "還原", redo: "重做", fitImage: "符合視窗", actualSize: "實際大小", dragPlace: "拖放至目標位置", saveChanges: "儲存變更")
        case .zhHK:
            .init(selectText: "選取辨識的文字", aspectRatio: "長寬比", freeCrop: "自由", quickLook: "快速查看",
                  rotateLeft: "向左旋轉", flipHorizontal: "水平翻轉", printImage: "列印…", openInMail: "在郵件中開啟…", cornerRadius: "圓角",
                  undo: "還原", redo: "重做", fitImage: "符合視窗", actualSize: "實際大小", dragPlace: "拖放到目標位置", saveChanges: "儲存變更")
        }
    }
}
