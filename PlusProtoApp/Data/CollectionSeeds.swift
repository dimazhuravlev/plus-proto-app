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
        return result
    }

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
    private static func googleBooks(_ id: String) -> ArtworkSource {
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
