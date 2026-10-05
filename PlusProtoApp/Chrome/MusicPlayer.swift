import SwiftUI
import UIKit

// MARK: - Геометрия

/// Числа макетов `6105:61569` (играет) и `6105:61328` (пауза). Холст макета — 375,
/// у проекта 402: поля 24 остаются, обложка и колонка становятся шире.
private enum MusicPlayerLayout {
    static let sideInset: CGFloat = 24
    /// Строка навбара под статус-баром.
    static let barHeight: CGFloat = 44
    static let barSide: CGFloat = 16
    static let barIcon: CGFloat = 24
    /// «Сейчас играет» ↔ название альбома.
    static let barCaptionGap: CGFloat = 2
    /// От навбара до обложки.
    static let coverTop: CGFloat = 12
    /// Обложка: скругление 18, хайрлайн и мягкая тень, как в макете.
    static let coverCorner: CGFloat = 18
    static let coverShadowRadius: CGFloat = 8
    static let coverShadowY: CGFloat = 4
    static let coverShadowOpacity: Double = 0.12
    /// На паузе обложка садится до 277 из 327, по бокам выглядывают соседние треки:
    /// квадраты 263 под ±3°, на 12pt от неё и на 13.78 ниже её центра.
    static let pausedScale: CGFloat = 277 / 327
    static let neighborScale: CGFloat = 263.15 / 277
    static let neighborGap: CGFloat = 12
    static let neighborDrop: CGFloat = 13.78 / 327
    static let neighborTilt: Double = 3

    static let coverToTitle: CGFloat = 24
    /// Бейдж 18+ у названия (`6105:61346`).
    static let titleBadge: CGFloat = 20
    static let titleBadgeGap: CGFloat = 8
    /// От строки названия до ряда артиста. Меряем по макету паузы от базовой линии:
    /// до верха аватара 9pt. В макете их дают зазор 2 и 6.9pt под базовой линией
    /// Headline L En (32/32, другой шрифт); у нашего L 28/28 под ней 4.4 — остаётся 4.5
    /// (жалоба пользователя 2026-10-03: при 2 аватар подпирал название).
    static let titleToArtist: CGFloat = 4.5
    static let artistRowHeight: CGFloat = 40
    static let avatar: CGFloat = 40
    static let avatarToText: CGFloat = 8
    /// Вторая строка лейбла заходит на первую на 2pt (`mb-[-2px]` в макете).
    static let textStackGap: CGFloat = -2
    /// Длинное имя артиста не обрывается многоточием, а гаснет на этой ширине.
    static let artistFade: CGFloat = 32
    static let rowButton: CGFloat = 40
    static let rowButtonIcon: CGFloat = 20
    static let rowButtonGap: CGFloat = 6
    static let artistToTimeline: CGFloat = 24
    /// Таймлайн: подписи 27 по краям, зазор 6, дорожка 6.
    static let timeLabelWidth: CGFloat = 27
    static let timeLabelGap: CGFloat = 6
    static let trackHeight: CGFloat = 6
    /// Хит-зона дорожки — 44 по высоте при видимых 6.
    static let trackHitOutset: CGFloat = 19
    static let timelineHeight: CGFloat = 16
    static let timelineToControls: CGFloat = 16
    /// Ряд транспорта: кнопки 64, иконки 24 по краям и 32 в середине, зазор 12.
    static let controlsPadding: CGFloat = 12
    static let control: CGFloat = 64
    static let controlIconSmall: CGFloat = 24
    static let controlIconLarge: CGFloat = 32
    static let playbackGap: CGFloat = 12
    static let controlsToQueue: CGFloat = 8
    /// Очередь: шапка (16 сверху, 12 снизу), строки по 64.
    static let queueSide: CGFloat = 16
    static let queueHeaderTop: CGFloat = 16
    static let queueHeaderBottom: CGFloat = 12
    static let queueChevron: CGFloat = 20
    static let queueChevronGap: CGFloat = 2
    /// Повтор и перемешивание висят поверх шапки на 15 от её верха (`6200:280427`).
    static let queueTogglesTop: CGFloat = 15
    static let queueToggleGap: CGFloat = 12
    static let queueToggleIcon: CGFloat = 24
    static let activeDot: CGFloat = 4
    static let rowVertical: CGFloat = 8
    static let rowCover: CGFloat = 48
    static let rowCoverCorner: CGFloat = 6
    static let rowCoverToText: CGFloat = 12
    static let rowBadge: CGFloat = 16
    static let rowBadgeGap: CGFloat = 6
    static let rowTrailingGap: CGFloat = 12
    /// Пустой слот значков строки — 44×20, как в макете; со значком он по его ширине.
    static let rowStatusWidth: CGFloat = 44
    static let rowStatusHeight: CGFloat = 20
    static let queueBottom: CGFloat = 56
    /// Фон — та же обложка 852×852 под блюром 80, со светлой и тёмной вуалью.
    static let backdropSize: CGFloat = 852
    static let backdropBlur: CGFloat = 80
    static let backdropLight = Color.white.opacity(0.03)
    static let backdropDark = Color.black.opacity(0.3)
    /// Подложка навбара проявляется, когда контент начинает уезжать под него.
    static let barBackdropStart: CGFloat = 8
    static let barBackdropRamp: CGFloat = 60
}

