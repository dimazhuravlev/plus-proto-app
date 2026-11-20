import SwiftUI

// MARK: - Карточка каруселей экрана книги

/// Книга или аудиокнига в каруселях экрана книги («Другие версии книги», «С этой книгой
/// читают / слушают»): тома Google Books — книгой своих пропорций, альбомы Deezer —
/// квадратом (`AudiobookFigure`).
struct BookShelfItem: Identifiable, Hashable {
    /// `gb-<том>` или `dz-<альбом>` — тот же id, что у маршрутов книги и альбома.
    let id: String
    let title: String
    /// Автор книги или исполнитель аудиокниги — подпись маршрута.
    let subtitle: String
    let cover: URL
    /// Пропорции обложки книги; у аудиокниги не нужны — она квадратная.
    let aspect: CGFloat?
    let isAudiobook: Bool

    var route: EntityRoute {
        let ref = EntityRef(id: id, title: title, subtitle: subtitle, artwork: .remote(cover))
        return isAudiobook ? .album(ref) : .book(ref)
    }
}

// MARK: - Аудиоверсия

/// Аудиоверсия книги — вторая обложка ленты экрана книги (макет `893:54891` файла
/// Petr Batur, задача 2026-11-20). Ищется в Deezer тем же правилом, что аудиокниги
/// выдачи поиска (`AudiobookMatch`). Не нашлась — версия моковая: квадрат из обложки
/// книги, без часов и издательства (решение пользователя 2026-11-20: свайп между версиями
/// есть всегда, а поля без данных не показываем).
@MainActor
@Observable
final class BookAudioStore {
    struct Audio: Equatable {
        let albumID: Int
        let title: String
        /// Исполнитель альбома — чтец или издательство.
        let narrator: String
        let cover: ArtworkSource
        /// Длительность, часы. `nil` — Deezer не отдал.
        let hours: Double?
        let label: String?
    }

    enum State: Equatable {
        case loading
        case found(Audio)
        case mock
    }

    private(set) var state: State = .loading
    /// Главы аудиокниги — очередь «Слушать». Пока не доехали, играет весь альбом одной записью.
    private(set) var chapters: [MusicNowPlaying] = []
    /// Другие аудиокниги автора — «С этой книгой слушают».
    private(set) var related: [BookShelfItem] = []
    private(set) var isRelatedLoaded = false

    private static let relatedLimit = 10

    /// Автор неизвестен — искать не по чему, версия моковая.
    func load(title: String, author: String?) async {
        guard state == .loading else { return }
        guard let author, !author.isEmpty,
              let query = AudiobookMatch.query(title: title, author: author),
              let albums = try? await DeezerService.shared.searchAlbums(query: query, limit: 10),
              let album = AudiobookMatch.best(in: albums, title: title, author: author)
        else {
            guard !Task.isCancelled else { return }
            state = .mock
            await loadRelated(author: author, excluding: nil)
            return
        }
        let full = try? await DeezerService.shared.album(id: album.id)
        guard !Task.isCancelled else { return }
        let cover = (album.coverXl ?? album.coverBig)?.deezerUpscaled
        let audio = Audio(
            albumID: album.id,
            title: album.title,
            narrator: album.artist?.name ?? author,
            cover: cover.map { .remote($0) } ?? .asset("mockAlbumCover"),
            hours: full?.duration.flatMap { $0 > 0 ? Double($0) / 3600 : nil },
            label: full?.label.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
        )
        state = .found(audio)
        await loadChapters(audio)
        await loadRelated(author: author, excluding: album.id)
    }

    private func loadChapters(_ audio: Audio) async {
        let ref = EntityRef(id: "dz-\(audio.albumID)", title: audio.title, subtitle: audio.narrator, artwork: audio.cover)
        let store = AlbumDetailsStore(entity: ref)
        await store.load(ref)
        guard !Task.isCancelled, let details = store.details else { return }
        chapters = details.allTracks.map { details.nowPlaying($0, albumID: ref.id, cover: audio.cover) }
    }

    /// Аудиокниги того же автора: альбомы без жанра (у Deezer так помечены аудиокниги),
    /// где автор — исполнитель или стоит в названии.
    private func loadRelated(author: String?, excluding albumID: Int?) async {
        defer { isRelatedLoaded = true }
        guard let author, let surname = author.split(separator: " ").last.map(String.init),
              surname.count > 1,
              let albums = try? await DeezerService.shared.searchAlbums(query: author, limit: 25)
        else { return }
        guard !Task.isCancelled else { return }
        var seen: Set<String> = []
        related = albums.compactMap { album -> BookShelfItem? in
            guard album.genreId == -1, (album.nbTracks ?? 0) > 1, album.id != albumID,
                  let cover = (album.coverXl ?? album.coverBig)?.deezerUpscaled,
                  (album.artist?.name ?? "").localizedCaseInsensitiveContains(surname)
                    || album.title.localizedCaseInsensitiveContains(surname),
                  seen.insert(album.title.lowercased()).inserted
            else { return nil }
            return BookShelfItem(
                id: "dz-\(album.id)",
                title: album.title,
                subtitle: album.artist?.name ?? author,
                cover: cover,
                aspect: nil,
                isAudiobook: true
            )
        }
        .prefix(Self.relatedLimit)
        .map { $0 }
    }
}

