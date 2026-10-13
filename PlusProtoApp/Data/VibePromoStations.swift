import SwiftUI

/// Станция «Моей волны» в промо «Главной» (задача 65, макет `2688:26198`): лепесток —
/// капля цвета станции, иллюстрация агента, «Моя волна» и название станции
/// (`PromoStationCard`). Станция на выбор трека не влияет: тап включает волну.
struct VibePromoStation: Hashable {
    let id: String
    let name: String
    /// Иллюстрация агента — растр из SVG макета `2688:26278` с его внутренними тенями,
    /// перекрашенный в цвета станции (фильтры SVG iOS не рисует).
    let asset: String
    /// Цвет капли и её светлой кромки
    let fill: Color
    let rim: Color
}

extension VibePromoStation {
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
            title: "Моя волна",
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
