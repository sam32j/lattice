// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct DiskExclusionStrings {
    let listTitle: String
    let sheetTitle: String
    let savedSection: String
    let discoverySection: String
    let noSavedDisks: String
    let noDiscoveredDisks: String
    let addButton: String
    let removeButton: String
    let emptyTitle: String
    let emptyDescription: String
    let caption: String
}

extension FeatureStrings {
    static func diskExclusions(_ language: AppLanguage) -> DiskExclusionStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        case .uk: return .uk
        }
    }
}

extension DiskExclusionStrings {
    static let enUS = DiskExclusionStrings(
        listTitle: "Don’t eject these disks…",
        sheetTitle: "Don’t eject these disks…",
        savedSection: "Excluded disks",
        discoverySection: "Connected disks",
        noSavedDisks: "No excluded disks",
        noDiscoveredDisks: "No other connected disks",
        addButton: "Add",
        removeButton: "Remove",
        emptyTitle: "No Disks Available",
        emptyDescription: "Connect an external disk to exclude it from being ejected.",
        caption: "Disks in this list are never unmounted when using Eject all disks."
    )

    static let ptBR = DiskExclusionStrings(
        listTitle: "Não ejetar estes discos…",
        sheetTitle: "Não ejetar estes discos…",
        savedSection: "Discos excluídos",
        discoverySection: "Discos conectados",
        noSavedDisks: "Nenhum disco excluído",
        noDiscoveredDisks: "Nenhum outro disco conectado",
        addButton: "Adicionar",
        removeButton: "Remover",
        emptyTitle: "Nenhum disco disponível",
        emptyDescription: "Conecte um disco externo para excluí-lo da ejeção.",
        caption: "Os discos nesta lista nunca são desmontados ao ejetar todos os discos."
    )

    static let tr = DiskExclusionStrings(
        listTitle: "Bu diskleri çıkarma…",
        sheetTitle: "Bu diskleri çıkarma…",
        savedSection: "Hariç tutulan sürücüler",
        discoverySection: "Bağlı sürücüler",
        noSavedDisks: "Hariç tutulan sürücü yok",
        noDiscoveredDisks: "Başka bağlı sürücü yok",
        addButton: "Ekle",
        removeButton: "Kaldır",
        emptyTitle: "Kullanılabilir Disk Yok",
        emptyDescription: "Çıkarılmasını önlemek için harici bir disk bağlayın.",
        caption: "Bu listedeki sürücüler Tüm diskleri çıkar kullanılırken hiçbir zaman çıkarılmaz."
    )

    static let ru = DiskExclusionStrings(
        listTitle: "Не извлекать эти диски…",
        sheetTitle: "Не извлекать эти диски…",
        savedSection: "Исключённые диски",
        discoverySection: "Подключённые диски",
        noSavedDisks: "Нет исключённых дисков",
        noDiscoveredDisks: "Нет других подключённых дисков",
        addButton: "Добавить",
        removeButton: "Удалить",
        emptyTitle: "Нет доступных дисков",
        emptyDescription: "Подключите внешний диск, чтобы исключить его из извлечения.",
        caption: "Диски из этого списка никогда не извлекаются при действии «Извлечь все диски»."
    )

    static let es = DiskExclusionStrings(
        listTitle: "No expulsar estos discos…",
        sheetTitle: "No expulsar estos discos…",
        savedSection: "Discos excluidos",
        discoverySection: "Discos conectados",
        noSavedDisks: "No hay discos excluidos",
        noDiscoveredDisks: "No hay otros discos conectados",
        addButton: "Añadir",
        removeButton: "Quitar",
        emptyTitle: "No hay discos disponibles",
        emptyDescription: "Conecta un disco externo para excluirlo de la expulsión.",
        caption: "Los discos de esta lista nunca se expulsan al expulsar todos los discos."
    )

    static let sk = DiskExclusionStrings(
        listTitle: "Nevysúvať tieto disky…",
        sheetTitle: "Nevysúvať tieto disky…",
        savedSection: "Vylúčené disky",
        discoverySection: "Pripojené disky",
        noSavedDisks: "Žiadne vylúčené disky",
        noDiscoveredDisks: "Žiadne ďalšie pripojené disky",
        addButton: "Pridať",
        removeButton: "Odstrániť",
        emptyTitle: "Žiadne dostupné disky",
        emptyDescription: "Pripojte externý disk a vylúčte ho z vysunutia.",
        caption: "Disky v tomto zozname sa nikdy neodpoja pri použití Vysunúť všetky disky."
    )

    static let de = DiskExclusionStrings(
        listTitle: "Diese Laufwerke nicht auswerfen…",
        sheetTitle: "Diese Laufwerke nicht auswerfen…",
        savedSection: "Ausgenommene Laufwerke",
        discoverySection: "Verbundene Laufwerke",
        noSavedDisks: "Keine ausgenommenen Laufwerke",
        noDiscoveredDisks: "Keine weiteren verbundenen Laufwerke",
        addButton: "Hinzufügen",
        removeButton: "Entfernen",
        emptyTitle: "Keine Volumes verfügbar",
        emptyDescription: "Schließe ein externes Laufwerk an, um es vom Auswerfen auszuschließen.",
        caption: "Laufwerke in dieser Liste werden beim Auswerfen aller Festplatten niemals ausgeworfen."
    )

