import Foundation

/// Стартовый набор коллекции «Моё» — чтобы в тестах она не была пустой (задача
/// пользователя 2026-10-04). Набор — по макету `2351:17327`: «Идеальные дни» первыми
/// в кино, Камю и Толстой в книгах, The Field Mice и The Smiths в треках, The Weeknd
/// в исполнителях, At the Drive-In, The Mars Volta и BRAT в альбомах.
///
/// Всё — живые сущности с настоящими id (замер 2026-10-04): фильмы — из запаса
/// витрины (`MoviePool`, их карточка открывается без запроса в квоту), книги — Google
/// Books со сканом обложки, музыка — Deezer. Экраны открываются так же, как из ленты.
/// «Скачанное» тоже не пустое: треки скачаны все (как в макете — фиолетовая отметка
/// у каждого), плюс фильм, две книги и два альбома.
enum CollectionSeeds {
    static func items(now: Date) -> [CollectionItem] {
        var result: [CollectionItem] = []
        var tick: TimeInterval = 0
        /// Свежие — первыми: каждая следующая запись на минуту «старше».
        func add(_ item: CollectionItem, downloaded: Bool = false) {
            var item = item
            let date = now.addingTimeInterval(-tick * 60)
            tick += 1
            item.favoritedAt = date
            if downloaded { item.downloadedAt = date }
            result.append(item)
        }

        for movie in movies {
            add(.movie(
                EntityRef(id: "kp-\(movie.id)", title: movie.title, subtitle: "", artwork: kinopoisk(movie.poster)),
                poster: kinopoisk(movie.poster),
                year: movie.year
            ), downloaded: movie.downloaded)
        }
        result.insert(downloadedSeries, at: 0)
        for book in books {
            add(.book(
                EntityRef(id: "gb-\(book.id)", title: book.title, subtitle: book.author, artwork: googleBooks(book.id)),
                aspect: book.aspect
            ), downloaded: book.downloaded)
        }
        for track in tracks {
            let cover = deezer("cover", track.cover)
            add(.track(
                MusicNowPlaying(
                    id: "track-\(track.id)",
                    cover: cover,
                    title: track.title,
                    artist: track.artist,
                    album: track.album.title
                ),
                album: .album(EntityRef(
                    id: "dz-\(track.album.id)",
                    title: track.album.title,
                    subtitle: track.artist,
                    artwork: cover
                ))
            ), downloaded: true)
        }
        for artist in artists {
            add(.artist(EntityRef(
                id: "dz-\(artist.id)",
                title: artist.name,
                subtitle: "",
                artwork: deezer("artist", artist.picture)
            )))
        }
        for album in albums {
            add(.album(
                EntityRef(
                    id: "dz-\(album.id)",
                    title: album.title,
                    subtitle: album.artist,
                    artwork: deezer("cover", album.cover)
                ),
                isExplicit: album.isExplicit
            ), downloaded: album.downloaded)
        }
        for playlist in playlists {
            add(.playlist(
                id: "playlist-\(playlist.id)",
                title: playlist.title,
                owner: playlist.owner,
                cover: deezer("playlist", playlist.picture)
            ))
        }
        let known = Set(result.map(\.id))
        result += downloadedTrackItems(now: now).filter { !known.contains($0.id) }
        return result.map(backfill)
    }

    // MARK: - Скачанное кино

    /// Кадр и хронометраж фильмов стартового набора — карточкам «Скачанного кино»
    /// (замер по пулу 2026-10-20). Дозаполняет и записи, сохранённые до этих полей.
    static func backfill(_ item: CollectionItem) -> CollectionItem {
        guard item.kind == .movie, let id = item.kinopoiskID,
              let known = movieFrames[id] else { return item }
        var item = item
        if item.still == nil { item.still = kinopoiskStill(known.still) }
        if item.runtime == nil { item.runtime = TimeInterval(known.minutes * 60) }
        return item
    }

    private static let movieFrames: [Int: (still: String, minutes: Int)] = [
        5283168: ("4483445/50c9d621-0217-4438-aa3d-33652c05df04", 124),
    ]

