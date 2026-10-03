import AVFoundation
import SwiftUI
import UIKit

// MARK: - Геометрия

/// Числа макета `2311:27039`. Кадр альбомный — 812×375, на iPhone 17 Pro тот же холст
/// 874×402: вёрстка отмеряется от кромок, середина просто становится шире.
private enum MoviePlayerLayout {
    /// Поле слева шире правого (правка макета 2026-10-03): приложение заперто в портрете,
    /// и статус-бар не поворачивается вместе с кадром — в альбомной ориентации его место
    /// вдоль левой кромки. 54 — его высота в макете, плюс обычные 24. Сам статус-бар
    /// в плеере скрыт (просьба пользователя тем же днём), поле осталось по макету.
    static let leadingInset: CGFloat = 78
    /// Справа — скругление экрана и полоска home indicator.
    static let trailingInset: CGFloat = 48
    /// Поле сверху и снизу.
    static let edgeInset: CGFloat = 16
    /// Зазор в группах круглых кнопок — сверху справа и снизу справа, и между пилюлями.
    static let buttonGap: CGFloat = 8
    /// Колонка названия по центру верхней полосы — бокс макета.
    static let metaWidth: CGFloat = 375
    static let metaTop: CGFloat = 2
    /// Кнопки транспорта — компонент `11:9197` (Size=2xl 52px): круг 52, глиф 24.
    static let transportSize: CGFloat = 52
    static let transportIcon: CGFloat = 24
    static let transportGap: CGFloat = 16
    /// Дорожка таймлайна: подписи времени над ней, ряд кнопок под ней.
    static let trackHeight: CGFloat = 16
    /// Backdrop-blur дорожки в CSS-единицах проекта (у кнопок — `buttonBlur` 20).
    static let trackBlur: CGFloat = 6
    static let labelsToTrack: CGFloat = 6
    static let trackToButtons: CGFloat = 16
    /// На сколько хит-зона дорожки выходит за её 16pt сверху и снизу: по полосе
    /// в 16pt пальцем не попасть, а растягивать ради этого раскладку нельзя.
    static let trackHitOutset: CGFloat = 14
    /// Насколько дорожка растёт под пальцем: +8 к высоте и к ширине, поровну во все
    /// стороны (просьба пользователя 2026-10-03). Растёт поверх зазоров — слот
    /// раскладки остаётся 16pt, и подписи времени над ней не сдвигаются.
    static let trackGrow: CGFloat = 8
    /// Кнопки с подписью — компонент `11:9094` (Size=md 40px, Icon=leading).
    static let pillHeight: CGFloat = 40
    static let pillLeading: CGFloat = 16
    static let pillTrailing: CGFloat = 20
    static let pillIconGap: CGFloat = 6
    static let pillIcon: CGFloat = 20
    /// Бордер стеклянных кнопок плеера — сырые white 6 %, как у круглой кнопки 40pt
    /// (DECISIONS 2026-08-22): у пилюль-кнопок макета он тот же.
    static let buttonBorder = Color.white.opacity(0.06)
}

// MARK: - Движение

