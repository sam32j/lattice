// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// Copy for the App Manager page and its tile. Same contract as the other
/// FeatureStrings structs: memberwise init in declaration order, one static
/// per language.
struct AppManagerStrings {
    let title: String
    let hubDescription: String
    let emptyDescription: String
    let tabInstaller: String
    let tabUpdates: String
    let tabUninstaller: String
    let tabHomebrew: String
    let helpInstaller: String
    let helpUpdates: String
    let helpUninstaller: String
    let helpHomebrew: String
    let alwaysOn: String
    let tabsLabel: String
}

extension FeatureStrings {
    static func appManager(_ language: AppLanguage) -> AppManagerStrings {
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

extension AppManagerStrings {
    static let enUS = AppManagerStrings(
        title: "App Manager",
        hubDescription: "Install, update and remove apps, and manage Homebrew.",
        emptyDescription: "Install, update, and uninstall apps, and manage Homebrew.",
        tabInstaller: "App Installer",
        tabUpdates: "App Updates",
        tabUninstaller: "App Uninstaller",
        tabHomebrew: "Homebrew",
        helpInstaller: "Install apps from disk images",
        helpUpdates: "Manage app updates in one place",
        helpUninstaller: "Remove applications and their data",
        helpHomebrew: "Manage Homebrew packages",
        alwaysOn: "Always On",
        tabsLabel: "App Manager sections")

    static let ptBR = AppManagerStrings(
        title: "Gerenciador de Apps",
        hubDescription: "Instale, atualize e remova apps e gerencie o Homebrew.",
        emptyDescription: "Instale, atualize e desinstale apps, e gerencie o Homebrew.",
        tabInstaller: "Instalador de Apps",
        tabUpdates: "Atualizações de Apps",
        tabUninstaller: "Desinstalador de Apps",
        tabHomebrew: "Homebrew",
        helpInstaller: "Instale apps de imagens de disco",
        helpUpdates: "Gerencie atualizações de apps em um só lugar",
        helpUninstaller: "Remova aplicativos e seus dados",
        helpHomebrew: "Gerencie pacotes do Homebrew",
        alwaysOn: "Sempre ativo",
        tabsLabel: "Seções do Gerenciador de Apps")

    static let tr = AppManagerStrings(
        title: "Uygulama Yöneticisi",
        hubDescription: "Uygulamaları yükleyin, güncelleyin, kaldırın ve Homebrew’u yönetin.",
        emptyDescription: "Uygulamaları yükleyin, güncelleyin, kaldırın ve Homebrew’u yönetin.",
        tabInstaller: "Uygulama Yükleyici",
        tabUpdates: "Uygulama Güncellemeleri",
        tabUninstaller: "Uygulama Kaldırıcı",
        tabHomebrew: "Homebrew",
        helpInstaller: "Disk görüntülerinden uygulama yükleyin",
        helpUpdates: "Uygulama güncellemelerini tek yerden yönetin",
        helpUninstaller: "Uygulamaları ve verilerini kaldırın",
        helpHomebrew: "Homebrew paketlerini yönetin",
        alwaysOn: "Her Zaman Açık",
        tabsLabel: "Uygulama Yöneticisi bölümleri")

    static let ru = AppManagerStrings(
        title: "Менеджер приложений",
        hubDescription: "Устанавливайте, обновляйте и удаляйте приложения, управляйте Homebrew.",
        emptyDescription: "Устанавливайте, обновляйте и удаляйте приложения, и управляйте Homebrew.",
        tabInstaller: "Установщик",
        tabUpdates: "Обновления",
        tabUninstaller: "Удаление",
        tabHomebrew: "Homebrew",
        helpInstaller: "Установка приложений из образов дисков",
        helpUpdates: "Управление обновлениями приложений в одном месте",
        helpUninstaller: "Удаление приложений и их данных",
        helpHomebrew: "Управление пакетами Homebrew",
        alwaysOn: "Всегда включено",
        tabsLabel: "Разделы менеджера приложений")

    static let es = AppManagerStrings(
        title: "Gestor de apps",
        hubDescription: "Instala, actualiza y elimina apps, y gestiona Homebrew.",
        emptyDescription: "Instala, actualiza y desinstala apps, y gestiona Homebrew.",
        tabInstaller: "Instalador de apps",
        tabUpdates: "Actualizaciones de apps",
        tabUninstaller: "Desinstalador de apps",
        tabHomebrew: "Homebrew",
        helpInstaller: "Instala apps desde imágenes de disco",
        helpUpdates: "Gestiona las actualizaciones de apps en un solo lugar",
        helpUninstaller: "Elimina aplicaciones y sus datos",
        helpHomebrew: "Gestiona los paquetes de Homebrew",
        alwaysOn: "Siempre activo",
        tabsLabel: "Secciones del gestor de apps")

    static let sk = AppManagerStrings(
        title: "Správca aplikácií",
        hubDescription: "Inštalujte, aktualizujte a odstraňujte aplikácie a spravujte Homebrew.",
        emptyDescription: "Inštalujte, aktualizujte a odinštalujte aplikácie a spravujte Homebrew.",
        tabInstaller: "Inštalátor aplikácií",
        tabUpdates: "Aktualizácie aplikácií",
        tabUninstaller: "Odinštalátor aplikácií",
        tabHomebrew: "Homebrew",
        helpInstaller: "Inštalujte aplikácie z obrazov diskov",
        helpUpdates: "Spravujte aktualizácie aplikácií na jednom mieste",
        helpUninstaller: "Odstráňte aplikácie a ich údaje",
        helpHomebrew: "Spravujte balíky Homebrew",
        alwaysOn: "Vždy zapnuté",
        tabsLabel: "Sekcie správcu aplikácií")

    static let de = AppManagerStrings(
        title: "App-Verwaltung",
        hubDescription: "Apps installieren, aktualisieren und entfernen sowie Homebrew verwalten.",
        emptyDescription: "Apps installieren, aktualisieren, deinstallieren und Homebrew verwalten.",
        tabInstaller: "App-Installer",
        tabUpdates: "App-Updates",
        tabUninstaller: "App-Deinstallation",
        tabHomebrew: "Homebrew",
        helpInstaller: "Apps aus Disk-Images installieren",
        helpUpdates: "App-Updates an einem Ort verwalten",
        helpUninstaller: "Apps und ihre Daten entfernen",
        helpHomebrew: "Homebrew-Pakete verwalten",
        alwaysOn: "Immer an",
        tabsLabel: "Bereiche der App-Verwaltung")

    static let fr = AppManagerStrings(
        title: "Gestionnaire d’apps",
        hubDescription: "Installez, mettez à jour et supprimez des apps, et gérez Homebrew.",
        emptyDescription: "Installez, mettez à jour et désinstallez des apps, et gérez Homebrew.",
        tabInstaller: "Installation d’apps",
        tabUpdates: "Mises à jour d’apps",
        tabUninstaller: "Désinstallation d’apps",
        tabHomebrew: "Homebrew",
        helpInstaller: "Installez des apps depuis des images disque",
        helpUpdates: "Gérez les mises à jour des apps en un seul endroit",
        helpUninstaller: "Supprimez des apps et leurs données",
        helpHomebrew: "Gérez les paquets Homebrew",
        alwaysOn: "Toujours activé",
        tabsLabel: "Sections du gestionnaire d’apps")

    static let it = AppManagerStrings(
        title: "Gestione app",
        hubDescription: "Installa, aggiorna e rimuovi app e gestisci Homebrew.",
        emptyDescription: "Installa, aggiorna e disinstalla app, e gestisci Homebrew.",
        tabInstaller: "Installazione app",
        tabUpdates: "Aggiornamenti app",
        tabUninstaller: "Disinstallazione app",
        tabHomebrew: "Homebrew",
        helpInstaller: "Installa app da immagini disco",
        helpUpdates: "Gestisci gli aggiornamenti delle app in un unico posto",
        helpUninstaller: "Rimuovi le app e i loro dati",
        helpHomebrew: "Gestisci i pacchetti Homebrew",
        alwaysOn: "Sempre attivo",
        tabsLabel: "Sezioni di Gestione app")

    static let ja = AppManagerStrings(
        title: "Appマネージャ",
        hubDescription: "Appのインストール、アップデート、削除とHomebrewの管理を行います。",
        emptyDescription: "Appのインストール・アップデート・削除とHomebrew管理を1か所で。",
        tabInstaller: "Appインストーラ",
        tabUpdates: "Appアップデート",
        tabUninstaller: "Appアンインストーラ",
        tabHomebrew: "Homebrew",
        helpInstaller: "ディスクイメージからAppをインストール",
        helpUpdates: "Appのアップデートをまとめて管理",
        helpUninstaller: "Appとそのデータを削除",
        helpHomebrew: "Homebrewパッケージを管理",
        alwaysOn: "常にオン",
        tabsLabel: "Appマネージャのセクション")

    static let ko = AppManagerStrings(
        title: "앱 관리자",
        hubDescription: "앱을 설치, 업데이트, 제거하고 Homebrew를 관리합니다.",
        emptyDescription: "앱 설치·업데이트·제거와 Homebrew 관리를 한곳에서.",
        tabInstaller: "앱 설치",
        tabUpdates: "앱 업데이트",
        tabUninstaller: "앱 제거",
        tabHomebrew: "Homebrew",
        helpInstaller: "디스크 이미지에서 앱 설치",
        helpUpdates: "앱 업데이트를 한곳에서 관리",
        helpUninstaller: "앱과 데이터 제거",
        helpHomebrew: "Homebrew 패키지 관리",
        alwaysOn: "항상 켬",
        tabsLabel: "앱 관리자 섹션")

    static let zhHans = AppManagerStrings(
        title: "App 管理器",
        hubDescription: "安装、更新和移除 App，并管理 Homebrew。",
        emptyDescription: "一站式安装、更新、卸载 App 并管理 Homebrew。",
        tabInstaller: "App 安装器",
        tabUpdates: "App 更新",
        tabUninstaller: "App 卸载器",
        tabHomebrew: "Homebrew",
        helpInstaller: "从磁盘映像安装 App",
        helpUpdates: "在一处管理 App 更新",
        helpUninstaller: "移除 App 及其数据",
        helpHomebrew: "管理 Homebrew 软件包",
        alwaysOn: "始终开启",
        tabsLabel: "App 管理器分区")

    static let zhTW = AppManagerStrings(
        title: "App 管理器",
        hubDescription: "安裝、更新和移除 App，並管理 Homebrew。",
        emptyDescription: "一站式安裝、更新、解除安裝 App 並管理 Homebrew。",
        tabInstaller: "App 安裝器",
        tabUpdates: "App 更新",
        tabUninstaller: "App 解除安裝器",
        tabHomebrew: "Homebrew",
        helpInstaller: "從磁碟映像檔安裝 App",
        helpUpdates: "在同一處管理 App 更新",
        helpUninstaller: "移除 App 及其資料",
        helpHomebrew: "管理 Homebrew 套件",
        alwaysOn: "永遠開啟",
        tabsLabel: "App 管理器區段")

    static let zhHK = AppManagerStrings(
        title: "App 管理器",
        hubDescription: "安裝、更新和移除 App，並管理 Homebrew。",
        emptyDescription: "一站式安裝、更新、解除安裝 App 並管理 Homebrew。",
        tabInstaller: "App 安裝器",
        tabUpdates: "App 更新",
        tabUninstaller: "App 解除安裝器",
        tabHomebrew: "Homebrew",
        helpInstaller: "從磁碟映像檔安裝 App",
        helpUpdates: "在同一處管理 App 更新",
        helpUninstaller: "移除 App 及其資料",
        helpHomebrew: "管理 Homebrew 套件",
        alwaysOn: "永遠開啟",
        tabsLabel: "App 管理器區段")

    static let uk = AppManagerStrings(
        title: "Менеджер програм",
        hubDescription: "Встановлюйте, оновлюйте й видаляйте програми та керуйте Homebrew.",
        emptyDescription: "Встановлюйте, оновлюйте й видаляйте програми та керуйте Homebrew.",
        tabInstaller: "Встановлення",
        tabUpdates: "Оновлення",
        tabUninstaller: "Видалення",
        tabHomebrew: "Homebrew",
        helpInstaller: "Встановлення програм з образів дисків",
        helpUpdates: "Керування оновленнями програм в одному місці",
        helpUninstaller: "Видалення програм і їхніх даних",
        helpHomebrew: "Керування пакетами Homebrew",
        alwaysOn: "Завжди ввімкнено",
        tabsLabel: "Розділи менеджера програм")
}