    /// Скачанный сериал стартового набора — «Белый лотос», две первые серии (сезоны —
    /// замер `/v1.4/season` 2026-10-20, длина серии 60 мин — `seriesLength`): «Скачанное»
    /// показывает и фильм, и сериал.
    static var downloadedSeries: CollectionItem {
        let date = Date.now
        var item = CollectionItem.movie(
            EntityRef(id: "kp-2000461", title: "Белый лотос", subtitle: "", artwork: kinopoisk("4486454/4461f04a-5083-4fc1-9931-0ae69f365770")),
            poster: kinopoisk("4486454/4461f04a-5083-4fc1-9931-0ae69f365770"),
            year: "2021",
            still: kinopoiskStill("6201401/12e83450-55ce-4bb1-abd9-6dc578b74a44"),
            isSeries: true
        )
        let episodes: [(number: Int, name: String, still: String)] = [
            (1, "Заезд", "1652588/2a0000017a99c432bb358299ec9380148899"),
            (2, "Новый день", "374297/2a0000017abdee6412b84e858d2ebc691741"),
        ]
        item.episodes = episodes.map { episode in
            let still = URL(string: "https://avatars.mds.yandex.net/get-ott/\(episode.still)/1344x756")
            return DownloadedEpisode(
                episode: SeriesEpisode(season: 1, number: episode.number, name: episode.name, still: still, runtime: 60 * 60),
                still: still.map { ArtworkSource.remote($0) },
                downloadedAt: date.addingTimeInterval(TimeInterval(episode.number - 3) * 60)
            )
        }
        item.downloadedAt = item.episodes?.map(\.downloadedAt).max()
        item.favoritedAt = nil
        return item
    }

    /// Кадр Кинопоиска — тем же пресетом, что кавер экрана тайтла (`MovieDetails.backdrop`).
    private static func kinopoiskStill(_ path: String) -> ArtworkSource {
        .remote(URL(string: "https://avatars.mds.yandex.net/get-kinopoisk-image/\(path)/1920x1920")!)
    }

    // MARK: - Покупки и прочитанное

    /// «Покупки» экрана «Кино» коллекции — покупок в прототипе нет, набор стартовый
    /// и неизменный (решение пользователя 2026-10-19). Фильмы — из запаса витрины
    /// (`MoviePool`, замер 2026-10-19), экраны открываются как из ленты.
    static var purchases: [CollectionItem] {
        purchasedMovies.map { movie in
            .movie(
                EntityRef(id: "kp-\(movie.id)", title: movie.title, subtitle: "", artwork: kinopoisk(movie.poster)),
                poster: kinopoisk(movie.poster),
                year: movie.year
            )
        }
    }

    /// «Прочитано» экрана «Книги» — так же стартовый набор: дочитанного прототип не
    /// знает. Тома Google Books со сканом обложки, пропорции — с самих обложек.
    static var read: [CollectionItem] {
        readBooks.map { book in
            .book(
                EntityRef(id: "gb-\(book.id)", title: book.title, subtitle: book.author, artwork: googleBooks(book.id)),
                aspect: book.aspect
            )
        }
    }

    private static let purchasedMovies: [(id: Int, title: String, year: String, poster: String)] = [
        (1262160, "Отец", "2020", "1629390/8563b753-d7f2-4eaf-b9af-3e44522b35fd"),
        (1143242, "Джентльмены", "2019", "1599028/637271d5-61b4-4e46-ac83-6d07494c7645"),
        (447301, "Начало", "2010", "1629390/8ab9a119-dd74-44f0-baec-0629797483d7"),
        (342, "Криминальное чтиво", "1994", "4716873/0a07a903-9025-4aff-bf7c-46bbb175888c"),
    ]

    private static let readBooks: [(id: String, title: String, author: String, aspect: CGFloat)] = [
        ("E_xrEAAAQBAJ", "1984", "Джордж Оруэлл", 0.6461),
        ("JY5EDwAAQBAJ", "Преступление и наказание", "Фёдор Достоевский", 0.6432),
        ("6rbPEQAAQBAJ", "Маленький принц", "Антуан де Сент-Экзюпери", 0.7697),
    ]

    // MARK: - Данные

