import SwiftUI

/// Подборка Таскалки — шторка во всю ширину экрана: карусели витрин рассчитаны
/// на ширину экрана, в карточке с полями они бы не встали. Над шторкой остаётся фраза
/// карточки — она и есть заголовок подборки.
///
/// Шторка всегда в дереве и только уезжает за нижнюю кромку: морф на живой вью, без
/// `if`. Закрывается свайпом вниз за ручку или тапом по фразе — назад к полю, где
/// осталось место выбора.
struct TaskalkaSheet: View {
    let open: (EntityRoute) -> Void

    @Environment(KeyboardObserver.self) private var keyboard
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Ход шторки за пальцем вниз; вверх — с сопротивлением.
    @State private var drag: CGFloat = 0
    /// Разделы встали — лесенкой после старта шторки. Снимается, когда шторка уехала:
    /// уезжает она с содержимым, а не пустой.
    @State private var isRevealed = false
    /// Порог закрытия пройден — тик на пересечении, а не на каждом событии.
    @State private var isPastThreshold = false

    private var session: TaskalkaSession { .shared }
    private var catalog: TaskalkaCatalog { .shared }

    private enum Layout {
        static let radius: CGFloat = 24
        /// Зона ручки — за неё шторку тянут. Лента начинается под ней, а при скролле
        /// уходит под неё до самого верха шторки (правка пользователя 2026-11-01).
        static let grabberZone: CGFloat = 24
        /// Затухание ленты у верхней кромки — лёгкое, чуть выше зоны ручки: в покое оно
        /// не задевает первый раздел (у того свои поля сверху).
        static let fadeHeight: CGFloat = 32
        static let grabber = CGSize(width: 36, height: 5)
        static let grabberTop: CGFloat = 8
        /// Разделы встают снизу на столько
        static let sectionRise: CGFloat = 12
        /// Тень над кромкой — размытый силуэт верха шторки, а не `shadow`: живая тень на
        /// шторке во весь экран пересчитывается на каждом кадре выезда. Силуэтом, а не
        /// прямоугольной полосой градиента: у полосы в вырезах скруглённых углов торчали
        /// квадратные тёмные углы (замечание пользователя 2026-11-01).
        static let shadeBand: CGFloat = 64
        static let shadeBlur: CGFloat = 12
        static let shadeLift: CGFloat = 4
        static let shadeOpacity: Double = 0.5
    }

    private enum Drag {
        /// Закрыть: дотянуть или бросить с разгона
        static let distance: CGFloat = 110
        static let projected: CGFloat = 240
        /// Вверх шторка идёт вчетверо медленнее пальца и не дальше потолка
        static let upResistance: CGFloat = 4
        static let upCeiling: CGFloat = 24
        static let settle: Animation = .spring(response: 0.35, dampingFraction: 0.86)
        /// За такой ход вниз поле под шторкой проявляется целиком
        static let fieldReveal: CGFloat = 240
    }

