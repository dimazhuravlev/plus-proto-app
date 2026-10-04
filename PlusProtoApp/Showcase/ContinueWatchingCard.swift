import AVFoundation
import SwiftUI
import UIKit

// MARK: - Геометрия

/// Карточка «Продолжить смотреть» — `2004:10703`, figma-screen1 §3.7.
/// Кадр карточки — слот витрины: ширина 402, высота 313 (вместе с блоком оценки).
/// По X координаты остаются в системе кадра витрины, по Y из спеки вычтен верх слота.
private enum WatchingGeometry {
    static let slot = ShowcaseLayout.Slot.watching
    static let size = CGSize(width: ShowcaseLayout.designWidth, height: slot.height)

    /// `2004:10705` — видеокадр 277×156, r12, рамка 0.66 white 8%, поворот −5°.
    static let videoSize = CGSize(width: 277, height: 156)
    static let videoRotation = Angle.degrees(-5)
    /// Левый верхний угол НЕповёрнутого кадра. В спеке дан только бокс карточки:
    /// поворот на 5° раздувает 277×156 до AABB 289.54×179.54, а её левый край (−7.27)
    /// и верх (1647) задают центр кадра (137.5, 1736.77) — отсюда и угол.
    static let videoOrigin = CGPoint(x: -1, y: 11.77)
    /// `2004:10704` — ореол: та же картинка в блюре 28, непрозрачность 0.50 (§7).
    static let ambilightOpacity: Double = 0.50

    /// `2004:10706` — скрим у нижнего края кадра под строкой и прогрессом
    static let scrimHeight: CGFloat = 35
    static let scrimOpacity: Double = 0.5
    /// Контент кадра: px8 pb8, зазор 2 (pt124 добирается прижатием к низу)
    static let contentInset: CGFloat = 8
    static let contentGap: CGFloat = 2
    /// `2004:10708` — трек прогресса
    static let trackWidth: CGFloat = 261

    /// `2004:10711` — логотип 147×101 в (237, 1671). Лежит отдельным слоем: кадр поворачивается, логотип нет.
    static let logoSize = CGSize(width: 147, height: 101)
    static let logoOrigin = CGPoint(x: 237, y: 1671 - slot.top)

    /// `2004:10712` — кнопка ✕ 40×40 в (16, 1647), только дисмисс, без ♥
    static let dismissOrigin = CGPoint(x: 16, y: 1647 - slot.top)

    /// `2004:10713` — блок оценки 402×158 в (0, 1802)
    static let rateOrigin = CGPoint(x: 0, y: 1802 - slot.top)

    /// Доля карточки на экране, с которой клип начинает играть.
    static let visibilityThreshold: Double = 0.2
    /// Кроссфейд «постер → видео» по первому готовому кадру
    static let videoFadeIn = Animation.easeInOut(duration: 0.35)
}

/// Блок «Что думаешь?» — `2004:10713`.
private enum RateBlockGeometry {
    static let size = CGSize(width: ShowcaseLayout.designWidth, height: 158)
    static let verticalPadding: CGFloat = 8
    static let horizontalPadding: CGFloat = 16
    /// Макетные 16 и 12 — плюс по 3: строка заголовка по шкале UI kit (Headline S,
    /// 20/20) на 6 ниже макетной 26, и без добавки глиф и ряд эмодзи уехали бы вверх.
    static let titleTop: CGFloat = 16 + 3
    static let titleBottom: CGFloat = 12 + 3
    /// Колонка: pt8 pb6 px8, зазор 8
    static let columnTop: CGFloat = 8
    static let columnBottom: CGFloat = 6
    static let columnInset: CGFloat = 8
    static let columnGap: CGFloat = 8
    /// Чип 52×52 r32 — при такой стороне радиус схлопывается в круг
    static let chip: CGFloat = 52
}

// MARK: - Карточка

