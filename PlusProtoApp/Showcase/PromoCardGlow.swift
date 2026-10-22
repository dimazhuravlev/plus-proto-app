import SwiftUI
import UIKit

enum PromoCardGlowConfig {
    static let blur: CGFloat = 40
    static let padding: CGFloat = blur * 3
    static let rasterScale: CGFloat = 0.25
    static let opacity: Double = 0.5
}

/// Цвет и силуэт самой карточки в небольшом прозрачном растре, без заливки экрана.
@MainActor enum PromoCardGlowRaster {
    struct Key: Hashable {
        let source: ArtworkSource
        let width: CGFloat
        let height: CGFloat
        let radius: CGFloat
        let station: VibePromoStation?
    }
    private static var cache = PromoResourceCache<Key, UIImage>(countLimit: 96, costLimit: 24 * 1024 * 1024)

    static func retain(_ items: [ShowcaseBlock]) {
        cache.retain(Set(items.map { key(for: $0) }))
    }

    private static func store(_ image: UIImage, for key: Key) {
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        cache.insert(image, for: key, cost: cost)
    }

    static func key(for item: ShowcaseBlock) -> Key {
        typealias Layout = ShowcasePromoLayout
        let size: CGSize
        let radius: CGFloat
        let source = item.promoArtwork
        var station: VibePromoStation?
        switch item {
        case .movie, .watching:
            size = Layout.poster; radius = Layout.posterRadius
        case .book, .reading:
            size = Layout.book.geometry.frameSize(coverWidth: Layout.book.coverWidth)
            radius = Layout.posterRadius
        case .album:
            size = CGSize(width: Layout.album, height: Layout.albumHeight)
            radius = Layout.albumRadius
        case .artist:
            size = CGSize(width: Layout.artist, height: Layout.artist)
            radius = Layout.artist / 2
        case .vibe(let vibe):
            station = vibe.promoStation
            size = CGSize(width: PromoStationLayout.frame.width * Layout.stationScale,
                          height: PromoStationLayout.frame.height * Layout.stationScale)
            radius = 16 * Layout.scale
        }
        return Key(source: source, width: size.width, height: size.height, radius: radius,
                   station: station)
    }

    static func cached(_ item: ShowcaseBlock) -> UIImage? { cache[key(for: item)] }

    static func canvas(_ item: ShowcaseBlock) -> CGSize {
        let key = key(for: item)
        let padding = PromoCardGlowConfig.padding * ShowcasePromoLayout.scale
        return CGSize(width: key.width + padding * 2, height: key.height + padding * 2)
    }

    static func render(_ item: ShowcaseBlock) async {
        guard !Task.isCancelled else { return }
        let key = key(for: item)
        guard cache[key] == nil else { return }
        if let station = key.station {
            // Render only the petal. Neither the avatar nor station captions enter
            // this bitmap; the genre mark is also excluded from its glow.
            let scale = PromoCardGlowConfig.rasterScale
            let padding = PromoCardGlowConfig.padding * ShowcasePromoLayout.scale
            let renderer = ImageRenderer(content:
                PromoStationPetal(station: station)
                    .frame(width: key.width, height: key.height, alignment: .topLeading)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: key.width * scale, height: key.height * scale, alignment: .topLeading)
                    .blur(radius: PromoCardGlowConfig.blur * ShowcasePromoLayout.scale * scale)
                    .padding(padding * scale)
            )
            renderer.scale = 1
            if let result = renderer.uiImage { store(result, for: key) }
            return
        }
        let image: UIImage?
        if let url = key.source.remoteURL { image = await ArtworkLoader.shared.image(for: url) }
        else { image = key.source.fallbackAsset.flatMap { UIImage(named: $0) } }
        guard !Task.isCancelled, let image else { return }
        guard cache[key] == nil else { return }
        let scale = PromoCardGlowConfig.rasterScale
        let padding = PromoCardGlowConfig.padding * ShowcasePromoLayout.scale
        let renderer = ImageRenderer(content:
            Image(uiImage: image).resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: key.width * scale, height: key.height * scale)
                .clipShape(RoundedRectangle(cornerRadius: key.radius * scale))
                .blur(radius: PromoCardGlowConfig.blur * ShowcasePromoLayout.scale * scale)
                .frame(width: (key.width + padding * 2) * scale,
                       height: (key.height + padding * 2) * scale)
        )
        renderer.scale = 1
        if let result = renderer.uiImage { store(result, for: key) }
    }
}
