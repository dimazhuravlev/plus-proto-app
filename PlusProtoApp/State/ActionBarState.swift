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
/// забандленные моки и картинки из API — различаем здесь, чтобы вёрстка не зависела
/// от того, приехали живые данные или нет.
enum ArtworkSource: Hashable {
    case asset(String)
    /// Живая картинка с бандленным фолбэком: пока она грузится и если не загрузится
    /// вовсе, рисуется ассет. Без фолбэка блок мигал бы пустотой на каждом холодном
    /// старте и оставался пустым без сети.
    case remote(URL, fallback: String?)

    static func remote(_ url: URL) -> ArtworkSource { .remote(url, fallback: nil) }

    /// Бандленная картинка, которой закрывается кадр до загрузки.
    var fallbackAsset: String? {
        switch self {
        case .asset(let name): name
        case .remote(_, let fallback): fallback
        }
    }

    var remoteURL: URL? {
        switch self {
        case .asset: nil
        case .remote(let url, _): url
        }
    }
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

    /// Мок-длительность трека: живого аудио нет, от неё считается шаг прогресса.
    private static let mockTrackDuration: TimeInterval = 210
    /// Шаг тика — дважды в секунду. Чаще не нужно: заливка между тиками анимируется.
    private static let progressTick: TimeInterval = 0.5
    private var progressTicker: Task<Void, Never>?

    func startMusic(_ item: MusicNowPlaying) {
        music = item
        musicProgress = 0
        isMusicPlaying = true
        isMusicLiked = false
        mode = .music
        startProgressTicking()
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

    /// Переключить воспроизведение. Прогресс тикает редко (2 раза в секунду) —
    /// промежуточные кадры дорисовывает анимация заливки, `body` на них не пересчитывается.
    func toggleMusicPlayback() {
        isMusicPlaying.toggle()
        if isMusicPlaying {
            startProgressTicking()
        } else {
            progressTicker?.cancel()
            progressTicker = nil
        }
    }

    /// Живого аудио в прототипе нет — прогресс идёт от мок-длительности трека.
    private func startProgressTicking() {
        progressTicker?.cancel()
        progressTicker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.progressTick))
                guard let self, self.isMusicPlaying else { return }
                let step = Self.progressTick / Self.mockTrackDuration
                self.musicProgress = (self.musicProgress + step).truncatingRemainder(dividingBy: 1)
            }
        }
    }

    /// Открыть плеер сущности с витрины. Повторный тап по той же карточке в музыке
    /// работает как пауза — иначе плеер нечем остановить, пока нет полноэкранного.
    func open(_ target: ShowcasePlayerTarget) {
        switch target {
        case .music(let item):
            if mode == .music, music?.id == item.id {
                // Через тот же метод, что и кнопка: иначе тикер прогресса
                // остался бы работать на паузе.
                toggleMusicPlayback()
            } else {
                startMusic(item)
            }
        case .movie(let item):
            resumeMovie(item)
        case .book(let item):
            resumeBook(item)
        }
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