    private static let movies: [(id: Int, title: String, year: String, poster: String, downloaded: Bool)] = [
        (5283168, "Идеальные дни", "2023", "10809116/53656129-a885-4731-968b-bf7aa4a9c3e8", true),
        (1048873, "Зона интересов", "2023", "10953618/8eeb958e-43b0-41b1-a634-b138745f7ef0", false),
        (1043758, "Паразиты", "2019", "4303601/aae3a928-6465-4bed-9af4-16929a44fd79", false),
        (683999, "Отель «Гранд Будапешт»", "2014", "1629390/ea08a062-81a9-46e9-a475-e49388216eea", false),
        (43970, "Сталкер", "1979", "10893610/731b20e7-b3b5-4ec4-b503-128e31cda34b", false),
        (258687, "Интерстеллар", "2014", "1600647/430042eb-ee69-4818-aed0-a312400a26bf", false),
    ]

    /// Пропорции — с самих обложек (`zoom=3`), чтобы книги встали сразу своей ширины.
    private static let books: [(id: String, title: String, author: String, aspect: CGFloat, downloaded: Bool)] = [
        ("AMoTDgAAQBAJ", "Чума", "Альбер Камю", 0.6333, false),
        ("5UhmEQAAQBAJ", "Анна Каренина", "Лев Толстой", 0.7626, false),
        ("wuiaEAAAQBAJ", "Мастер и Маргарита", "Михаил Булгаков", 0.6686, true),
        ("mAWwDQAAQBAJ", "Sapiens. Краткая история человечества", "Юваль Ной Харари", 0.6789, true),
        ("nj1mEQAAQBAJ", "Биология добра и зла", "Роберт Сапольски", 0.6953, false),
        ("8pCRDwAAQBAJ", "Краткая история времени", "Стивен Хокинг", 0.6602, false),
    ]

    private static let tracks: [(id: Int, title: String, artist: String, album: (id: Int, title: String), cover: String)] = [
        (30910351, "Sensitive", "The Field Mice", (2948621, "Coastal"), "1897723b4f8e8eb0c4219191e58144ed"),
        (672271572, "Eli", "Bosnian Rainbows", (95104172, "Bosnian Rainbows"), "718fe9a868eea0fb378c1ffe9163a176"),
        (2302698185, "Bending Hectic", "The Smile", (447073745, "Bending Hectic"), "9b141e7d5d90de5d992601f92b00cd9c"),
        (1717942497, "Waiting Room", "Fugazi", (310447807, "13 Songs"), "581ec2884da760b9febdea49513f9e98"),
        (7179758, "No One Knows", "Queens of the Stone Age", (662259, "Songs For The Deaf"), "ace9490e8fe0c7468b102aa5145fb766"),
        (29373661, "Roygbiv", "Boards of Canada", (2795271, "Music Has The Right To Children"), "c3c2e2a739ed501d01791b16a3fd9ad3"),
        (138546809, "Weird Fishes / Arpeggi", "Radiohead", (14880659, "In Rainbows"), "a175af9b7d329bc678cb4d26fc13d6de"),
        (131744724, "Blitzkrieg Bop", "Ramones", (13995252, "Ramones"), "5e4fa09fd2de120d601098123f43e328"),
        (5093617, "There Is a Light That Never Goes Out", "The Smiths", (467267, "The Sound of the Smiths"), "d1005397b8a3a743fb0c8aad35f42db3"),
    ]