// MARK: - Другие издания

/// «Другие версии книги» — другие тома Google Books с тем же названием и автором
/// (переиздания, другие переводы). Только со сканом обложки, без открытого тома.
@MainActor
@Observable
final class BookEditionsStore {
    private(set) var books: [BookShelfItem] = []
    private(set) var isLoaded = false

    private static let limit = 10

    func load(title: String, author: String, excludingVolume volumeID: String) async {
        guard !isLoaded else { return }
        defer { isLoaded = true }
        let core = (title.split(separator: ":").first.map(String.init) ?? title)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let surname = author.split(separator: " ").last.map(String.init) ?? author
        guard !core.isEmpty,
              let volumes = try? await BooksService.shared.search("\(core) \(surname)", limit: 20)
        else { return }
        guard !Task.isCancelled else { return }
        let picked = volumes.filter { volume in
            volume.id != volumeID
                && volume.hasScannedCover
                && volume.title.localizedCaseInsensitiveContains(core)
                && (volume.volumeInfo.authors ?? []).contains { $0.localizedCaseInsensitiveContains(surname) }
        }
        .prefix(Self.limit)
        let aspects = await AuthorBooksStore.aspects(of: Array(picked))
        guard !Task.isCancelled else { return }
        books = picked.compactMap { volume in
            guard let cover = volume.coverURL else { return nil }
            return BookShelfItem(
                id: "gb-\(volume.id)",
                title: volume.title,
                subtitle: volume.author,
                cover: cover,
                aspect: aspects[volume.id],
                isAudiobook: false
            )
        }
    }

    /// Моковая книга без тома — искать нечего.
    func markEmpty() {
        isLoaded = true
    }
}

// MARK: - Выдуманные факты

/// Счётчики, детали и теги экрана книги, которых нет в Google Books и Deezer: читатели,
/// прослушивания, возраст, переводчик, издательство, добор тегов до 5–10 (просьба
/// пользователя 2026-11-20: «если не найдёшь реальные данные — выдуманные, главное,
/// чтобы были»). Живое значение, если есть, всегда важнее. Числа — от id книги
/// стабильным хешем: у книги одни и те же факты из запуска в запуск.
struct BookMockFacts {
    let pages: Int
    let readers: Int
    let hours: Double
    let listens: Int
    let age: String
    let translator: String
    let narrator: String
    let publisher: String
    let audioPublisher: String
    /// Сколько тегов показать: 5…10.
    let tagCount: Int
    private let seed: UInt64

    init(bookID: String) {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in bookID.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        seed = hash
        func pick(_ salt: UInt64, _ range: Int) -> Int {
            var x = hash ^ (salt &* 0x9E3779B97F4A7C15)
            x ^= x >> 33; x &*= 0xff51afd7ed558ccd; x ^= x >> 33
            return Int(x % UInt64(range))
        }
        pages = 180 + pick(1, 440)
        readers = 1_200 + pick(2, 46_000)
        hours = Double(40 + pick(3, 140)) / 10
        listens = 800 + pick(4, 29_000)
        age = Self.ages[pick(5, Self.ages.count)]
        translator = Self.translators[pick(6, Self.translators.count)]
        narrator = Self.narrators[pick(7, Self.narrators.count)]
        publisher = Self.publishers[pick(8, Self.publishers.count)]
        audioPublisher = Self.audioPublishers[pick(9, Self.audioPublishers.count)]
        tagCount = 5 + pick(10, 6)
    }

    /// Живые теги, добранные выдуманными до `tagCount`; `extra` («Аудио») — в том же счёте.
    func tags(real: [String], extra: [String] = []) -> [String] {
        var result: [String] = []
        for tag in real + Self.tagPool.rotated(by: Int(seed % UInt64(Self.tagPool.count))) where !result.contains(tag) {
            result.append(tag)
        }
        let kept = Array(result.prefix(max(tagCount - extra.count, 0)))
        return kept + extra
    }

    private static let ages = ["12+", "16+", "16+", "18+", "6+"]
    private static let translators = [
        "Мария Сорокина", "Андрей Левитский", "Елена Кравец", "Николай Бережной",
        "Ольга Ветрова", "Дмитрий Арсеньев", "Татьяна Луговая", "Сергей Ильинский",
    ]
    private static let narrators = [
        "Александр Клюквин", "Ирина Литвинова", "Григорий Перель", "Кирилл Радциг",
        "Юлия Яблонская", "Максим Суханов",
    ]
    private static let publishers = [
        "Азбука", "Эксмо", "АСТ", "Иностранка", "Альпина нон-фикшн", "Corpus", "Манн, Иванов и Фербер",
    ]
    private static let audioPublishers = ["Вимбо", "Аудиокнига", "Звукобук", "Яндекс Книги", "Union Studio"]
    private static let tagPool = [
        "Художественная литература", "Классика", "Зарубежная литература", "Современная проза",
        "Роман", "Психологическая проза", "Бестселлеры", "Экранизации", "Философия",
        "Драма", "Книги-легенды", "Про любовь", "Семейная сага", "Приключения",
    ]
}

private extension Array {
    func rotated(by shift: Int) -> [Element] {
        guard !isEmpty else { return self }
        let k = shift % count
        return Array(self[k...] + self[..<k])
    }
}
