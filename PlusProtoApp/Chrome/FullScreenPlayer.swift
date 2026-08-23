import SwiftUI

// MARK: - Движение

/// Форминг мини-плеера в полноэкранный.
enum FullPlayerMotion {
    /// Одна кривая на весь морф. Длиннее морфа бара (0.32): здесь едет вся площадь
    /// экрана, и на коротком тайминге рост читается как подмена, а не как раскрытие.
    static let morph: Animation = .smooth(duration: 0.5)
    /// Порог свайпа вниз, после которого плеер закрывается.
    static let dismissDistance: CGFloat = 120
    /// Скорость броска, которая закрывает плеер, не доводя до порога.
    static let dismissVelocity: CGFloat = 600
    /// Резина свайпа: за палец идём не один в один, иначе лист улетает от короткого движения.
    static let dragRate: CGFloat = 0.55
    /// Насколько лист подсаживается к концу свайпа — подсказка, что он закроется.
    static let dragScale: CGFloat = 0.06
    /// Возврат листа, если свайп не дотянул до порога.
    static let dragRelease: Animation = .spring(duration: 0.35, bounce: 0.2)
}

/// Геометрия полноэкранного плеера.
private enum FullPlayerGeometry {
    /// Радиус скругления листа в раскрытом виде. Кромка экрана скруглена сильнее,
    /// но лист не должен упираться в неё вплотную.
    static let openCorner: CGFloat = 44
    static let openCoverSize: CGFloat = 300
    static let openCoverTop: CGFloat = 132
    static let openCoverCorner: CGFloat = 24
    /// Подписи под обложкой.
    static let titleTop: CGFloat = 40
    static let titleGap: CGFloat = 4
}

// MARK: - Кадр мини-плеера

/// Кадр мини-плеера на экране — источник морфа.
///
/// Считается аналитически из метрик хрома, а не измеряется у самой пилюли:
/// раскладка бара детерминирована, а измерять анимируемый размер в этом проекте
/// запрещено — однажды это уже повесило рендер на 100% CPU (см. DECISIONS).
enum MiniPlayerFrame {
    static func onScreen(mode: ActionBarMode, hasMusic: Bool, in screen: CGSize) -> CGRect? {
        guard hasMusic, mode == .music || mode == .search, screen.width > 0 else { return nil }

        let margin = PlusMetrics.screenMargin
        // В music плеер занимает остаток бара, в search сжат в круг.
        let width: CGFloat = mode == .music
            ? screen.width - 2 * margin - PlusMetrics.actionBarCompact - PlusMetrics.actionBarGap
            : PlusMetrics.actionBarCompact
        let bottomInset = PlusChromeMetrics.bottomSafeArea
            + PlusChromeMetrics.tabsRowHeight
            + PlusChromeMetrics.actionBarToTabsGap

        return CGRect(
            x: screen.width - margin - width,
            y: screen.height - bottomInset - PlusMetrics.actionBarHeight,
            width: width,
            height: PlusMetrics.actionBarHeight
        )
    }

    /// Кадр обложки внутри мини-плеера.
    static func cover(in pill: CGRect) -> CGRect {
        let side = PlusMetrics.miniPlayerCover
        return CGRect(
            x: pill.minX + ActionBarGeometry.miniPlayerPaddingLeading,
            y: pill.midY - side / 2,
            width: side,
            height: side
        )
    }
}

// MARK: - Слой

/// Полноэкранный плеер, который формится из мини-плеера в action bar.
///
/// Содержимого у него пока нет — по решению пользователя сейчас проектируется
/// только форминг формы. Поэтому лист несёт ровно то, что было в мини-плеере:
/// обложку и подписи. Им некуда исчезнуть по дороге, всё остальное появится позже.
///
/// **Как устроен морф.** В теле считаются только два конечных состояния — кадр
/// пилюли и кадр экрана; интерполирует их сам SwiftUI штатными анимируемыми
/// модификаторами (`frame`, `offset`, `opacity`, радиус фигуры) под одной
/// транзакцией. Ручной прогресс 0…1 через `Animatable`-обёртку здесь не заработал:
/// вью с таким прогрессом не пересобиралось на промежуточных кадрах и лист
/// не появлялся вовсе — при этом та же вёрстка, поднятая сразу в раскрытом
/// состоянии, рисовалась корректно.
struct FullScreenPlayer: View {
    /// Размер экрана приходит снаружи, от `GeometryReader` в корне: свой размер
    /// вью читать нельзя, а `UIScreen.main` в этом месте ненадёжен.
    let screen: CGSize

    /// Состояние читается отсюда, а не приходит параметром: переданное параметром
    /// значение до `body` этого вью не доезжало — корень видел новое, а вью
    /// пересобиралось со старым. Через `@Environment` зависимость регистрирует
    /// само вью, и это единственный путь, который в проекте работает предсказуемо.
    @Environment(ActionBarState.self) private var actionBar

