import SwiftUI

/// Главная Книг — промо и тематические карусели (задача пользователя 2026-10-04):
/// упор на научпоп, рядом — мировая и русская классика (правка тем же днём).
///
/// Живёт в корне приложения, как остальные каталоги витрин: экран таба размонтируется
/// на переключении, а лента собирается раз за процесс.
///
/// **Почему по авторам, а не по темам.** Тематический поиск Google Books по-русски —
/// мусор: на «фантастику» — номера журнала «Мир фантастики», на «психологию» и «историю» —
/// учебники XIX века (замер 2026-10-04). Поэтому карусель темы собирается из книг двух
/// авторов этой темы — тот же приём, что у витрины (`ShowcaseCatalog.isShowcaseBook`):
/// поиск по имени и отбор собственных томов со сканом обложки. Авторы выбраны по замеру —
/// у кого сканы есть. Запрос на автора — десять за ленту при лимите API раз в секунду,
/// дальше ответы с диска `URLCache`.
@MainActor
@Observable
final class BooksHomeCatalog {
    struct Book: Identifiable, Equatable {
        let id: String
        let title: String
        let author: String
        let cover: ArtworkSource
        /// Пропорции обложки — ширина книги в проекции идёт от них. `nil` — по умолчанию.
        let aspect: CGFloat?
        /// Коротко о книге — под книгой в промо, в несколько строк. `nil` — описания нет.
        var blurb: String? = nil

        var route: EntityRoute {
            .book(EntityRef(id: id, title: title, subtitle: author, artwork: cover))
        }

        var reading: BookInProgress {
            BookInProgress(id: id, cover: cover, title: title, author: author.isEmpty ? nil : author)
        }
    }

    struct Row: Identifiable, Equatable {
        let id: String
        let title: String
        let books: [Book]
    }

    private(set) var promos: [Book] = []
    private(set) var rows: [Row] = []
    /// Книга промо, на которой остановились, — на всю сессию (экран таба
    /// пересоздаётся на каждом переключении).
    var promoIndex = 0
    private(set) var isLoaded = false
    private var didStart = false

    private struct Seed {
        let query: String
        let surname: String
    }

    /// Научпоп вперемешку с классикой. Авторы научпопа — из сидов витрины, по замеру
    /// у них есть сканы обложек (у Сапольски и Каку — по шесть томов).
    private static let rowSpecs: [(id: String, title: String, seeds: [Seed])] = [
        ("history", "История человечества", [Seed(query: "Юваль Ной Харари", surname: "Харари"), Seed(query: "Джаред Даймонд", surname: "Даймонд")]),
        ("world-classics", "Мировая классика", [Seed(query: "Жюль Верн", surname: "Верн"), Seed(query: "Конан Дойл", surname: "Дойл")]),
        ("brain", "Мозг и поведение", [Seed(query: "Роберт Сапольски", surname: "Сапольски"), Seed(query: "Оливер Сакс", surname: "Сакс")]),
        ("russian-classics", "Русская классика", [Seed(query: "Толстой Лев", surname: "Толстой"), Seed(query: "Чехов", surname: "Чехов")]),
        ("space", "Космос и физика", [Seed(query: "Стивен Хокинг", surname: "Хокинг"), Seed(query: "Митио Каку", surname: "Каку")]),
        ("decisions", "Психология решений", [Seed(query: "Даниэль Канеман", surname: "Канеман"), Seed(query: "Дэн Ариели", surname: "Ариели")]),
    ]

    private static let rowLimit = 10
    /// Сколько ждём обложки, чтобы знать их пропорции, — дольше книга встаёт
    /// с пропорциями по умолчанию, а обложка доедет на месте.
    private static let coverWait: Duration = .seconds(3)

