import SwiftUI

/// Режим action bar. По решению 2026-08-22 определяется **последним потреблённым
/// контентом**, а не активным табом: бар — это быстрый возврат к продолжению
/// прослушивания/просмотра/чтения. Ничего не потреблялось → `search`.
enum ActionBarMode: String, Equatable, Codable {
    case search
    case music
    case movie
    case book
}

/// Откуда берётся картинка. Прототип живёт на двух источниках одновременно:
/// забандленные моки и картинки из API — различаем здесь, чтобы вёрстка не зависела
/// от того, приехали живые данные или нет.
enum ArtworkSource: Hashable, Codable {
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
/// Опциональные поля — для полноэкранного плеера; их знает только экран альбома,
/// и снимок бара, записанный до них, по-прежнему читается.
/// Прогресс трека как функция времени: опора плюс ход от неё. Вью читают его
/// на кадрах `TimelineView` — полоса едет плавно и линейно, а стейт пишется
/// только на тиках и событиях транспорта.
struct MusicClock: Equatable {
    let anchor: Double
    let date: Date
    let isAdvancing: Bool

    func progress(at now: Date) -> Double {
        guard isAdvancing else { return anchor }
        let advanced = anchor + max(0, now.timeIntervalSince(date)) / ActionBarState.musicDuration
        return advanced.truncatingRemainder(dividingBy: 1)
    }
}

struct MusicNowPlaying: Equatable, Codable {
    var id: String
    var cover: ArtworkSource
    var title: String
    var artist: String
    /// Альбом трека — вторая строка навбара плеера («Альбом «…»»).
    var album: String? = nil
    /// Год альбома — серая строка под артистом.
    var year: String? = nil
    /// Фото артиста — кружок у строки артиста. Нет — там обложка трека.
    var artistPicture: ArtworkSource? = nil
    /// Бейдж 18+ у названия. Опционал ради старых снимков: `nil` читается как «нет».
    var isExplicit: Bool? = nil
}

/// Что смотрели: кадр 80×46 внутри чипа 88×54 (figma-actionbar §4.4).
/// Чипу нужен только кадр; остальное — для киноплеера, который открывает тап по нему.
///
/// Новые поля опциональны: снимок бара лежит на диске, и запись, сделанная до них,
/// обязана читаться — синтезированный `Codable` берёт для опционалов `decodeIfPresent`.
struct MovieInProgress: Equatable, Codable {
    var id: String
    var still: ArtworkSource
    var title: String
    /// Вторая строка шапки плеера — год и жанр. Нет — шапка в одну строку.
    var subtitle: String? = nil
    /// Хронометраж тайтла, секунды. Нет — плеер берёт длительность из макета.
    var runtime: TimeInterval? = nil
    /// Где остановились, секунды. Пишется на закрытии плеера: чип бара — это
    /// «продолжить смотреть», и возвращать к началу фильма он не должен.
    var position: TimeInterval? = nil
}

/// Что читали: обложка 36×52 внутри чипа 44×60 (figma-actionbar §4.3).
struct BookInProgress: Equatable, Codable {
    var id: String
    var cover: ArtworkSource
    var title: String
    /// Подпись в шапке читалки. Нет — её дотягивает из API `BookTextStore`.
    var author: String? = nil
}

/// Что развёрнуто на весь экран поверх приложения: плеер музыки, киноплеер или читалка.
/// Показывает их `ContentPlayerPresenter` — одной точкой входа для всех кнопок.
enum ContentPlayer: Equatable, Identifiable {
    /// Полноэкранный плеер музыки. Что играет, он читает из бара сам: трек может
    /// смениться, пока плеер открыт («Дальше», дизлайк, строка очереди).
    case music
    case movie(MovieInProgress)
    /// `showsMusic` фиксируется в момент запуска: мини-плеер музыки в читалке есть,
    /// только если музыка играла, когда читалку открыли (правило пользователя
    /// 2026-10-03). Пауза внутри читалки его не убирает — иначе снова включить
    /// музыку было бы нечем.
    case reader(BookInProgress, showsMusic: Bool)

