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
    /// Цвет капли и её светлой кромки — хексами палитры: `Color` считается при обращении,
    /// в пространстве палитры (`PlusColorSpace`), и переключается вместе с ней.
    let fillHex: UInt32
    let rimHex: UInt32
    var fill: Color { Color(hex: fillHex) }
    var rim: Color { Color(hex: rimHex) }

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
    init(id: String, name: String, asset: String, fillHex: UInt32, rimHex: UInt32) {
        self.init(id: id, name: name, kind: .genre(asset: asset), fillHex: fillHex, rimHex: rimHex)
    }

    /// Волна «в стиле артиста» (задача 68): id — `artist-wave-<id Deezer>`, название — имя
    /// артиста. Цвет капли — из палитры по id артиста: один и тот же на любой пересборке.
    static func artistWave(_ artist: ArtistBlock) -> VibePromoStation {
        let color = palette[abs(artist.id) % palette.count]
        return VibePromoStation(
            id: "artist-wave-\(artist.id)",
            name: artist.name,
            kind: .artist(artist),
            fillHex: color.fill,
            rimHex: color.rim
        )
    }

    /// Место цвета станции в палитре — по нему фон промо волны «в стиле артиста» берёт
    /// растр её капли.
    var paletteIndex: Int? { Self.palette.firstIndex { $0.fill == fillHex && $0.rim == rimHex } }

    /// Палитра «Моя волна 2026» — 16 цветов капли и кромки (файл `ggO4AevC3hbrmBYsNGXq3S`,
    /// нода `11403:7010`): carmine, coral, tangerine, clover, emerald, turquoise, aquamarine,
    /// glacier, slate, sapphire, indigo, amethyst, plum, orchid, raspberry, fuchsia.
    static let palette: [(fill: UInt32, rim: UInt32)] = [
        (0xF5002E, 0xFF99AC),
        (0xF53700, 0xFFB099),
        (0xF56E00, 0xFFC799),
        (0x34C03E, 0xAFE9B3),
        (0x00C789, 0x00C789),
        (0x00C7A6, 0x00C7A6),
        (0x00B2CC, 0x00B2CC),
        (0x5C8E9B, 0xBFD4D9),
        (0x4F6C9B, 0xBBC8DD),
        (0x0C41E8, 0x9EB4FA),
        (0x160CE8, 0xA29EFA),
        (0x5035C0, 0xBAAFE9),
        (0x7C35C0, 0xCDAFE9),
        (0xBB1ADB, 0xE7A4F4),
        (0xDB1A7D, 0xF4A4CD),
        (0xF5007C, 0xFF99CD),
    ]

    /// Восемь станций — разные иллюстрации, цвета и названия; названия — от пользователя
    /// (2026-10-13). Цвета — палитра «Моя волна 2026» (файл `ggO4AevC3hbrmBYsNGXq3S`,
    /// нода `11403:7010`). Первая — станция макета и мок-промо.
    static let all: [VibePromoStation] = [
        VibePromoStation(id: "medieval-emo", name: "Средневековое симфоническое мидвест-эмо",
                         asset: "vibeStationPopCarmine", fillHex: 0xF5002E, rimHex: 0xFF99AC),
        VibePromoStation(id: "space-fusion", name: "Космический джаз-фьюжн",
                         asset: "vibeStationPopIndigo", fillHex: 0x160CE8, rimHex: 0xA29EFA),
        VibePromoStation(id: "dacha-shoegaze", name: "Дачный шугейз",
                         asset: "vibeStationSentimentalCoral", fillHex: 0xF53700, rimHex: 0xFFB099),
        VibePromoStation(id: "tropical-dreampop", name: "Тропический дрим-поп",
                         asset: "vibeStationSentimentalAquamarine", fillHex: 0x00B2CC, rimHex: 0x00B2CC),
        VibePromoStation(id: "sad-hyperpop", name: "Гиперпоп для грустных",
                         asset: "vibeStationAltrockOrchid", fillHex: 0xBB1ADB, rimHex: 0xE7A4F4),
        VibePromoStation(id: "siberian-postpunk", name: "Сибирский пост-панк",
                         asset: "vibeStationAltrockSapphire", fillHex: 0x0C41E8, rimHex: 0x9EB4FA),
        VibePromoStation(id: "balkan-breakcore", name: "Балканский брейккор",
                         asset: "vibeStationEstradaClover", fillHex: 0x34C03E, rimHex: 0xAFE9B3),
        VibePromoStation(id: "baroque-house", name: "Барочный хаус",
                         asset: "vibeStationEstradaTangerine", fillHex: 0xF56E00, rimHex: 0xFFC799),
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