// MARK: - Движение

enum MusicPlayerMotion {
    /// Пауза и воспроизведение: обложка садится и встаёт, соседи въезжают и уходят.
    /// Пружина с лёгким отскоком — обложка живая, это её главное движение в плеере.
    static let pauseSpring: Animation = .spring(duration: 0.5, bounce: 0.2)
    /// То же с «уменьшением движения»: без отскока и короче.
    static let pauseReduced: Animation = .easeOut(duration: 0.2)
    /// Дорожка под пальцем: +4 к высоте и к ширине (просьба пользователя 2026-10-03 —
    /// как у киноплеера, только сдвиги меньше).
    static let trackGrow: CGFloat = 4
    static let trackGrab: Animation = .smooth(duration: 0.25)
    /// Заливка между тиками прогресса — та же, что у мини-плеера в баре.
    static let progressStep: Animation = .easeOut(duration: 0.12)
    /// Трещотка перемотки: дорожка короче, чем у киноплеера, — шаг мельче.
    static let scrubTickStep: CGFloat = 4
    static let scrubTickInterval: TimeInterval = 1.0 / 30
    static let scrubTickIntensity: CGFloat = 0.5
    /// Бегущая строка длинного названия: пауза в начале круга, скорость, зазор копий.
    static let marqueePause: TimeInterval = 2.5
    static let marqueeSpeed: CGFloat = 30
    static let marqueeGap: CGFloat = 48
    /// Края бегущей строки — маски макета: у кромки 10pt пусто, к 75pt строка видна целиком.
    static let marqueeEdgeClear: CGFloat = 10
    static let marqueeFadeEnd: CGFloat = 75
    /// За столько пунктов хода проявляется левое затухание: в покое начало названия
    /// стоит у поля целиком, гаснуть ему незачем.
    static let marqueeFadeRamp: CGFloat = 24
}

// MARK: - Плеер

/// Полноэкранный плеер музыки — макеты `6105:61569` (играет) и `6105:61328` (пауза).
///
/// Показывается тем же презентером, что киноплеер и читалка: выезжает снизу и уезжает
/// вниз, без прозрачности и масштаба (правка пользователя 2026-10-03; раньше лист
/// формился из мини-плеера). Свайп вниз от верха ленты уводит весь экран за пальцем —
/// это живёт в презентере (`PullToDismiss`), а не здесь. Экран прокручивается
/// целиком — обложка, транспорт, очередь; навбар стоит, а под ним при прокрутке
/// проявляется общая подложка с прогрессивным блюром (`NavBarBackdrop`).
struct MusicPlayerView: View {
    @Environment(ActionBarState.self) private var actionBar
    @State private var scrollOffset: CGFloat = 0
    @State private var ratchet = ScrubRatchet(
        step: MusicPlayerMotion.scrubTickStep,
        interval: MusicPlayerMotion.scrubTickInterval,
        intensity: MusicPlayerMotion.scrubTickIntensity
    )
    /// Палец на дорожке. `GestureState`, а не флаг из `onEnded`: жест может оборваться
    /// без конца (уход в фон, шторка), `onEnded` тогда не зовётся — и тикер прогресса
    /// так и стоял бы, считая, что позицию держит палец.
    @GestureState private var isScrubGestureActive = false
    /// Повтор и перемешивание — состояние макета: у мок-очереди его некуда применить.
    @State private var isRepeating = false
    @State private var isShuffling = true

    /// Год под артистом нужен всегда (правка пользователя 2026-10-03), а знает его только
    /// экран альбома — у треков очереди и витрины года нет. Мок — год из примера пользователя.
    private static let fallbackYear = "2005"