    var id: String {
        switch self {
        case .music: "music"
        case .movie(let item): "movie-" + item.id
        case .reader(let item, _): "reader-" + item.id
        }
    }
}

/// Модель action bar: режим + payload на каждый режим.
///
/// `@Observable` вместо `ObservableObject` из MusicPlayer сознательно: наблюдение
/// по-свойственное, поэтому тик прогресса плеера не инвалидирует ни витрину, ни таббар —
/// только тот подслой бара, который прогресс читает. Это прямо в цель «120 fps на скролле».
@Observable
final class ActionBarState {
    private(set) var mode: ActionBarMode = .search { didSet { persist() } }

    init() {
        restore()
        #if DEBUG
        // Флаг запуска перекрывает восстановленное состояние: прогон обязан начинаться
        // с того, что в нём попросили, а не с того, что осталось от прошлой сессии.
        applyDebugLaunchModeIfNeeded()
        #endif
    }

    /// Payload'ы не сбрасываются при смене режима.
    /// (никаких if/else-подмен — решение 2026-08-22), значит уходящий элемент должен
    /// оставаться отрисованным до конца анимации, а вернувшийся режим — не мигать пустотой.
    private(set) var music: MusicNowPlaying? { didSet { persist() } }
    private(set) var movie: MovieInProgress? { didSet { persist() } }
    private(set) var book: BookInProgress? { didSet { persist() } }

    /// «Смотреть дальше» главной Кинопоиска — всё, что запускали в киноплеере.
    /// Живёт здесь, потому что вход в плеер один — `watch` (2026-10-04).
    let watchHistory = WatchHistory()

    /// Транспорт музыки — отдельными свойствами, а не полями `music`: они меняются
    /// на каждом тике плеера, и при вложении в структуру тик инвалидировал бы
    /// и обложку с подписью.
    ///
    /// Прогресс наблюдателя не имеет намеренно: он меняется дважды в секунду, и запись
    /// на диск на каждый тик была бы дорогой. На диск он уезжает вместе с ближайшим
    /// событием — паузой, сменой трека, запуском другого контента.
    var musicProgress: Double = 0 { didSet { musicProgressDate = .now } }
    var isMusicPlaying: Bool = false { didSet { persist() } }
    /// Когда поставили `musicProgress` — опора плавного хода (`musicClock`).
    private(set) var musicProgressDate = Date.now
    /// Прогресс идёт: трек играет, и звук не в пути (или его нет вовсе). Ставит тикер.
    private(set) var isMusicAdvancing = false

    /// Прогресс как функция времени — полоса плееров едет по нему плавно и линейно
    /// (правка пользователя 2026-10-06: прежде шагала на каждом тике). Вью считают
    /// позицию на кадре сами (`MusicProgressReader`), в стейт пишутся только тики.
    var musicClock: MusicClock {
        MusicClock(
            anchor: musicProgress,
            date: musicProgressDate,
            isAdvancing: isMusicAdvancing && isMusicPlaying && !isMusicScrubbing
        )
    }

    /// Позиция прямо сейчас, между тиками.
    private var liveMusicProgress: Double {
        musicClock.progress(at: .now)
    }

    /// Сердце мини-плеера и плеера музыки — играющий трек в «Любимом» коллекции «Моё»
    /// (2026-10-04). Прежде это был флаг бара, забывавший отметку на смене трека.
    @MainActor var isMusicLiked: Bool {
        guard let music else { return false }
        return CollectionStore.shared.isFavorite(CollectionItem.track(music).id)
    }

    /// Открытый плеер музыки, киноплеер или читалка. На диск не пишется: после
    /// перезапуска приложение поднимается на экране, а не посреди фильма.
    private(set) var contentPlayer: ContentPlayer?

    /// Палец на таймлайне плеера музыки: тикер прогресса молчит, иначе он тянул бы
    /// заливку вперёд из-под пальца дважды в секунду.
    var isMusicScrubbing = false {
        // Отпустили — ход идёт от точки отпускания, а не от последнего сдвига пальца.
        didSet {
            guard oldValue, !isMusicScrubbing else { return }
            let released = musicProgress
            musicProgress = released
        }
    }