    static let fr = DiskExclusionStrings(
        listTitle: "Ne pas éjecter ces disques…",
        sheetTitle: "Ne pas éjecter ces disques…",
        savedSection: "Disques exclus",
        discoverySection: "Disques connectés",
        noSavedDisks: "Aucun disque exclu",
        noDiscoveredDisks: "Aucun autre disque connecté",
        addButton: "Ajouter",
        removeButton: "Retirer",
        emptyTitle: "Aucun disque disponible",
        emptyDescription: "Connectez un disque externe pour l’exclure de l’éjection.",
        caption: "Les disques de cette liste ne sont jamais éjectés lors de l’éjection de tous les disques."
    )

    static let it = DiskExclusionStrings(
        listTitle: "Non espellere questi dischi…",
        sheetTitle: "Non espellere questi dischi…",
        savedSection: "Dischi esclusi",
        discoverySection: "Dischi collegati",
        noSavedDisks: "Nessun disco escluso",
        noDiscoveredDisks: "Nessun altro disco collegato",
        addButton: "Aggiungi",
        removeButton: "Rimuovi",
        emptyTitle: "Nessun disco disponibile",
        emptyDescription: "Collega un disco esterno per escluderlo dall’espulsione.",
        caption: "I dischi in questo elenco non vengono mai espulsi quando si espellono tutti i dischi."
    )

    static let ja = DiskExclusionStrings(
        listTitle: "これらのディスクを取り出さない…",
        sheetTitle: "これらのディスクを取り出さない…",
        savedSection: "除外するドライブ",
        discoverySection: "接続中のドライブ",
        noSavedDisks: "除外されたドライブはありません",
        noDiscoveredDisks: "他の接続中ドライブはありません",
        addButton: "追加",
        removeButton: "削除",
        emptyTitle: "利用可能なディスクがありません",
        emptyDescription: "取り出しから除外する外部ディスクを接続してください。",
        caption: "このリストにあるドライブは「すべてのディスクを取り出す」を実行しても取り出されません。"
    )

    static let ko = DiskExclusionStrings(
        listTitle: "이 디스크 추출 안 함…",
        sheetTitle: "이 디스크 추출 안 함…",
        savedSection: "제외된 드라이브",
        discoverySection: "연결된 드라이브",
        noSavedDisks: "제외된 드라이브 없음",
        noDiscoveredDisks: "연결된 다른 드라이브 없음",
        addButton: "추가",
        removeButton: "제거",
        emptyTitle: "사용 가능한 디스크 없음",
        emptyDescription: "추출에서 제외할 외장 디스크를 연결하십시오.",
        caption: "이 목록에 있는 드라이브는 모든 디스크 추출 시 추출되지 않습니다."
    )

    static let zhHans = DiskExclusionStrings(
        listTitle: "不推出这些磁盘…",
        sheetTitle: "不推出这些磁盘…",
        savedSection: "排除的驱动器",
        discoverySection: "已连接的驱动器",
        noSavedDisks: "没有排除的驱动器",
        noDiscoveredDisks: "没有其他已连接的驱动器",
        addButton: "添加",
        removeButton: "移除",
        emptyTitle: "无可用磁盘",
        emptyDescription: "连接外部磁盘以将其排除在推出操作之外。",
        caption: "使用“推出所有磁盘”时，此列表中的驱动器绝不会被推出。"
    )

    static let zhTW = DiskExclusionStrings(
        listTitle: "不退出這些磁碟…",
        sheetTitle: "不退出這些磁碟…",
        savedSection: "排除的磁碟機",
        discoverySection: "已連接的磁碟機",
        noSavedDisks: "沒有排除的磁碟機",
        noDiscoveredDisks: "沒有其他已連接的磁碟機",
        addButton: "加入",
        removeButton: "移除",
        emptyTitle: "無可用磁碟",
        emptyDescription: "連接外接磁碟以將其排除在退出操作之外。",
        caption: "使用「退出所有磁碟」時，此列表中的磁碟機絕不會被退出。"
    )

    static let zhHK = DiskExclusionStrings(
        listTitle: "不推出這些磁碟…",
        sheetTitle: "不推出這些磁碟…",
        savedSection: "排除的磁碟機",
        discoverySection: "已連接的磁碟機",
        noSavedDisks: "沒有排除的磁碟機",
        noDiscoveredDisks: "沒有其他已連接的磁碟機",
        addButton: "加入",
        removeButton: "移除",
        emptyTitle: "無可用磁碟",
        emptyDescription: "連接外置磁碟以將其排除在退出操作之外。",
        caption: "使用「推出所有磁碟」時，此清單中的磁碟機絕不會被推出。"
    )

    static let uk = DiskExclusionStrings(
        listTitle: "Не виймати ці диски…",
        sheetTitle: "Не виймати ці диски…",
        savedSection: "Виключені диски",
        discoverySection: "Підключені диски",
        noSavedDisks: "Немає виключених дисків",
        noDiscoveredDisks: "Немає інших підключених дисків",
        addButton: "Додати",
        removeButton: "Видалити",
        emptyTitle: "Немає доступних дисків",
        emptyDescription: "Підключіть зовнішній диск, щоб виключити його з виймання.",
        caption: "Диски з цього списку ніколи не демонтуються при використанні «Вийняти всі диски»."
    )
}