    /// Альбом под «Сейчас играет» — тоже всегда. Без альбома трек считаем синглом:
    /// у витринной карточки альбома название трека и есть название альбома.
    private static func albumTitle(_ music: MusicNowPlaying) -> String {
        music.album ?? music.title
    }

    var body: some View {
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            ZStack(alignment: .top) {
                ScrollView {
                    if let music = actionBar.music {
                        content(music, width: proxy.size.width, safeTop: safeTop, safeBottom: proxy.safeAreaInsets.bottom)
                    }
                }
                .scrollIndicators(.hidden)
                .trackNavBarScroll(into: $scrollOffset)

                navBar
                    .padding(.top, safeTop)
            }
            .ignoresSafeArea()
        }
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: Навбар

    private var navBar: some View {
        ZStack {
            HStack(spacing: 0) {
                barButton(icon: "iconChevronDown", title: "Свернуть") {
                    actionBar.closeContentPlayer()
                }
                Spacer(minLength: 0)
                barButton(icon: "iconCastMusic", title: "Слушать на другом устройстве") {}
            }
            VStack(spacing: 0) {
                Text("Сейчас играет")
                    .plusText(.textS, .medium)
                    .padding(.bottom, MusicPlayerLayout.barCaptionGap)
                if let music = actionBar.music {
                    // 15 Semibold — исключение правил UI kit для хедера навбара.
                    Text("Альбом «\(Self.albumTitle(music))»")
                        .plusText(.textM, .semibold)
                }
            }
            .foregroundStyle(Color.fillSubtitle)
            .lineLimit(1)
            .padding(.horizontal, MusicPlayerLayout.barSide * 2 + MusicPlayerLayout.barIcon)
            .allowsHitTesting(false)
        }
        .padding(.horizontal, MusicPlayerLayout.barSide)
        .frame(height: MusicPlayerLayout.barHeight)
        .frame(maxWidth: .infinity)
        // Подложка — общая с навбаром экранов сущностей: блюр под элементами бара,
        // размывает только уехавший под него контент.
        .background(alignment: .bottom) {
            NavBarBackdrop()
                .opacity(NavBarRamp.progress(
                    scrollOffset,
                    start: MusicPlayerLayout.barBackdropStart,
                    length: MusicPlayerLayout.barBackdropRamp
                ))
        }
    }

    private func barButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button {
            PlayerHaptics.tap()
            action()
        } label: {
            MovieIcon(name: icon, box: MusicPlayerLayout.barIcon)
                // Хит-зона шире глифа, раскладка — нет: тот же приём, что у play в мини-плеере.
                .padding(10)
                .contentShape(.rect)
                .padding(-10)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(title)
    }

    // MARK: Содержимое

    private func content(_ music: MusicNowPlaying, width: CGFloat, safeTop: CGFloat, safeBottom: CGFloat) -> some View {
        let column = width - 2 * MusicPlayerLayout.sideInset
        return VStack(spacing: 0) {
            CoverCarousel(
                cover: music.cover,
                previous: MusicQueue.previousCover,
                next: MusicQueue.upcoming(after: music.id).first?.cover,
                isPlaying: actionBar.isMusicPlaying,
                side: column,
                screenWidth: width
            )
            .padding(.top, safeTop + MusicPlayerLayout.barHeight + MusicPlayerLayout.coverTop)

            MarqueeTitle(
                text: music.title,
                isExplicit: music.isExplicit == true,
                column: column,
                screenWidth: width
            )
            .padding(.top, MusicPlayerLayout.coverToTitle)

            artistRow(music)
                .padding(.top, MusicPlayerLayout.titleToArtist)
                .padding(.horizontal, MusicPlayerLayout.sideInset)

            timeline(width: column)
                .padding(.top, MusicPlayerLayout.artistToTimeline)

            controls
                .padding(.top, MusicPlayerLayout.timelineToControls)

            queue(after: music.id)
                .padding(.top, MusicPlayerLayout.controlsToQueue)
                .padding(.bottom, MusicPlayerLayout.queueBottom + safeBottom)
        }
        .frame(width: width)
        .background(alignment: .top) { backdrop(music.cover) }
    }

