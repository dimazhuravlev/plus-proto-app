import SwiftUI

/// Запись коллекции «Моё» — фильм, книга, трек, исполнитель, альбом или плейлист.
///
/// Одна запись на сущность: «Любимое» и «Скачанное» — её отметки с датами, а не два
/// отдельных списка. Сняты обе — записи нет. Новые поля — только опциональные:
/// коллекция лежит на диске, и запись, сделанная до них, обязана читаться.
struct CollectionItem: Codable, Identifiable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case movie, book, track, artist, album, playlist

        /// Заголовок секции коллекции и экрана полного списка.
        var title: String {
            switch self {
            case .movie: "Кино"
            case .book: "Книги"
            case .track: "Треки"
            case .artist: "Исполнители"
            case .album: "Альбомы"
            case .playlist: "Плейлисты"
            }
        }
    }

    /// `<вид>:<ключ>` — ключ сущности в своём сервисе: id маршрута (`kp-…`, `gb-…`,
    /// `dz-…`); у трека — id трека Deezer, если его можно вынуть из id плеера
    /// (`CollectionItem.trackKey`), у плейлиста — id плеера.
    let id: String
    let kind: Kind
    var title: String
    /// Год у фильма, автор у книги, исполнитель у трека и альбома, владелец у плейлиста;
    /// у исполнителя пусто.
    var subtitle: String
    var artwork: ArtworkSource?
    /// Куда ведёт тап: экран фильма, книги, альбома, исполнителя. У трека — его альбом
    /// (переход из меню строки), тап по треку включает музыку.
    var route: EntityRoute?
    /// Что играет тап по треку или плейлисту.
    var playable: MusicNowPlaying?
    /// Пропорции обложки книги — ширина книги в проекции.
    var aspect: CGFloat?
    var isExplicit: Bool?
    var favoritedAt: Date?
    var downloadedAt: Date?

    func date(on shelf: CollectionStore.Shelf) -> Date? {
        switch shelf {
        case .favorites: favoritedAt
        case .downloads: downloadedAt
        }
    }

    /// Свежее описание той же сущности — с нового места, откуда её отметили: название
    /// и обложка могли уточниться (экран деталей знает больше, чем карточка). Пустое
    /// новое значение старое не затирает.
    mutating func refresh(from fresh: CollectionItem) {
        if !fresh.title.isEmpty { title = fresh.title }
        if !fresh.subtitle.isEmpty { subtitle = fresh.subtitle }
        artwork = fresh.artwork ?? artwork
        route = fresh.route ?? route
        playable = fresh.playable ?? playable
        aspect = fresh.aspect ?? aspect
        isExplicit = fresh.isExplicit ?? isExplicit
    }
}

// MARK: - Записи из мест, где их отмечают

extension CollectionItem {
    /// Фильм — постером: карусель коллекции стоит на 2:3. Нет постера — обложка,
    /// с которой экран открыли.
    static func movie(_ ref: EntityRef, poster: ArtworkSource?, year: String?) -> CollectionItem {
        let artwork = kinopoiskPoster(poster ?? ref.artwork)
        return CollectionItem(
            id: "movie:\(ref.id)",
            kind: .movie,
            title: ref.title,
            subtitle: year ?? "",
            artwork: artwork,
            route: .movie(EntityRef(id: ref.id, title: ref.title, subtitle: "", artwork: artwork))
        )
    }

    static func book(_ ref: EntityRef, aspect: CGFloat?) -> CollectionItem {
        CollectionItem(
            id: "book:\(ref.id)",
            kind: .book,
            title: ref.title,
            subtitle: ref.subtitle,
            artwork: ref.artwork,
            route: .book(ref),
            aspect: aspect
        )
    }

    static func album(_ ref: EntityRef, isExplicit: Bool? = nil) -> CollectionItem {
        CollectionItem(
            id: "album:\(ref.id)",
            kind: .album,
            title: ref.title,
            subtitle: ref.subtitle,
            artwork: ref.artwork,
            route: .album(ref),
            isExplicit: isExplicit
        )
    }

    static func artist(_ ref: EntityRef) -> CollectionItem {
        CollectionItem(
            id: "artist:\(ref.id)",
            kind: .artist,
            title: ref.title,
            subtitle: "",
            artwork: ref.artwork,
            route: .artist(ref)
        )
    }

