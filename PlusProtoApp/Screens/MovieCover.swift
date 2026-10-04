import SwiftUI

// MARK: - Логотип тайтла

/// Геометрия логотипа из `figma-moviecard.md` §2.2 (секция «Логотипы» `3826:37555`).
enum MovieLogoLayout {
    /// Бокс логотипа в шапке: top 63 (высота статус-бара). Слева в макете 20,
    /// но у нас 16 (правка пользователя 2026-08-25) — в линию с правым полем
    /// кнопок шапки и общим полем экрана.
    static let leading: CGFloat = 16
    static let top: CGFloat = 63
    /// Квадратным лого считается при пропорции меньше 1.2 — тогда бокс 100×100.
    /// Оба бокса на 15 % крупнее макетных 88×88 и 188×64 (правка пользователя
    /// 2026-10-03, «немного увеличь логотип»).
    static let squareRatio: CGFloat = 1.2
    static let squareBox = CGSize(width: 100, height: 100)
    /// Длинное лого — 216×74
    static let longBox = CGSize(width: 216, height: 74)
}

/// Логотип тайтла в шапке карточки — PNG с альфой из Кинопоиска (`logo.url`).
///
/// Второй половины правила макета («лого нет — текстовое название») здесь нет
/// намеренно: у нас название в этом случае занимает слот лида, как было до логотипов.
/// Рисовать его ещё и в шапке значило бы показать название дважды.
///
/// Натуральный размер картинки нужен, чтобы выбрать бокс (квадратный или длинный),
/// поэтому логотип грузится напрямую через `ArtworkLoader`, а не через `ArtworkImage`:
/// тот отдаёт готовый `Image` и размеров не показывает. Читать размер отрисованной вью
/// нельзя — от него зависит её же раскладка (DECISIONS).
struct MovieTitleLogo: View {
    let url: URL
    let title: String

    @State private var image: Image?
    @State private var natural: CGSize?
    /// Тёмный PNG — рисуется белым силуэтом (`ArtworkLoader.isDarkLogo`).
    @State private var isDark = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Бокс держится распоркой, а не самой картинкой. Не украшательство: `.task`
        // на пустом теле не выполняется вовсе — вью, у которой нечего рисовать, SwiftUI
        // не создаёт, и логотип, ждущий загрузки внутри собственной задачи, не грузится
        // никогда. На этом уже потерян один заход.
        Color.clear
            .frame(width: box.width, height: box.height)
            .overlay(alignment: .bottomLeading) {
                // Пока логотип едет — пусто: подменять его чем-то, а через полсекунды
                // картинкой, значит дёргать шапку на каждом входе.
                if let image {
                    image
                        .renderingMode(isDark ? .template : .original)
                        .resizable()
                        .foregroundStyle(Color.fillOne)
                        .frame(width: drawn.width, height: drawn.height)
                        .accessibilityLabel(title)
                }
            }
            .task(id: url) { await load() }
    }

    /// Бокс по пропорции логотипа. До загрузки — длинный: почти все логотипы тайтлов
    /// это широкие начертания названия.
    private var box: CGSize {
        guard let natural, natural.height > 0 else { return MovieLogoLayout.longBox }
        let ratio = natural.width / natural.height
        return ratio < MovieLogoLayout.squareRatio ? MovieLogoLayout.squareBox : MovieLogoLayout.longBox
    }

    /// Размер самой картинки в боксе. Считаем сами, а не `scaledToFit`: тот оставляет
    /// вью размером с бокс, и картинка внутри него оказывается по центру — а в макете
    /// логотип прижат к низу бокса (VStack `justify=MAX`).
    private var drawn: CGSize {
        guard let natural, natural.width > 0, natural.height > 0 else { return box }
        let scale = min(box.width / natural.width, box.height / natural.height)
        return CGSize(width: natural.width * scale, height: natural.height * scale)
    }

    private func load() async {
        if let hit = ArtworkLoader.shared.cached(url) {
            isDark = ArtworkLoader.shared.isDarkLogo(url, image: hit)
            image = Image(uiImage: hit)
            natural = hit.size
            return
        }
        image = nil
        natural = nil
        guard let loaded = await ArtworkLoader.shared.image(for: url) else { return }
        isDark = ArtworkLoader.shared.isDarkLogo(url, image: loaded)
        // Приехавший по сети логотип проявляется, а не вставает резко; кэшированный
        // (ветка выше) показан с первого кадра — анимировать нечего. Тот же паттерн,
        // что у чистого кадра кавера (`loadClean`).
        withAnimation(reduceMotion ? nil : .easeOut(duration: MovieCoverMotion.logoFade)) {
            image = Image(uiImage: loaded)
            natural = loaded.size
        }
    }
}

