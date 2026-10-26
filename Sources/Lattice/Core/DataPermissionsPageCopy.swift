// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

enum DataPermissionsPageCopy {
    enum Key: Int { case settings, importDescription, exportDescription, deviceAccess, systemAudio, openSettings, requestAccess }
    static func text(_ key: Key, _ language: AppLanguage) -> String {
        let values: [String]
        switch language {
        case .enUS: values = ["Settings", "Load settings from a file you exported earlier.",
            "Lattice will not export your Scratchpad notes, clipboard history, File Cache, or permissions.",
            "Device Control and Data Access", "System Audio Recording", "Open System Settings for %@", "Request %@ access"]
        case .ptBR: values = ["Ajustes", "Carregue os ajustes de um arquivo exportado anteriormente.",
            "O Lattice não exporta suas notas do Bloco de Notas, histórico da área de transferência, Cache de Arquivos ou permissões.",
            "Controle do dispositivo e acesso a dados", "Gravação de áudio do sistema", "Abrir Ajustes do Sistema para %@", "Solicitar acesso a %@"]
        case .es: values = ["Ajustes", "Carga los ajustes de un archivo que hayas exportado antes.",
            "Lattice no exportará tus notas, historial del portapapeles, Caché de Archivos ni permisos.",
            "Control del dispositivo y acceso a datos", "Grabación de audio del sistema", "Abrir Ajustes del Sistema para %@", "Solicitar acceso a %@"]
        case .de: values = ["Einstellungen", "Lade Einstellungen aus einer zuvor exportierten Datei.",
            "Lattice exportiert keine Notizblock-Inhalte, Zwischenablage-Verläufe, Dateiablage oder Berechtigungen.",
            "Gerätesteuerung und Datenzugriff", "Systemaudioaufnahme", "Systemeinstellungen für %@ öffnen", "Zugriff auf %@ anfordern"]
        case .fr: values = ["Réglages", "Chargez les réglages d’un fichier exporté précédemment.",
            "Lattice n’exporte ni vos notes, ni l’historique du presse-papiers, ni le Cache de fichiers, ni les autorisations.",
            "Contrôle de l’appareil et accès aux données", "Enregistrement audio du système", "Ouvrir les Réglages Système pour %@", "Demander l’accès à %@"]
        case .it: values = ["Impostazioni", "Carica le impostazioni da un file esportato in precedenza.",
            "Lattice non esporta le note, la cronologia degli appunti, la Cache file o i permessi.",
            "Controllo del dispositivo e accesso ai dati", "Registrazione audio di sistema", "Apri Impostazioni di Sistema per %@", "Richiedi accesso a %@"]
        case .ja: values = ["設定", "以前書き出したファイルから設定を読み込みます。",
            "Latticeはスクラッチパッドのメモ、クリップボード履歴、ファイルキャッシュ、アクセス権を書き出しません。",
            "デバイス制御とデータアクセス", "システムオーディオ録音", "%@のシステム設定を開く", "%@へのアクセスを要求"]
        case .ko: values = ["설정", "이전에 내보낸 파일에서 설정을 불러옵니다.",
            "Lattice는 메모, 클립보드 기록, 파일 캐시 또는 권한을 내보내지 않습니다.",
            "기기 제어 및 데이터 접근", "시스템 오디오 녹음", "%@ 시스템 설정 열기", "%@ 접근 요청"]
        case .zhHans: values = ["设置", "从之前导出的文件中载入设置。",
            "Lattice 不会导出你的便笺、剪贴板历史、文件缓存或权限。",
            "设备控制与数据访问", "系统音频录制", "打开%@的系统设置", "请求%@访问权限"]
        case .zhTW, .zhHK: values = ["設定", "從之前匯出的檔案載入設定。",
            "Lattice 不會匯出你的便箋、剪貼簿記錄、檔案快取或權限。",
            "裝置控制與資料存取", "系統音訊錄製", "開啟%@的系統設定", "要求%@存取權限"]
        case .ru: values = ["Настройки", "Загрузите настройки из ранее экспортированного файла.",
            "Lattice не экспортирует заметки, историю буфера обмена, Файловый кэш или разрешения.",
            "Управление устройством и доступ к данным", "Запись системного звука", "Открыть Системные настройки для %@", "Запросить доступ к %@"]
        case .uk: values = ["Параметри", "Завантажте налаштування з раніше експортованого файлу.",
            "Lattice не експортує нотатки, історію буфера обміну, Файловий кеш або дозволи.",
            "Керування пристроєм і доступ до даних", "Запис системного звуку", "Відкрити Системні параметри для %@", "Запросити доступ до %@"]
        case .tr: values = ["Ayarlar", "Daha önce dışa aktardığınız bir dosyadan ayarları yükleyin.",
            "Lattice; notlarınızı, pano geçmişini, Dosya Önbelleğini veya izinleri dışa aktarmaz.",
            "Aygıt denetimi ve veri erişimi", "Sistem sesi kaydı", "%@ için Sistem Ayarları’nı aç", "%@ erişimi iste"]
        case .sk: values = ["Nastavenia", "Načítajte nastavenia zo súboru, ktorý ste predtým exportovali.",
            "Lattice neexportuje vaše poznámky, históriu schránky, Súborovú vyrovnávaciu pamäť ani povolenia.",
            "Ovládanie zariadenia a prístup k údajom", "Nahrávanie systémového zvuku", "Otvoriť Systémové nastavenia pre %@", "Požiadať o prístup k %@"]
        }
        return values[key.rawValue]
    }
}