    /// Ещё 30 скачанных треков — «Скачанное» не из пары строк (задача пользователя
    /// 2026-10-21): только скачаны, «нравится» на них нет. Живые Deezer, превью играют
    /// (замер 2026-10-21).
    private static let downloadedTracks: [(id: Int, title: String, artist: String, album: (id: Int, title: String), cover: String, isExplicit: Bool)] = [
        (138539981, "Karma Police", "Radiohead", (14879699, "OK Computer"), "05a186e0a859a36f9cd51cdae2158fe1", false),
        (138546815, "Reckoner", "Radiohead", (14880659, "In Rainbows"), "a175af9b7d329bc678cb4d26fc13d6de", false),
        (1021196862, "Love Will Tear Us Apart", "Joy Division", (160648172, "Love Will Tear Us Apart (2020 Digital Remaster)"), "782d05923f29f050b1c799e2d5994526", false),
        (910120, "Just Like Heaven", "The Cure", (102619, "Kiss Me Kiss Me Kiss Me"), "5225e065ccb1c1d6375b10ddfc33a7c5", false),
        (131744046, "Blue Monday", "New Order", (13995194, "Singles (2016 Remaster)"), "197e425f52b7841c402437f34594a7bb", false),
        (68515055, "Enjoy the Silence", "Depeche Mode", (6709163, "The Singles 86-98"), "e73716d037ee24f1331a8c0332526590", false),
        (70322130, "Do I Wanna Know?", "Arctic Monkeys", (6899610, "AM"), "64e54e307bd5e2bdb27ffeb662fd910d", false),
        (958109, "Last Nite", "The Strokes", (101618, "Is This It"), "700f0375d5ac8570f16a2c7eb128303f", false),
        (944791, "Obstacle 1", "Interpol", (106308, "Matador At Fifteen"), "6f32e755ee7d0534451309d4ea837c7f", false),
        (936899, "Where Is My Mind?", "Pixies", (105352, "Death to the Pixies"), "fa4a3bb8ef29a683940f740a6ef85601", false),
        (104234648, "Teen Age Riot", "Sonic Youth", (10843530, "Daydream Nation"), "72f81ca7d2e4d281468de1e417e3e671", false),
        (2246288, "Alison", "Slowdive", (224401, "Souvlaki"), "4e045f8b3ff1cfc02bbd6211b87497d8", false),
        (1265932532, "sometimes", "my bloody valentine", (212636922, "loveless"), "217f6c70913d113d09a561cb17b64f6e", false),
        (942505, "Heaven or Las Vegas", "Cocteau Twins", (106054, "Heaven or Las Vegas"), "be62b1479e0baf17d8f9beca911ee8cd", false),
        (106380372, "Space Song", "Beach House", (11093204, "Depression Cherry"), "399cffa2434760d22746a10a44c80bc2", false),
        (982678, "Glory Box", "Portishead", (109301, "Dummy"), "5942b88996f33c82790023d5d99395d3", false),
        (3129748, "Teardrop", "Massive Attack", (301773, "Mezzanine"), "85abbdc3ed4a7b94ace97f868fe70f63", false),
        (3614317, "This Must Be the Place (Naive Melody)", "Talking Heads", (340889, "Speaking in Tongues (Deluxe Version)"), "70db13b9aec041ca74d0ec2b815846e9", false),
        (3110852, "All My Friends", "LCD Soundsystem", (300592, "Sound of Silver"), "d5aec97cfc1581df6b32a267fe067827", false),
        (103052662, "The Less I Know The Better", "Tame Impala", (10709540, "Currents"), "de5b9b704cd4ec36f8bf49beb3e17ba2", true),
        (63480987, "Dreams", "Fleetwood Mac", (6237061, "Rumours"), "9732751ce91d786dcf30069853697078", false),
        (461043312, "\"Heroes\"", "David Bowie", (56889262, "\"Heroes\""), "5fb91018679f65199308256be3c584ab", false),
        (13791930, "Smells Like Teen Spirit", "Nirvana", (1262014, "Nevermind (Remastered)"), "f0282817b697279e56df13909962a54a", false),
        (948331, "Cut Your Hair", "Pavement", (106700, "Crooked Rain, Crooked Rain: LA's Desert Origins"), "4f7553a1987ef17d30c6e7c3c78674ed", false),
        (3360821, "Fade Into You", "Mazzy Star", (319814, "So Tonight That I Might See"), "5d3703e81301662626cc06a8b2843c78", false),
        (448265892, "Звезда по имени Солнце", "Кино", (54718352, "Звезда по имени Солнце"), "b4076a916063e924824664e18292fad2", false),
        (836932812, "Судно (Борис Рыжий)", "Молчат Дома", (123870262, "Этажи"), "9cfa05e131119b60cf1d5cfe124d7d59", true),
        (2173954687, "Running Up That Hill (A Deal With God)", "Kate Bush", (413452427, "Hounds Of Love"), "22fedaf5d2b0ac8977b93bc1db7a4a2a", false),
        (540172652, "Pale Blue Eyes", "The Velvet Underground", (70487632, "The Velvet Underground (45th Anniversary)"), "b8438109e927f41cf792f84503f15983", false),
        (5093604, "This Charming Man", "The Smiths", (467267, "The Sound of the Smiths (Deluxe; 2008 Remaster)"), "d1005397b8a3a743fb0c8aad35f42db3", false),
    ]