enum MoviePlayerMotion {
    /// Сколько контролы ждут без касаний, пока фильм идёт. На паузе не гаснут:
    /// смотреть не на что, а кнопки нужны.
    static let controlsIdle: Duration = .seconds(4)
    /// Показ и скрытие по тапу — ответ на касание, поэтому коротко и с сильным ease-out:
    /// бо́льшая часть хода приходится на первые кадры, и отклик виден сразу.
    /// Штатный `.easeOut` для этого слишком вялый.
    static let controlsToggle: Animation = .timingCurve(0.23, 1, 0.32, 1, duration: 0.2)
    /// Уход по таймеру — без спешки: он ничего не сообщает, а резкое исчезновение
    /// посреди кадра дёргает глаз.
    static let controlsIdleHide: Animation = .easeInOut(duration: 0.3)
    /// Сдвиг полос вместе с прозрачностью (просьба пользователя 2026-10-03): верхняя
    /// приходит сверху вниз, нижняя с таймлайном — снизу вверх, обе от своей кромки.
    /// Транспорт по центру только проявляется: сдвиг посреди кадра читался бы прыжком.
    static let chromeShift: CGFloat = 12
    /// Дорожка под пальцем растёт и возвращается пружиной без отскока: палец могут
    /// отпустить посреди роста, и пружина развернётся с текущей скорости.
    static let trackGrab: Animation = .smooth(duration: 0.25)
    /// Трещотка перемотки: тик на каждые 6pt хода головки, но не чаще 30 раз в секунду —
    /// на быстрой протяжке выходит очередь, на медленной отдельные щелчки.
    static let scrubTickStep: CGFloat = 6
    static let scrubTickInterval: TimeInterval = 1.0 / 30
    /// Лёгкая (просьба пользователя): очередь сопровождает палец, а не трясёт телефон.
    static let scrubTickIntensity: CGFloat = 0.5
    /// Шаг кнопок перемотки.
    static let skipStep: TimeInterval = 10
    /// Длительность фильма, когда хронометража нет, — число макета (1:37:46).
    static let fallbackRuntime: TimeInterval = 1 * 3600 + 37 * 60 + 46
}

// MARK: - Часы фильма

/// Время фильма поверх забандленного ролика.
///
/// Потока у фильма нет (Кинопоиск отдаёт страницу плеера, а не файл — см.
/// `ShowcaseSeeds.watchingClip`), картинка — ролик-мок на 20 секунд. Таймлайн при этом
/// обязан вести себя как у фильма: макет показывает «43:21 из 1:37:46». Поэтому позиция
/// считается своими часами, а ролик крутится по кругу и на любой перемотке встаёт
/// в `позиция mod длина ролика`. Кнопки и дорожка работают как в настоящем плеере,
/// под ними — тот же мок.
@MainActor
@Observable
final class MovieClock {
    let duration: TimeInterval
    /// Позиция фильма. Пишется на смене каждой секунды, а не каждый кадр: от неё
    /// зависят подпись времени и дорожка, а дорожка на полуторачасовом фильме
    /// за секунду проходит десятую долю пункта.
    private(set) var position: TimeInterval
    private(set) var isPlaying = false
    /// Палец на дорожке: часы стоят, кадр идёт за пальцем.
    private(set) var isScrubbing = false

    let video = LoopingVideoPlayback()
    @ObservationIgnored private var clipDuration: TimeInterval = 0
    /// Опора часов: с какой позиции и в какой момент пошло воспроизведение.
    /// Позиция между тиками считается от неё, поэтому тики не копят ошибку.
    @ObservationIgnored private var anchorPosition: TimeInterval = 0
    @ObservationIgnored private var anchorDate = Date.now
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var resumesAfterScrub = false
    @ObservationIgnored private var seekInFlight = false
    @ObservationIgnored private var pendingSeek: CMTime?

    init(duration: TimeInterval, position: TimeInterval) {
        let length = max(1, duration)
        self.duration = length
        // Досмотренный до конца фильм открывается с начала, а не на последнем кадре.
        self.position = position < length ? max(0, position) : 0
    }

    var progress: Double { position / duration }

    /// Позиция прямо сейчас, между тиками: закрытие плеера запоминает место точно,
    /// а не с точностью до последней смены секунды.
    var livePosition: TimeInterval {
        guard isPlaying else { return position }
        return min(duration, anchorPosition + Date.now.timeIntervalSince(anchorDate))
    }

    /// Зарядить ролик и сразу играть: «Смотреть» обещает фильм, а не паузу.
    func start(clip: String) async {
        guard let url = LoopingVideoPlayback.bundled(clip) else { return }
        video.prepare(url: url)
        // Фильм смотрят, не касаясь экрана, — гаснуть посреди сцены ему нельзя.
        // Фоновые ролики этот флаг сознательно снимают (`LoopingVideoPlayback.prepare`).
        video.queue.preventsDisplaySleepDuringVideoPlayback = true
        let length = (try? await AVURLAsset(url: url).load(.duration))?.seconds ?? 0
        guard !Task.isCancelled else { return }
        clipDuration = length.isFinite ? length : 0
        seekVideo(to: position)
        play()
    }

