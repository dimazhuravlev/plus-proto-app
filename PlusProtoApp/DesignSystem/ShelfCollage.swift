import SwiftUI

/// Обложка полки — мозаика 2×2 из обложек её книг без зазоров, как у своих плейлистов
/// (`mockMyPlaylist…`); габарит — квадрат, как `card / collection` ДС (`205:26919`).
/// Обложки книг вертикальные — в квадратной клетке режутся по центру. Рамку, форму,
/// заливку скелетона и кромку задаёт место: строка таба, карточка сетки.
struct ShelfCollage: View {
    let sources: [ArtworkSource]
    /// Как проявляются обложки, приехавшие из сети, — в такт строке или карточке.
    var appear: Animation? = nil

    /// Клеток в мозаике — 2×2.
    static let cells = 4

    var body: some View {
        // Стопки делят рамку поровну: клетки одинаково гибкие, размер даёт место.
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                cell(0)
                cell(1)
            }
            HStack(spacing: 0) {
                cell(2)
                cell(3)
            }
        }
    }

    private func cell(_ index: Int) -> some View {
        // Кадр задаёт распорка, картинка — `scaledToFill` поверх и обрезана по клетке.
        Color.clear
            .overlay {
                if sources.indices.contains(index) {
                    ResolvedArtwork(source: sources[index], appear: appear) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                }
            }
            .clipped()
    }
}
