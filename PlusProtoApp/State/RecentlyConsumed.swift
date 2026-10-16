import Foundation

/// Айтем ряда «продолженного потребления» «Главной» — то, что начинали смотреть, слушать
/// или читать (задача 71). Хранит ровно то, чем запускается: плитка по нему же и открывает
/// плеер.
enum RecentItem: Codable, Equatable, Identifiable {
    case movie(MovieInProgress)
    /// Трек; плитка — квадрат его обложки.
    case music(MusicNowPlaying)
    case book(BookInProgress)
    /// Исполнитель — только из стартового набора: его не «запускают», тап открывает экран.
    case artist(EntityRef)
    /// Главная «Моя волна» — после того как её включили кнопкой таба Музыки или плиткой
    /// ряда (`openMainVibe`; правка пользователя 2026-10-16). Станции волны сюда не пишутся.
    case myVibe

    /// Повтор поднимается наверх, а не дублируется. Музыка — по альбому или плейлисту,
    /// из которого трек играл (`containerID`): разные треки одного альбома — одна плитка
    /// с обложкой последнего; трек без источника — сам по себе.
    var id: String {
        switch self {
        case .movie(let movie): "movie:" + movie.id
        case .music(let track): "music:" + (track.containerID ?? track.id)
        case .book(let book): "book:" + book.id
        case .artist(let artist): "artist:" + artist.id
        case .myVibe: "myVibe"
        }
    }

    /// Имя для VoiceOver.
    var title: String {
        switch self {
        case .movie(let movie): movie.title
        case .music(let track): "\(track.title), \(track.artist)"
        case .book(let book): book.title
        case .artist(let artist): artist.title
        case .myVibe: "Моя волна"
        }
    }

    /// Картинка плитки: у фильма — горизонтальный кадр, у трека — обложка, у книги —
    /// обложка, у исполнителя — фото.
    var artwork: ArtworkSource {
        switch self {
        case .movie(let movie): movie.still
        case .music(let track): track.cover
        case .book(let book): book.cover
        case .artist(let artist): artist.artwork
        case .myVibe: .asset("vibeRecentDrop")
        }
    }
}

/// «Продолженное потребление» — ряд над промо «Главной» (задача 71): всё, что запускали
/// в плеерах, свежее — первым. Пишется из единого входа плееров — `ActionBarState.open`;
/// треки «Моей волны» не пишутся — у главной волны своя плитка `.myVibe`, её пишет
/// `ActionBarState.openMainVibe`.
///
/// На свежей установке — стартовый набор (`RecentlySeeds`), чтобы ряд не стоял пустым.
/// Сеется один раз: удалённые и вытесненные из ряда не возвращаются.
@Observable
final class RecentlyConsumed {
    private(set) var items: [RecentItem] = [] {
        didSet { persist() }
    }

    /// Хвост ряда ничего не стоит потерять.
    private static let limit = 20
    private static let storageKey = "recentlyConsumed"
    private static let seededKey = "recentlyConsumedSeeded"

    init() {
        let defaults = UserDefaults.standard
        #if DEBUG
        // `-debugResetRecently 1` — стереть ряд и посеять стартовый набор заново.
        if defaults.bool(forKey: "debugResetRecently") {
            defaults.removeObject(forKey: Self.storageKey)
            defaults.removeObject(forKey: Self.seededKey)
        }
        #endif
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([RecentItem].self, from: data) {
            items = saved
        }
        guard !defaults.bool(forKey: Self.seededKey) else { return }
        if items.isEmpty { items = RecentlySeeds.items }
        defaults.set(true, forKey: Self.seededKey)
    }

    /// Айтем запустили — встаёт в начало; уже был — поднимается, а не дублируется.
    ///
    /// Позиция фильма не хранится: прогресс плитки — живой, из истории просмотра
    /// (`WatchHistory`), копия здесь разошлась бы с ней на первом же закрытии плеера.
    func record(_ item: RecentItem) {
        var item = item
        if case .movie(var movie) = item {
            movie.position = nil
            item = .movie(movie)
        }
        var list = items
        list.removeAll { $0.id == item.id }
        list.insert(item, at: 0)
        if list.count > Self.limit {
            list.removeLast(list.count - Self.limit)
        }
        items = list
    }

    /// Картинки ряда — для прогрева под заставкой.
    var artworks: [ArtworkSource] {
        items.map(\.artwork)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}

extension MusicNowPlaying {
    /// Экран, откуда трек, — для плитки ПП: альбом или плейлист по `containerID`
    /// (`album:dz-…`, `playlist:dz-…`), иначе альбом по id трека `dz-<альбом>-t<трек>`.
    /// `nil` — альбом неизвестен (трек из выдачи, `track-…`).
    var containerRoute: EntityRoute? {
        if let container = containerID {
            let parts = container.split(separator: ":", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                switch parts[0] {
                case "album":
                    return .album(EntityRef(id: parts[1], title: album ?? title, subtitle: artist, artwork: cover))
                case "playlist":
                    return .playlist(EntityRef(id: parts[1], title: album ?? title, subtitle: "", artwork: cover))
                default: break
                }
            }
        }
        if id.hasPrefix("dz-"), let range = id.range(of: "-t") {
            let albumID = String(id[id.startIndex..<range.lowerBound])
            return .album(EntityRef(id: albumID, title: album ?? title, subtitle: artist, artwork: cover))
        }
        return nil
    }
}