    func togglePlayback() {
        isPlaying ? pause() : play()
    }

    func play() {
        guard !isPlaying else { return }
        if position >= duration { jump(to: 0) }
        isPlaying = true
        anchorPosition = position
        anchorDate = .now
        video.queue.play()
        startTicking()
    }

    func pause() {
        guard isPlaying else { return }
        position = livePosition
        isPlaying = false
        stopTicking()
        video.pause()
    }

    func skip(by delta: TimeInterval) {
        jump(to: livePosition + delta)
    }

    /// Палец на дорожке. Первое касание ставит фильм на паузу — кадр идёт за пальцем,
    /// а не убегает вперёд; играл ли фильм, запоминаем, чтобы вернуть на отпускании.
    func scrub(to fraction: Double) {
        if !isScrubbing {
            resumesAfterScrub = isPlaying
            pause()
            isScrubbing = true
        }
        position = min(max(0, fraction), 1) * duration
        seekVideo(to: position)
    }

    func endScrub() {
        guard isScrubbing else { return }
        isScrubbing = false
        if resumesAfterScrub, position < duration { play() }
    }

    /// Плеер закрыли — ролик и часы встают.
    func stop() {
        isPlaying = false
        stopTicking()
        video.pause()
    }

    // MARK: Внутреннее

    private func jump(to target: TimeInterval) {
        position = min(max(0, target), duration)
        anchorPosition = position
        anchorDate = .now
        seekVideo(to: position)
        guard isPlaying else { return }
        if position >= duration {
            finish()
        } else {
            // Перезапуск выравнивает тики по новой секунде: иначе подпись времени
            // после перемотки сменилась бы не через секунду, а когда придётся.
            startTicking()
        }
    }

    private func finish() {
        position = duration
        isPlaying = false
        stopTicking()
        video.pause()
    }

    /// Тик ровно на смене секунды фильма: подпись времени меняется раз в секунду
    /// и без дрожи, а не «когда пришёлся таймер».
    private func startTicking() {
        stopTicking()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                guard let wait = self?.secondsToNextTick else { return }
                try? await Task.sleep(for: .seconds(wait))
                guard !Task.isCancelled, let self else { return }
                position = livePosition
                if position >= duration {
                    finish()
                    return
                }
            }
        }
    }

    private func stopTicking() {
        ticker?.cancel()
        ticker = nil
    }

    private var secondsToNextTick: TimeInterval {
        let now = livePosition
        return max(0.05, now.rounded(.down) + 1 - now)
    }

    private func seekVideo(to moviePosition: TimeInterval) {
        guard clipDuration > 0 else { return }
        let clipTime = moviePosition.truncatingRemainder(dividingBy: clipDuration)
        seek(CMTime(seconds: clipTime, preferredTimescale: 600))
    }

    /// Одна перемотка за раз. Дорожка под пальцем шлёт их десятками в секунду,
    /// и каждая новая отменяла бы предыдущую — кадр стоял бы на месте до самого
    /// отпускания. Пока идёт одна, запоминается только последняя цель.
    private func seek(_ time: CMTime) {
        guard !seekInFlight else {
            pendingSeek = time
            return
        }
        seekInFlight = true
        video.queue.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                seekInFlight = false
                if let next = pendingSeek {
                    pendingSeek = nil
                    seek(next)
                }
            }
        }
    }
}

// MARK: - Плеер

/// Киноплеер — макет `2311:27039`.
///
/// **Альбомный макет на портретном экране.** Плеер выезжает снизу и накрывает экран,
/// под ним ничего не двигается (требование пользователя 2026-10-03). Настоящий поворот
/// интерфейса переложил бы и экран под плеером, поэтому приложение заперто в портрете,
/// а альбомный холст рисуется повёрнутым на 90°: телефон поворачивают, когда плеер
/// уже открыт. Поворот по часовой — кадр стоит прямо, когда телефон повёрнут против
/// часовой, вырезом влево: это `landscapeRight`, куда уходят и системные видеоплееры.
/// Портретный статус-бар встал бы вдоль левой кромки кадра — макет держит под него
/// широкое левое поле, а сам он в плеере скрыт.
struct MoviePlayerView: View {
    let movie: MovieInProgress
    @Environment(ActionBarState.self) private var actionBar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock: MovieClock
    @State private var ratchet = ScrubRatchet()
    @State private var controlsVisible = true
    /// Счётчик касаний: каждое перезапускает отсчёт до скрытия контролов.
    @State private var touches = 0
    /// Кадр с кропом во весь экран, как в макете, или вписанный целиком —
    /// кнопка с рамкой в правом нижнем углу.
    @State private var fillsFrame = true

