import Foundation

enum MediaOptimizerStrings {
    static func caption(_ language: AppLanguage) -> String {
        switch language {
        case .ptBR: return "Otimize imagens, GIFs e vídeos no seu Mac."
        case .es: return "Optimiza imágenes, GIF y vídeos en tu Mac."
        case .fr: return "Optimisez vos images, GIF et vidéos sur votre Mac."
        case .de: return "Bilder, GIFs und Videos auf deinem Mac optimieren."
        case .it: return "Ottimizza immagini, GIF e video sul tuo Mac."
        case .tr: return "Görselleri, GIF’leri ve videoları Mac’inizde iyileştirin."
        case .ru: return "Оптимизируйте изображения, GIF и видео на вашем Mac."
        case .uk: return "Оптимізуйте зображення, GIF і відео на вашому Mac."
        case .sk: return "Optimalizujte obrázky, GIF-y a videá na svojom Macu."
        case .ja: return "Mac上で画像、GIF、ビデオを最適化します。"
        case .ko: return "Mac에서 이미지, GIF 및 비디오를 최적화합니다."
        case .zhHans: return "在 Mac 上优化图片、GIF 和视频。"
        case .zhTW, .zhHK: return "在 Mac 上最佳化圖片、GIF 和影片。"
        default: return "Optimize images, GIFs and videos on your Mac."
        }
    }
    static func title(_ language: AppLanguage) -> String {
        switch language {
        case .ptBR: return "Otimizador de mídia"
        case .es: return "Optimizador multimedia"
        case .fr: return "Optimiseur multimédia"
        case .de: return "Medienoptimierung"
        case .it: return "Ottimizzatore multimediale"
        case .tr: return "Medya İyileştirici"
        case .ru: return "Оптимизация медиа"
        case .uk: return "Оптимізація медіа"
        case .sk: return "Optimalizácia médií"
        case .ja: return "メディア最適化"
        case .ko: return "미디어 최적화"
        case .zhHans: return "媒体优化"
        case .zhTW, .zhHK: return "媒體最佳化"
        default: return "Media Optimizer"
        }
    }
    static func preview(_ language: AppLanguage) -> String {
        switch language {
        case .ptBR: return "Prévia"
        case .es: return "Vista previa"
        case .fr: return "Aperçu"
        case .de: return "Vorschau"
        case .it: return "Anteprima"
        case .tr: return "Önizleme"
        case .ru: return "Предпросмотр"
        case .uk: return "Перегляд"
        case .sk: return "Náhľad"
        case .ja: return "プレビュー"
        case .ko: return "미리보기"
        case .zhHans: return "预览"
        case .zhTW, .zhHK: return "預覽"
        default: return "Preview"
        }
    }
}
