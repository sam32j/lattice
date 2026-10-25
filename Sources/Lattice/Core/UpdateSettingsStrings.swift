// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

struct UpdateSettingsStrings {
    let automatic: String
    let check: String
    let review: String
    let notChecked: String
    let changelog: String
    let latticeScope: String
    let upstreamScope: String

    static func localized(_ language: AppLanguage) -> Self {
        switch language {
        case .enUS:
            return Self(automatic: "Check for updates automatically",
                        check: "Check for updates",
                        review: "Review update…",
                        notChecked: "Updates haven’t been checked yet",
                        changelog: "Changelog",
                        latticeScope: "Lattice",
                        upstreamScope: "Upstream")
        case .ptBR:
            return Self(automatic: "Verificar atualizações automaticamente",
                        check: "Verificar atualizações",
                        review: "Revisar atualização…",
                        notChecked: "As atualizações ainda não foram verificadas",
                        changelog: "Histórico de alterações",
                        latticeScope: "Lattice",
                        upstreamScope: "Base original")
        case .tr:
            return Self(automatic: "Güncellemeleri otomatik denetle",
                        check: "Güncellemeleri denetle",
                        review: "Güncellemeyi incele…",
                        notChecked: "Güncellemeler henüz denetlenmedi",
                        changelog: "Değişiklik günlüğü",
                        latticeScope: "Lattice",
                        upstreamScope: "Üst proje")
        case .ru:
            return Self(automatic: "Проверять обновления автоматически",
                        check: "Проверить обновления",
                        review: "Просмотреть обновление…",
                        notChecked: "Обновления ещё не проверялись",
                        changelog: "История изменений",
                        latticeScope: "Lattice",
                        upstreamScope: "Исходный проект")
        case .es:
            return Self(automatic: "Buscar actualizaciones automáticamente",
                        check: "Buscar actualizaciones",
                        review: "Revisar actualización…",
                        notChecked: "Aún no se han buscado actualizaciones",
                        changelog: "Registro de cambios",
                        latticeScope: "Lattice",
                        upstreamScope: "Proyecto original")
        case .sk:
            return Self(automatic: "Automaticky kontrolovať aktualizácie",
                        check: "Skontrolovať aktualizácie",
                        review: "Zobraziť aktualizáciu…",
                        notChecked: "Aktualizácie ešte neboli skontrolované",
                        changelog: "História zmien",
                        latticeScope: "Lattice",
                        upstreamScope: "Pôvodný projekt")
        case .de:
            return Self(automatic: "Automatisch nach Updates suchen",
                        check: "Nach Updates suchen",
                        review: "Update ansehen…",
                        notChecked: "Es wurde noch nicht nach Updates gesucht",
                        changelog: "Änderungsprotokoll",
                        latticeScope: "Lattice",
                        upstreamScope: "Ursprungsprojekt")
        case .fr:
            return Self(automatic: "Rechercher automatiquement les mises à jour",
                        check: "Rechercher les mises à jour",
                        review: "Examiner la mise à jour…",
                        notChecked: "Les mises à jour n’ont pas encore été recherchées",
                        changelog: "Historique des modifications",
                        latticeScope: "Lattice",
                        upstreamScope: "Projet d’origine")
        case .it:
            return Self(automatic: "Cerca automaticamente gli aggiornamenti",
                        check: "Cerca aggiornamenti",
                        review: "Esamina aggiornamento…",
                        notChecked: "Gli aggiornamenti non sono ancora stati cercati",
                        changelog: "Registro delle modifiche",
                        latticeScope: "Lattice",
                        upstreamScope: "Progetto originale")
        case .ja:
            return Self(automatic: "アップデートを自動的に確認",
                        check: "アップデートを確認",
                        review: "アップデートを確認…",
                        notChecked: "アップデートはまだ確認されていません",
                        changelog: "変更履歴",
                        latticeScope: "Lattice",
                        upstreamScope: "元のプロジェクト")
        case .ko:
            return Self(automatic: "자동으로 업데이트 확인",
                        check: "업데이트 확인",
                        review: "업데이트 검토…",
                        notChecked: "아직 업데이트를 확인하지 않았습니다",
                        changelog: "변경 내역",
                        latticeScope: "Lattice",
                        upstreamScope: "원본 프로젝트")
        case .uk:
            return Self(automatic: "Автоматично перевіряти оновлення",
                        check: "Перевірити оновлення",
                        review: "Переглянути оновлення…",
                        notChecked: "Оновлення ще не перевірялися",
                        changelog: "Історія змін",
                        latticeScope: "Lattice",
                        upstreamScope: "Початковий проєкт")
        case .zhHans:
            return Self(automatic: "自动检查更新",
                        check: "检查更新",
                        review: "查看更新…",
                        notChecked: "尚未检查更新",
                        changelog: "更新日志",
                        latticeScope: "Lattice",
                        upstreamScope: "上游项目")
        case .zhTW, .zhHK:
            return Self(automatic: "自動檢查更新",
                        check: "檢查更新",
                        review: "檢視更新…",
                        notChecked: "尚未檢查更新",
                        changelog: "更新日誌",
                        latticeScope: "Lattice",
                        upstreamScope: "上游專案")
        }
    }
}