/// «Продолжить смотреть»: повёрнутый видеокадр с ореолом, логотип поверх, ✕ в углу
/// и блок оценки под ним. У ✕ логики нет, оценка — реакция без записи (`RateBlock`).
struct ContinueWatchingCard: View {
    let block: WatchingBlock

    @Environment(\.scenePhase) private var scenePhase
    @State private var playback = ClipPlayback()
    /// Клип играет только пока карточка в зоне видимости — иначе лента платит за декодер вслепую.
    @State private var isVisible = false
    /// Первый отрисованный кадр видео: до него виден постер.
    @State private var isVideoReady = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Кадр — интерактивная миниатюра карточки: ✕, логотип и блок оценки
            // остаются снаружи и в зум-переходе не участвуют. Миниатюрой себя
            // помечает сам `AmbilightArtwork` — см. комментарий у него.
            videoFrame
                .showcasePlaced(at: WatchingGeometry.videoOrigin)

            projectLogo
                .frame(
                    width: WatchingGeometry.logoSize.width,
                    height: WatchingGeometry.logoSize.height,
                    alignment: .bottomLeading
                )
                .offset(x: WatchingGeometry.logoOrigin.x, y: WatchingGeometry.logoOrigin.y)
                .allowsHitTesting(false)

            GlassIconButton(icon: "iconCross", accessibilityTitle: "Скрыть")
                .offset(x: WatchingGeometry.dismissOrigin.x, y: WatchingGeometry.dismissOrigin.y)

            RateBlock()
                .offset(x: WatchingGeometry.rateOrigin.x, y: WatchingGeometry.rateOrigin.y)
        }
        .frame(width: WatchingGeometry.size.width, height: WatchingGeometry.size.height, alignment: .topLeading)
        .onScrollVisibilityChange(threshold: WatchingGeometry.visibilityThreshold) { visible in
            isVisible = visible
            syncPlayback()
        }
        .onChange(of: scenePhase) { _, _ in syncPlayback() }
        .onDisappear { playback.pause() }
    }

    /// Логотип проекта, а если его нет — название текстом.
    ///
    /// Логотипы Кинопоиск раздаёт с `image.tmdb.org`, и он недоступен из России
    /// (замер 2026-08-23: соединение не устанавливается вовсе). Подставлять сюда
    /// чужой моковый логотип нельзя — это была бы прямая ложь о контенте,
    /// поэтому фолбэк текстовый.
    @ViewBuilder
    private var projectLogo: some View {
        ResolvedArtwork(source: block.logo) { image in
            image
                .resizable()
                .scaledToFit()
        } placeholder: {
            Text(block.title)
                .plusHeadline(.s)
                .foregroundStyle(Color.fillOne)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .multilineTextAlignment(.leading)
                .shadow(color: .black.opacity(0.6), radius: 8, y: 2)
        }
    }

    private func syncPlayback() {
        if isVisible, scenePhase == .active {
            playback.start(clip: block.clip)
        } else {
            playback.pause()
        }
    }

    // MARK: Видеокадр

    /// Ореол, постер, видео и подпись — один слой с одним поворотом.
    ///
    /// Поворот обязан быть **общим**: пока кадр и подпись поворачивались каждый своим
    /// `rotationEffect`, они крутились вокруг разных центров и прогресс-бар печатался
    /// двумя разъехавшимися полосами. На нулевом угле дефект пропадал — слои совпадали.
    /// Поэтому и угол, и слои поверх кадра отдаются `AmbilightArtwork` параметрами:
    /// он поворачивает их вместе с обложкой и он же метит получившийся кадр
    /// источником зума.
    ///
    /// Клип по скруглению — только у видео: ореолу нужно торчать за границы кадра,
    /// а подписи хватает отступа 8pt, чтобы не заехать на скругление.
    private var videoFrame: some View {
        let shape = RoundedRectangle(cornerRadius: PlusRadius.card, style: .continuous)

        return AmbilightArtwork(
            source: block.still,
            size: WatchingGeometry.videoSize,
            rotation: WatchingGeometry.videoRotation,
            glowOpacity: WatchingGeometry.ambilightOpacity,
            borderWidth: PlusMetrics.hairline
        ) {
            ClipLayerView(player: playback.queue) { isVideoReady = true }
                .frame(width: WatchingGeometry.videoSize.width, height: WatchingGeometry.videoSize.height)
                .opacity(isVideoReady ? 1 : 0)
                .animation(WatchingGeometry.videoFadeIn, value: isVideoReady)
                .clipShape(shape)
                .allowsHitTesting(false)

            frameCaption
                .allowsHitTesting(false)
        }
    }

    /// Скрим, остаток времени и прогресс — прижаты к низу кадра.
    /// Backdrop-blur 6 у трека из макета не воспроизводим: он лежит на непрозрачном кадре
    /// (визуально no-op), а живой блюр над едущей лентой стоит кадров.
    private var frameCaption: some View {
        VStack(alignment: .leading, spacing: WatchingGeometry.contentGap) {
            Text(block.remaining)
                .plusText(.textS, .medium)
                .foregroundStyle(Color.fillOne)

            PlusProgressBar(progress: block.progress, width: WatchingGeometry.trackWidth)
        }
        .padding(.horizontal, WatchingGeometry.contentInset)
        .padding(.bottom, WatchingGeometry.contentInset)
        .frame(
            width: WatchingGeometry.videoSize.width,
            height: WatchingGeometry.videoSize.height,
            alignment: .bottomLeading
        )
        .background(alignment: .bottom) {
            LinearGradient(
                colors: [.black.opacity(WatchingGeometry.scrimOpacity), .clear],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: WatchingGeometry.scrimHeight)
        }
    }
}

