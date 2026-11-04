import Foundation

@main enum PromoCarouselGeometryChecks {
    static func main() {
        for width: CGFloat in [320, 375, 390, 402, 414, 440, 528, 744, 834, 1024, 2048] {
            let g = PromoCarouselGeometry(viewportWidth: width, movieWidth: 240, bookWidth: 240,
                                          albumWidth: 272, artistWidth: 272, stationWidth: 272)
            let neighbourScale = PromoViewportSizing.scale(viewportWidth: width)
            let mainScale = min(max(min(width, 528) / 440, 0.6), 1.2)
            for (card, base, neighbour, ratio, cap): (PromoCarouselGeometry.Card, CGFloat, CGFloat, CGFloat, CGFloat) in [
                (g.movie, 240, 162, 1.5, 288), (g.book, 240, 162, 1.5, 288),
                (g.album, 272, 169, 1, 326), (g.artist, 272, 169, 1, 326),
                (g.station, 272, 160, 249.0 / 208, 326)
            ] {
                precondition(card.main.width == min((base * mainScale).rounded(), cap))
                precondition(card.main.height == (card.main.width * ratio).rounded())
                precondition(card.neighbour.width == (neighbour * neighbourScale).rounded())
                precondition(card.neighbour.height == (card.neighbour.width * ratio).rounded())
                precondition(g.centerY >= card.main.height / 2)
                precondition(g.height >= g.centerY + card.main.height / 2 + 80)
            }
            precondition(g.step == (180 * neighbourScale).rounded())
            precondition(g.neighbourDrop(additionalOffset: 32) == (43 * neighbourScale).rounded())
            if width == 440 { precondition(g.movie.main.width == 240 && g.album.main.width == 272) }
        }
        for width: CGFloat in [375, 440, 744, 834, 2048] {
            let g = PromoCarouselGeometry(viewportWidth: width, movieWidth: 400, bookWidth: 400,
                                          albumWidth: 400, artistWidth: 400, stationWidth: 400)
            precondition(g.movie.main.width <= 288 && g.book.main.width <= 288)
            precondition(g.album.main.width <= 326 && g.artist.main.width <= 326 && g.station.main.width <= 326)
        }
        for count in [5, 7] {
            for tick in 0...1000 {
                let center = CGFloat(tick) / 1000
                let visible = (-8...8).filter { PromoViewportSizing.visibility(at: CGFloat($0) - center, count: count) > 0 }
                precondition(visible.count <= count)
            }
        }
        print("PASS: widths use 440pt reference; neighbours and step preserved; bounded media and five/seven-slot visibility")
    }
}