    /// Фон экрана — обложка под блюром во всю ширину, уезжает вместе с контентом.
    /// Запекается в растр (`drawingGroup`): блюр 80 по картинке 852pt на каждом кадре
    /// прокрутки — лишняя работа, а меняется фон только со сменой трека.
    private func backdrop(_ cover: ArtworkSource) -> some View {
        let spill = MusicPlayerLayout.backdropBlur * 2
        return ZStack(alignment: .top) {
            ArtworkImage(source: cover)
                .scaledToFill()
                .frame(width: MusicPlayerLayout.backdropSize, height: MusicPlayerLayout.backdropSize)
                .clipped()
                // Прозрачное поле под размытие: растр режется по кадру, и без поля
                // блюр обрывался бы ступенькой на нижней кромке картинки, а не гас в чёрный.
                .padding(spill)
                .blur(radius: MusicPlayerLayout.backdropBlur)
                .drawingGroup()
                .padding(-spill)
                .frame(maxWidth: .infinity)
            MusicPlayerLayout.backdropLight
            MusicPlayerLayout.backdropDark
        }
        .allowsHitTesting(false)
    }

    // MARK: Артист

    private func artistRow(_ music: MusicNowPlaying) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: MusicPlayerLayout.avatarToText) {
                avatar(music.artistPicture ?? music.cover)
                VStack(alignment: .leading, spacing: MusicPlayerLayout.textStackGap) {
                    FadingLine(text: music.artist, fade: MusicPlayerLayout.artistFade)
                    Text(music.year ?? Self.fallbackYear)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillSubtitle)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: MusicPlayerLayout.rowButtonGap)
            HStack(spacing: MusicPlayerLayout.rowButtonGap) {
                rowButton(icon: "iconRead", title: "Текст песни")
                rowButton(icon: "iconMore", title: "Ещё")
            }
        }
        .frame(height: MusicPlayerLayout.artistRowHeight)
    }

    private func avatar(_ source: ArtworkSource) -> some View {
        Color.clear
            .frame(width: MusicPlayerLayout.avatar, height: MusicPlayerLayout.avatar)
            .overlay { ArtworkImage(source: source).scaledToFill() }
            .clipShape(Circle())
            .coverBorder(Circle())
    }

    /// Кнопка 40 на подложке Buttons/Secondary — со стеклом и бордером серых кнопок
    /// (правка пользователя 2026-10-04; в макете их не было). Текст песни и меню трека
    /// в прототипе не спроектированы — кнопки только откликаются.
    private func rowButton(icon: String, title: String) -> some View {
        Button(action: PlayerHaptics.tap) {
            MovieIcon(name: icon, box: MusicPlayerLayout.rowButtonIcon)
                .frame(width: MusicPlayerLayout.rowButton, height: MusicPlayerLayout.rowButton)
                .secondaryButtonSurface(Circle(), fill: .buttonsSecondary)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(title)
    }

    // MARK: Таймлайн

    private func timeline(width: CGFloat) -> some View {
        let duration = ActionBarState.musicDuration
        let elapsed = actionBar.musicProgress * duration
        let trackWidth = width - 2 * (MusicPlayerLayout.timeLabelWidth + MusicPlayerLayout.timeLabelGap)
        return HStack(spacing: MusicPlayerLayout.timeLabelGap) {
            timecode(elapsed, alignment: .leading)
            track(width: trackWidth)
            // Справа — сколько осталось, без минуса, как в макете.
            timecode(duration - elapsed, alignment: .trailing)
        }
        .frame(width: width, height: MusicPlayerLayout.timelineHeight)
    }

    private func timecode(_ seconds: TimeInterval, alignment: Alignment) -> some View {
        Text(MovieTimecode.text(seconds))
            .plusText(.textS, .medium)
            .monospacedDigit()
            .foregroundStyle(Color.fillSubtitle)
            .fixedSize()
            .frame(minWidth: MusicPlayerLayout.timeLabelWidth, alignment: alignment)
    }

    private func track(width: CGFloat) -> some View {
        let grabbed = actionBar.isMusicScrubbing
        let grow = grabbed ? MusicPlayerMotion.trackGrow : 0
        let height = MusicPlayerLayout.trackHeight + grow
        let fullWidth = width + grow
        let shape = Capsule(style: .continuous)
        let progress = actionBar.musicProgress
        // Слот раскладки — исходные 6pt: подписи времени по бокам не двигаются,
        // дорожка растёт поверх зазоров.
        return Color.clear
            .frame(width: width, height: MusicPlayerLayout.trackHeight)
            .overlay {
                // Два цвета — подложка и белая позиция. Полосы догрузки из макета нет
                // (правка пользователя 2026-10-03): живого потока нет, и она только шумела.
                ZStack(alignment: .leading) {
                    shape.fill(Color.fillTen)
                    shape.fill(Color.fillOne)
                        .frame(width: max(height, fullWidth * progress))
                        .opacity(progress > 0 ? 1 : 0)
                        // Между тиками тикера заливку дотягивает анимация, как в мини-плеере.
                        // Под пальцем — без неё: позиция обязана стоять ровно под пальцем.
                        // Своя анимация только у заливки: повешенная на всю дорожку, она
                        // на хвате гасила бы и рост — хват и прыжок позиции в одном апдейте.
                        .animation(grabbed ? nil : MusicPlayerMotion.progressStep, value: progress)
                }
                .frame(width: fullWidth, height: height)
                .clipShape(shape)
                .animation(MusicPlayerMotion.trackGrab, value: grabbed)
            }
            .padding(.vertical, MusicPlayerLayout.trackHitOutset)
            .contentShape(.rect)
            .gesture(scrubGesture(width: width))
            .padding(.vertical, -MusicPlayerLayout.trackHitOutset)
            .onChange(of: isScrubGestureActive) { _, active in
                guard !active else { return }
                actionBar.isMusicScrubbing = false
                ratchet.end()
            }
            .accessibilityElement()
            .accessibilityLabel("Перемотка")
            .accessibilityValue(MovieTimecode.text(progress * ActionBarState.musicDuration))
    }

    /// Касание сразу ставит позицию под палец, протяжка ведёт её за пальцем.
    /// Палец меряется по выросшей дорожке — она шире слота на `trackGrow`.
    /// Отпускание — в `onChange` от `isScrubGestureActive`: он ловит и обрыв жеста.
    private func scrubGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isScrubGestureActive) { _, active, _ in active = true }
            .onChanged { value in
                let grow = MusicPlayerMotion.trackGrow
                let grown = width + grow
                let fraction = min(max(0, (value.location.x + grow / 2) / grown), 1)
                if !actionBar.isMusicScrubbing { actionBar.isMusicScrubbing = true }
                actionBar.seekMusic(to: fraction)
                ratchet.move(to: fraction * grown)
            }
    }

    // MARK: Транспорт

    private var controls: some View {
        HStack(spacing: 0) {
            controlButton(icon: "iconDislike", box: MusicPlayerLayout.controlIconSmall, title: "Не нравится") {
                actionBar.skipToNext()
            }
            HStack(spacing: MusicPlayerLayout.playbackGap) {
                controlButton(icon: "iconNext", box: MusicPlayerLayout.controlIconLarge, title: "С начала", mirrored: true) {
                    actionBar.restartTrack()
                }
                playPauseButton
                controlButton(icon: "iconNext", box: MusicPlayerLayout.controlIconLarge, title: "Дальше") {
                    actionBar.skipToNext()
                }
            }
            likeButton
        }
        .padding(.vertical, MusicPlayerLayout.controlsPadding)
    }

    /// «Назад» — отзеркаленный глиф «дальше»: зеркальные ассеты проект не плодит
    /// (приём шеврона секций).
    private func controlButton(
        icon: String,
        box: CGFloat,
        title: String,
        mirrored: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            PlayerHaptics.tap()
            action()
        } label: {
            MovieIcon(name: icon, box: box)
                .scaleEffect(x: mirrored ? -1 : 1)
                .frame(width: MusicPlayerLayout.control, height: MusicPlayerLayout.control)
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(title)
    }

    private var playPauseButton: some View {
        let isPlaying = actionBar.isMusicPlaying
        return Button {
            PlayerHaptics.tap()
            actionBar.toggleMusicPlayback()
        } label: {
            // Общая смена play/pause — та же, что у мини-плеера, киноплеера и карточек.
            PlayPauseGlyph(isPlaying: isPlaying, box: MusicPlayerLayout.controlIconLarge)
                .foregroundStyle(Color.fillOne)
                .frame(width: MusicPlayerLayout.control, height: MusicPlayerLayout.control)
                .secondaryButtonSurface(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(isPlaying ? "Пауза" : "Играть")
    }

    /// Сердце: контур — не нравится (макет паузы), залитое — нравится (макет воспроизведения).
    private var likeButton: some View {
        let isLiked = actionBar.isMusicLiked
        return Button {
            PlayerHaptics.tap()
            actionBar.toggleMusicLike()
        } label: {
            // Общий рисунок лайка (`LikeGlyph`) — тот же, что в мини-плеере и везде.
            LikeGlyph(isLiked: isLiked, box: MusicPlayerLayout.controlIconSmall)
                .frame(width: MusicPlayerLayout.control, height: MusicPlayerLayout.control)
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(isLiked ? "Убрать из любимых" : "Нравится")
    }

    // MARK: Очередь

    private func queue(after id: String) -> some View {
        VStack(spacing: 0) {
            queueHeader
            ForEach(MusicQueue.upcoming(after: id)) { item in
                QueueRow(item: item) {
                    PlayerHaptics.tap()
                    actionBar.startMusic(item.nowPlaying)
                }
            }
        }
    }

    private var queueHeader: some View {
        HStack(spacing: MusicPlayerLayout.queueChevronGap) {
            Text("Что дальше")
                .plusHeadline(.s)
                .foregroundStyle(Color.fillOne)
                .lineLimit(1)
            // Правый шеврон — отзеркаленный `icon / dropleft`, как у секций альбома.
            Image("iconDropleft")
                .renderingMode(.template)
                .resizable()
                .frame(width: MusicPlayerLayout.queueChevron, height: MusicPlayerLayout.queueChevron)
                .scaleEffect(x: -1)
                .foregroundStyle(Color.fillSubtitle)
                .offset(y: PlusMetrics.headerChevronDrop)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MusicPlayerLayout.queueSide)
        .padding(.top, MusicPlayerLayout.queueHeaderTop)
        .padding(.bottom, MusicPlayerLayout.queueHeaderBottom)
        // Переключатели — поверх шапки, как в макете: точка «включено» под глифом
        // не раздвигает шапку.
        .overlay(alignment: .topTrailing) {
            HStack(alignment: .top, spacing: MusicPlayerLayout.queueToggleGap) {
                queueToggle(icon: "iconRepeat", title: "Повтор", isOn: $isRepeating)
                queueToggle(icon: "iconShuffle", title: "Перемешать", isOn: $isShuffling)
            }
            .padding(.top, MusicPlayerLayout.queueTogglesTop)
            .padding(.trailing, MusicPlayerLayout.queueSide)
        }
    }

    /// Переключатель с точкой «включено» под глифом — точку рисует код, а не ассет.
    private func queueToggle(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        Button {
            PlayerHaptics.tap()
            isOn.wrappedValue.toggle()
        } label: {
            VStack(spacing: 0) {
                MovieIcon(name: icon, box: MusicPlayerLayout.queueToggleIcon)
                Circle()
                    .fill(Color.fillOne)
                    .frame(width: MusicPlayerLayout.activeDot, height: MusicPlayerLayout.activeDot)
                    .opacity(isOn.wrappedValue ? 1 : 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(title)
        .accessibilityValue(isOn.wrappedValue ? "Включено" : "Выключено")
    }
}

// MARK: - Обложка

/// Обложка с соседями. Играет — обложка во всю колонку, соседей не видно; пауза —
/// обложка садится, а по бокам под наклоном выглядывают предыдущий и следующий трек
/// (макет `6105:61328`). Всё — одной пружиной от `isPlaying`.
private struct CoverCarousel: View {
    let cover: ArtworkSource
    let previous: ArtworkSource
    let next: ArtworkSource?
    let isPlaying: Bool
    /// Сторона обложки на воспроизведении — ширина колонки.
    let side: CGFloat
    let screenWidth: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let current = isPlaying ? side : side * MusicPlayerLayout.pausedScale
        let neighbor = side * MusicPlayerLayout.pausedScale * MusicPlayerLayout.neighborScale
        let tilt = MusicPlayerLayout.neighborTilt * .pi / 180
        // Ширина повёрнутого соседа по осям — от неё отсчитывается зазор 12, как в макете.
        let neighborBox = neighbor * (cos(tilt) + sin(tilt))
        let shift = current / 2 + MusicPlayerLayout.neighborGap + neighborBox / 2
        let drop = side * MusicPlayerLayout.neighborDrop

        return ZStack {
            neighborCover(previous, size: neighbor)
                .rotationEffect(.degrees(-MusicPlayerLayout.neighborTilt))
                .offset(x: -shift, y: drop)
            if let next {
                neighborCover(next, size: neighbor)
                    .rotationEffect(.degrees(MusicPlayerLayout.neighborTilt))
                    .offset(x: shift, y: drop)
            }
            artwork(cover, size: current)
        }
        .frame(width: screenWidth, height: side)
        .animation(reduceMotion ? MusicPlayerMotion.pauseReduced : MusicPlayerMotion.pauseSpring, value: isPlaying)
    }

    /// Соседи видны только на паузе: на воспроизведении обложка во всю колонку,
    /// и их кромки у краёв экрана читались бы мусором.
    private func neighborCover(_ source: ArtworkSource, size: CGFloat) -> some View {
        artwork(source, size: size)
            .opacity(isPlaying ? 0 : 1)
    }

    private func artwork(_ source: ArtworkSource, size: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: MusicPlayerLayout.coverCorner, style: .continuous)
        return Color.clear
            .frame(width: size, height: size)
            .overlay { ArtworkImage(source: source).scaledToFill() }
            .clipShape(shape)
            .coverBorder(shape)
            .shadow(
                color: .black.opacity(MusicPlayerLayout.coverShadowOpacity),
                radius: MusicPlayerLayout.coverShadowRadius,
                y: MusicPlayerLayout.coverShadowY
            )
    }
}

// MARK: - Название

/// Название трека — Headline L, у explicit-трека с бейджем 18+. Не влезает в колонку —
/// бежит строкой во всю ширину экрана с гаснущими краями, как в макете `6105:61569`;
/// влезает — стоит у левого поля.
///
/// Ширина строки меряется шрифтом, а не вью: своя ширина вью в проекте под запретом,
/// а строка в одну линию по метрикам шрифта считается точно.
private struct MarqueeTitle: View {
    let text: String
    let isExplicit: Bool
    let column: CGFloat
    let screenWidth: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now

    private var lineWidth: CGFloat {
        let font = UIFont(name: PlusFont.displaySemibold, size: PlusHeadline.l.size)
            ?? .systemFont(ofSize: PlusHeadline.l.size, weight: .bold)
        let textWidth = ceil((text as NSString).size(withAttributes: [.font: font]).width)
        return isExplicit
            ? textWidth + MusicPlayerLayout.titleBadgeGap + MusicPlayerLayout.titleBadge
            : textWidth
    }

    var body: some View {
        Group {
            if lineWidth <= column {
                line
                    .frame(width: column, alignment: .leading)
                    .frame(width: screenWidth)
            } else if reduceMotion {
                // Без бегущей строки: стоит у поля и гаснет у правого края.
                faded(leading: 0) {
                    line
                        .offset(x: MusicPlayerLayout.sideInset)
                        .frame(width: screenWidth, alignment: .leading)
                }
            } else {
                marquee
            }
        }
        .frame(height: PlusHeadline.l.lineHeight)
        .onChange(of: text) { start = .now }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    private var line: some View {
        HStack(spacing: MusicPlayerLayout.titleBadgeGap) {
            Text(text)
                .plusHeadline(.l)
                .foregroundStyle(Color.fillOne)
                .lineLimit(1)
            if isExplicit {
                Image("iconExplicit")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: MusicPlayerLayout.titleBadge, height: MusicPlayerLayout.titleBadge)
                    // Белый 15 % из макета; токена нет — оттенок живёт только здесь.
                    .foregroundStyle(Color.white.opacity(0.15))
            }
        }
        .fixedSize()
    }

    private var marquee: some View {
        let distance = lineWidth + MusicPlayerMotion.marqueeGap
        let travel = TimeInterval(distance / MusicPlayerMotion.marqueeSpeed)
        let period = MusicPlayerMotion.marqueePause + travel

        return TimelineView(.animation) { context in
            let phase = context.date.timeIntervalSince(start).truncatingRemainder(dividingBy: period)
            let moved = phase < MusicPlayerMotion.marqueePause
                ? 0
                : CGFloat(phase - MusicPlayerMotion.marqueePause) * MusicPlayerMotion.marqueeSpeed
            // Левый край гаснет только на ходу: проявляется с первых пунктов хода
            // и уходит, пока вторая копия доезжает до поля.
            let leading = min(1, min(moved, distance - moved) / MusicPlayerMotion.marqueeFadeRamp)
            // Две копии подряд: когда первая уехала на всю длину с зазором, на её месте
            // ровно вторая — круг замыкается без скачка. Всё, что за кромками экрана,
            // прячет маска — отдельный клип не нужен.
            faded(leading: leading) {
                HStack(spacing: MusicPlayerMotion.marqueeGap) {
                    line
                    line
                }
                .offset(x: MusicPlayerLayout.sideInset - moved)
                .frame(width: screenWidth, alignment: .leading)
            }
        }
        .frame(width: screenWidth)
    }

    /// Строка под масками краёв. Маска выше рамки на запас глифов (`inkOutset`):
    /// по рамке строки она срезала бы хвосты «у», «р» и точки «Й».
    private func faded(leading: Double, @ViewBuilder content: () -> some View) -> some View {
        let outset = PlusHeadline.l.inkOutset
        return content()
            .padding(.vertical, outset)
            .mask { fadeMask(leading: leading) }
            .padding(.vertical, -outset)
    }

    /// Маски краёв из макета. `leading` — сила левого затухания, 0…1.
    private func fadeMask(leading: Double) -> some View {
        let clear = MusicPlayerMotion.marqueeEdgeClear / screenWidth
        let full = MusicPlayerMotion.marqueeFadeEnd / screenWidth
        let edge = Color.black.opacity(1 - leading)
        return LinearGradient(
            stops: [
                .init(color: edge, location: 0),
                .init(color: edge, location: clear),
                .init(color: .black, location: full),
                .init(color: .black, location: 1 - full),
                .init(color: .clear, location: 1 - clear),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Строка, гаснущая у края

/// Строка, которая не влезла, гаснет у правого края, а не обрывается многоточием —
/// так в макете нарисовано длинное имя артиста. Влезла — обычный текст, без маски.
private struct FadingLine: View {
    let text: String
    let fade: CGFloat

    var body: some View {
        ViewThatFits(in: .horizontal) {
            label
            // `minWidth: 0` обязателен: без него рамка с одним `maxWidth` при узком
            // предложении берёт ширину текста целиком — и длинная строка распирала ряд
            // шире экрана, выталкивая аватар и кнопки за кромки (жалоба 2026-10-03).
            label
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .clipped()
                .mask {
                    HStack(spacing: 0) {
                        Color.black
                        LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: fade)
                    }
                }
        }
    }

    private var label: some View {
        Text(text)
            .plusText(.textM, .medium)
            .foregroundStyle(Color.fillOne)
            .lineLimit(1)
            .fixedSize()
    }
}

// MARK: - Строка очереди

private struct QueueRow: View {
    let item: MusicQueueItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                cover
                HStack(spacing: MusicPlayerLayout.rowTrailingGap) {
                    titles
                    status
                    Image("iconDragHandle")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: MusicPlayerLayout.rowBadge, height: MusicPlayerLayout.rowBadge)
                        // Белый 60 % из макета; токена нет — оттенок живёт только здесь
                        // (как у «ещё» в треклисте альбома).
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                .padding(.leading, MusicPlayerLayout.rowCoverToText)
            }
            .padding(.horizontal, MusicPlayerLayout.queueSide)
            .padding(.vertical, MusicPlayerLayout.rowVertical)
            .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.rowScale))
        .accessibilityLabel("\(item.title), \(item.artist)")
    }

    private var cover: some View {
        let shape = RoundedRectangle(cornerRadius: MusicPlayerLayout.rowCoverCorner, style: .continuous)
        return Color.clear
            .frame(width: MusicPlayerLayout.rowCover, height: MusicPlayerLayout.rowCover)
            .overlay { ArtworkImage(source: item.cover).scaledToFill() }
            .clipShape(shape)
            .coverBorder(shape)
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: MusicPlayerLayout.textStackGap) {
            HStack(spacing: MusicPlayerLayout.rowBadgeGap) {
                Text(item.title)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillOne)
                if item.isExplicit {
                    Image("iconExplicit")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: MusicPlayerLayout.rowBadge, height: MusicPlayerLayout.rowBadge)
                        // Белый 30 % — как бейдж в треклисте альбома.
                        .foregroundStyle(Color.white.opacity(0.3))
                }
            }
            Text(item.artist)
                .plusText(.textM, .medium)
                .foregroundStyle(Color.fillSubtitle)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Значок «скачан» стоит у ручки; без него слот держит место 44×20, как в макете.
    @ViewBuilder
    private var status: some View {
        if item.isDownloaded {
            MovieIcon(name: "iconDownload", box: MusicPlayerLayout.rowBadge)
        } else {
            Color.clear
                .frame(width: MusicPlayerLayout.rowStatusWidth, height: MusicPlayerLayout.rowStatusHeight)
        }
    }
}
