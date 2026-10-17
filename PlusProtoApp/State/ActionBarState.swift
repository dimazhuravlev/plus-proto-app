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
        return rawProgress(at: now).truncatingRemainder(dividingBy: 1)
    }

    /// Ход без заворота: больше или равно 1 — трек дошёл до конца (мок-ход без звука).
    func rawProgress(at now: Date) -> Double {
        guard isAdvancing else { return anchor }
        return anchor + max(0, now.timeIntervalSince(date)) / ActionBarState.musicDuration
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
    /// Откуда трек: `"album:dz-123"`, `"playlist:dz-456"`. Заполняют экраны альбома
    /// и плейлиста; по нему кнопка «Слушать/Пауза» узнаёт свой трек в баре, не дожидаясь
    /// загрузки треклиста и не завися от режима бара. `nil` у треков из других мест
    /// и у записей на диске, сделанных до поля: для них экран узнаёт свой трек по
    /// префиксу id (`dz-<альбом>-t<трек>`).
    var containerID: String? = nil
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
    /// Вертикальный постер — лицо карточки «Продолжить» в промо «Главной» (задача 69).
    /// Заполняют входы, которые его знают (экран тайтла, промо Кинопоиска); у остальных
    /// и у старых записей его нет — карточка тогда из кадра.
    var poster: ArtworkSource? = nil
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
        // Посев «Продолжить» — до режима бара: `-debugActionBar` перекрывает чип книги.
        applyDebugSeedContinueIfNeeded()
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
    private(set) var book: BookInProgress? {
        didSet {
            persist()
            if book?.cover != oldValue?.cover { resolveBookCoverAspect() }
        }
    }

    /// Пропорции обложки книги в баре — по ним чип меняет ширину, как все книги приложения
    /// (правка пользователя 2026-10-16). Из кэша — сразу; нет — догружается, и бар доезжает
    /// своим морфом. `nil` — пропорций нет (ещё едет или картинки нет): макетная ширина.
    private(set) var bookCoverAspect: CGFloat?
    @ObservationIgnored private var bookAspectTask: Task<Void, Never>?

    private func resolveBookCoverAspect() {
        bookAspectTask?.cancel()
        guard let cover = book?.cover else {
            bookCoverAspect = nil
            return
        }
        if Thread.isMainThread, let cached = MainActor.assumeIsolated({ BookCoverAspect.cached(of: cover) }) {
            bookCoverAspect = cached
            return
        }
        bookAspectTask = Task { @MainActor [weak self] in
            let aspect = await BookCoverAspect.load(of: cover)
            guard !Task.isCancelled, let self, self.book?.cover == cover else { return }
            withAnimation(ActionBarMotion.morph) { self.bookCoverAspect = aspect }
        }
    }

    /// «Смотреть дальше» главной Кинопоиска — всё, что запускали в киноплеере.
    /// Живёт здесь, потому что вход в плеер один — `watch` (2026-10-04).
    let watchHistory = WatchHistory()
    /// Ряд «продолженного потребления» «Главной» (задача 71) — пишется отсюда же,
    /// из единого входа плееров (`open`).
    let recently = RecentlyConsumed()

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
    private(set) var contentPlayer: ContentPlayer? {
        didSet {
            // Сменилась или закрылась сама читалка — слой музыки над ней уходит вместе с ней.
            if contentPlayer?.id != oldValue?.id { isMusicOverReader = false }
        }
    }

    /// Большой плеер музыки открыт поверх читалки. Слотов `contentPlayer` один, и музыка
    /// не должна его занимать: презентер тогда снял бы читалку, и после закрытия плеера
    /// пользователь оказался бы в приложении, а не в книге. Поэтому поверх читалки —
    /// второй слой флагом, а не стек: слоёв ровно два и только в этом сочетании.
    /// Закрывается только он; читалка под ним живёт.
    private(set) var isMusicOverReader = false

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
    ///
    /// Круг — **только** от активации поиска (правка пользователя 2026-10-10): `didSet`
    /// срабатывает и на снятии фокуса, и на повторной записи того же значения, а `false`
    /// пишут отовсюду (выход из поиска, затемнение, уход в карточку, тост «Моё»), —
    /// и развёрнутая пилюля схлопывалась без всякого поиска. Поэтому повышаем режим
    /// только на переходе «нет фокуса → есть фокус».
    var isSearchFocused: Bool = false {
        didSet {
            guard isSearchFocused, !oldValue else { return }
            promoteSearchIfCompact()
        }
    }

    /// Повышает режим до `.search`, если поиск сейчас круг.
    ///
    /// Зовётся только на получении фокуса (правка пользователя 2026-10-10: круг —
    /// только по активации поиска). Музыка, начавшаяся **пока поиск открыт**, пилюлю
    /// не схлопывает: активации поиска не было.
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

    /// Очередь треков: список, из которого запустили трек (альбом, плейлист, коллекция,
    /// выдача). Конец превью переключает на следующий, в конце — снова первый. Запустили
    /// без списка, но альбом трека известен — очередь из его треклиста
    /// (`fillQueueFromAlbum`); нет и альбома — трек повторяется. Пишется в снимок бара:
    /// после холодного старта очередь та же (правка пользователя 2026-10-16: «по
    /// завершении трек не переключается на следующий»).
    private(set) var queue: [MusicNowPlaying] = []
    /// Позиция играющего трека в очереди — числом, а не по id: в плейлисте один
    /// трек бывает дважды.
    private(set) var queueIndex = 0
    /// Следующий трек «Моей волны», выбранный при старте текущего: звук успевает
    /// найти его превью заранее, и «Дальше» играет тот же трек.
    @ObservationIgnored private var vibeNext: MusicNowPlaying?
    /// Сборка очереди из альбома трека — одна на трек.
    @ObservationIgnored private var albumQueueTask: Task<Void, Never>?

    /// Мини-плеер на экране: круг (`.search`) или капсула (`.music`) с играющим треком.
    var isMiniPlayerVisible: Bool {
        Self.showsMiniPlayer(mode: mode, hasMusic: music != nil)
    }

    /// Один предикат на состояние и на раскладку бара (`ActionBarLayout`): мини-плеер
    /// есть только в режимах музыки и поиска, и только пока есть трек.
    static func showsMiniPlayer(mode: ActionBarMode, hasMusic: Bool) -> Bool {
        hasMusic && (mode == .music || mode == .search)
    }

    /// Играет ли в мини-плеере трек этого альбома или плейлиста (`kind` — `"album"`
    /// или `"playlist"`). Кнопка «Слушать/Пауза» экрана зависит только от этого: ни от
    /// режима бара (после поиска он остаётся кругом `.search`, а не `.music`), ни от
    /// загруженного треклиста (с первого кадра экрана, пока детали едут). Режимы
    /// `.book` и `.movie` не в счёт: бар за чипом, мини-плеера нет.
    func isPlayingMusic(from entityID: String, kind: String) -> Bool {
        guard isMiniPlayerVisible, isMusicPlaying, let music else { return false }
        return music.containerID == "\(kind):\(entityID)"
            || music.id == entityID
            || music.id.hasPrefix(entityID + "-t")
    }

    /// Что играет дальше: хвост очереди после текущего, по кругу, без самого текущего.
    /// Пусто — очереди нет (одиночный запуск, «Моя волна»): «Что дальше» не показываем.
    var upcoming: [MusicNowPlaying] {
        guard queue.count > 1, queue.indices.contains(queueIndex) else { return [] }
        return (1..<queue.count).prefix(Self.upcomingLimit).map { queue[(queueIndex + $0) % queue.count] }
    }

    private static let upcomingLimit = 20

    /// Запуск трека пользователем: мини-плеер разворачивается в капсулу.
    /// `list` — откуда запустили (пустой — очереди нет), `index` — позиция трека
    /// в списке, если вызывающий её знает (дубли id в плейлисте).
    func startMusic(_ item: MusicNowPlaying, queue list: [MusicNowPlaying] = [], at index: Int? = nil) {
        queue = list
        if let index, list.indices.contains(index), list[index].id == item.id {
            queueIndex = index
        } else {
            queueIndex = list.firstIndex { $0.id == item.id } ?? 0
        }
        switchTrack(item)
        mode = .music
    }

    /// Смена трека без смены режима: авто-переход на конце превью не должен
    /// разворачивать круг в капсулу.
    private func switchTrack(_ item: MusicNowPlaying) {
        music = item
        musicProgress = 0
        isMusicAdvancing = false
        isMusicPlaying = true
        vibeNext = nil
        startProgressTicking()
        // Тот же трек ещё раз — тоже с начала.
        audio { audio in
            audio.play(item, from: 0, isPlaying: true)
            audio.seek(to: 0)
        }
        // Следующему треку превью ищем заранее: между треками без дыры.
        if let next = nextTrack() {
            Task { @MainActor in await MusicAudio.shared.prefetch(next.item) }
        }
        fillQueueFromAlbum(item)
    }

    /// Трек запущен без очереди (экран исполнителя, плитка трека, колдунщик поиска,
    /// старый снимок), но из альбома: id `dz-<альбом>-t<трек>` — очередь из треклиста
    /// этого альбома, с позиции трека. Тем же загрузчиком, что экран альбома (Deezer,
    /// без квоты, общий кэш), и тем же видом треков — пилюля экрана альбома их узнает.
    private func fillQueueFromAlbum(_ item: MusicNowPlaying) {
        albumQueueTask?.cancel()
        guard queue.isEmpty, !MyVibeTracks.isVibe(item.id),
              let albumID = Self.albumEntityID(of: item) else { return }
        albumQueueTask = Task { @MainActor [weak self] in
            let ref = EntityRef(id: albumID, title: item.album ?? "", subtitle: item.artist, artwork: item.cover)
            let store = AlbumDetailsStore(entity: ref)
            await store.load(ref)
            guard !Task.isCancelled, let self, let details = store.details,
                  self.queue.isEmpty, self.music?.id == item.id else { return }
            let list = details.allTracks.map { details.nowPlaying($0, albumID: albumID, cover: item.cover) }
            guard list.count > 1, let index = list.firstIndex(where: { $0.id == item.id }) else { return }
            self.queue = list
            self.queueIndex = index
            self.persist()
            if let next = self.nextTrack() {
                await MusicAudio.shared.prefetch(next.item)
            }
        }
    }

    /// Альбом трека: `album:<id>` источника или `<id>` из `dz-<альбом>-t<трек>`.
    private static func albumEntityID(of item: MusicNowPlaying) -> String? {
        if let container = item.containerID, container.hasPrefix("album:") {
            return String(container.dropFirst("album:".count))
        }
        guard let match = item.id.firstMatch(of: #/^(dz-\d+)-t\d+$/#) else { return nil }
        return String(match.1)
    }

    /// Что играет после текущего: «Моя волна» — случайный трек волны (выбранный один
    /// раз на трек), очередь — следующий по кругу, иначе `nil` (одиночный запуск).
    private func nextTrack() -> (item: MusicNowPlaying, index: Int)? {
        if let music, MyVibeTracks.isVibe(music.id) {
            let next = vibeNext ?? MyVibeTracks.random(excluding: music.id)
            vibeNext = next
            return (next, queueIndex)
        }
        guard queue.count > 1, queue.indices.contains(queueIndex) else { return nil }
        let index = (queueIndex + 1) % queue.count
        return (queue[index], index)
    }

    /// Конец превью решает очередь этого бара: звук только сообщает, что трек доиграл.
    /// Подключает корень (`AppRootView.onAppear`), а не `init`: начальное значение `@State`
    /// корня пересоздаётся на каждой его инициализации, и лишний экземпляр перезаписывал
    /// обработчик собой и умирал — конец превью уходил в пустоту, трек вставал в конце,
    /// очередь не шла (жалоба пользователя 2026-10-17; замер — два `init` за запуск).
    func attachAudio() {
        audio { [weak self] audio in
            audio.onTrackEnd = { self?.musicTrackDidEnd() }
        }
    }

    /// Превью доиграло (от звука или от мок-хода часов): следующий трек очереди,
    /// а очереди нет — тот же трек с начала.
    func musicTrackDidEnd() {
        guard isMusicPlaying else { return }
        if let next = nextTrack() {
            queueIndex = next.index
            switchTrack(next.item)
        } else {
            restartTrack()
            audio { $0.setPlaying(true) }
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
        /// Очередь и позиция в ней. Опциональны: снимок, записанный до них, читается как есть.
        var queue: [MusicNowPlaying]?
        var queueIndex: Int?
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
            isMusicPlaying: isMusicPlaying,
            queue: queue.isEmpty ? nil : queue,
            queueIndex: queue.isEmpty ? nil : queueIndex
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
        // Старый снимок с «треком» «Моя Волна» (id `my-vibe`) — такого трека нет:
        // вместо него настоящий трек волны (правка пользователя 2026-10-09).
        music = snapshot.music?.id == "my-vibe" ? MyVibeTracks.random() : snapshot.music
        movie = snapshot.movie
        book = snapshot.book
        // Очередь — только если трек в ней на своём месте; иначе (старый снимок) — из альбома.
        if let music, let list = snapshot.queue, let index = snapshot.queueIndex,
           list.indices.contains(index), list[index].id == music.id {
            queue = list
            queueIndex = index
        } else if let music {
            fillQueueFromAlbum(music)
        }
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
                    // Мок-ход дошёл до конца — как конец превью: следующий трек очереди.
                    if self.musicClock.rawProgress(at: .now) >= 1 {
                        await MainActor.run { self.musicTrackDidEnd() }
                        continue
                    }
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
    func open(_ target: ShowcasePlayerTarget, queue list: [MusicNowPlaying] = [], at index: Int? = nil) {
        switch target {
        case .music(let item):
            if music?.id == item.id, isMiniPlayerVisible {
                // Через тот же метод, что и кнопка: иначе тикер прогресса
                // остался бы работать на паузе.
                toggleMusicPlayback()
            } else {
                startMusic(item, queue: list, at: index)
                // Волна — поток с закреплённой плиткой в начале ряда, в ряд не пишется.
                if !MyVibeTracks.isVibe(item.id) { recently.record(.music(item)) }
            }
        case .movie(let item):
            watch(item)
            // В ряд — под выехавшим плеером, вместе с баром (`applyPendingResume`).
            pendingRecent = .movie(item)
        case .book(let item):
            read(item)
            pendingRecent = .book(item)
        }
    }

    // MARK: - Плеер музыки

    /// Открыть полноэкранный плеер музыки — тап по широкой пилюле мини-плеера.
    func openMusicPlayer() {
        guard music != nil else { return }
        if case .reader = contentPlayer {
            isMusicOverReader = true
        } else {
            contentPlayer = .music
        }
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

    /// «Дальше» и дизлайк: следующий трек очереди; следующего нет — этот с начала.
    /// Режим не трогаем: полноэкранный плеер открыт, бар под ним остаётся как был.
    func skipToNext() {
        if let next = nextTrack() {
            queueIndex = next.index
            switchTrack(next.item)
        } else {
            restartTrack()
        }
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
    /// Запуск из `open` для ряда «продолженного»: фильм и книга встают в его начало
    /// под плеером, а не переставляют ряд на глазах, пока плеер едет снизу.
    @ObservationIgnored private var pendingRecent: RecentItem?
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
        if let recent = pendingRecent {
            pendingRecent = nil
            recently.record(recent)
        }
        guard let pending = pendingResume else { return }
        pendingResume = nil
        switch pending {
        case .movie(let item):
            watchHistory.record(item)
            // Постер для «Продолжить» промо — под выехавшим плеером, если запуск пришёл
            // без него (ПП, «Смотреть дальше», чип бара).
            Task { await watchHistory.backfillContinuingPoster() }
            resumeMovie(item)
        case .book(let item):
            resumeBook(item)
        }
    }

    /// Закрыть всё, что играет поверх экрана: музыку над читалкой и саму читалку/киноплеер.
    /// Нужен тапу по тосту. Сброс флага до закрытия — иначе `closeContentPlayer` снял бы
    /// только верхний слой (музыку) и остановился.
    func closeAllPlayers() {
        isMusicOverReader = false
        closeContentPlayer()
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
        // Плеер музыки над читалкой: закрывается только верхний слой.
        if isMusicOverReader {
            isMusicOverReader = false
            return
        }
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
        // Слой музыки над читалкой сняли жестом или системой — читалка остаётся.
        if id == "music", isMusicOverReader {
            isMusicOverReader = false
            return
        }
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
        title: "Бредовая работа"
    )

    /// Начатый фильм `-debugSeedContinue`: «Идеальные дни» (124 мин) на 35 %. Id — тот же,
    /// что у мок-фильма витрины: на `-debugMockFeed` промо прячет обычную карточку
    /// этого фильма, видно и само исключение.
    static let debugContinueMovie = MovieInProgress(
        id: "perfect-days",
        still: .asset("mockChipMovieStill"),
        title: "Идеальные дни",
        runtime: 7_440,
        position: 2_604,
        poster: .asset("mockMoviePoster")
    )

    /// `-debugSeedContinue 1` — начатые фильм и книга для карточек «Продолжить» промо
    /// «Главной» (задача 69). Тем же API, что настоящий запуск: фильм — в историю
    /// просмотра (`record`, как после выезда киноплеера), книга — последней открытой
    /// (`resumeBook`, как после выезда читалки: бар встаёт на её чип). Записи остаются
    /// на диске; историю стирает `-debugResetWatchHistory 1`.
    private func applyDebugSeedContinueIfNeeded() {
        guard UserDefaults.standard.bool(forKey: "debugSeedContinue") else { return }
        watchHistory.record(Self.debugContinueMovie)
        resumeBook(Self.debugBook)
    }

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
