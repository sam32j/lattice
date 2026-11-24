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
        emptyDescription: "Install disk images automatically, check for app updates, remove apps with their leftovers, and manage Homebrew packages in one place.",
        tabInstaller: "App Installer",
        tabUpdates: "App Updates",
        tabUninstaller: "App Uninstaller",
        tabHomebrew: "Homebrew",
        helpInstaller: "Install single-app disk images and clean up downloads",
        helpUpdates: "Check for updates across Homebrew, App Store, and web channels",
        helpUninstaller: "Remove apps, leftovers, and Homebrew casks cleanly",
        helpHomebrew: "Browse, install, upgrade, and manage Homebrew packages",
        alwaysOn: "Always On",
        tabsLabel: "App Manager sections")

    static let ptBR = AppManagerStrings(
        title: "Gerenciador de Apps",
        hubDescription: "Instale, atualize e remova apps e gerencie o Homebrew.",
        emptyDescription: "Instale imagens de disco automaticamente, procure atualizações de apps, remova apps com seus restos e gerencie pacotes do Homebrew em um só lugar.",
        tabInstaller: "Instalador de Apps",
        tabUpdates: "Atualizações de Apps",
        tabUninstaller: "Desinstalador de Apps",
        tabHomebrew: "Homebrew",
        helpInstaller: "Instale imagens de disco com um único app e limpe os downloads",
        helpUpdates: "Procure atualizações no Homebrew, na App Store e em canais da web",
        helpUninstaller: "Remova apps, restos e casks do Homebrew por completo",
        helpHomebrew: "Explore, instale, atualize e gerencie pacotes do Homebrew",
        alwaysOn: "Sempre ativo",
        tabsLabel: "Seções do Gerenciador de Apps")

    static let tr = AppManagerStrings(
        title: "Uygulama Yöneticisi",
        hubDescription: "Uygulamaları yükleyin, güncelleyin, kaldırın ve Homebrew’u yönetin.",
        emptyDescription: "Disk görüntülerini otomatik yükleyin, uygulama güncellemelerini denetleyin, uygulamaları artıklarıyla kaldırın ve Homebrew paketlerini tek yerden yönetin.",
        tabInstaller: "Uygulama Yükleyici",
        tabUpdates: "Uygulama Güncellemeleri",
        tabUninstaller: "Uygulama Kaldırıcı",
        tabHomebrew: "Homebrew",
        helpInstaller: "Tek uygulamalı disk görüntülerini yükleyin ve indirilenleri temizleyin",
        helpUpdates: "Homebrew, App Store ve web kanallarında güncellemeleri denetleyin",
        helpUninstaller: "Uygulamaları, artıklarını ve Homebrew cask’lerini temizce kaldırın",
        helpHomebrew: "Homebrew paketlerine göz atın, yükleyin, yükseltin ve yönetin",
        alwaysOn: "Her Zaman Açık",
        tabsLabel: "Uygulama Yöneticisi bölümleri")

    static let ru = AppManagerStrings(
        title: "Менеджер приложений",
        hubDescription: "Устанавливайте, обновляйте и удаляйте приложения, управляйте Homebrew.",
        emptyDescription: "Автоматически устанавливайте образы дисков, проверяйте обновления, удаляйте приложения вместе с остатками и управляйте пакетами Homebrew в одном месте.",
        tabInstaller: "Установщик",
        tabUpdates: "Обновления",
        tabUninstaller: "Удаление",
        tabHomebrew: "Homebrew",
        helpInstaller: "Установка образов дисков с одним приложением и очистка загрузок",
        helpUpdates: "Проверка обновлений в Homebrew, App Store и веб-каналах",
        helpUninstaller: "Полное удаление приложений, остатков и cask Homebrew",
        helpHomebrew: "Поиск, установка, обновление и управление пакетами Homebrew",
        alwaysOn: "Всегда включено",
        tabsLabel: "Разделы менеджера приложений")

    static let es = AppManagerStrings(
        title: "Gestor de apps",
        hubDescription: "Instala, actualiza y elimina apps, y gestiona Homebrew.",
        emptyDescription: "Instala imágenes de disco automáticamente, busca actualizaciones de apps, elimina apps con sus restos y gestiona paquetes de Homebrew en un solo lugar.",
        tabInstaller: "Instalador de apps",
        tabUpdates: "Actualizaciones de apps",
        tabUninstaller: "Desinstalador de apps",
        tabHomebrew: "Homebrew",
        helpInstaller: "Instala imágenes de disco con una sola app y limpia las descargas",
        helpUpdates: "Busca actualizaciones en Homebrew, App Store y canales web",
        helpUninstaller: "Elimina apps, restos y casks de Homebrew por completo",
        helpHomebrew: "Explora, instala, actualiza y gestiona paquetes de Homebrew",
        alwaysOn: "Siempre activo",
        tabsLabel: "Secciones del gestor de apps")

    static let sk = AppManagerStrings(
        title: "Správca aplikácií",
        hubDescription: "Inštalujte, aktualizujte a odstraňujte aplikácie a spravujte Homebrew.",
        emptyDescription: "Automaticky inštalujte obrazy diskov, kontrolujte aktualizácie aplikácií, odstraňujte aplikácie aj so zvyškami a spravujte balíky Homebrew na jednom mieste.",
        tabInstaller: "Inštalátor aplikácií",
        tabUpdates: "Aktualizácie aplikácií",
        tabUninstaller: "Odinštalátor aplikácií",
        tabHomebrew: "Homebrew",
        helpInstaller: "Inštalujte obrazy diskov s jednou aplikáciou a upracte stiahnuté súbory",
        helpUpdates: "Kontrolujte aktualizácie v Homebrew, App Store a webových kanáloch",
        helpUninstaller: "Čisto odstráňte aplikácie, zvyšky a casky Homebrew",
        helpHomebrew: "Prehliadajte, inštalujte, aktualizujte a spravujte balíky Homebrew",
        alwaysOn: "Vždy zapnuté",
        tabsLabel: "Sekcie správcu aplikácií")

    static let de = AppManagerStrings(
        title: "App-Verwaltung",
        hubDescription: "Apps installieren, aktualisieren und entfernen sowie Homebrew verwalten.",
        emptyDescription: "Disk-Images automatisch installieren, nach App-Updates suchen, Apps samt Resten entfernen und Homebrew-Pakete an einem Ort verwalten.",
        tabInstaller: "App-Installer",
        tabUpdates: "App-Updates",
        tabUninstaller: "App-Deinstallation",
        tabHomebrew: "Homebrew",
        helpInstaller: "Disk-Images mit einer App installieren und Downloads aufräumen",
        helpUpdates: "Nach Updates über Homebrew, App Store und Webkanäle suchen",
        helpUninstaller: "Apps, Reste und Homebrew-Casks sauber entfernen",
        helpHomebrew: "Homebrew-Pakete durchsuchen, installieren, aktualisieren und verwalten",
        alwaysOn: "Immer an",
        tabsLabel: "Bereiche der App-Verwaltung")

    static let fr = AppManagerStrings(
        title: "Gestionnaire d’apps",
        hubDescription: "Installez, mettez à jour et supprimez des apps, et gérez Homebrew.",
        emptyDescription: "Installez automatiquement les images disque, recherchez les mises à jour des apps, supprimez les apps avec leurs restes et gérez les paquets Homebrew au même endroit.",
        tabInstaller: "Installation d’apps",
        tabUpdates: "Mises à jour d’apps",
        tabUninstaller: "Désinstallation d’apps",
        tabHomebrew: "Homebrew",
        helpInstaller: "Installer les images disque à une seule app et nettoyer les téléchargements",
        helpUpdates: "Rechercher des mises à jour via Homebrew, l’App Store et les canaux web",
        helpUninstaller: "Supprimer proprement les apps, leurs restes et les casks Homebrew",
        helpHomebrew: "Parcourir, installer, mettre à niveau et gérer les paquets Homebrew",
        alwaysOn: "Toujours activé",
        tabsLabel: "Sections du gestionnaire d’apps")

    static let it = AppManagerStrings(
        title: "Gestione app",
        hubDescription: "Installa, aggiorna e rimuovi app e gestisci Homebrew.",
        emptyDescription: "Installa automaticamente le immagini disco, cerca aggiornamenti delle app, rimuovi le app con i loro residui e gestisci i pacchetti Homebrew in un unico posto.",
        tabInstaller: "Installazione app",
        tabUpdates: "Aggiornamenti app",
        tabUninstaller: "Disinstallazione app",
        tabHomebrew: "Homebrew",
        helpInstaller: "Installa immagini disco con una sola app e pulisci i download",
        helpUpdates: "Cerca aggiornamenti su Homebrew, App Store e canali web",
        helpUninstaller: "Rimuovi in modo pulito app, residui e cask Homebrew",
        helpHomebrew: "Sfoglia, installa, aggiorna e gestisci i pacchetti Homebrew",
        alwaysOn: "Sempre attivo",
        tabsLabel: "Sezioni di Gestione app")

    static let ja = AppManagerStrings(
        title: "Appマネージャ",
        hubDescription: "Appのインストール、アップデート、削除とHomebrewの管理を行います。",
        emptyDescription: "ディスクイメージの自動インストール、Appのアップデート確認、残りファイルを含めたAppの削除、Homebrewパッケージの管理を1か所で行えます。",
        tabInstaller: "Appインストーラ",
        tabUpdates: "Appアップデート",
        tabUninstaller: "Appアンインストーラ",
        tabHomebrew: "Homebrew",
        helpInstaller: "単一Appのディスクイメージをインストールしてダウンロードを片付けます",
        helpUpdates: "Homebrew、App Store、Webチャンネルのアップデートを確認します",
        helpUninstaller: "App、残りファイル、Homebrew caskをきれいに削除します",
        helpHomebrew: "Homebrewパッケージの検索、インストール、アップグレード、管理",
        alwaysOn: "常にオン",
        tabsLabel: "Appマネージャのセクション")

    static let ko = AppManagerStrings(
        title: "앱 관리자",
        hubDescription: "앱을 설치, 업데이트, 제거하고 Homebrew를 관리합니다.",
        emptyDescription: "디스크 이미지를 자동으로 설치하고, 앱 업데이트를 확인하고, 남은 파일까지 앱을 제거하고, Homebrew 패키지를 한곳에서 관리하세요.",
        tabInstaller: "앱 설치",
        tabUpdates: "앱 업데이트",
        tabUninstaller: "앱 제거",
        tabHomebrew: "Homebrew",
        helpInstaller: "앱 하나가 든 디스크 이미지를 설치하고 다운로드를 정리합니다",
        helpUpdates: "Homebrew, App Store, 웹 채널에서 업데이트를 확인합니다",
        helpUninstaller: "앱, 남은 파일, Homebrew cask를 깔끔하게 제거합니다",
        helpHomebrew: "Homebrew 패키지를 탐색, 설치, 업그레이드, 관리합니다",
        alwaysOn: "항상 켬",
        tabsLabel: "앱 관리자 섹션")

    static let zhHans = AppManagerStrings(
        title: "App 管理器",
        hubDescription: "安装、更新和移除 App，并管理 Homebrew。",
        emptyDescription: "在一个地方自动安装磁盘映像、检查 App 更新、连同残留文件移除 App，并管理 Homebrew 软件包。",
        tabInstaller: "App 安装器",
        tabUpdates: "App 更新",
        tabUninstaller: "App 卸载器",
        tabHomebrew: "Homebrew",
        helpInstaller: "安装只含一个 App 的磁盘映像并清理下载",
        helpUpdates: "通过 Homebrew、App Store 和网页渠道检查更新",
        helpUninstaller: "干净地移除 App、残留文件和 Homebrew cask",
        helpHomebrew: "浏览、安装、升级和管理 Homebrew 软件包",
        alwaysOn: "始终开启",
        tabsLabel: "App 管理器分区")

    static let zhTW = AppManagerStrings(
        title: "App 管理器",
        hubDescription: "安裝、更新和移除 App，並管理 Homebrew。",
        emptyDescription: "在同一處自動安裝磁碟映像檔、檢查 App 更新、連同殘留檔案移除 App，並管理 Homebrew 套件。",
        tabInstaller: "App 安裝器",
        tabUpdates: "App 更新",
        tabUninstaller: "App 解除安裝器",
        tabHomebrew: "Homebrew",
        helpInstaller: "安裝只含一個 App 的磁碟映像檔並清理下載項目",
        helpUpdates: "透過 Homebrew、App Store 和網頁管道檢查更新",
        helpUninstaller: "乾淨地移除 App、殘留檔案和 Homebrew cask",
        helpHomebrew: "瀏覽、安裝、升級和管理 Homebrew 套件",
        alwaysOn: "永遠開啟",
        tabsLabel: "App 管理器區段")

    static let zhHK = AppManagerStrings(
        title: "App 管理器",
        hubDescription: "安裝、更新和移除 App，並管理 Homebrew。",
        emptyDescription: "在同一處自動安裝磁碟映像檔、檢查 App 更新、連同殘留檔案移除 App，並管理 Homebrew 套件。",
        tabInstaller: "App 安裝器",
        tabUpdates: "App 更新",
        tabUninstaller: "App 解除安裝器",
        tabHomebrew: "Homebrew",
        helpInstaller: "安裝只含一個 App 的磁碟映像檔並清理下載項目",
        helpUpdates: "透過 Homebrew、App Store 和網頁渠道檢查更新",
        helpUninstaller: "乾淨地移除 App、殘留檔案和 Homebrew cask",
        helpHomebrew: "瀏覽、安裝、升級和管理 Homebrew 套件",
        alwaysOn: "永遠開啟",
        tabsLabel: "App 管理器區段")

    static let uk = AppManagerStrings(
        title: "Менеджер програм",
        hubDescription: "Встановлюйте, оновлюйте й видаляйте програми та керуйте Homebrew.",
        emptyDescription: "Автоматично встановлюйте образи дисків, перевіряйте оновлення, видаляйте програми разом із залишками та керуйте пакетами Homebrew в одному місці.",
        tabInstaller: "Встановлення",
        tabUpdates: "Оновлення",
        tabUninstaller: "Видалення",
        tabHomebrew: "Homebrew",
        helpInstaller: "Встановлення образів дисків з однією програмою й очищення завантажень",
        helpUpdates: "Перевірка оновлень у Homebrew, App Store та вебканалах",
        helpUninstaller: "Повне видалення програм, залишків і cask Homebrew",
        helpHomebrew: "Пошук, встановлення, оновлення й керування пакетами Homebrew",
        alwaysOn: "Завжди ввімкнено",
        tabsLabel: "Розділи менеджера програм")
}