    /// Поиск в фокусе: поле расширяется, плеер сжимается в круг 60×60, бар поднимается
    /// над клавиатурой. Не локальный стейт бара, потому что таббар уезжает под клавиатуру
    /// вместе с этим флагом.
    ///
    /// Фокус **повышает режим до `.search`**, если поиск был кругом. Круг он только
    /// в `.music` — в остальных режимах поле и так во всю ширину, и трогать их незачем
    /// (у `.book`/`.movie` пришлось бы выбросить их чип).
    ///
    /// Зачем: раньше поиск на активации прыгал из круга сразу во всю ширину, а после
    /// снятия фокуса схлопывался обратно в круг. Теперь он на активации разворачивается
    /// в свою широкую версию — а плеер тем же движением сжимается в круг и уезжает
    /// за кромку, — и после снятия фокуса бар в ней и остаётся. Возвращать круг незачем:
    /// пользователь только что показал, что ему нужен поиск.
    var isSearchFocused: Bool = false {
        didSet { promoteSearchIfCompact() }
    }

    /// Повышает режим до `.search`, если поиск сейчас круг.
    ///
    /// Зовётся и на получении фокуса, и на снятии, и это не перестраховка: музыка может
    /// начаться **пока поиск открыт** (тап по карточке витрины из-под слоя, автозапуск
    /// плеера), и тогда проверка только на входе промахивается — режим уезжает
    /// в `.music` уже после неё, и на выходе поле снова схлопывается в круг. Ровно этот
    /// промах и ловился, когда музыка приезжала позже фокуса.
    ///
    /// Круг поиска бывает только в `.music`: в `.book` и `.movie` поле и так во всю
    /// ширину, и повышение выбросило бы их чип — то есть отобрало бы книгу или фильм,
    /// которые пользователь смотрит, ради поиска, который он уже закрыл.
    private func promoteSearchIfCompact() {
        guard mode == .music else { return }
        mode = .search
    }

    /// Длительность трека — 30 с, как у превью Deezer, которые играет `MusicAudio`:
    /// плеер не врёт о длине того, что звучит. Пока превью играет, прогресс идёт
    /// за звуком; без звука (сеть, трек не нашёлся) — шагом от этой длительности.
    /// Не приватная: от неё полноэкранный плеер считает таймкоды.
    static let musicDuration: TimeInterval = 30
    /// Шаг тика — дважды в секунду. Чаще не нужно: заливка между тиками анимируется.
    private static let progressTick: TimeInterval = 0.5
    private var progressTicker: Task<Void, Never>?

    func startMusic(_ item: MusicNowPlaying) {
        music = item
        musicProgress = 0
        isMusicAdvancing = false
        isMusicPlaying = true
        mode = .music
        startProgressTicking()
        // Тот же трек ещё раз — тоже с начала.
        audio { audio in
            audio.play(item, from: 0, isPlaying: true)
            audio.seek(to: 0)
        }
    }

    func resumeMovie(_ item: MovieInProgress) {
        stopMusic()
        movie = item
        mode = .movie
    }

    /// Книга в баре. Музыку не глушит: читать под музыку — штатный сценарий, ради него
    /// в читалке есть свой мини-плеер (правило пользователя 2026-10-03). Пока музыка
    /// играет, бар остаётся за ней: плеер в баре один, и спрятать играющий трек
    /// за чипом книги значит снова сделать из него призрака, которого нечем остановить.
    func resumeBook(_ item: BookInProgress) {
        book = item
        if !isMusicPlaying { mode = .book }
    }

    /// Музыка выключается ровно в двух случаях: вручную кнопкой play/pause и здесь —
    /// когда включают кино (правило пользователя 2026-08-29). Плеер в баре один, чип
    /// кино занимает его место, и играющая под ним музыка была бы призраком:
    /// остановить её стало бы нечем. Книгу музыка переживает — см. `resumeBook`.
    ///
    /// Навигация музыку не трогает вовсе — ни переход по табам, ни открытие экрана,
    /// ни поиск. `music` тут тоже не сбрасывается: payload остаётся, чтобы к треку
    /// можно было вернуться.
    private func stopMusic() {
        if isMusicPlaying { musicProgress = liveMusicProgress }
        isMusicAdvancing = false
        isMusicPlaying = false
        progressTicker?.cancel()
        progressTicker = nil
        audio { $0.setPlaying(false) }
    }

