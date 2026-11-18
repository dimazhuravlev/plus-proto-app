import Foundation

/// Current State 19537:59105: между 375 и 528 pt растёт только медиа.
/// Девменю может изменить границы ширины, не масштабируя текст и контролы.
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
    let wave: PromoWaveGeometry
    let centerY: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let avatar: CGFloat
    let captionGap: CGFloat
    let artistCaptionGap: CGFloat

    init(viewportWidth: CGFloat, movieWidths: PromoMediaWidthRange = .poster,
         bookWidths: PromoMediaWidthRange = .poster, albumWidths: PromoMediaWidthRange = .square,
         artistWidths: PromoMediaWidthRange = .square) {
        let scale = PromoViewportSizing.scale(viewportWidth: viewportWidth)
        self.scale = scale
        func card(_ widths: PromoMediaWidthRange, neighbour: CGFloat, ratio: CGFloat = 1) -> Card {
            let width = widths.width(viewportWidth: viewportWidth)
            let sideWidth = min(width, (neighbour * scale).rounded())
            return Card(main: CGSize(width: width, height: (width * ratio).rounded()),
                        neighbour: CGSize(width: sideWidth, height: (sideWidth * ratio).rounded()))
        }
        movie = card(movieWidths, neighbour: 162, ratio: 1.5)
        book = card(bookWidths, neighbour: 162, ratio: 1.5)
        album = card(albumWidths, neighbour: 169)
        artist = card(artistWidths, neighbour: 169)
        wave = PromoWaveGeometry(artSize: artist.main.width)
        let neighbourScale = artist.neighbour.width / artist.main.width
        station = Card(main: wave.frame,
                       neighbour: CGSize(width: wave.frame.width * neighbourScale,
                                         height: wave.frame.height * neighbourScale))
        step = (180 * scale).rounded()
        cornerRadius = 18
        avatar = 40
        captionGap = 8
        artistCaptionGap = 8
        // The station frame includes controls and caption; like album captions these use
        // the existing outer reserve, not the media height that sets the row center.
        let stationMediaHeight = wave.artSize
        // Reserve the tallest supported book, not one example's aspect ratio.
        let bookHeight = (book.main.width / 0.6).rounded()
        let tallestMedia = max(movie.main.height, bookHeight, album.main.height,
                               artist.main.height, stationMediaHeight)
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

/// Figma spacing and captions; artwork shares the ordinary artist card sizing.
struct PromoWaveGeometry {
    let captionWidth: CGFloat
    let artSize: CGFloat
    let frame: CGSize
    let captionTop: CGFloat
    let artOrigin: CGPoint

    var artCenter: CGPoint { CGPoint(x: frame.width / 2, y: artOrigin.y + artSize / 2) }
    /// Align the picture with other media; controls and caption are asymmetric.
    var centeringOffset: CGFloat { frame.height / 2 - artCenter.y }

    init(artSize: CGFloat) {
        self.artSize = artSize
        captionWidth = 220
        frame = CGSize(width: max(captionWidth, artSize), height: 118 + artSize)
        captionTop = 56 + artSize
        artOrigin = CGPoint(x: (frame.width - artSize) / 2, y: 48)
    }
}


struct PromoMediaWidthRange {
    let minimum: CGFloat
    let maximum: CGFloat
    static let poster = Self(minimum: 205, maximum: 240)
    static let square = Self(minimum: 232, maximum: 272)

    static func progress(viewportWidth: CGFloat) -> CGFloat {
        min(1, max(0, (viewportWidth - 375) / (528 - 375)))
    }

    func width(viewportWidth: CGFloat) -> CGFloat {
        minimum + (maximum - minimum) * Self.progress(viewportWidth: viewportWidth)
    }
}

/// Exact gradient stops from Current State; the small artist instance has a linear falloff.
enum PromoWaveShadowGeometry {
    static let width: CGFloat = 284
    static let height: CGFloat = 148
    static let opacity: Double = 0.99
    static let captionOffset: CGFloat = -50
    static let smoothAlphas: [Double] = [
        0.4, 0.3965411186, 0.3857960105, 0.3673360646,
        0.3410354853, 0.3072900772, 0.2672464550, 0.2229235172,
        0.1770764887, 0.1327535510, 0.0927099288, 0.0589645319,
        0.0326639414, 0.0142040001, 0.0034588787, 0
    ]

    static func alphas(artist: Bool, viewportWidth: CGFloat) -> [Double] {
        let t = artist ? Double(PromoMediaWidthRange.progress(viewportWidth: viewportWidth)) : 1
        return smoothAlphas.enumerated().map { index, alpha in
            let linear = 0.4 * (1 - Double(index) / 15)
            return linear + (alpha - linear) * t
        }
    }
}
