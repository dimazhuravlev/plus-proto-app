import SwiftUI

enum HomeShelfLift: Int, CaseIterable, Identifiable {
    case off = 0, up16 = 16, up32 = 32
    var id: Int { rawValue }
    var title: String { self == .off ? "Как раньше" : "↑ \(rawValue) px" }
}

enum HomePromoKind: String, CaseIterable, Identifiable {
    case movie, album, book, artist, station
    var id: Self { self }
    var title: String {
        switch self {
        case .movie: "Фильм"
        case .album: "Альбом"
        case .book: "Книга"
        case .artist: "Артист"
        case .station: "Моя волна"
        }
    }
    var originalWidth: Double {
        switch self {
        case .movie, .book: 210.155
        case .album, .artist: 219.8
        case .station: 208
        }
    }
    var initialWidth: Double {
        switch self {
        case .movie, .book: 236
        case .album: 276
        case .artist: 280
        case .station: 260
        }
    }
}

/// Общие параметры главной; отдельный компонент девменю меняет их через слой хранения.
@MainActor @Observable
final class HomePresentationSettings {
    static let shared = HomePresentationSettings()
    private static let prefix = "localHomeDev."
    private static let presetWidths = Dictionary(uniqueKeysWithValues: HomePromoKind.allCases.map { ($0.rawValue, $0.initialWidth) })
    /// Базовые параметры оставшихся регуляторов. Существующие локальные значения приоритетнее.
    private static let selectedDefaults: [String: Any] = [
        "recentlyHeight": 64.0, "sizes": true, "upright": true,
        "promoArtistWidth": 280.0,
        "promoMovieWidth": 236.0, "promoBookWidth": 236.0,
        "headerGapEnabled": true, "headerGap": 8.0,
        "heroGapEnabled": true, "heroGap": 24.0,
        "shelves": true, "shelfLift": 32, "widths": presetWidths
    ]
    var promoArtistWidth: Double { didSet { save("promoArtistWidth", promoArtistWidth) } }
    var shelfLift: HomeShelfLift { didSet { save("shelfLift", shelfLift.rawValue) } }
    var heroGapEnabled: Bool { didSet { save("heroGapEnabled", heroGapEnabled) } }
    var heroGap: Double { didSet { save("heroGap", heroGap) } }
    var headerGapEnabled: Bool { didSet { save("headerGapEnabled", headerGapEnabled) } }
    var headerGap: Double { didSet { save("headerGap", headerGap) } }
    var promoMovieWidth: Double { didSet { save("promoMovieWidth", promoMovieWidth) } }
    var promoBookWidth: Double { didSet { save("promoBookWidth", promoBookWidth) } }
    var sizesEnabled: Bool { didSet { save("sizes", sizesEnabled) } }
    var uprightEnabled: Bool { didSet { save("upright", uprightEnabled) } }
    var shelvesEnabled: Bool { didSet { save("shelves", shelvesEnabled) } }
    var recentlyWaveVideoEnabled: Bool { didSet { save("recentlyWaveVideo", recentlyWaveVideoEnabled) } }
    var waveShaderEnabled: Bool { didSet { save("waveShaderEnabled", waveShaderEnabled) } }
    var waveShaderScale: Double { didSet { save("waveShaderScale", waveShaderScale) } }
    var waveShaderGlow: Double { didSet { save("waveShaderGlow", waveShaderGlow) } }
    var waveShaderHue: Double { didSet { save("waveShaderHue", waveShaderHue) } }
    var waveShaderSaturation: Double { didSet { save("waveShaderSaturation", waveShaderSaturation) } }
    var waveShaderContrast: Double { didSet { save("waveShaderContrast", waveShaderContrast) } }
    var waveShaderWarp: Double { didSet { save("waveShaderWarp", waveShaderWarp) } }
    var waveShaderSpeed: Double { didSet { save("waveShaderSpeed", waveShaderSpeed) } }
    var waveShaderCoreSpeed: Double { didSet { save("waveShaderCoreSpeed", waveShaderCoreSpeed) } }
    var waveShaderMiddleSpeed: Double { didSet { save("waveShaderMiddleSpeed", waveShaderMiddleSpeed) } }
    var waveShaderRimSpeed: Double { didSet { save("waveShaderRimSpeed", waveShaderRimSpeed) } }
    var recentlyWaveOpacity: Double { didSet { save("recentlyWaveOpacity", recentlyWaveOpacity) } }
    var recentlyWaveSaturation: Double { didSet { save("recentlyWaveSaturation", recentlyWaveSaturation) } }
    var recentlyWaveContrast: Double { didSet { save("recentlyWaveContrast", recentlyWaveContrast) } }
    var recentlyPreviewIndex = -1
    var recentlyHeight: Double { didSet { save("recentlyHeight", recentlyHeight) } }
    var recentlyPreviewProgress: Double = 0.82
    var sideAngle: Double { didSet { save("angle", sideAngle) } }
    var widths: [String: Double] { didSet { save("widths", widths) } }

