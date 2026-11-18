import Foundation

@main enum PromoCarouselGeometryChecks {
    static func close(_ actual: CGFloat, _ expected: CGFloat) {
        precondition(abs(actual - expected) < 0.000001, "Expected \(expected), got \(actual)")
    }
    static func main() {
        for width: CGFloat in [320, 375, 390, 402, 414, 440, 528, 744, 834, 1024, 2048] {
            let g = PromoCarouselGeometry(viewportWidth: width)
            let t = min(1, max(0, (width - 375) / 153))
            close(g.movie.main.width, 205 + 35 * t)
            close(g.book.main.width, g.movie.main.width)
            close(g.album.main.width, 232 + 40 * t)
            close(g.artist.main.width, g.album.main.width)
            close(g.wave.artSize, g.artist.main.width)
            precondition(g.avatar == 40 && g.captionGap == 8 && g.artistCaptionGap == 8)
            precondition(g.cornerRadius == 18 && g.wave.captionWidth == 220)
            close(g.wave.frame.height, g.wave.artSize + 118)
            close(g.wave.frame.height - g.wave.captionTop, 62)
            close(g.wave.artOrigin.y - 40, 8)
            close(g.wave.captionTop - g.wave.artOrigin.y - g.wave.artSize, 8)
            precondition(g.centerY >= (g.book.main.width / 0.6).rounded() / 2)
            precondition(g.centerY + (g.book.main.width / 0.6).rounded() / 2 + 60 <= g.height)
            close(g.wave.artSize * g.station.neighbour.width / g.station.main.width, g.artist.neighbour.width)
            let top = g.centerY - g.station.main.height / 2 + g.wave.centeringOffset
            close(top + g.wave.artCenter.y, g.centerY)
            close(g.neighbourDrop(additionalOffset: 32), (43 * g.scale).rounded())
            if width <= 375 { precondition(g.movie.main.width == 205 && g.movie.main.height == 308) }
            if width >= 528 { precondition(g.movie.main.width == 240 && g.movie.main.height == 360) }
            let custom = PromoCarouselGeometry(viewportWidth: width,
                movieWidths: .init(minimum: 190, maximum: 260),
                bookWidths: .init(minimum: 210, maximum: 250),
                albumWidths: .init(minimum: 200, maximum: 300),
                artistWidths: .init(minimum: 160, maximum: 240))
            close(custom.movie.main.width, 190 + 70 * t)
            close(custom.book.main.width, 210 + 40 * t)
            close(custom.album.main.width, 200 + 100 * t)
            close(custom.artist.main.width, 160 + 80 * t)
            close(custom.wave.artSize, custom.artist.main.width)
            precondition(custom.artist.neighbour.width <= custom.artist.main.width)
            precondition(custom.avatar == 40 && custom.captionGap == 8)
        }
        let shadow = PromoWaveShadowGeometry.self
        precondition(shadow.width == 284 && shadow.height == 148 && shadow.captionOffset == -50)
        let smallArtist = shadow.alphas(artist: true, viewportWidth: 375)
        let largeArtist = shadow.alphas(artist: true, viewportWidth: 528)
        let genre = shadow.alphas(artist: false, viewportWidth: 375)
        for i in 0..<16 {
            close(CGFloat(smallArtist[i]), 0.4 * (1 - CGFloat(i) / 15))
            close(CGFloat(largeArtist[i]), CGFloat(genre[i]))
        }
        close(CGFloat(genre[0] * shadow.opacity), 0.396)
        close(CGFloat(genre[15]), 0)
        for count in [5, 7] {
            for tick in 0...1000 {
                let center = CGFloat(tick) / 1000
                let visible = (-8...8).filter { PromoViewportSizing.visibility(at: CGFloat($0) - center, count: count) > 0 }
                precondition(visible.count <= count)
            }
        }
        print("PASS: default Figma endpoints, editable ranges, fixed controls/text, wave centering, exact shadow gradients and slot visibility")
    }
}
