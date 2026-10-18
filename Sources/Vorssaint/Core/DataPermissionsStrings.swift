// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct DataPermissionsStrings {
    let title: String
    let data: String

    static func localized(_ language: AppLanguage) -> Self {
        switch language {
        case .enUS: return Self(title: "Data and Permissions", data: "Lattice Data")
        case .ptBR: return Self(title: "Dados e permissões", data: "Dados do Lattice")
        case .tr: return Self(title: "Veriler ve İzinler", data: "Lattice Verileri")
        case .ru: return Self(title: "Данные и разрешения", data: "Данные Lattice")
        case .es: return Self(title: "Datos y permisos", data: "Datos de Lattice")
        case .sk: return Self(title: "Údaje a povolenia", data: "Údaje Lattice")
        case .de: return Self(title: "Daten und Berechtigungen", data: "Lattice-Daten")
        case .fr: return Self(title: "Données et autorisations", data: "Données Lattice")
        case .it: return Self(title: "Dati e permessi", data: "Dati di Lattice")
        case .ja: return Self(title: "データとアクセス権", data: "Latticeのデータ")
        case .ko: return Self(title: "데이터 및 권한", data: "Lattice 데이터")
        case .zhHans: return Self(title: "数据与权限", data: "Lattice 数据")
        case .zhTW, .zhHK: return Self(title: "資料與權限", data: "Lattice 資料")
        case .uk: return Self(title: "Дані та дозволи", data: "Дані Lattice")
        }
    }
}
