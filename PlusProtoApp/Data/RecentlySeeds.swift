import Foundation

/// Стартовый набор ряда «продолженного потребления» «Главной» (задача 71) — чтобы на свежей
/// установке ряд не стоял пустым. Восемь айтемов в порядке макета `2713:26833`: фильм,
/// альбом, книга, исполнитель — и ещё раз.
///
/// Всё запускается так же, как записанное: фильм — киноплеер с места остановки, альбом —
/// трек Deezer (превью ищется по `track-<id>`), книга — читалка по тому Google Books,
/// исполнитель — его экран. Музыка, книги и исполнители — живые сущности из стартовой
/// коллекции «Моё» (`CollectionSeeds`, сверены 2026-10-04); книги — с обложкой 2:3, как
/// плитка ряда. У фильмов горизонтальные кадры есть только забандленные: «Здесь был Юра»
/// (кадр макета) и «Падшие ангелы» (кадр ролика `fallen-angels`).
enum RecentlySeeds {
    static var items: [RecentItem] {
        [
            // Прогресс — как у карточки макета (0.815) и мок-«Смотреть дальше» того же
            // фильма: 16 мин до конца из 86.5.
            .movie(MovieInProgress(
                id: "yura",
                still: .asset("mockVideoStill"),
                title: "Здесь был Юра",
                runtime: 5_190,
                position: 4_230
            )),
            .music(track(
                138546809, "Weird Fishes / Arpeggi", "Radiohead",
                album: (14880659, "In Rainbows"), cover: "a175af9b7d329bc678cb4d26fc13d6de"
            )),
            .book(book("wuiaEAAAQBAJ", "Мастер и Маргарита", "Михаил Булгаков")),
            .artist(artist(4505880, "Кино", picture: "ec428d21f614b586a7b647f8da435913")),
            // 99 мин, просмотрено 42 %.
            .movie(MovieInProgress(
                id: "fallen-angels",
                still: .asset("mockFallenAngelsStill"),
                title: "Падшие ангелы",
                runtime: 5_940,
                position: 2_495
            )),
            .music(track(
                5093617, "There Is a Light That Never Goes Out", "The Smiths",
                album: (467267, "The Sound of the Smiths"), cover: "d1005397b8a3a743fb0c8aad35f42db3"
            )),
            .book(book("8pCRDwAAQBAJ", "Краткая история времени", "Стивен Хокинг")),
            .artist(artist(4050205, "The Weeknd", picture: "581693b4724a7fcfa754455101e13a44")),
        ]
    }

    // MARK: - Сборка

    /// Трек — из своего альбома: по `containerID` экран альбома узнаёт его в баре.
    /// Обложка 1000 — под полноэкранный плеер, как у треков «Моей волны».
    private static func track(
        _ id: Int, _ title: String, _ artist: String,
        album: (id: Int, title: String), cover: String
    ) -> MusicNowPlaying {
        MusicNowPlaying(
            id: "track-\(id)",
            cover: deezer("cover", cover, size: 1000),
            title: title,
            artist: artist,
            album: album.title,
            containerID: "album:dz-\(album.id)"
        )
    }

    /// Обложка — та же ссылка, что собирает `GoogleBook.coverURL`.
    private static func book(_ id: String, _ title: String, _ author: String) -> BookInProgress {
        BookInProgress(
            id: "gb-\(id)",
            cover: remote("https://books.google.com/books/content?id=\(id)&printsec=frontcover&img=1&zoom=3&source=gbs_api"),
            title: title,
            author: author
        )
    }

    private static func artist(_ id: Int, _ name: String, picture: String) -> EntityRef {
        EntityRef(id: "dz-\(id)", title: name, subtitle: "", artwork: deezer("artist", picture, size: 500))
    }

    private static func deezer(_ type: String, _ hash: String, size: Int) -> ArtworkSource {
        remote("https://cdn-images.dzcdn.net/images/\(type)/\(hash)/\(size)x\(size)-000000-80-0-0.jpg")
    }

    private static func remote(_ string: String) -> ArtworkSource {
        URL(string: string).map { ArtworkSource.remote($0) } ?? .asset("")
    }
}