    /// Контента нет (холодный старт, всё сброшено) — бар в поиске.
    func resetToSearch() {
        mode = .search
    }

    /// Тап по компактному кругу разворачивает плеер прямо в баре (правило пользователя
    /// 2026-08-29). Полноэкранный из круга не открываем: круг — это свёрнутый плеер,
    /// и первый тап по нему обязан его развернуть, а не перепрыгнуть через состояние.
    func expandMiniPlayer() {
        guard music != nil else { return }
        mode = .music
    }

    // MARK: - Диск

    /// Снимок бара на диске. Восстанавливается на холодном старте, чтобы плеер
    /// пережил перезапуск (задача пользователя 2026-08-29): бар — это «продолжить
    /// то, что слушал/смотрел/читал», и терять это на выходе из приложения нельзя.
    private struct Snapshot: Codable {
        var mode: ActionBarMode
        var music: MusicNowPlaying?
        var movie: MovieInProgress?
        var book: BookInProgress?
        var musicProgress: Double
        var isMusicPlaying: Bool
    }

    private static let storageKey = "actionBarState"

    /// Пока раскладываем снимок по свойствам, наблюдатели молчат: иначе каждое
    /// присваивание писало бы на диск то, что мы только что с него прочитали.
    private var isRestoring = false

    private func persist() {
        guard !isRestoring else { return }
        let snapshot = Snapshot(
            mode: mode,
            music: music,
            movie: movie,
            book: book,
            musicProgress: musicProgress,
            isMusicPlaying: isMusicPlaying
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
        else { return }

        isRestoring = true
        defer { isRestoring = false }

        mode = snapshot.mode
        music = snapshot.music
        movie = snapshot.movie
        book = snapshot.book
        musicProgress = snapshot.musicProgress
        // Плеер возвращается на паузе, как у любого музыкального приложения: с тех пор
        // как у музыки есть звук (2026-10-05), сам он на холодном старте не включается.
        // Трек и позиция — на месте, play продолжит с них.
        isMusicPlaying = false
    }

    /// Переключить воспроизведение. Прогресс тикает редко (2 раза в секунду) —
    /// промежуточные кадры дорисовывает анимация заливки, `body` на них не пересчитывается.
    func toggleMusicPlayback() {
        // Опора — на «сейчас» и в обе стороны: пауза замирает там, где звучал звук,
        // продолжение идёт от той же точки (со старой опорой ход насчитался бы и за
        // паузу) и сразу, если звук уже загружен, — без полусекунды до первого тика.
        musicProgress = audioFractionNow() ?? liveMusicProgress
        isMusicPlaying.toggle()
        isMusicAdvancing = isMusicPlaying && audioFractionNow() != nil
        if isMusicPlaying {
            startProgressTicking()
        } else {
            progressTicker?.cancel()
            progressTicker = nil
        }
        syncAudio()
    }

    /// Звук догоняет транспорт: пауза — стоять; play — тот же трек играет дальше,
    /// ещё не загруженный (после холодного старта) грузится с позиции прогресса.
    private func syncAudio() {
        guard isMusicPlaying, let music else {
            audio { $0.setPlaying(false) }
            return
        }
        let progress = musicProgress
        audio { $0.play(music, from: progress, isPlaying: true) }
    }

    /// Доля трека по звуку, если превью играет и вызов пришёл с главного потока.
    private func audioFractionNow() -> Double? {
        guard Thread.isMainThread else { return nil }
        return MainActor.assumeIsolated { MusicAudio.shared.tickerFraction }
    }

    /// Звук живёт на главном потоке. Транспорт трогают кнопки и экраны — с него же,
    /// но на всякий случай с другого потока вызов доезжает задачей.
    private func audio(_ body: @escaping @MainActor (MusicAudio) -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { body(MusicAudio.shared) }
        } else {
            Task { @MainActor in body(MusicAudio.shared) }
        }
    }

