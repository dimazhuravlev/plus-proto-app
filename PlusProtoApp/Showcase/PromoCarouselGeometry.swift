import Foundation

/// Единственное место расчёта размеров промокарусели. Размеры и отступы округлены
/// до целых pt; центрирование нечётного размера может дать координату0.5pt.
struct PromoCarouselGeometry {
    struct Card {
        let main: CGSize
        let neighbour: CGSize
    }

    let scale: CGFloat
    let step: CGFloat
    let movie: Card
    let book: Card
    let album: Card
    let artist: Card
    let station: Card
    let centerY: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let avatar: CGFloat
    let captionGap: CGFloat
    let stationCaptionWidth: CGFloat
    let stationCaptionOrigin: CGPoint
    let artistCaptionGap: CGFloat

    init(viewportWidth: CGFloat, movieWidth: CGFloat, bookWidth: CGFloat,
         albumWidth: CGFloat, artistWidth: CGFloat, stationWidth: CGFloat) {
        let scale = PromoViewportSizing.scale(viewportWidth: viewportWidth)
        self.scale = scale
        // Размеры, заданные пользователем для440pt, не являются базой402pt.
        // Меняем только основные карточки; масштаб соседей и шаг сохраняются.
        let mainScale = min(max(min(viewportWidth, PromoViewportSizing.maximumMediaViewportWidth) / 440,
                                PromoViewportSizing.scaleRange.lowerBound), PromoViewportSizing.scaleRange.upperBound)
        func size(_ width: CGFloat, ratio: CGFloat, factor: CGFloat, maximum: CGFloat) -> CGSize {
            let width = min((width * factor).rounded(), maximum)
            return CGSize(width: width, height: (width * ratio).rounded())
        }
        func card(_ width: CGFloat, neighbour: CGFloat, ratio: CGFloat = 1, maximum: CGFloat = PromoViewportSizing.maximumOtherWidth) -> Card {
            Card(main: size(width, ratio: ratio, factor: mainScale, maximum: maximum),
                 neighbour: size(neighbour, ratio: ratio, factor: scale, maximum: maximum))
        }
        movie = card(movieWidth, neighbour: 162, ratio: 3.0 / 2, maximum: PromoViewportSizing.maximumPosterWidth)
        book = card(bookWidth, neighbour: 162, ratio: 3.0 / 2, maximum: PromoViewportSizing.maximumPosterWidth)
        album = card(albumWidth, neighbour: 169)
        artist = card(artistWidth, neighbour: 169)
        // Пропорции исходной иллюстрации, а не произвольный коэффициент лейаута.
        station = card(stationWidth, neighbour: 160, ratio: 249.0 / 208)
        let stationArtScale = station.main.width / 208
        stationCaptionWidth = (163 * stationArtScale).rounded()
        stationCaptionOrigin = CGPoint(x: (22.5 * stationArtScale).rounded(), y: (119 * stationArtScale).rounded())
        step = (180 * scale).rounded()
        cornerRadius = (16 * scale).rounded()
        avatar = (40 * scale).rounded()
        captionGap = (7 * scale).rounded()
        artistCaptionGap = (captionGap + (avatar - 38) / 2).rounded()
        let tallestMedia = max(movie.main.height, book.main.height, album.main.height,
                               artist.main.height, station.main.height)
        centerY = max(175 * scale, tallestMedia / 2 + 17 * scale).rounded()
        let tallestWithCaptions = max(tallestMedia, album.main.height + 2 * avatar,
                                      artist.main.height + 2 * artistCaptionGap)
        // Нижний резерв под описания и реакции не растёт с шириной окна.
        height = (centerY + tallestWithCaptions / 2 + 80).rounded()
    }

    /// 11pt — середина прежнего диапазона6…16; теперь посадка не меняется между запусками.
    func neighbourDrop(additionalOffset: CGFloat) -> CGFloat { scaled(11 + additionalOffset) }

    func scaled(_ base: CGFloat) -> CGFloat { (base * scale).rounded() }
}