    func loadIfNeeded() async {
        guard !didStart else { return }
        didStart = true

        #if DEBUG
        if UserDefaults.standard.bool(forKey: "debugMockFeed") {
            applyMocks()
            return
        }
        #endif

        // Каждый холодный запуск — свой набор книг тем и своё промо (правка пользователя
        // 2026-10-04: витрина повторялась из запуска в запуск — книги брались в порядке
        // ответа API). Зерно случайное на запуск, `-debugFrozenFeed` его фиксирует.
        // Авторы тем те же: запросы — с диска `URLCache`, сеть не трогается.
        var rng = ShowcaseRotation.generator(salt: ShowcaseRotation.Salt.booksHome)
        var built: [(id: String, title: String, volumes: [GoogleBook])] = []
        var seenIDs = Set<String>()
        for spec in Self.rowSpecs {
            var perAuthor: [[GoogleBook]] = []
            for seed in spec.seeds {
                let volumes = (try? await BooksService.shared.search(seed.query, limit: 20)) ?? []
                var seenTitles = Set<String>()
                perAuthor.append(volumes.filter { volume in
                    guard volume.volumeInfo.language == "ru",
                          (volume.volumeInfo.authors ?? []).contains(where: { $0.localizedCaseInsensitiveContains(seed.surname) }),
                          !volume.title.isEmpty,
                          volume.coverURL != nil,
                          !ShowcaseSeeds.bookSummaryMarkers.contains(where: { volume.title.lowercased().contains($0) }),
                          !seenIDs.contains(volume.id)
                    else { return false }
                    return seenTitles.insert(volume.title.lowercased()).inserted
                }.shuffled(using: &rng))
            }
            // Авторы вперемешку — по книге от каждого по очереди.
            var mixed: [GoogleBook] = []
            let longest = perAuthor.map(\.count).max() ?? 0
            for index in 0..<longest {
                for books in perAuthor where index < books.count { mixed.append(books[index]) }
            }
            let picked = Array(mixed.prefix(Self.rowLimit))
            seenIDs.formUnion(picked.map(\.id))
            if !picked.isEmpty { built.append((spec.id, spec.title, picked)) }
        }

        let all = built.flatMap(\.volumes)
        guard !all.isEmpty else {
            applyMocks()
            return
        }
        let aspects = await Self.aspects(of: all)

        // Промо — первая книга каждой темы (после перемешивания — случайная); в своей
        // карусели её уже нет. Порядок тем в промо — тоже свой на запуск.
        promos = built.compactMap { $0.volumes.first.map { Self.book($0, aspects) } }
            .shuffled(using: &rng)
        rows = built.map { row in
            Row(id: row.id, title: row.title, books: row.volumes.dropFirst().map { Self.book($0, aspects) })
        }
        isLoaded = true
    }

    private static func book(_ volume: GoogleBook, _ aspects: [String: CGFloat]) -> Book {
        Book(
            id: "gb-\(volume.id)",
            title: volume.title,
            author: volume.author,
            cover: volume.coverURL.map { ArtworkSource.remote($0) } ?? .asset("mockChipBookCover"),
            aspect: aspects[volume.id],
            blurb: blurb(volume)
        )
    }

    /// Под книгой в промо — три строки, по предложению.
    private static let blurbLength = 130

    /// Коротко о книге — **короткое описание из выдачи поиска** (`textSnippet`, правка
    /// пользователя 2026-10-04: прежде резалась длинная аннотация). У старых сканов
    /// сниппет бывает обрывком текста самой книги с подсветкой запроса `<b>` — тогда
    /// начало аннотации; нет и её — подзаголовок.
    private static func blurb(_ volume: GoogleBook) -> String? {
        if let snippet = volume.searchInfo?.textSnippet, !snippet.contains("<b>"),
           let text = plainText(snippet) {
            return text.showcaseCaption(maxCharacters: Self.blurbLength)
        }
        return plainText(volume.volumeInfo.description ?? volume.volumeInfo.subtitle)?
            .showcaseCaption(maxCharacters: Self.blurbLength)
    }

    /// HTML Google Books (`<p>`, `<br>`, сущности) — в плоский текст. Хвост сниппета
    /// « ...» — в многоточие.
    private static func plainText(_ html: String?) -> String? {
        guard let html, !html.isEmpty else { return nil }
        var text = html.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        for (entity, symbol) in [
            ("&nbsp;", " "), ("&quot;", "\""), ("&laquo;", "«"), ("&raquo;", "»"),
            ("&mdash;", "—"), ("&ndash;", "–"), ("&hellip;", "…"), ("&#39;", "'"), ("&amp;", "&"),
        ] {
            text = text.replacingOccurrences(of: entity, with: symbol)
        }
        text = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s*\.\.\.\s*$"#, with: "…", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Сниппет бывает начат посреди цитаты: закрывающая «»» раньше открывающей —
        // открывающую возвращаем («Рождение человечества» у графического Sapiens).
        if let close = text.firstIndex(of: "»"), text.firstIndex(of: "«").map({ $0 > close }) ?? true {
            text = "«" + text
        }
        return text.isEmpty ? nil : text
    }