    /// Играет превью — опора за звуком; превью в пути — стоит (без отскока назад,
    /// когда звук начнётся); звука нет — идёт сама от длительности трека, по кругу.
    /// Между тиками полосу ведут вью по `musicClock`, тик только поправляет опору.
    private func startProgressTicking() {
        progressTicker?.cancel()
        progressTicker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.progressTick))
                guard let self, self.isMusicPlaying else { return }
                // Палец на таймлайне — позиция за ним, тикер не вмешивается.
                guard !self.isMusicScrubbing else { continue }
                let (fraction, isAwaiting) = await MainActor.run {
                    (MusicAudio.shared.tickerFraction, MusicAudio.shared.isAwaitingAudio)
                }
                if let fraction {
                    self.musicProgress = fraction
                    self.setMusicAdvancing(true)
                } else if isAwaiting {
                    self.setMusicAdvancing(false)
                } else {
                    self.musicProgress = self.liveMusicProgress
                    self.setMusicAdvancing(true)
                }
            }
        }
    }

    /// Без лишней записи: флаг наблюдаемый, а тик — дважды в секунду.
    private func setMusicAdvancing(_ value: Bool) {
        if isMusicAdvancing != value { isMusicAdvancing = value }
    }

    /// Открыть плеер сущности. Повторный тап по той же карточке в музыке работает
    /// как пауза — иначе плеер нечем остановить, пока нет полноэкранного. Кино и книга
    /// открываются сразу на весь экран: «Смотреть» и «Читать» обещают фильм и текст,
    /// а не чип в баре.
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
            watch(item)
        case .book(let item):
            read(item)
        }
    }

    // MARK: - Плеер музыки

    /// Открыть полноэкранный плеер музыки — тап по широкой пилюле мини-плеера.
    func openMusicPlayer() {
        guard music != nil else { return }
        contentPlayer = .music
    }

    /// Перемотка таймлайном плеера: позиция трека долей, 0…1.
    func seekMusic(to fraction: Double) {
        musicProgress = min(max(0, fraction), 1)
        let progress = musicProgress
        audio { $0.seek(to: progress) }
    }

    /// «Назад»: трек с начала. Предыдущего трека у мока нет — история не хранится.
    func restartTrack() {
        musicProgress = 0
        audio { $0.seek(to: 0) }
    }

    /// «Дальше» и дизлайк: следующий трек из очереди «Что дальше».
    func skipToNext() {
        guard let next = MusicQueue.upcoming(after: music?.id).first else { return }
        startMusic(next.nowPlaying)
    }

    /// Отметить играющий трек в «Любимом» коллекции или снять отметку.
    @MainActor func toggleMusicLike() {
        guard let music else { return }
        CollectionStore.shared.toggleFavorite(.track(music))
    }

    // MARK: - Киноплеер и читалка

    /// Открыть киноплеер. Один вход и для «Смотреть» на карточке тайтла, и для чипа
    /// кино в баре — чтобы плеер нигде не открывался по-своему.
    func watch(_ item: MovieInProgress) {
        var item = item
        // Тот же фильм продолжается с места, где его закрыли: экран тайтла про
        // сохранённую позицию не знает и приходит без неё. Не в чипе бара — из истории
        // просмотра: «Смотреть дальше» продолжает любой запущенный фильм (2026-10-04).
        if item.position == nil {
            item.position = movie?.id == item.id ? movie?.position : watchHistory.position(for: item.id)
        }
        // Хронометраж — тоже из истории, если вход его не знает (чип бара, витрина):
        // иначе плеер шёл бы по числу макета, а карточка «Смотреть дальше» — по
        // настоящему, и полосы разошлись бы.
        if item.runtime == nil {
            item.runtime = watchHistory.runtime(for: item.id)
        }
        deferResume(.movie(item))
        contentPlayer = .movie(item)
    }

    /// Открыть читалку. Играет ли музыка, снимается **до** того, как книга займёт
    /// бар: мини-плеер в читалке — для музыки, которая звучала в момент запуска.
    func read(_ item: BookInProgress) {
        let showsMusic = isMusicPlaying && music != nil
        deferResume(.book(item))
        contentPlayer = .reader(item, showsMusic: showsMusic)
    }

    // MARK: Бар — после выезда плеера

    /// Смена бара под запущенный фильм или книгу, отложенная до конца выезда плеера
    /// (правка пользователя 2026-10-04): прежде бар морфился в чип на глазах, пока
    /// киноплеер или читалка ещё ехали снизу. Теперь он меняется под плеером, когда
    /// тот закрыл экран, — на закрытии плеера бар уже в новом состоянии. Так же
    /// и «Смотреть дальше» на главной Кинопоиска (правка тем же днём): фильм встаёт
    /// в карусель под плеером, а не переставляет её в момент тапа.
    private enum PendingResume {
        case movie(MovieInProgress)
        case book(BookInProgress)
    }

    @ObservationIgnored private var pendingResume: PendingResume?
    @ObservationIgnored private var pendingResumeFallback: Task<Void, Never>?

    /// Запасной срок: презентер сообщает о конце выезда сам (`contentPlayerDidPresent`),
    /// но если показать было не с чего, бар всё равно обязан догнать запуск.
    private static let resumeFallback: Duration = .milliseconds(800)

    /// Плеер встал на весь экран — бар меняется под ним, невидимо.
    func contentPlayerDidPresent() {
        applyPendingResume()
    }

    private func deferResume(_ resume: PendingResume) {
        applyPendingResume()
        pendingResume = resume
        // На главном акторе: бар — состояние интерфейса.
        pendingResumeFallback = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.resumeFallback)
            guard !Task.isCancelled else { return }
            self?.applyPendingResume()
        }
    }

    private func applyPendingResume() {
        pendingResumeFallback?.cancel()
        pendingResumeFallback = nil
        guard let pending = pendingResume else { return }
        pendingResume = nil
        switch pending {
        case .movie(let item):
            watchHistory.record(item)
            resumeMovie(item)
        case .book(let item):
            resumeBook(item)
        }
    }

    /// Закрыть киноплеер или читалку.
    ///
    /// - Parameters:
    ///   - moviePosition: где остановился фильм — чип бара продолжит с этого места.
    ///     Нужен только киноплееру.
    ///   - movieRuntime: длина таймлайна, по которому шёл плеер, — с ней карточка
    ///     «Смотреть дальше» показывает ту же полосу просмотра.
    func closeContentPlayer(moviePosition: TimeInterval? = nil, movieRuntime: TimeInterval? = nil) {
        // Закрыли раньше, чем плеер доехал, — бар догоняет запуск сейчас: позиция
        // фильма пишется в его чип.
        applyPendingResume()
        switch contentPlayer {
        case .movie(let item):
            if let moviePosition, movie?.id == item.id {
                movie?.position = moviePosition
            }
            if let moviePosition {
                watchHistory.update(id: item.id, position: moviePosition, runtime: movieRuntime)
            }
        case .music:
            break
        case .reader:
            // Музыку поставили на паузу прямо в читалке — бар больше не за ней,
            // и последним потреблённым становится книга. Играет — бар остаётся
            // за музыкой (см. `resumeBook`).
            if !isMusicPlaying, book != nil { mode = .book }
        case nil:
            break
        }
        contentPlayer = nil
    }

    /// Слой плеера сняли не кнопкой (например, вместе с презентацией под ним).
    /// Состояние обязано догнать экран, иначе следующий тап не откроет ничего:
    /// презентер считал бы, что плеер уже показан.
    func contentPlayerDidDisappear(id: ContentPlayer.ID) {
        guard contentPlayer?.id == id else { return }
        closeContentPlayer()
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
            syncAudio()
            audio { $0.seek(to: 0.42) }
        case "movie":
            resumeMovie(Self.debugMovie)
        case "book":
            // Книга музыку больше не глушит, а играющая музыка держит бар за собой —
            // но пресет обязан начаться с чипа книги, что бы ни лежало в снимке на диске.
            stopMusic()
            resumeBook(Self.debugBook)
        default:
            break
        }
        if UserDefaults.standard.bool(forKey: "debugFullPlayerNow"), music != nil {
            contentPlayer = .music
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