    init(movie: MovieInProgress) {
        self.movie = movie
        _clock = State(initialValue: MovieClock(
            duration: movie.runtime ?? MoviePlayerMotion.fallbackRuntime,
            position: movie.position ?? 0
        ))
    }

    var body: some View {
        GeometryReader { proxy in
            // Холст альбомный: его ширина — высота экрана. Размер берётся у экрана,
            // а не у самого холста, — своё измерение вью в проекте под запретом.
            let canvas = CGSize(width: proxy.size.height, height: proxy.size.width)
            landscape(canvas)
                .frame(width: canvas.width, height: canvas.height)
                .rotationEffect(.degrees(90))
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .background(Color.black)
        .task { await clock.start(clip: ShowcaseSeeds.playerClip) }
        .task(id: idleKey) { await hideControlsWhenIdle() }
        // Ушли из приложения — фильм встаёт, как в системных плеерах: часы идут
        // от настенного времени и иначе убежали бы вперёд на всё время в фоне.
        // Уведомление, а не `scenePhase`: плеер живёт в своём хостинге вне сцены
        // SwiftUI, и фаза сцены до него может не доехать.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            clock.pause()
        }
        .onDisappear { clock.stop() }
    }

    private func landscape(_ canvas: CGSize) -> some View {
        ZStack {
            LoopingVideoLayer(
                player: clock.video.queue,
                videoGravity: fillsFrame ? .resizeAspectFill : .resizeAspect,
                onReadyForDisplay: {}
            )
            // Тап по кадру показывает и прячет контролы. Отдельным слоем, а не жестом
            // на самом видео: у платформенной вью свой хит-тест, жест на ней ненадёжен.
            Color.clear
                .contentShape(.rect)
                .onTapGesture(perform: toggleControls)
            controls(canvas)
                // Погасшие кнопки тапов не ловят: первый тап по экрану возвращает
                // контролы, а не жмёт невидимую кнопку под пальцем.
                .allowsHitTesting(controlsVisible)
        }
    }

    /// Показ и уход полос — одной транзакцией (`withAnimation` у того, кто меняет
    /// `controlsVisible`): сдвиг и прозрачность едут одной кривой с одной точки старта.
    private func controls(_ canvas: CGSize) -> some View {
        let trackWidth = canvas.width - MoviePlayerLayout.leadingInset - MoviePlayerLayout.trailingInset
        // С «уменьшением движения» полосы только проявляются, без сдвига.
        let shift = controlsVisible || reduceMotion ? 0 : MoviePlayerMotion.chromeShift
        let opacity: Double = controlsVisible ? 1 : 0
        return ZStack {
            VStack(spacing: 0) {
                topBar
                    .offset(y: -shift)
                    .opacity(opacity)
                Spacer(minLength: 0)
                bottomBlock(trackWidth: trackWidth)
                    .offset(y: shift)
                    .opacity(opacity)
            }
            .padding(.leading, MoviePlayerLayout.leadingInset)
            .padding(.trailing, MoviePlayerLayout.trailingInset)
            .padding(.vertical, MoviePlayerLayout.edgeInset)

            // Транспорт — по центру всего кадра, а не колонки между полями: так в макете,
            // и кнопки остаются на середине экрана, хотя левое поле шире правого.
            transport
                .opacity(opacity)
        }
    }

    // MARK: Верхняя полоса