    /// Пропорции обложек — по самим картинкам, с потолком ожидания (приём
    /// `AuthorBooksStore`). Заодно они уже в кэше загрузчика, и лента встаёт
    /// с обложками, а не с пустыми книгами.
    private static func aspects(of volumes: [GoogleBook]) async -> [String: CGFloat] {
        let urls = volumes.compactMap { volume in volume.coverURL.map { (volume.id, $0) } }
        guard !urls.isEmpty else { return [:] }
        return await withTaskGroup(of: (String, CGFloat?).self) { group in
            for (id, url) in urls {
                group.addTask { @MainActor in
                    let image = await ArtworkLoader.shared.image(for: url)
                    return (id, image.map { $0.size.width / max($0.size.height, 1) })
                }
            }
            group.addTask {
                try? await Task.sleep(for: coverWait)
                return ("", nil)
            }
            var aspects: [String: CGFloat] = [:]
            var answered = 0
            for await (id, aspect) in group {
                // Пустой id — истёк потолок ожидания.
                guard !id.isEmpty else { break }
                answered += 1
                if let aspect { aspects[id] = aspect }
                if answered == urls.count { break }
            }
            group.cancelAll()
            return aspects
        }
    }

    // MARK: - Моки

    /// Без сети и под `-debugMockFeed` — забандленные обложки витрины.
    private func applyMocks() {
        // Четыре настоящие книги со своими обложками и описаниями (по аннотациям
        // издательств) — и в промо, и в каруселях тем.
        let shelf: [(id: String, title: String, author: String, cover: String, blurb: String)] = [
            ("graeber-truth", "Главная тайная истина мира…", "Дэвид Гребер", "mockBookGraeberTruth",
             "Посмертный сборник эссе Гребера: мир — то, что мы создаём, и его вполне можно устроить иначе"),
            ("fedorova-35-july", "35 июля. Но это не точно", "Аня Фёдорова", "mockBookFedorova",
             "Две повести о детстве на стыке девяностых и нулевых: бабушка, тамагочи, приволжский город"),
            ("zamirovskaya-things", "Некоторые вещи уже произошли", "Татьяна Замировская", "mockBookZamirovskaya",
             "Рассказы о катастрофах и о том, как они меняют память, язык и нас самих"),
            ("bullshit-jobs", "Бредовая работа", "Дэвид Гребер", "mockChipBookCover",
             "Трактат о распространении бессмысленного труда — работы, в смысл которой не верят даже те, кто её делает"),
        ]
        func mockBook(_ id: String, _ title: String, _ author: String, _ index: Int) -> Book {
            let book = shelf[index % shelf.count]
            return Book(id: "mock-book-\(id)", title: title, author: author, cover: .asset(book.cover), aspect: nil, blurb: book.blurb)
        }
        promos = shelf.enumerated().map { index, book in mockBook(book.id, book.title, book.author, index) }
        #if DEBUG
        promos = DebugMockPromos.padded(promos) { book, index in
            Book(id: "\(book.id)-\(index)", title: book.title, author: book.author, cover: book.cover, aspect: book.aspect, blurb: book.blurb)
        }
        #endif
        rows = Self.rowSpecs.enumerated().map { rowIndex, spec in
            Row(
                id: spec.id,
                title: spec.title,
                // Те же четыре настоящие книги, у каждой темы — в своём порядке. Раньше тут
                // стояли «Книга 1…5» под фамилиями авторов темы — на настоящих обложках это
                // враньё (правка пользователя 2026-10-09).
                books: shelf.indices.map { offset in
                    let index = (rowIndex + offset) % shelf.count
                    let book = shelf[index]
                    return mockBook("\(spec.id)-\(book.id)", book.title, book.author, index)
                }
            )
        }
        isLoaded = true
    }
}