    /// Записи 30 скачанных треков — старше остального стартового набора: свежие
    /// отметки пользователя остаются сверху.
    static func downloadedTrackItems(now: Date) -> [CollectionItem] {
        downloadedTracks.enumerated().map { index, track in
            let cover = deezer("cover", track.cover)
            var item = CollectionItem.track(
                MusicNowPlaying(
                    id: "track-\(track.id)",
                    cover: cover,
                    title: track.title,
                    artist: track.artist,
                    album: track.album.title,
                    isExplicit: track.isExplicit
                ),
                album: .album(EntityRef(
                    id: "dz-\(track.album.id)",
                    title: track.album.title,
                    subtitle: track.artist,
                    artwork: cover
                ))
            )
            item.downloadedAt = now.addingTimeInterval(-2 * 24 * 60 * 60 - TimeInterval(index) * 60)
            return item
        }
    }

    private static let artists: [(id: Int, name: String, picture: String)] = [
        (8706544, "Dua Lipa", "877872aaf75694f11d53c318700ab2b5"),
        (4050205, "The Weeknd", "581693b4724a7fcfa754455101e13a44"),
        (569, "The Strokes", "88e8ecd06aae5cd69d414af57a67f339"),
        (1182, "Arctic Monkeys", "6c03e4c7c36800897fd468633286db24"),
        (399, "Radiohead", "0d58cfbc90f2e776608bcdc0c45a4711"),
        (4505880, "Кино", "ec428d21f614b586a7b647f8da435913"),
    ]

    private static let albums: [(id: Int, title: String, artist: String, cover: String, isExplicit: Bool, downloaded: Bool)] = [
        (420206277, "Relationship of Command", "At the Drive-In", "b0892516361122a4a153e96f78681b4c", false, false),
        (230048, "Frances the Mute", "The Mars Volta", "726d2777243de725313e5392fcb6f097", false, false),
        (597350882, "BRAT", "Charli xcx", "de9e79511cda59914de9add50946e43c", true, true),
        (14880659, "In Rainbows", "Radiohead", "a175af9b7d329bc678cb4d26fc13d6de", false, true),
        (2795271, "Music Has The Right To Children", "Boards of Canada", "c3c2e2a739ed501d01791b16a3fd9ad3", false, false),
        (1261474, "The Queen Is Dead", "The Smiths", "7ca9c4c9988765720bf3b722e101d2c3", false, false),
    ]

    private static let playlists: [(id: Int, title: String, owner: String, picture: String)] = [
        (8716319082, "Indie Rock Essentials", "Deezer Alternative", "f9704a71bc3a51dd8ac519f8fbd5ad63"),
        (1306931615, "Rock Essentials", "Deezer Rock", "e17f63541e66d8f110ae90207b6c6007"),
        (6598036324, "Lo-Fi Beats", "JayVeeEss", "9fa86d931c007943f0fa217954176efd"),
        (1615514485, "Jazz Essentials", "Deezer Jazz & Blues", "cc8067c8528f163ae218b3e4d22815d3"),
    ]

    // MARK: - Ссылки

    /// Постер — пресетом 300x450 (`KinopoiskPosterSize.small`): голый хвост `…/600`
    /// из запаса CDN не отдаёт.
    private static func kinopoisk(_ path: String) -> ArtworkSource {
        remote("https://avatars.mds.yandex.net/get-kinopoisk-image/\(path)/\(KinopoiskPosterSize.small.rawValue)")
    }

    /// Обложка книги — та же ссылка, что собирает `GoogleBook.coverURL`.
    static func googleBooks(_ id: String) -> ArtworkSource {
        remote("https://books.google.com/books/content?id=\(id)&printsec=frontcover&img=1&zoom=3&source=gbs_api")
    }

    /// Картинки Deezer — 500×500: карточке 86 и строке 48 на ×3 этого хватает с запасом.
    private static func deezer(_ type: String, _ hash: String) -> ArtworkSource {
        remote("https://cdn-images.dzcdn.net/images/\(type)/\(hash)/500x500-000000-80-0-0.jpg")
    }

    private static func remote(_ string: String) -> ArtworkSource {
        URL(string: string).map { ArtworkSource.remote($0) } ?? .asset("")
    }
}