    var body: some View {
        let isShown = session.isSheetShown
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: Layout.radius,
            topTrailingRadius: Layout.radius,
            style: .continuous
        )
        ZStack(alignment: .top) {
            content
            // Затухание — градиентом цвета самой шторки поверх ленты, а не `.mask` на ней:
            // фон сплошной, вид тот же, а маска уводила бы всю ленту с каруселями
            // в отдельный проход отрисовки на каждом кадре скролла.
            LinearGradient(
                colors: [Color.surfaceTwo, Color.surfaceTwo.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: Layout.fadeHeight)
            .allowsHitTesting(false)
            grabber
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.surfaceTwo, in: shape)
        .clipShape(shape)
        .overlay { shape.stroke(Color.fillNine, lineWidth: PlusMetrics.hairline) }
        .background(alignment: .top) {
            shape
                .fill(Color.black.opacity(Layout.shadeOpacity))
                .frame(height: Layout.shadeBand)
                .blur(radius: Layout.shadeBlur)
                .offset(y: -Layout.shadeLift)
                .allowsHitTesting(false)
        }
        // С «уменьшением движения» — только прозрачность.
        .offset(y: reduceMotion ? 0 : (isShown ? drag : hiddenOffset))
        .opacity(reduceMotion && !isShown ? 0 : 1)
        .ignoresSafeArea(.container, edges: .bottom)
        .allowsHitTesting(isShown)
        .accessibilityHidden(!isShown)
        .task(id: isShown) {
            if isShown {
                isRevealed = true
                return
            }
            // Уехала — разделы прячутся без анимации, к следующему выезду.
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                isRevealed = false
                drag = 0
            }
        }
    }

    /// За нижней кромкой с запасом под тень: на высоту экрана — константу процесса,
    /// приложение заперто в портрете.
    private var hiddenOffset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.effectiveGeometry.coordinateSpace.bounds.height ?? 2 * PlusMetrics.screenWidth
    }

    // MARK: - Ручка

    private var grabber: some View {
        Capsule()
            .fill(Color.fillSeven)
            .frame(width: Layout.grabber.width, height: Layout.grabber.height)
            .padding(.top, Layout.grabberTop)
            .frame(maxWidth: .infinity, minHeight: Layout.grabberZone, alignment: .top)
            .contentShape(.rect)
            .gesture(dragGesture)
            .onTapGesture { session.closeSheet() }
            .accessibilityElement()
            .accessibilityLabel(TaskalkaCopy.grabberLabel)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { session.closeSheet() }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let dy = value.translation.height
                // За пальцем 1:1 вниз; вверх — с сопротивлением и мягким потолком.
                drag = dy >= 0 ? dy : -min(Drag.upCeiling, -dy / Drag.upResistance)
                session.sheetPull = min(1, max(0, dy) / Drag.fieldReveal)
                let past = dy > Drag.distance
                if past != isPastThreshold {
                    isPastThreshold = past
                    UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
                }
            }
            .onEnded { value in
                isPastThreshold = false
                if value.translation.height > Drag.distance || value.predictedEndTranslation.height > Drag.projected {
                    session.closeSheet()
                } else {
                    withAnimation(Drag.settle) {
                        drag = 0
                        session.sheetPull = 0
                    }
                }
            }
    }

    // MARK: - Содержимое

    @ViewBuilder
    private var content: some View {
        if let mood = session.chosen {
            let selection = catalog.selection(for: mood) ?? TaskalkaCatalog.Selection()
            ScrollView {
                VStack(spacing: 0) {
                    music(mood, selection.tracks)
                        .modifier(Reveal(index: 0, isRevealed: isRevealed, reduceMotion: reduceMotion))
                    movies(selection.movies)
                        .modifier(Reveal(index: 1, isRevealed: isRevealed, reduceMotion: reduceMotion))
                    books(selection.books)
                        .modifier(Reveal(index: 2, isRevealed: isRevealed, reduceMotion: reduceMotion))
                    if selection.isEmpty {
                        Text(TaskalkaCopy.empty)
                            .plusText(.textL, .semibold)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.fillSeven)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 64)
                    }
                }
                .padding(.bottom, bottomInset)
            }
            .scrollIndicators(.hidden)
            // В покое лента — под ручкой; при скролле уходит под неё до верха шторки.
            .contentMargins(.top, Layout.grabberZone, for: .scrollContent)
            // Новое настроение — лента с начала.
            .id(mood.id)
        }
    }

    @ViewBuilder
    private func music(_ mood: TaskalkaMood, _ tracks: [MusicNowPlaying]?) -> some View {
        if let tracks {
            if !tracks.isEmpty {
                MusicOpenPlaylistCard(title: TaskalkaCopy.music, tracks: tracks)
            }
        } else {
            TaskalkaPlaylistSkeleton()
        }
    }

    @ViewBuilder
    private func movies(_ titles: [CinemaCatalog.Title]?) -> some View {
        if let titles {
            if !titles.isEmpty {
                CinemaPosterCarousel(title: TaskalkaCopy.movies, titles: titles, showsChevron: false, onOpen: open)
            }
        } else {
            CinemaRowSkeleton(title: TaskalkaCopy.movies)
        }
    }

    @ViewBuilder
    private func books(_ items: [BooksHomeCatalog.Book]?) -> some View {
        if let items {
            if !items.isEmpty {
                BooksCarousel(title: TaskalkaCopy.books, books: items, showsChevron: false, onOpen: open)
            }
        } else {
            BooksRowSkeleton(title: TaskalkaCopy.books)
        }
    }

    /// Низ ленты — над баром поиска: с клавиатурой — над ней, без — над местом таббара.
    /// Шторка доходит до физического низа экрана, отсчёт — от него.
    private var bottomInset: CGFloat {
        let bar = PlusMetrics.actionBarHeight + TaskalkaLayout.barGap
        return keyboard.isUp
            ? keyboard.overlap + PlusChromeMetrics.focusKeyboardGap + bar
            : PlusChromeMetrics.chromeBottom + bar
    }

    /// Раздел встаёт снизу с проявлением, лесенкой за предыдущим.
    private struct Reveal: ViewModifier {
        let index: Int
        let isRevealed: Bool
        let reduceMotion: Bool

        func body(content: Content) -> some View {
            content
                .opacity(isRevealed ? 1 : 0)
                .offset(y: isRevealed || reduceMotion ? 0 : Layout.sectionRise)
                .animation(
                    TaskalkaMotion.section.delay(TaskalkaMotion.sectionDelay + Double(index) * TaskalkaMotion.sectionStagger),
                    value: isRevealed
                )
        }
    }
}

/// Скелетон «Открытого плейлиста» — той же геометрии (`MusicOpenPlaylistLayout`):
/// пришедшие треки встают на его место, лента под ним не сдвигается.
private struct TaskalkaPlaylistSkeleton: View {
    private typealias Layout = MusicOpenPlaylistLayout

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Layout.radius, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Layout.headerGap) {
                Circle()
                    .plusSkeleton()
                    .frame(width: Layout.playButton.height, height: Layout.playButton.height)
                SkeletonBar(width: 140, height: 24)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Layout.side)
            .padding(.bottom, Layout.headerBottom)

            VStack(spacing: 0) {
                ForEach(0..<Layout.tracksPerColumn, id: \.self) { _ in
                    EntityTrackRowSkeleton()
                }
            }
            .padding(.vertical, -Layout.rowInset)
            .padding(.horizontal, Layout.side)
            .frame(height: Layout.columnHeight, alignment: .top)
        }
        .padding(.vertical, Layout.verticalPadding)
        .frame(maxWidth: .infinity)
        .background(Color.fillNine, in: shape)
        .padding(Layout.side)
        .accessibilityHidden(true)
    }
}
