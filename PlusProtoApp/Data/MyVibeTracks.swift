import Foundation

/// «Моя Волна» — поток, а не трек: её кнопка, лепестки барабана и карточка «Главной»
/// включают настоящий трек в её настроении (правка пользователя 2026-10-09: «не бывает
/// трека „Моя волна“»). Треки — постпанк, холодная волна, синтезаторы восьмидесятых,
/// у всех есть превью Deezer.
///
/// Id — `my-vibe-t<трек Deezer>`: по хвосту звук находит превью сразу (`MusicAudio`),
/// по префиксу экран волны узнаёт в баре свою волну.
enum MyVibeTracks {
    static let idPrefix = "my-vibe-"

    static let all: [MusicNowPlaying] = [
        track(741235352, "Disorder", "Joy Division", cover: "013c601da70bf83a0fea61bd9c526449"),
        track(2498167, "A Forest", "The Cure", cover: "e7bc87da0296382c7089aa7631f00058"),
        track(131744032, "Ceremony", "New Order", cover: "197e425f52b7841c402437f34594a7bb"),
        track(1148491, "Spellbound", "Siouxsie and The Banshees", cover: "218fd9b857115b772a34b4d056294ddf"),
        track(942505, "Heaven or Las Vegas", "Cocteau Twins", cover: "be62b1479e0baf17d8f9beca911ee8cd"),
        track(68515055, "Enjoy the Silence", "Depeche Mode", cover: "e73716d037ee24f1331a8c0332526590"),
        track(836932812, "Судно (Борис Рыжий)", "Molchat Doma", cover: "9cfa05e131119b60cf1d5cfe124d7d59"),
    ]

    static func isVibe(_ id: String?) -> Bool {
        id?.hasPrefix(idPrefix) ?? false
    }

    /// Случайный трек волны — не тот, что уже стоит в баре.
    static func random(excluding id: String? = nil) -> MusicNowPlaying {
        all.filter { $0.id != id }.randomElement() ?? all[0]
    }

    /// Обложка — альбома трека на CDN Deezer, 1000 — под полноэкранный плеер.
    private static func track(_ id: Int, _ title: String, _ artist: String, cover: String) -> MusicNowPlaying {
        MusicNowPlaying(
            id: "\(idPrefix)t\(id)",
            cover: URL(string: "https://cdn-images.dzcdn.net/images/cover/\(cover)/1000x1000-000000-80-0-0.jpg")
                .map { ArtworkSource.remote($0, fallback: nil) } ?? .asset("mockPlayerCover"),
            title: title,
            artist: artist
        )
    }
}

extension ActionBarState {
    /// Включить «Мою Волну». Волна уже в баре — тот же трек: повторный тап ставит
    /// на паузу и снимает с неё, как у любого трека; иначе — трек волны наугад.
    func openMyVibe() {
        if let current = music, MyVibeTracks.isVibe(current.id) {
            open(.music(current))
        } else {
            open(.music(MyVibeTracks.random()))
        }
    }
}
