import SwiftUI

/// Станция «Моей волны» в промо «Главной» (задача 65, макет `2688:26198`): лепесток —
/// капля цвета станции, иллюстрация агента, «Моя волна» и название станции
/// (`PromoStationCard`). Станция на выбор трека не влияет: тап включает волну.
///
/// Вид станции (задача 68): жанровая — с иллюстрацией агента, или волна «в стиле артиста»
/// (макет `2698:27113`) — тот же лепесток с круглым фото артиста, имя артиста — название.
struct VibePromoStation: Hashable {
    enum Kind: Hashable {
        /// Иллюстрация агента — растр из SVG макета `2688:26278` с его внутренними тенями,
        /// перекрашенный в цвета станции (фильтры SVG iOS не рисует).
        case genre(asset: String)
        /// Волна в стиле артиста — его фото в круге на месте иллюстрации.
        case artist(ArtistBlock)
    }

    let id: String
    let name: String
    let kind: Kind
    /// Цвет капли и её светлой кромки
    let fill: Color
    let rim: Color

    /// Иллюстрация жанровой станции; у артист-волны — `nil`.
    var asset: String? {
        if case .genre(let asset) = kind { asset } else { nil }
    }

    /// Артист волны «в стиле артиста»; у жанровой станции — `nil`.
    var artist: ArtistBlock? {
        if case .artist(let artist) = kind { artist } else { nil }
    }

    /// Картинка станции — фон под слайдером: иллюстрация в цветах станции или фото артиста.
    var artwork: ArtworkSource {
        switch kind {
        case .genre(let asset): .asset(asset)
        case .artist(let artist): artist.picture
        }
    }
}

extension VibePromoStation {
    /// Жанровая станция — с иллюстрацией агента.
    init(id: String, name: String, asset: String, fill: Color, rim: Color) {
        self.init(id: id, name: name, kind: .genre(asset: asset), fill: fill, rim: rim)
    }

    /// Волна «в стиле артиста» (задача 68): id — `artist-wave-<id Deezer>`, название — имя
    /// артиста. Цвет капли — из палитры по id артиста: один и тот же на любой пересборке.
    static func artistWave(_ artist: ArtistBlock) -> VibePromoStation {
        let color = palette[abs(artist.id) % palette.count]
        return VibePromoStation(
            id: "artist-wave-\(artist.id)",
            name: artist.name,
            kind: .artist(artist),
            fill: color.fill,
            rim: color.rim
        )
    }

    /// Место цвета станции в палитре — по нему фон промо волны «в стиле артиста» берёт
    /// растр её капли.
    var paletteIndex: Int? { Self.palette.firstIndex { $0.fill == fill && $0.rim == rim } }

    /// Палитра «Моя волна 2026» — 16 цветов капли и кромки (файл `ggO4AevC3hbrmBYsNGXq3S`,
    /// нода `11403:7010`): carmine, coral, tangerine, clover, emerald, turquoise, aquamarine,
    /// glacier, slate, sapphire, indigo, amethyst, plum, orchid, raspberry, fuchsia.
    static let palette: [(fill: Color, rim: Color)] = [
        (Color(hex: 0xF5002E), Color(hex: 0xFF99AC)),
        (Color(hex: 0xF53700), Color(hex: 0xFFB099)),
        (Color(hex: 0xF56E00), Color(hex: 0xFFC799)),
        (Color(hex: 0x34C03E), Color(hex: 0xAFE9B3)),
        (Color(hex: 0x00C789), Color(hex: 0x00C789)),
        (Color(hex: 0x00C7A6), Color(hex: 0x00C7A6)),
        (Color(hex: 0x00B2CC), Color(hex: 0x00B2CC)),
        (Color(hex: 0x5C8E9B), Color(hex: 0xBFD4D9)),
        (Color(hex: 0x4F6C9B), Color(hex: 0xBBC8DD)),
        (Color(hex: 0x0C41E8), Color(hex: 0x9EB4FA)),
        (Color(hex: 0x160CE8), Color(hex: 0xA29EFA)),
        (Color(hex: 0x5035C0), Color(hex: 0xBAAFE9)),
        (Color(hex: 0x7C35C0), Color(hex: 0xCDAFE9)),
        (Color(hex: 0xBB1ADB), Color(hex: 0xE7A4F4)),
        (Color(hex: 0xDB1A7D), Color(hex: 0xF4A4CD)),
        (Color(hex: 0xF5007C), Color(hex: 0xFF99CD)),
    ]

    /// Восемь станций — разные иллюстрации, цвета и названия; названия — от пользователя
    /// (2026-10-13). Цвета — палитра «Моя волна 2026» (файл `ggO4AevC3hbrmBYsNGXq3S`,
    /// нода `11403:7010`). Первая — станция макета и мок-промо.
    static let all: [VibePromoStation] = [
        VibePromoStation(id: "medieval-emo", name: "Средневековое симфоническое мидвест-эмо",
                         asset: "vibeStationPopCarmine", fill: Color(hex: 0xF5002E), rim: Color(hex: 0xFF99AC)),
        VibePromoStation(id: "space-fusion", name: "Космический джаз-фьюжн",
                         asset: "vibeStationPopIndigo", fill: Color(hex: 0x160CE8), rim: Color(hex: 0xA29EFA)),
        VibePromoStation(id: "dacha-shoegaze", name: "Дачный шугейз",
                         asset: "vibeStationSentimentalCoral", fill: Color(hex: 0xF53700), rim: Color(hex: 0xFFB099)),
        VibePromoStation(id: "tropical-dreampop", name: "Тропический дрим-поп",
                         asset: "vibeStationSentimentalAquamarine", fill: Color(hex: 0x00B2CC), rim: Color(hex: 0x00B2CC)),
        VibePromoStation(id: "sad-hyperpop", name: "Гиперпоп для грустных",
                         asset: "vibeStationAltrockOrchid", fill: Color(hex: 0xBB1ADB), rim: Color(hex: 0xE7A4F4)),
        VibePromoStation(id: "siberian-postpunk", name: "Сибирский пост-панк",
                         asset: "vibeStationAltrockSapphire", fill: Color(hex: 0x0C41E8), rim: Color(hex: 0x9EB4FA)),
        VibePromoStation(id: "balkan-breakcore", name: "Балканский брейккор",
                         asset: "vibeStationEstradaClover", fill: Color(hex: 0x34C03E), rim: Color(hex: 0xAFE9B3)),
        VibePromoStation(id: "baroque-house", name: "Барочный хаус",
                         asset: "vibeStationEstradaTangerine", fill: Color(hex: 0xF56E00), rim: Color(hex: 0xFFC799)),
    ]
}

extension VibeBlock {
    /// Станция промо — блок «Моей волны» со станцией. Не блок ленты: у ленты свой
    /// (орб `MyVibeCard`), а станция промо своя на каждый холодный запуск.
    static func promo(_ station: VibePromoStation) -> VibeBlock {
        VibeBlock(
            id: "vibe-\(station.id)",
            // У артист-волны — две строки (макет `2698:27113`), под ними имя артиста.
            title: station.artist == nil ? "Моя волна" : "Моя волна\nв стиле артиста",
            subtitle: station.name,
            // Своей обложки у волны нет — заглушка трека, как у мок-станции ленты.
            cover: .asset("mockPlayerCover"),
            station: station
        )
    }

    /// Станция карточки промо. Блок без станции в круг не попадает (`ShowcaseCatalog`
    /// публикует только станции); на этот случай — первая станция списка, как у мок-промо.
    var promoStation: VibePromoStation {
        station ?? VibePromoStation.all[0]
    }
}