    private var topBar: some View {
        HStack(alignment: .top, spacing: 0) {
            GlassIconButton(icon: "iconCross", accessibilityTitle: "Закрыть") {
                PlayerHaptics.tap()
                close()
            }
            Spacer(minLength: 0)
            HStack(spacing: MoviePlayerLayout.buttonGap) {
                GlassIconButton(icon: "iconPip", accessibilityTitle: "Картинка в картинке", action: press)
                GlassIconButton(icon: "iconCast", accessibilityTitle: "Транслировать на экран", action: press)
                GlassIconButton(icon: "iconMore", accessibilityTitle: "Ещё", action: press)
            }
        }
        // Название — по центру полосы, а не между группами кнопок: группы разной
        // ширины, и колонка между ними уехала бы влево. Полоса начинается после
        // статус-бара, поэтому её центр правее центра кадра — так и в макете.
        .overlay(alignment: .top) { meta }
    }

    private var meta: some View {
        VStack(spacing: 0) {
            Text(movie.title)
                .plusText(.textL, .semibold)
                .foregroundStyle(Color.fillOne)
            if let subtitle = movie.subtitle {
                Text(subtitle)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillSubtitle)
            }
        }
        .lineLimit(1)
        .multilineTextAlignment(.center)
        .padding(.top, MoviePlayerLayout.metaTop)
        .frame(width: MoviePlayerLayout.metaWidth)
        // Подписи — не кнопка: тап сквозь них уходит на кадр и прячет контролы.
        .allowsHitTesting(false)
    }

    // MARK: Транспорт

    private var transport: some View {
        HStack(spacing: MoviePlayerLayout.transportGap) {
            TransportButton(icon: "iconRewind10", title: "Назад на 10 секунд") {
                clock.skip(by: -MoviePlayerMotion.skipStep)
                registerTouch()
            }
            PlayPauseButton(isPlaying: clock.isPlaying) {
                clock.togglePlayback()
                registerTouch()
            }
            TransportButton(icon: "iconForward10", title: "Вперёд на 10 секунд") {
                clock.skip(by: MoviePlayerMotion.skipStep)
                registerTouch()
            }
        }
    }

    // MARK: Низ: время, дорожка, кнопки

    private func bottomBlock(trackWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                timecode(clock.position)
                Spacer(minLength: 0)
                timecode(clock.duration)
            }
            .allowsHitTesting(false)

            timeline(width: trackWidth)
                .padding(.top, MoviePlayerLayout.labelsToTrack)

            HStack(spacing: 0) {
                HStack(spacing: MoviePlayerLayout.buttonGap) {
                    pill(icon: "iconEpisodes", title: "Серии")
                    pill(icon: "iconSubtitles", title: "Аудио и субтитры")
                }
                Spacer(minLength: 0)
                HStack(spacing: MoviePlayerLayout.buttonGap) {
                    GlassIconButton(
                        icon: "iconAspect",
                        accessibilityTitle: fillsFrame ? "Вписать кадр" : "Заполнить экран",
                        action: toggleFill
                    )
                    GlassIconButton(icon: "iconRotate", accessibilityTitle: "Повернуть экран", action: press)
                    GlassIconButton(icon: "iconNext", accessibilityTitle: "Дальше", action: press)
                }
            }
            .padding(.top, MoviePlayerLayout.trackToButtons)
        }
    }

    private func timecode(_ seconds: TimeInterval) -> some View {
        Text(MovieTimecode.text(seconds))
            .plusText(.textM, .semibold)
            // Цифры одной ширины: левая подпись меняется каждую секунду,
            // и без этого её правый край дрожал бы.
            .monospacedDigit()
            .foregroundStyle(Color.fillOne)
    }

    private func timeline(width: CGFloat) -> some View {
        let grow = clock.isScrubbing ? MoviePlayerLayout.trackGrow : 0
        // Слот раскладки — исходные 16pt во всю колонку. Дорожка лежит поверх него
        // и под пальцем растёт во все стороны в зазоры — подписи времени над ней
        // и кнопки под ней не двигаются.
        return Color.clear
            .frame(width: width, height: MoviePlayerLayout.trackHeight)
            .overlay {
                track(width: width + grow, height: MoviePlayerLayout.trackHeight + grow)
                    // Ключ — сам хват: в той же транзакции заливка доезжает до точки
                    // касания, а дальше идёт за пальцем без анимации.
                    .animation(MoviePlayerMotion.trackGrab, value: clock.isScrubbing)
            }
            // Хит-зона выше дорожки, раскладка — нет: отрицательный отступ возвращает
            // кадру исходные 16pt, увеличенной остаётся только форма касания.
            .padding(.vertical, MoviePlayerLayout.trackHitOutset)
            .contentShape(.rect)
            .gesture(scrubGesture(width: width))
            .padding(.vertical, -MoviePlayerLayout.trackHitOutset)
            .accessibilityElement()
            .accessibilityLabel("Перемотка")
            .accessibilityValue(MovieTimecode.text(clock.position))
    }

    private func track(width: CGFloat, height: CGFloat) -> some View {
        let shape = Capsule(style: .continuous)
        return ZStack(alignment: .leading) {
            Color.clear
                .glassSurface(shape, blur: MoviePlayerLayout.trackBlur)
            // Заливка длиннее пройденного на высоту дорожки и сдвинута влево на столько
            // же: левый торец уходит за кромку и срезается клипом дорожки, а правый
            // остаётся скруглённым, как в макете. На нуле заливки не видно вовсе —
            // а укороченная капсула у самого старта стала бы кружком.
            shape
                .fill(Color.fillOne)
                .frame(width: width * clock.progress + height)
                .offset(x: -height)
        }
        .frame(width: width, height: height)
        .clipShape(shape)
    }

    /// Касание дорожки сразу ставит кадр под палец (`minimumDistance: 0`): тап —
    /// это перемотка в точку, протяжка — перемотка вслед за пальцем.
    private func scrubGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Под пальцем дорожка шире на `trackGrow` — по половине с каждой стороны,
                // и позиция считается по растянутой: кромка заливки стоит ровно под пальцем.
                let grown = width + MoviePlayerLayout.trackGrow
                let fraction = min(max(0, (value.location.x + MoviePlayerLayout.trackGrow / 2) / grown), 1)
                clock.scrub(to: fraction)
                ratchet.move(to: fraction * grown)
                registerTouch()
            }
            .onEnded { _ in
                clock.endScrub()
                ratchet.end()
                registerTouch()
            }
    }

    private func pill(icon: String, title: String) -> some View {
        Button(action: press) {
            HStack(spacing: MoviePlayerLayout.pillIconGap) {
                MovieIcon(name: icon, box: MoviePlayerLayout.pillIcon)
                Text(title)
                    .plusText(.textM, .semibold)
                    .foregroundStyle(Color.fillOne)
                    .fixedSize()
            }
            .padding(.leading, MoviePlayerLayout.pillLeading)
            .padding(.trailing, MoviePlayerLayout.pillTrailing)
            .frame(height: MoviePlayerLayout.pillHeight)
            .glassSurface(
                Capsule(style: .continuous),
                blur: PlusMetrics.buttonBlur,
                border: MoviePlayerLayout.buttonBorder
            )
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    // MARK: Действия

    private func close() {
        actionBar.closeContentPlayer(moviePosition: clock.livePosition)
    }

    private func toggleFill() {
        fillsFrame.toggle()
        press()
    }

    private func toggleControls() {
        withAnimation(MoviePlayerMotion.controlsToggle) { controlsVisible.toggle() }
        registerTouch()
    }

    /// Нажатие кнопки без своей логики: отклик пальцу и перезапуск отсчёта
    /// до скрытия контролов. Хаптика — на всех кнопках плеера (просьба пользователя).
    private func press() {
        PlayerHaptics.tap()
        registerTouch()
    }

    private func registerTouch() {
        touches += 1
    }

    // MARK: Автоскрытие контролов

    private struct IdleKey: Hashable {
        let touches: Int
        let visible: Bool
        let playing: Bool
        let scrubbing: Bool
    }

    /// Ключ задачи скрытия: любое касание, пауза или палец на дорожке перезапускают
    /// отсчёт с нуля.
    private var idleKey: IdleKey {
        IdleKey(
            touches: touches,
            visible: controlsVisible,
            playing: clock.isPlaying,
            scrubbing: clock.isScrubbing
        )
    }

    private func hideControlsWhenIdle() async {
        guard controlsVisible, clock.isPlaying, !clock.isScrubbing else { return }
        try? await Task.sleep(for: MoviePlayerMotion.controlsIdle)
        guard !Task.isCancelled else { return }
        withAnimation(MoviePlayerMotion.controlsIdleHide) { controlsVisible = false }
    }
}

// MARK: - Хаптика

private enum PlayerHaptics {
    /// Нажатие любой кнопки плеера — impact light, как у play/pause мини-плеера.
    static func tap() {
        UIImpactFeedbackGenerator(style: .light)
            .impactOccurred(intensity: ActionBarMotion.transportHapticIntensity)
    }
}

/// Трещотка перемотки — серия лёгких тиков, пока головка едет под пальцем («как
/// пулемётная очередь», просьба пользователя 2026-10-03). Тик привязан к ходу
/// **головки**, а не пальца: у краёв дорожки головка упирается, и очередь стихает
/// вместе с ней. Частота ограничена сверху — быстрая протяжка даёт ровную очередь,
/// а не гул, который Taptic Engine всё равно не отыграл бы.
@MainActor
private final class ScrubRatchet {
    private let generator = UIImpactFeedbackGenerator(style: .light)
    private var lastX: CGFloat?
    private var travel: CGFloat = 0
    private var lastTick = Date.distantPast

    /// Положение головки на дорожке, pt. Первый вызов за жест — хват: тик сразу,
    /// чтобы касание отозвалось ещё до того, как палец сдвинулся.
    func move(to x: CGFloat) {
        guard let lastX else {
            self.lastX = x
            tick()
            return
        }
        travel += abs(x - lastX)
        self.lastX = x
        guard travel >= MoviePlayerMotion.scrubTickStep,
              Date.now.timeIntervalSince(lastTick) >= MoviePlayerMotion.scrubTickInterval
        else { return }
        travel = 0
        tick()
    }

    func end() {
        lastX = nil
        travel = 0
    }

    private func tick() {
        generator.impactOccurred(intensity: MoviePlayerMotion.scrubTickIntensity)
        lastTick = .now
        // Следующий тик может прийти через 33мс — движок держим разогретым.
        generator.prepare()
    }
}

// MARK: - Кнопки транспорта

/// Круглая стеклянная кнопка 52 с глифом 24 — компонент `11:9197`. Рецепт стекла
/// тот же, что у кнопки 40 (`glassCircle`), отличаются только размеры.
private struct TransportButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            PlayerHaptics.tap()
            action()
        } label: {
            MovieIcon(name: icon, box: MoviePlayerLayout.transportIcon)
                .frame(width: MoviePlayerLayout.transportSize, height: MoviePlayerLayout.transportSize)
                .glassCircle()
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(title)
    }
}