    private init() {
        let defaults = HomeSettingsStorage(defaults: Dictionary(uniqueKeysWithValues: Self.selectedDefaults.map {
            (Self.prefix + $0.key, $0.value)
        }))
        // Новый согласованный пресет применяется один раз, включая существующую
        // установку. Другие настройки и последующие ручные правки сохраняются.
        let layoutRevision = Self.prefix + "recentlyLayout20261022"
        if defaults.object(forKey: layoutRevision) as? Bool != true {
            HomeSettingsStorage.save(64.0, forKey: Self.prefix + "recentlyHeight")
            HomeSettingsStorage.save(24.0, forKey: Self.prefix + "heroGap")
            HomeSettingsStorage.save(true, forKey: Self.prefix + "heroGapEnabled")
            HomeSettingsStorage.save(true, forKey: layoutRevision)
        }
        func flag(_ key: String) -> Bool {
            defaults.object(forKey: Self.prefix + key) as? Bool ?? true
        }
        let oldArtistWidth = (defaults.dictionary(forKey: Self.prefix + "widths")?[HomePromoKind.artist.rawValue] as? Double)
        promoArtistWidth = defaults.object(forKey: Self.prefix + "promoArtistWidth") as? Double
            ?? oldArtistWidth.flatMap { $0 == 276 ? nil : $0 } ?? 280
        let storedShelfLift = defaults.object(forKey: Self.prefix + "shelfLift") as? Int ?? 32
        shelfLift = HomeShelfLift(rawValue: storedShelfLift) ?? .up32
        if storedShelfLift == 24 {
            HomeSettingsStorage.save(32, forKey: Self.prefix + "shelfLift")
        }
        heroGapEnabled = flag("heroGapEnabled")
        let storedHeroGap = defaults.object(forKey: Self.prefix + "heroGap") as? Double ?? 24
        heroGap = (min(max(storedHeroGap, -24), 96) / 4).rounded() * 4
        headerGapEnabled = flag("headerGapEnabled")
        let storedHeaderGap = defaults.object(forKey: Self.prefix + "headerGap") as? Double ?? 8
        headerGap = (min(max(storedHeaderGap, -24), 160) / 4).rounded() * 4
        promoMovieWidth = defaults.object(forKey: Self.prefix + "promoMovieWidth") as? Double ?? 236
        promoBookWidth = defaults.object(forKey: Self.prefix + "promoBookWidth") as? Double ?? 236
        sizesEnabled = flag("sizes")
        uprightEnabled = flag("upright")
        shelvesEnabled = flag("shelves")
        recentlyWaveVideoEnabled = flag("recentlyWaveVideo")
        waveShaderEnabled = flag("waveShaderEnabled")
        waveShaderScale = defaults.object(forKey: Self.prefix + "waveShaderScale") as? Double ?? 1
        waveShaderGlow = defaults.object(forKey: Self.prefix + "waveShaderGlow") as? Double ?? 0.14
        waveShaderHue = defaults.object(forKey: Self.prefix + "waveShaderHue") as? Double ?? 0
        waveShaderSaturation = defaults.object(forKey: Self.prefix + "waveShaderSaturation") as? Double ?? 1
        waveShaderContrast = defaults.object(forKey: Self.prefix + "waveShaderContrast") as? Double ?? 1
        waveShaderWarp = defaults.object(forKey: Self.prefix + "waveShaderWarp") as? Double ?? 0.035
        waveShaderSpeed = defaults.object(forKey: Self.prefix + "waveShaderSpeed") as? Double ?? 1
        waveShaderCoreSpeed = defaults.object(forKey: Self.prefix + "waveShaderCoreSpeed") as? Double ?? 0.5
        waveShaderMiddleSpeed = defaults.object(forKey: Self.prefix + "waveShaderMiddleSpeed") as? Double ?? 1
        waveShaderRimSpeed = defaults.object(forKey: Self.prefix + "waveShaderRimSpeed") as? Double ?? 0.7
        recentlyWaveOpacity = min(max(defaults.object(forKey: Self.prefix + "recentlyWaveOpacity") as? Double ?? 1, 0.5), 1)
        recentlyWaveSaturation = min(max(defaults.object(forKey: Self.prefix + "recentlyWaveSaturation") as? Double ?? 1.25, 0.75), 2)
        recentlyWaveContrast = min(max(defaults.object(forKey: Self.prefix + "recentlyWaveContrast") as? Double ?? 1.15, 0.8), 1.5)
        let height = defaults.object(forKey: Self.prefix + "recentlyHeight") as? Double ?? 64
        recentlyHeight = (min(max(height, 48), 96) / 4).rounded() * 4
        #if DEBUG
        // Только на этот процесс: компактный контрольный кадр без записи тестовых
        // размеров и прогресса в настройки или историю пользователя.
        if ProcessInfo.processInfo.arguments.contains("-debugRecentlyLayout") {
            recentlyHeight = 48
            recentlyPreviewIndex = 0
        }
        if ProcessInfo.processInfo.arguments.contains("-debugPromoArtistName") {
            sizesEnabled = true
        }
        #endif
        sideAngle = defaults.object(forKey: Self.prefix + "angle") as? Double ?? 5
        widths = defaults.dictionary(forKey: Self.prefix + "widths") as? [String: Double]
            ?? Dictionary(uniqueKeysWithValues: HomePromoKind.allCases.map { ($0.rawValue, $0.initialWidth) })
    }

    func width(for kind: HomePromoKind) -> Double {
        guard sizesEnabled else { return kind.originalWidth }
        switch kind {
        case .artist: return promoArtistWidth
        case .movie: return promoMovieWidth
        case .book: return promoBookWidth
        default: return widths[kind.rawValue] ?? kind.initialWidth
        }
    }

    func multiplier(for kind: HomePromoKind) -> CGFloat {
        CGFloat(width(for: kind) / kind.originalWidth)
    }

    private func save(_ key: String, _ value: Any) {
        HomeSettingsStorage.save(value, forKey: Self.prefix + key)
    }
}

extension ShowcaseBlock {
    var homePromoKind: HomePromoKind {
        switch self {
        case .movie, .watching: .movie
        case .album: .album
        case .book, .reading: .book
        case .artist: .artist
        case .vibe: .station
        }
    }
}