// MARK: - Блок оценки

/// «Что думаешь?»: заголовок по центру и четыре равные колонки «эмодзи + подпись».
/// Тап — реакция (`RateReaction`): кнопка встаёт на белый, вверх улетают эмодзи.
/// Оценка ничего не отправляет и карточку не скрывает.
private struct RateBlock: View {
    private struct Option: Identifiable {
        /// Ассет эмодзи. Картинка, а не глиф шрифта: эмодзи-шрифт симулятора iOS 26.3
        /// рисует вместо них квадраты с «?» (жалоба пользователя 2026-10-03, повторная),
        /// а демо идёт именно на симуляторе. PNG сняты с Apple Color Emoji macOS —
        /// на устройстве глиф был бы тот же.
        let emoji: String
        let label: String
        /// Сколько эмодзи улетает из кнопки — по силе оценки (задача пользователя)
        let burst: Int
        var id: String { label }
    }

    private let options = [
        Option(emoji: "emojiRateDislike", label: "Нет", burst: 1),
        Option(emoji: "emojiRateMeh", label: "Норм", burst: 1),
        Option(emoji: "emojiRateGood", label: "Супер", burst: 2),
        Option(emoji: "emojiRateLove", label: "Шедевр", burst: 6),
    ]

    @State private var selected: String?
    /// Нажатия по кнопкам: каждое — новая стайка эмодзи из этой кнопки
    @State private var launches: [String: Int] = [:]

    /// Эмодзи — 24, как глиф кегля 24 (Title S макета), которым он был текстом.
    private static let emojiSize: CGFloat = 24