    /// Ход пальца при свайпе вниз. Живёт здесь, а не в `ActionBarState`:
    /// запись 120 раз в секунду в `@Observable` инвалидировала бы весь хром.
    @State private var drag: CGFloat = 0

    var body: some View {
        let open = actionBar.isFullPlayerOpen
        let item = actionBar.music
        let source = MiniPlayerFrame.onScreen(
            mode: actionBar.mode,
            hasMusic: item != nil,
            in: screen
        )

        ZStack(alignment: .topLeading) {
            // Распорка задаёт систему координат, в которой лист сдвигается `offset`.
            Color.clear

            if let item, let source {
                sheet(item: item, source: source, open: open)
            }
        }
        .frame(width: screen.width, height: screen.height, alignment: .topLeading)
        // Свёрнутый лист точно совпадает с пилюлей мини-плеера и был бы её дублем.
        .opacity(open ? 1 : 0)
        .allowsHitTesting(open)
        .animation(FullPlayerMotion.morph, value: open)
    }

    private func sheet(item: MusicNowPlaying, source: CGRect, open: Bool) -> some View {
        let frame = open ? CGRect(origin: .zero, size: screen) : source
        let corner = open ? FullPlayerGeometry.openCorner : PlusMetrics.actionBarHeight / 2
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)

        let coverSide = open ? FullPlayerGeometry.openCoverSize : PlusMetrics.miniPlayerCover
        let coverOrigin: CGPoint = open
            ? CGPoint(
                x: (screen.width - FullPlayerGeometry.openCoverSize) / 2,
                y: FullPlayerGeometry.openCoverTop
            )
            : MiniPlayerFrame.cover(in: source).origin
        let coverCorner = open
            ? FullPlayerGeometry.openCoverCorner
            : PlusMetrics.miniPlayerCover / 2
        let coverShape = RoundedRectangle(cornerRadius: coverCorner, style: .continuous)

        // Свайп вниз: лист идёт за пальцем с резиной и подсаживается — так видно,
        // что отпускание его закроет.
        let pulled = drag * FullPlayerMotion.dragRate
        let shrink = 1 - min(
            FullPlayerMotion.dragScale,
            drag / max(1, screen.height) * FullPlayerMotion.dragScale * 4
        )

        return ZStack(alignment: .topLeading) {
            // Фон листа: от стекла мини-плеера к плотному экрану. Обложка под ним
            // размыта — это и есть амбиент полноэкранного плеера.
            ZStack {
                Color.buttonsPrimary
                ArtworkImage(source: item.cover)
                    .scaledToFill()
                    .frame(width: frame.width, height: frame.height)
                    .blur(radius: PlusMetrics.backdropBlur)
                    .opacity(open ? 1 : 0)
                Color.black.opacity(open ? 0.55 : 0)
            }
            .frame(width: frame.width, height: frame.height)
            .clipShape(shape)
            .overlay { shape.strokeBorder(Color.fillNine, lineWidth: PlusMetrics.hairline) }

            ArtworkImage(source: item.cover)
                .scaledToFill()
                .frame(width: coverSide, height: coverSide)
                .clipShape(coverShape)
                .overlay { coverShape.strokeBorder(Color.fillNine, lineWidth: PlusMetrics.hairline) }
                .offset(x: coverOrigin.x - frame.minX, y: coverOrigin.y - frame.minY)

            // Подписи переезжают из строки мини-плеера под обложку. Кегль не растёт:
            // типографика полноэкранного плеера ещё не спроектирована, и подменять
            // её на глаз — значит потом переделывать.
            VStack(alignment: .leading, spacing: FullPlayerGeometry.titleGap) {
                Text(item.title)
                    .plusTitleL()
                    .foregroundStyle(Color.fillOne)
                Text(item.artist)
                    .plusTextM()
                    .foregroundStyle(Color.fillSubtitle)
            }
            .lineLimit(1)
            .opacity(open ? 1 : 0)
            .offset(
                x: coverOrigin.x - frame.minX,
                y: coverOrigin.y + coverSide + FullPlayerGeometry.titleTop - frame.minY
            )
        }
        .frame(width: frame.width, height: frame.height, alignment: .topLeading)
        .scaleEffect(shrink, anchor: .center)
        .offset(x: frame.minX, y: frame.minY + pulled)
        .contentShape(shape)
        .gesture(dismissGesture)
    }

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            // Без withAnimation: лист идёт за пальцем, догонять его пружиной нельзя.
            .onChanged { drag = max(0, $0.translation.height) }
            .onEnded { value in
                let closing = value.translation.height > FullPlayerMotion.dismissDistance
                    || value.velocity.height > FullPlayerMotion.dismissVelocity
                if closing {
                    // Ход пальца снимаем без анимации: иначе он сложился бы с морфом
                    // и лист уехал бы вниз мимо пилюли.
                    drag = 0
                    actionBar.isFullPlayerOpen = false
                } else {
                    withAnimation(FullPlayerMotion.dragRelease) { drag = 0 }
                }
            }
    }
}