private struct PlayPauseButton: View {
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button {
            PlayerHaptics.tap()
            action()
        } label: {
            // Кросс-поп глифов — тот же, что у play/pause мини-плеера: обе иконки
            // в дереве, уходящая утапливается, приходящая выныривает.
            ZStack {
                MovieIcon(name: "iconPlay", box: MoviePlayerLayout.transportIcon)
                    .opacity(isPlaying ? 0 : 1)
                    .scaleEffect(isPlaying ? ActionBarMotion.iconSwapScale : 1)
                MovieIcon(name: "iconPause", box: MoviePlayerLayout.transportIcon)
                    .opacity(isPlaying ? 1 : 0)
                    .scaleEffect(isPlaying ? 1 : ActionBarMotion.iconSwapScale)
            }
            .animation(ActionBarMotion.iconSwap, value: isPlaying)
            .frame(width: MoviePlayerLayout.transportSize, height: MoviePlayerLayout.transportSize)
            .glassCircle()
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(isPlaying ? "Пауза" : "Смотреть")
    }
}

// MARK: - Таймкод

enum MovieTimecode {
    /// «43:21», «1:37:46» — часы только там, где они есть, как в макете.
    static func text(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = total % 3600 / 60
        let rest = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, rest)
            : String(format: "%d:%02d", minutes, rest)
    }
}
