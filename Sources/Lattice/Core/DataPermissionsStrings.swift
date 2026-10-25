// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct DataPermissionsStrings {
    let title: String
    let data: String
    let details: String
    let dangerZone: String

    static func localized(_ language: AppLanguage) -> Self {
        switch language {
        case .enUS: return Self(title: "Data & Permissions", data: "Lattice Data", details: "Permission details", dangerZone: "Danger Zone")
        case .ptBR: return Self(title: "Dados & permissões", data: "Dados do Lattice", details: "Detalhes da permissão", dangerZone: "Zona de perigo")
        case .tr: return Self(title: "Veriler & İzinler", data: "Lattice Verileri", details: "İzin ayrıntıları", dangerZone: "Tehlike Bölgesi")
        case .ru: return Self(title: "Данные & разрешения", data: "Данные Lattice", details: "Сведения о разрешении", dangerZone: "Опасная зона")
        case .es: return Self(title: "Datos & permisos", data: "Datos de Lattice", details: "Detalles del permiso", dangerZone: "Zona de peligro")
        case .sk: return Self(title: "Údaje & povolenia", data: "Údaje Lattice", details: "Podrobnosti povolenia", dangerZone: "Nebezpečná zóna")
        case .de: return Self(title: "Daten & Berechtigungen", data: "Lattice-Daten", details: "Berechtigungsdetails", dangerZone: "Gefahrenbereich")
        case .fr: return Self(title: "Données & autorisations", data: "Données Lattice", details: "Détails de l’autorisation", dangerZone: "Zone de danger")
        case .it: return Self(title: "Dati & permessi", data: "Dati di Lattice", details: "Dettagli del permesso", dangerZone: "Zona di pericolo")
        case .ja: return Self(title: "データ & アクセス権", data: "Latticeのデータ", details: "アクセス権の詳細", dangerZone: "デンジャーゾーン")
        case .ko: return Self(title: "데이터 & 권한", data: "Lattice 데이터", details: "권한 세부사항", dangerZone: "위험 구역")
        case .zhHans: return Self(title: "数据 & 权限", data: "Lattice 数据", details: "权限详情", dangerZone: "危险区域")
        case .zhTW, .zhHK: return Self(title: "資料 & 權限", data: "Lattice 資料", details: "權限詳情", dangerZone: "危險區域")
        case .uk: return Self(title: "Дані & дозволи", data: "Дані Lattice", details: "Відомості про дозвіл", dangerZone: "Небезпечна зона")
        }
    }
}