// MARK: - Кавер с трейлером

/// Кавер карточки тайтла: неподвижный кадр, из которого ролик разворачивается **по тапу**
/// и по повторному тапу сворачивается обратно.
///
/// Само́ зацикливание — из макета (§5.4 «зацикливаем воспроизведение трейлера»),
/// а вот старт по тапу — нет: раньше ролик запускался сам, и верхний блок экрана
/// всё время шевелился, ничего об этом не спрашивая.
///
/// **Статичный кадр — `backdrop`, а не постер.** В Кинопоиске из трёх картинок тайтла
/// чистая ровно одна: `poster` (600×900) идёт с нанесённым названием, `logo` — это
/// само название и есть, а `backdrop` (1344×756) — кадр без надписей. Названию на кавере
/// не место дважды: логотип рисует шапка.
///
/// Настоящий трейлер Кинопоиска сюда не доезжает: API отдаёт не файл, а страницу своего
/// плеера, и подписанный поток внутри неё закрыт для сторонних клиентов (см.
/// `KinopoiskVideo`). Поэтому движущаяся картинка — забандленный клип, а из API живёт
/// имя ролика. Как только `trailer.stream` окажется непустым, играть будет он:
/// ветка одна, мёртвого кода нет.
struct MovieTrailerCover: View {
    /// Постер сущности — **только для моковых тайтлов**: у них чистого кадра не будет
    /// вовсе, и серый плейсхолдер стоял бы вечно. Живым тайтлам постер не показывается:
    /// раньше он стоял первым кадром и подменялся чистым кадром — шапка дёргалась
    /// сменой картинки (правка пользователя 2026-08-25).
    let poster: ArtworkSource?
    /// Чистый кадр тайтла — уже загруженный. Грузит его **экран**, а не кавер:
    /// тот же кадр стоит зеркалом под кавером, и обе картинки обязаны проявиться
    /// одной транзакцией (правка пользователя 2026-08-25). Пока `nil`, кадр держит
    /// тёмно-серый плейсхолдер `#141414` (фон макета скелетона `2097:13780`).
    let clean: Image?
    let trailer: MovieTrailer?

    @State private var playback = LoopingVideoPlayback()
    /// Пользователь включил ролик тапом. Единственный источник правды: и плеер,
    /// и видимость слоя, и возврат из фона смотрят сюда.
    @State private var isPlaying = false
    @State private var isVideoReady = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            // Неподвижный кадр и видео — **взаимоисключающие** слои: одновременно
            // в кадре они бывают только в те 0.4с, пока идёт кроссфейд.
            still
                .opacity(isVideoShown ? 0 : 1)

