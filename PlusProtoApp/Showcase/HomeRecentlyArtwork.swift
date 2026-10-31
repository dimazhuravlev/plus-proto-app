import SwiftUI

/// Представление миниатюр остаётся extension того же View: извлечение не добавляет
/// контейнеров в дерево и сохраняет порядок геометрии, обрезки и наложений.
extension HomeQuickAccess {
    var bookSlotWidth: CGFloat { 54 }

    func captioned<Content: View>(_ title: String, width: CGFloat, leading: CGFloat = 0, @ViewBuilder content: () -> Content) -> some View {
        let baseWidth = width
        let contentWidth = width * HomeQuickAccessLayout.scale
        let width = contentWidth
        return content().frame(width: contentWidth, height: HomeQuickAccessLayout.height)
        .overlay(alignment: .bottom) {
            FadingCardCaption(title: title, width: width - leading)
                .padding(.leading, leading)
                .opacity(HomeQuickAccessLayout.labelProgress)
                .frame(height: 16)
                .offset(y: 20)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .padding(.bottom, 20 * HomeQuickAccessLayout.labelProgress)
        .frame(width: width)
        .preference(key: HomeRecentlyWidths.self, value: [baseWidth])
        .contentShape(Rectangle())
    }

    func artwork(_ source: ArtworkSource, width: CGFloat, height: CGFloat, radius: CGFloat) -> some View {
        let scale = HomeQuickAccessLayout.scale
        let shape = RoundedRectangle(cornerRadius: radius * scale, style: .continuous)
        return Color.clear
            .frame(width: width * scale, height: height * scale)
            .overlay { ArtworkImage(source: source).scaledToFill() }
            .clipShape(shape)
            .overlay { shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 0.66) }
    }

    func movieThumbnail(_ source: ArtworkSource, movieID: String, progress: Double?) -> some View {
        let scale = HomeQuickAccessLayout.scale
        let width = 138 * scale
        let trackWidth = width - 8
        let shape = RoundedRectangle(cornerRadius: 6 * scale, style: .continuous)
        return Color.clear
            .frame(width: width, height: 78 * scale)
            .overlay { RecentMovieFrame(movieID: movieID, source: source).id(movieID) }
            .overlay(alignment: .bottomLeading) {
                Capsule().fill(Color.white.opacity(0.1))
                        .overlay(alignment: .leading) {
                            Capsule().fill(HomeQuickAccessLayout.progressColor)
                                .frame(width: trackWidth * min(max(progress ?? 0, 0), 1))
                        }
                        .frame(width: trackWidth, height: 3)
                        .padding(4)
            }
            .clipShape(shape)
            .overlay { shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 0.66) }
            .frame(height: HomeQuickAccessLayout.height)
    }

    func bookThumbnail(_ source: ArtworkSource) -> some View {
        bookArtwork(source)
            .frame(width: bookSlotWidth * HomeQuickAccessLayout.scale, height: HomeQuickAccessLayout.height)
    }

    /// Книга — общая карточка книги (`BookFigure`, `card / book`) высотой ряда: слот
    /// 54 × 80 макета, обложка заполняет его целиком.
    private func bookArtwork(_ source: ArtworkSource) -> some View {
        let scale = HomeQuickAccessLayout.scale
        let geometry = BookFigureGeometry(coverHeight: 80 * scale)
        return BookFigure(geometry: geometry, coverWidth: bookSlotWidth * scale) {
            ArtworkImage(source: source).scaledToFill()
        }
    }
}
