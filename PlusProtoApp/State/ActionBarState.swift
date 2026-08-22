import SwiftUI

/// Режим action bar. По решению 2026-08-22 определяется **последним потреблённым
/// контентом**, а не активным табом: бар — это быстрый возврат к продолжению
/// прослушивания/просмотра/чтения. Ничего не потреблялось → `search`.
enum ActionBarMode: Equatable {
    case search
    case music
    case movie
    case book
}

/// Откуда берётся картинка. Прототип живёт на двух источниках одновременно:
/// забандленные моки сейчас и картинки из API на Этапе 7 — различаем здесь,
/// чтобы вёрстка бара не переписывалась при переходе на живые данные.
enum ArtworkSource: Equatable {
    case asset(String)
    case remote(URL)
}

/// Что играет: круглая обложка 48×48 + две строки подписи (figma-actionbar §4.2).
struct MusicNowPlaying: Equatable {
    var id: String
    var cover: ArtworkSource
    var title: String
    var artist: String
}

/// Что смотрели: кадр 80×46 внутри чипа 88×54 (figma-actionbar §4.4).
/// Прогресс и подписи чипу не нужны — в макете это просто кадр.
struct MovieInProgress: Equatable {
    var id: String
    var still: ArtworkSource
    var title: String
}

/// Что читали: обложка 36×52 внутри чипа 44×60 (figma-actionbar §4.3).
struct BookInProgress: Equatable {
    var id: String
    var cover: ArtworkSource
    var title: String
}

/// Модель action bar: режим + payload на каждый режим.
///
/// `@Observable` вместо `ObservableObject` из MusicPlayer сознательно: наблюдение
/// по-свойственное, поэтому тик прогресса плеера не инвалидирует ни витрину, ни таббар —
/// только тот подслой бара, который прогресс читает. Это прямо в цель «120 fps на скролле».
@Observable
final class ActionBarState {
    private(set) var mode: ActionBarMode = .search

    init() {
        #if DEBUG
        applyDebugLaunchModeIfNeeded()
        #endif
    }

    /// Payload'ы не сбрасываются при смене режима.
    /// (никаких if/else-подмен — решение 2026-08-22), значит уходящий элемент должен
    /// оставаться отрисованным до конца анимации, а вернувшийся режим — не мигать пустотой.
    private(set) var music: MusicNowPlaying?
    private(set) var movie: MovieInProgress?
    private(set) var book: BookInProgress?

    /// Транспорт музыки — отдельными свойствами, а не полями `music`: они меняются
    /// на каждом тике плеера, и при вложении в структуру тик инвалидировал бы
    /// и обложку с подписью.
    var musicProgress: Double = 0
    var isMusicPlaying: Bool = false
    var isMusicLiked: Bool = false

    /// Поиск в фокусе: поле расширяется, плеер сжимается в круг 60×60, бар поднимается
    /// над клавиатурой. Не локальный стейт бара, потому что таббар уезжает под клавиатуру
    /// вместе с этим флагом.
    var isSearchFocused: Bool = false

    func startMusic(_ item: MusicNowPlaying) {
        music = item
        musicProgress = 0
        isMusicPlaying = true
        isMusicLiked = false
        mode = .music
    }

    func resumeMovie(_ item: MovieInProgress) {
        movie = item
        mode = .movie
    }

    func resumeBook(_ item: BookInProgress) {
        book = item
        mode = .book
    }

    /// Контента нет (холодный старт, всё сброшено) — бар в поиске.
    func resetToSearch() {
        mode = .search
    }
}

#if DEBUG
extension ActionBarState {
    static let debugMusic = MusicNowPlaying(
        id: "debug-music",
        cover: .asset("mockAlbumCover"),
        title: "Strawberry Line",
        artist: "Cocteau Twins"
    )

    static let debugMovie = MovieInProgress(
        id: "debug-movie",
        still: .asset("mockChipMovieStill"),
        title: "Здесь был Юра"
    )

    static let debugBook = BookInProgress(
        id: "debug-book",
        cover: .asset("mockChipBookCover"),
        title: "Технофеодализм"
    )

    /// `-debugActionBar search|music|movie|book` — см. `PlusProtoAppApp.parseDebugLaunchArguments`.
    private func applyDebugLaunchModeIfNeeded() {
        guard let key = UserDefaults.standard.string(forKey: "debugActionBar") else { return }
        switch key {
        case "search":
            music = Self.debugMusic
            mode = .search
            isMusicPlaying = true
            musicProgress = 0
        case "music":
            startMusic(Self.debugMusic)
            musicProgress = 0.42
            isMusicPlaying = false
        case "movie":
            resumeMovie(Self.debugMovie)
        case "book":
            resumeBook(Self.debugBook)
        default:
            break
        }
    }

    func cycleDebugMode() {
        switch mode {
        case .search:
            startMusic(Self.debugMusic)
        case .music:
            resumeMovie(Self.debugMovie)
        case .movie:
            resumeBook(Self.debugBook)
        case .book:
            resetToSearch()
        }
    }

    var debugModeTitle: String {
        switch mode {
        case .search: "поиск"
        case .music: "музыка"
        case .movie: "кино"
        case .book: "книга"
        }
    }
}
#endif