    static func track(_ music: MusicNowPlaying, album: EntityRoute? = nil) -> CollectionItem {
        CollectionItem(
            id: "track:\(trackKey(music.id))",
            kind: .track,
            title: music.title,
            subtitle: music.artist,
            artwork: music.cover,
            route: album,
            playable: music,
            isExplicit: music.isExplicit
        )
    }

    static func playlist(id: String, title: String, owner: String, cover: ArtworkSource?) -> CollectionItem {
        CollectionItem(
            id: "playlist:\(id)",
            kind: .playlist,
            title: title,
            subtitle: owner,
            artwork: cover,
            playable: MusicNowPlaying(id: id, cover: cover ?? .asset("mockAlbumCover"), title: title, artist: owner)
        )
    }

    /// Постер с Яндекс-CDN — пресетом 300x450: карточке 86 на ×3 его хватает, а голый
    /// хвост размера (`…/600`) CDN не отдаёт вовсе — так легли первые стартовые постеры.
    static func kinopoiskPoster(_ source: ArtworkSource) -> ArtworkSource {
        guard case .remote(let url, let fallback) = source,
              url.host == "avatars.mds.yandex.net",
              let resized = URL(string: KinopoiskImage.resized(url.absoluteString, to: .small))
        else { return source }
        return .remote(resized, fallback: fallback)
    }

    /// Запись, сохранённая до правки постеров, — с рабочей ссылкой.
    func repairingPoster() -> CollectionItem {
        guard kind == .movie, let artwork else { return self }
        var item = self
        let poster = Self.kinopoiskPoster(artwork)
        item.artwork = poster
        if case .movie(let ref)? = route {
            item.route = .movie(EntityRef(id: ref.id, title: ref.title, subtitle: ref.subtitle, artwork: poster))
        }
        return item
    }

    /// Ключ трека — один на трек Deezer, откуда бы его ни включили: выдача поиска
    /// зовёт его `track-<id>`, экран альбома — `dz-<альбом>-t<id>`. Иначе один и тот
    /// же трек, отмеченный из двух мест, лёг бы в коллекцию дважды, а сердце
    /// мини-плеера его бы не узнавало.
    static func trackKey(_ playerID: String) -> String {
        if playerID.hasPrefix("track-"), let id = Int(playerID.dropFirst("track-".count)) {
            return "dz-\(id)"
        }
        if playerID.hasPrefix("dz-"), let marker = playerID.range(of: "-t", options: .backwards),
           let id = Int(playerID[marker.upperBound...]) {
            return "dz-\(id)"
        }
        return playerID
    }

    /// Строка выдачи поиска. Персоны (режиссёр, писатель) в коллекцию не ложатся —
    /// у неё нет для них полки.
    init?(hit: SearchHit) {
        switch hit.kind {
        case .movie:
            guard case .movie(let ref)? = hit.route else { return nil }
            self = .movie(ref, poster: hit.artwork, year: hit.subtitle)
        case .book:
            guard case .book(let ref)? = hit.route else { return nil }
            self = .book(ref, aspect: hit.artworkAspect)
        case .album:
            guard case .album(let ref)? = hit.route else { return nil }
            self = .album(ref)
        case .artist:
            guard case .artist(let ref)? = hit.route else { return nil }
            self = .artist(ref)
        case .track:
            let album: String? = if case .album(let ref)? = hit.route { ref.title } else { nil }
            self = .track(
                MusicNowPlaying(
                    id: hit.id,
                    cover: hit.artwork ?? .asset("mockAlbumCover"),
                    title: hit.title,
                    artist: hit.subtitle,
                    album: album
                ),
                album: hit.route
            )
        case .playlist:
            self = .playlist(id: hit.id, title: hit.title, owner: hit.subtitle, cover: hit.artwork)
        case .director, .writer:
            return nil
        }
    }
}

// MARK: - Хранилище