            fill {
                LoopingVideoLayer(player: playback.queue) { isVideoReady = true }
            }
            .opacity(isVideoShown ? 1 : 0)
            .allowsHitTesting(false)
        }
        .animation(fade(MovieCoverMotion.videoFadeIn), value: isVideoShown)
        // Кадр целиком — одна кнопка. `contentShape` обязателен: без него тап ловят
        // только непрозрачные пиксели, а слои здесь появляются и исчезают.
        .contentShape(Rectangle())
        .onTapGesture { isPlaying.toggle() }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(trailer?.name ?? "Трейлер")
        .accessibilityValue(isPlaying ? "Играет" : "Остановлен")
        // Ролик заряжается заранее, но не играет: к моменту тапа он уже разобран,
        // и проявление начинается сразу, а не после разбора файла.
        .task(id: trailer?.stream) { prepare() }
        #if DEBUG
        // `-debugTapCover` — тап по каверу и повторный тап: снять оба состояния
        // из шелла иначе нечем.
        .task {
            guard UserDefaults.standard.bool(forKey: "debugTapCover") else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            isPlaying = true
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            isPlaying = false
        }
        #endif
        .onChange(of: isPlaying) { _, playing in
            playing ? start() : playback.pause()
        }
        .onDisappear { playback.pause() }
        // Экран ушёл в фон — клип обязан встать, иначе он крутится вхолостую.
        // Вернулись: продолжаем только если пользователь его и включал.
        .onChange(of: scenePhase) { _, phase in
            guard isPlaying else { return }
            phase == .active ? start() : playback.pause()
        }
    }

    /// Видео действительно на экране: пользователь его включил **и** слой отдал кадр.
    /// Пока плеер не готов, гасить неподвижный кадр нельзя — получилась бы дыра.
    private var isVideoShown: Bool {
        isPlaying && isVideoReady
    }

    /// Неподвижный кадр: плейсхолдер (у моков — постер), а поверх — чистый кадр
    /// из API, когда доедет.
    private var still: some View {
        ZStack {
            MovieCoverPlaceholder.color

            if let poster {
                fill {
                    ArtworkImage(source: poster)
                        .scaledToFill()
                }
            }

            if let clean {
                fill {
                    clean
                        .resizable()
                        .scaledToFill()
                }
                .transition(.opacity)
            }
        }
    }

    /// Слой во весь кадр. Размер держит распорка, а картинка её заполняет.
    ///
    /// Без распорки слои разъезжаются, и это не теория: `scaledToFill` отдаёт наверх
    /// **свой** размер (для постера 2:3 это 402×603, для кадра 16:9 — 953×536), стек
    /// берёт объединение и раскладывает детей каждого по своему размеру. Замер
    /// тонировкой слоёв: постер занимал верхние 380pt кадра, кадр из API — оставшиеся
    /// 156, то есть в одном кавере одновременно висели две разные картинки.
    private func fill<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        Color.clear
            .overlay { content() }
            .clipped()
    }

    /// Проявление без анимации при «уменьшении движения». Само воспроизведение при
    /// этом не запрещено: раньше ролик стартовал сам и был фоновым движением — теперь
    /// он трогается только по тапу, а это уже осознанное действие пользователя.
    private func fade(_ duration: Double) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: duration)
    }

    private func prepare() {
        if let stream = trailer?.stream {
            playback.prepare(url: stream)
        } else {
            playback.prepare(bundled: ShowcaseSeeds.trailerClip)
        }
    }

    private func start() {
        if let stream = trailer?.stream {
            playback.start(url: stream)
        } else {
            playback.start(bundled: ShowcaseSeeds.trailerClip)
        }
    }

}

enum MovieCoverMotion {
    /// Проявление и уход видео по тапу
    static let videoFadeIn: Double = 0.4
    /// Проявление чистого кадра из API поверх серого плейсхолдера — 200мс
    /// (правка пользователя 2026-08-25, было 350 при подмене постера)
    static let cleanFade: Double = 0.2
    /// Проявление логотипа тайтла в шапке: раньше он вставал резко.
    /// Кэшированный логотип показывается сразу, без анимации, — как чистый кадр.
    static let logoFade: Double = 0.2
}

/// Плейсхолдер кадра, пока чистый кадр не доехал: серый скелетона — тот же, что
/// у всех скелетонов экрана (правка пользователя 2026-10-04: на экране тайтла были
/// разные серые). Прежний непрозрачный #141414 на чёрном фоне выглядел так же,
/// но был отдельным цветом.
enum MovieCoverPlaceholder {
    static let color = PlusSkeleton.fill
}
