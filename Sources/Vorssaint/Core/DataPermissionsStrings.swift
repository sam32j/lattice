// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct DataPermissionsStrings {
    let title: String
    let data: String
    let details: String

    static func localized(_ language: AppLanguage) -> Self {
        switch language {
        case .enUS: return Self(title: "Data and Permissions", data: "Lattice Data", details: "Permission details")
        case .ptBR: return Self(title: "Dados e permissões", data: "Dados do Lattice", details: "Detalhes da permissão")
        case .tr: return Self(title: "Veriler ve İzinler", data: "Lattice Verileri", details: "İzin ayrıntıları")
        case .ru: return Self(title: "Данные и разрешения", data: "Данные Lattice", details: "Сведения о разрешении")
        case .es: return Self(title: "Datos y permisos", data: "Datos de Lattice", details: "Detalles del permiso")
        case .sk: return Self(title: "Údaje a povolenia", data: "Údaje Lattice", details: "Podrobnosti povolenia")
        case .de: return Self(title: "Daten und Berechtigungen", data: "Lattice-Daten", details: "Berechtigungsdetails")
        case .fr: return Self(title: "Données et autorisations", data: "Données Lattice", details: "Détails de l’autorisation")
        case .it: return Self(title: "Dati e permessi", data: "Dati di Lattice", details: "Dettagli del permesso")
        case .ja: return Self(title: "データとアクセス権", data: "Latticeのデータ", details: "アクセス権の詳細")
        case .ko: return Self(title: "데이터 및 권한", data: "Lattice 데이터", details: "권한 세부사항")
        case .zhHans: return Self(title: "数据与权限", data: "Lattice 数据", details: "权限详情")
        case .zhTW, .zhHK: return Self(title: "資料與權限", data: "Lattice 資料", details: "權限詳情")
        case .uk: return Self(title: "Дані та дозволи", data: "Дані Lattice", details: "Відомості про дозвіл")
        }
    }
}