/// Коллекция «Моё» — общая для кино, книг и музыки (задача пользователя 2026-10-04,
/// макет `2351:17327`): «Любимое» — всё, что отмечено «нравится» или «позже»,
/// «Скачанное» — всё, что скачано. Отмечают её отовсюду: сердца экранов сущностей,
/// мини-плеера и строк выдачи, «Позже» и «Скачать» тайтла, «Скачать» альбома и книги.
///
/// Одна на приложение (`shared`): мини-плеер отмечает трек из `ActionBarState`, у которого
/// своего окружения нет. Экраны берут её из окружения — его раздаёт корень.
///
/// Лежит на диске (`UserDefaults`, JSON), как история просмотра. Первый запуск получает
/// стартовый набор (`CollectionSeeds`): коллекция в тестах не пустая.
@MainActor
@Observable
final class CollectionStore {
    static let shared = CollectionStore()

    /// Полки коллекции — табы её навигации.
    enum Shelf: Int, CaseIterable {
        case favorites, downloads

        var title: String {
            switch self {
            case .favorites: "Любимое"
            case .downloads: "Скачанное"
            }
        }
    }

    /// Свежие отметки — первыми.
    private(set) var items: [CollectionItem] = [] {
        didSet { persist() }
    }

    private static let storageKey = "collection"

    private init() {
        #if DEBUG
        // `-debugResetCollection 1` — начать со стартового набора.
        if UserDefaults.standard.bool(forKey: "debugResetCollection") {
            UserDefaults.standard.removeObject(forKey: Self.storageKey)
        }
        #endif
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([CollectionItem].self, from: data) {
            items = saved.map { $0.repairingPoster() }
        } else {
            items = CollectionSeeds.items(now: .now)
            // Наблюдатель свойства в инициализаторе молчит — пишем сами: даты стартового
            // набора должны пережить перезапуск, иначе порядок пересобирался бы.
            persist()
        }
    }

    // MARK: Чтение

    func item(_ id: String) -> CollectionItem? {
        items.first { $0.id == id }
    }

    func isFavorite(_ id: String) -> Bool {
        item(id)?.favoritedAt != nil
    }

    func isDownloaded(_ id: String) -> Bool {
        item(id)?.downloadedAt != nil
    }

    /// Полка одного вида — свежие сверху.
    func items(_ kind: CollectionItem.Kind, on shelf: Shelf) -> [CollectionItem] {
        items
            .compactMap { item in item.date(on: shelf).map { (item, $0) } }
            .filter { $0.0.kind == kind }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    // MARK: Отметки

    /// Сердце строки выдачи. `nil` — такую строку коллекция не хранит (персоны).
    func isFavorite(hit: SearchHit) -> Bool? {
        CollectionItem(hit: hit).map { isFavorite($0.id) }
    }

    /// Отметить строку выдачи. `false` — коллекция её не хранит.
    @discardableResult
    func toggleFavorite(hit: SearchHit) -> Bool {
        guard let item = CollectionItem(hit: hit) else { return false }
        toggleFavorite(item)
        return true
    }

    func toggleFavorite(_ item: CollectionItem) {
        setFavorite(item, !isFavorite(item.id))
    }

    func toggleDownload(_ item: CollectionItem) {
        setDownloaded(item, !isDownloaded(item.id))
    }

    func setFavorite(_ item: CollectionItem, _ isOn: Bool) {
        update(item) { $0.favoritedAt = isOn ? .now : nil }
    }

    func setDownloaded(_ item: CollectionItem, _ isOn: Bool) {
        update(item) { $0.downloadedAt = isOn ? .now : nil }
    }

    /// Отметить сущность или снять отметку. Отмеченная поднимается наверх; без отметок
    /// запись уходит из коллекции.
    private func update(_ item: CollectionItem, _ change: (inout CollectionItem) -> Void) {
        var list = items
        var record = item
        if let index = list.firstIndex(where: { $0.id == item.id }) {
            record = list.remove(at: index)
            record.refresh(from: item)
        }
        change(&record)
        if record.favoritedAt != nil || record.downloadedAt != nil {
            list.insert(record, at: 0)
        }
        items = list
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}

// MARK: - Подписи

enum CollectionCopy {
    /// «1 трек», «3 трека», «274 трека», «11 треков» — русские формы числа.
    static func tracks(_ count: Int) -> String {
        "\(count) \(plural(count, one: "трек", few: "трека", many: "треков"))"
    }

    static func plural(_ count: Int, one: String, few: String, many: String) -> String {
        let tens = count % 100
        let units = count % 10
        if (11...14).contains(tens) { return many }
        if units == 1 { return one }
        if (2...4).contains(units) { return few }
        return many
    }
}