    var body: some View {
        VStack(spacing: 0) {
            Text("Что думаешь?")
                .plusHeadline(.s)
                .foregroundStyle(Color.fillOne)
                .padding(.top, RateBlockGeometry.titleTop)
                .padding(.bottom, RateBlockGeometry.titleBottom)

            HStack(spacing: 0) {
                ForEach(options) { option in
                    Button { react(option) } label: { column(option) }
                        .buttonStyle(PressScaleButtonStyle())
                        .overlay(alignment: .top) {
                            RateBalloons(
                                emoji: option.emoji,
                                emojiSize: Self.emojiSize,
                                diameter: RateBlockGeometry.chip,
                                burst: option.burst,
                                launches: launches[option.id] ?? 0
                            )
                            .padding(.top, RateBlockGeometry.columnTop)
                        }
                        .accessibilityLabel(option.label)
                        .accessibilityAddTraits(selected == option.id ? .isSelected : [])
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, RateBlockGeometry.horizontalPadding)
        }
        .padding(.vertical, RateBlockGeometry.verticalPadding)
        .frame(width: RateBlockGeometry.size.width, height: RateBlockGeometry.size.height, alignment: .top)
    }

    private func react(_ option: Option) {
        selected = option.id
        launches[option.id, default: 0] += 1
    }

    private func column(_ option: Option) -> some View {
        VStack(spacing: RateBlockGeometry.columnGap) {
            RateReactionChip(
                emoji: option.emoji,
                isSelected: selected == option.id,
                diameter: RateBlockGeometry.chip,
                emojiSize: Self.emojiSize
            )

            GradientText(option.label, from: .fillOne, to: .white.opacity(0.7))
                .plusText(.textM, .medium)
        }
        .padding(.top, RateBlockGeometry.columnTop)
        .padding(.bottom, RateBlockGeometry.columnBottom)
        .padding(.horizontal, RateBlockGeometry.columnInset)
    }
}

// MARK: - Тихий зацикленный клип

/// Плеер карточки. Item создаётся при первом появлении карточки на экране и живёт дальше:
/// пересобирать его на каждом проходе по ленте дороже, чем держать один `AVQueuePlayer`.
private final class ClipPlayback {
    let queue = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    func start(clip: String) {
        if looper == nil {
            guard let url = Bundle.main.url(forResource: clip, withExtension: "mp4") else { return }
            AmbientAudioSession.configureOnce()
            queue.isMuted = true
            queue.preventsDisplaySleepDuringVideoPlayback = false
            looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
        }
        queue.play()
    }

    func pause() {
        queue.pause()
    }
}

/// Клип в ленте беззвучный, но без категории `.ambient` его старт всё равно оборвёт
/// музыку у пользователя — категорию ставим один раз на приложение.
private enum AmbientAudioSession {
    private static var isConfigured = false

    static func configureOnce() {
        guard !isConfigured else { return }
        isConfigured = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
    }
}

/// Видео как `AVPlayerLayer`: `VideoPlayer` тянет за собой системный контрол-оверлей,
/// которого в карточке быть не должно.
private struct ClipLayerView: UIViewRepresentable {
    let player: AVQueuePlayer
    /// Первый готовый кадр — по нему постер уступает место видео.
    let onReadyForDisplay: () -> Void

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.backgroundColor = .clear
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        context.coordinator.observe(view.playerLayer, onReadyForDisplay)
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var token: NSKeyValueObservation?

        func observe(_ layer: AVPlayerLayer, _ onReady: @escaping () -> Void) {
            token = layer.observe(\.isReadyForDisplay, options: [.initial, .new]) { layer, _ in
                guard layer.isReadyForDisplay else { return }
                DispatchQueue.main.async(execute: onReady)
            }
        }
    }
}

/// Слой плеера — сам корневой слой вью, без вложенного `CALayer` и ручного ресайза.
private final class PlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

#Preview {
    // ScrollView обязателен: без него `onScrollVisibilityChange` не сработает и клип не стартует.
    ScrollView {
        ContinueWatchingCard(block: WatchingBlock(
            id: "yura",
            title: "Здесь был Юра",
            still: .asset("mockVideoStill"),
            clip: "yura",
            logo: .asset("mockLogoYura"),
            progress: 0.815,
            remaining: "Осталось 16 мин"
        ))
    }
    .background(Color.black)
}
