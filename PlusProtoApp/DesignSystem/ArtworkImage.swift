import SwiftUI

/// Картинка контента: сейчас из бандла, на Этапе 7 — из API.
/// Источник различаем здесь, чтобы вёрстка карточек не переписывалась при переходе
/// на живые данные (приём `Track` из MusicPlayer: имя ассета + опциональный URL).
struct ArtworkImage: View {
    let source: ArtworkSource

    var body: some View {
        switch source {
        case .asset(let name):
            Image(name).resizable()
        case .remote(let url):
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable()
                } else {
                    Color.buttonsPrimary
                }
            }
        }
    }
}

extension ArtworkSource {
    /// `Image` напрямую — нужен там, где вью требует именно его (например `AmbilightArtwork`).
    /// Для `.remote` вернёт плейсхолдер: асинхронную загрузку умеет только `ArtworkImage`.
    var staticImage: Image {
        switch self {
        case .asset(let name): Image(name)
        case .remote: Image(systemName: "photo")
        }
    }
}
