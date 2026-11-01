import SwiftUI

// MARK: - Геометрия

/// Габариты Таскалки. Макета нет — числа взяты у соседей по поиску, карта поля — от ширины
/// экрана (правило 4 CLAUDE.md). Ни карточки вокруг фразы и поля, ни рамки у самого поля
/// нет (правки пользователя 2026-10-31 и 2026-11-01): сетка точек стоит прямо на затемнении
/// поиска, по его полям 16, без внутренних отступов.
enum TaskalkaLayout {
    /// Поля экрана поиска (`SearchResultsView.Layout.side`)
    static let side: CGFloat = 16
    /// Фраза встаёт под статус-баром там же, где первый заголовок выдачи
    static let top: CGFloat = 8
    /// До верха бара поиска, опущенного на место таббара (`SearchResultsView.Layout.barGap`)
    static let barGap: CGFloat = 12
    /// Фраза → поле точек. Подписи под фразой нет (правка пользователя 2026-11-01), поле
    /// поднялось на её место; зазор — как у заголовка секции выдачи до карусели
    /// (`SearchResultsView.Layout.headerBottom`).
    static let headerGap: CGFloat = 12
    /// Подписи осей стоят в крайних рядах сетки, точки под ними вырезаны — с этим запасом
    /// вокруг текста.
    static let labelClearance: CGFloat = 6

    /// Шапка: две строки фразы — место держится всегда, слово меняется, раскладка нет.
    static var headerHeight: CGFloat {
        2 * PlusHeadline.m.lineHeight + headerGap
    }

    /// Низ поля — над баром поиска на месте таббара, **с клавиатурой и без**: поле
    /// уходит под клавиатуру и открывается целиком, когда касание её опускает (правка
    /// пользователя 2026-10-31). От нижней безопасной зоны — по ней кончается кадр слоя.
    @MainActor
    static var bottomInset: CGFloat {
        max(0, PlusChromeMetrics.chromeBottom + PlusMetrics.actionBarHeight + barGap - PlusChromeMetrics.bottomSafeArea)
    }

    /// Фраза, пока открыта подборка, отходит вглубь — как экран под шторкой iOS. Поле под
    /// шторкой гаснет (иначе его край выглядывал в вырезы её скруглённых углов)
    /// и проявляется, пока шторку тянут вниз (`TaskalkaSession.sheetPull`).
    static let backScale: CGFloat = 0.96
}

/// Сетка точек поля. Столбцов — постоянное число, крайние стоят ровно по кромкам поля —
/// по полям 16, на одной линии с фразой и баром (правка пользователя 2026-11-01: полшага
/// отступа по бокам читались лишним полем); шаг — от ширины поля. Строк — сколько влезет
/// тем же шагом, остаток делится поровну. Ячейка — для тиков хаптики.
enum TaskalkaGrid {
    /// Двенадцать: шаг тот же, что был у одиннадцати с полушагом по краям (~34 pt).
    static let columns = 12
    /// Крайние столбцы отступают на радиус точки в покое: по полям 16 встаёт внешняя кромка
    /// точки, а не её центр (правка пользователя 2026-11-01: «отступ меньше 16»).
    static var edgeInset: CGFloat { TaskalkaDotsStyle.restRadius }

    struct Cell: Equatable {
        var column: Int
        var row: Int
    }

    struct Metrics {
        let pitchX: CGFloat
        let pitchY: CGFloat
        let rows: Int
    }

    static func metrics(for size: CGSize) -> Metrics {
        let pitchX = (size.width - 2 * edgeInset) / CGFloat(columns - 1)
        let rows = max(3, Int((size.height / max(pitchX, 1)).rounded(.down)))
        return Metrics(pitchX: pitchX, pitchY: size.height / CGFloat(rows), rows: rows)
    }

    /// Ближайшая точка сетки к месту на поле (в пунктах).
    static func cell(at location: CGPoint, in size: CGSize) -> Cell {
        let grid = metrics(for: size)
        return Cell(
            column: min(columns - 1, max(0, Int(((location.x - edgeInset) / grid.pitchX).rounded()))),
            row: min(grid.rows - 1, max(0, Int(location.y / grid.pitchY)))
        )
    }
}

/// Рисунок поля — точки, свечение, вступительная волна.
private enum TaskalkaDotsStyle {
    /// Точка в покое и под самым пальцем — радиусы
    static let restRadius: CGFloat = 1.3
    /// Под пальцем — до предела: диаметр 26 при шаге сетки ~30, соседи не слипаются
    /// (шара под пальцем нет — точки и есть отклик, правка пользователя 2026-10-31)
    static let peakRadius: CGFloat = 13
    /// Дальность влияния пальца, pt (сигма гауссианы)
    static let reach: CGFloat = 62
    /// Точки под пальцем чуть расступаются от него — палец раздвигает «водоросли»,
    /// а не стягивает их к себе (`TaskalkaFlow`). Слабо: крупные точки наезжали бы на соседей
    static let push: CGFloat = 0.08
    /// Холст шире поля на столько с каждой стороны: крайние столбцы стоят по кромке,
    /// и набухшая и качнувшаяся точка не должна срезаться кадром холста (радиус 13,
    /// размытый край +⅓, вытянута в полтора раза, отклонена до 13)
    static let bleed: CGFloat = 48
    /// Точки в покое — белый 30 % (`fillSeven`), под пальцем — цвет настроения, осветлённый,
    /// чтобы на тёмном светился, а не тонул
    static let lighten: Double = 0.3
    /// Свечение под пальцем: радиус — доля ширины поля, прозрачность в центре
    static let glowReach: CGFloat = 0.7
    static let glowOpacity: Double = 0.5
    /// Спад ореола — колокол e^(−k·r²), а не ломаная: у ломаной на внешнем крае излом,
    /// и глаз видел границу круга (правка пользователя 2026-11-01). Было 0.85 ширины.
    static let glowFalloff: Double = 4.5
    static let glowStops = 8
    /// Вступительная волна по точкам — раз за процесс
    static let rippleDelay: Double = 0.35
    static let rippleDuration: Double = 1.5
    static let rippleWidth: CGFloat = 28
    /// Насколько волна раздувает точку на гребне: заметно, но не до набухания под пальцем
    /// (правка пользователя 2026-11-01: «чуть заметнее»; было 2.2)
    static let rippleRadius: CGFloat = 3.6
}

// MARK: - Фраза и поле

/// Таскалка без шторки: фраза сверху, поле точек под ней. Вся геометрия — от кадра, который
/// даёт родитель; собственный размер вью не читает.
struct TaskalkaCard: View {
    @Environment(ActionBarState.self) private var actionBar
    @Environment(KeyboardObserver.self) private var keyboard
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Течение идёт: палец на поле или колебания ещё не улеглись (`TaskalkaFlow.window`).
    /// Меняется дважды за жест, не на кадре; общее у точек и подписей осей.
    @State private var isFlowing = false

    private var session: TaskalkaSession { .shared }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let panel = CGRect(
                x: 0,
                y: TaskalkaLayout.headerHeight,
                width: max(1, size.width),
                height: max(1, size.height - TaskalkaLayout.headerHeight)
            )
            ZStack(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    TaskalkaLight(panel: panel)
                    TaskalkaGlow(panel: panel, isFlowing: isFlowing && !reduceMotion)
                    TaskalkaAxisLabels(panel: panel, isFlowing: isFlowing && !reduceMotion)
                }
                .opacity(session.isSheetShown ? session.sheetPull : 1)

                TaskalkaHeader()
                    .frame(width: size.width, height: TaskalkaLayout.headerHeight, alignment: .topLeading)

                TaskalkaTouchArea(panel: panel)
            }
        }
        .scaleEffect(session.isSheetShown && !reduceMotion ? TaskalkaLayout.backScale : 1, anchor: .top)
        .task(id: session.phase) {
            if session.phase == .picking {
                isFlowing = true
                return
            }
            try? await Task.sleep(for: .seconds(TaskalkaFlow.window))
            guard !Task.isCancelled else { return }
            isFlowing = false
        }
    }
}

// MARK: - Шапка

/// «Хочется чего-нибудь / под плед». Слово сменяется через блюр — палец водит быстро,
/// последовательная смена не успевала бы за ним.
private struct TaskalkaHeader: View {
    private var session: TaskalkaSession { .shared }

    var body: some View {
        let mood = session.mood
        VStack(alignment: .leading, spacing: 0) {
            Text(TaskalkaCopy.lead)
                .plusHeadline(.m)
                .foregroundStyle(Color.fillOne)
                .frame(height: PlusHeadline.m.lineHeight, alignment: .leading)

            ZStack(alignment: .leading) {
                Text(mood?.word ?? TaskalkaCopy.idleWord)
                    .plusHeadline(.m)
                    .foregroundStyle(mood.map { AnyShapeStyle($0.wordGradient) } ?? AnyShapeStyle(Color.fillSeven))
                    .id(mood?.id)
                    .transition(.blurReplace)
            }
            .frame(height: PlusHeadline.m.lineHeight, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, TaskalkaLayout.headerGap)
        .contentShape(.rect)
        // Пока открыта подборка, фраза — её заголовок, а тап по ней — «назад к полю».
        .onTapGesture { session.closeSheet() }
        .allowsHitTesting(session.isSheetShown)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(session.isSheetShown ? [.isHeader, .isButton] : .isHeader)
        .accessibilityHint(session.isSheetShown ? TaskalkaCopy.backHint : "")
    }
}

// MARK: - Подписи осей

/// Подписи осей — в крайних рядах и столбцах сетки, по их середине: точки под текстом
/// вырезаны (`knockouts`), подпись встаёт в ряд вместо них.
private struct TaskalkaAxisLabels: View {
    let panel: CGRect
    /// Течение идёт — подписи качаются вместе с точками (правка пользователя 2026-11-01:
    /// «тот же офсет и для подписей»): то же отклонение от пальца и то же покачивание.
    let isFlowing: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var session: TaskalkaSession { .shared }

    var body: some View {
        let energy: CGFloat = switch session.phase {
        case .idle: 0
        case .picking: 1
        case .chosen: 0.5
        }
        let finger = CGPoint(x: panel.minX + session.point.x * panel.width, y: panel.minY + session.point.y * panel.height)
        TimelineView(.animation(minimumInterval: nil, paused: !isFlowing)) { context in
            let now = context.date.timeIntervalSinceReferenceDate
            let impulses = isFlowing ? session.flow.resolved(in: panel, now: now) : []
            ZStack(alignment: .topLeading) {
                ForEach(Self.placements(in: panel), id: \.text) { placement in
                    label(placement.text)
                        .rotationEffect(.degrees(placement.rotation))
                        .position(placement.center)
                        .offset(offset(of: placement.center, finger: finger, energy: energy, impulses: impulses, now: now))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Сдвиг подписи — тот же, что у точки на её месте (`TaskalkaDots`): «расступиться»
    /// от пальца и покачивание течением.
    private func offset(
        of center: CGPoint,
        finger: CGPoint,
        energy: CGFloat,
        impulses: [TaskalkaFlow.Resolved],
        now: TimeInterval
    ) -> CGSize {
        guard !reduceMotion else { return .zero }
        let dx = center.x - finger.x, dy = center.y - finger.y
        let touch = exp(-(dx * dx + dy * dy) / (TaskalkaDotsStyle.reach * TaskalkaDotsStyle.reach)) * energy
        let sway = impulses.isEmpty
            ? TaskalkaFlow.Sway()
            : TaskalkaFlow.sway(at: Double(center.x), Double(center.y), impulses: impulses, now: now)
        return CGSize(
            width: dx * TaskalkaDotsStyle.push * touch + CGFloat(sway.dx),
            height: dy * TaskalkaDotsStyle.push * touch + CGFloat(sway.dy)
        )
    }

    struct Placement {
        let text: String
        let center: CGPoint
        let rotation: Double
    }

    static func placements(in panel: CGRect) -> [Placement] {
        let grid = TaskalkaGrid.metrics(for: panel.size)
        return [
            Placement(text: TaskalkaCopy.axisUp, center: CGPoint(x: panel.midX, y: panel.minY + grid.pitchY / 2), rotation: 0),
            Placement(text: TaskalkaCopy.axisDown, center: CGPoint(x: panel.midX, y: panel.maxY - grid.pitchY / 2), rotation: 0),
            // Боковые подписи — верхом заглавных по кромке поля, как и точки: по центру столбца
            // половина текста вылезала за поля 16, а по рамке строки буквы отступали на ~3.
            Placement(text: TaskalkaCopy.axisLeft, center: CGPoint(x: panel.minX + sideLabelCenter, y: panel.midY), rotation: -90),
            Placement(text: TaskalkaCopy.axisRight, center: CGPoint(x: panel.maxX - sideLabelCenter, y: panel.midY), rotation: 90),
        ]
    }

    /// От кромки поля до середины строки повёрнутой подписи: половина строки минус зазор
    /// от её верха до верха заглавных — его дают поле строки стиля (`FigmaTextStyle`)
    /// и выносной элемент шрифта над заглавными. Замер — шрифтом стиля.
    private static let sideLabelCenter: CGFloat = {
        let font = PlusTextSize.textS.uiFont(.medium)
        let lineHeight = PlusTextSize.textS.lineHeight
        let capGap = (lineHeight - font.lineHeight) / 2 + (font.ascender - font.capHeight)
        return lineHeight / 2 - capGap
    }()

    /// Где точки не рисуются: рамка каждой подписи с запасом. Ширина текста — замером
    /// шрифтом стиля (`uiFont`), один раз за процесс.
    static func knockouts(in panel: CGRect) -> [CGRect] {
        placements(in: panel).map { placement in
            let width = textWidths[placement.text] ?? 0
            let height = PlusTextSize.textS.lineHeight
            let size = placement.rotation == 0 ? CGSize(width: width, height: height) : CGSize(width: height, height: width)
            return CGRect(
                x: placement.center.x - size.width / 2,
                y: placement.center.y - size.height / 2,
                width: size.width,
                height: size.height
            ).insetBy(dx: -TaskalkaLayout.labelClearance, dy: -TaskalkaLayout.labelClearance)
        }
    }

    private static let textWidths: [String: CGFloat] = {
        let attributes: [NSAttributedString.Key: Any] = [.font: PlusTextSize.textS.uiFont(.medium)]
        let texts = [TaskalkaCopy.axisUp, TaskalkaCopy.axisDown, TaskalkaCopy.axisLeft, TaskalkaCopy.axisRight]
        return Dictionary(uniqueKeysWithValues: texts.map { ($0, ceil(($0 as NSString).size(withAttributes: attributes).width)) })
    }()

    private func label(_ text: String) -> some View {
        Text(text)
            // Text S Medium — 13 (правка пользователя 2026-10-31)
            .plusText(.textS, .medium)
            .foregroundStyle(Color.fillSeven)
            .fixedSize()
    }
}

// MARK: - Свечение и точки

/// Слой, читающий точку пальца: от неё перерисовывается только он.
private struct TaskalkaGlow: View {
    let panel: CGRect

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Старт вступительной волны; `nil` — её нет, таймлайн стоит.
    @State private var rippleStart: Date?
    let isFlowing: Bool

    private var session: TaskalkaSession { .shared }

    var body: some View {
        let energy: CGFloat = switch session.phase {
        case .idle: 0
        case .picking: 1
        case .chosen: 0.5
        }
        TaskalkaDots(
            point: session.point,
            energy: energy,
            panel: panel,
            rippleStart: rippleStart,
            flow: session.flow,
            isFlowing: isFlowing,
            pushesApart: !reduceMotion
        )
            .allowsHitTesting(false)
            .task {
                guard !session.didIntro, !reduceMotion else { return }
                session.didIntro = true
                let start = Date.now.addingTimeInterval(TaskalkaDotsStyle.rippleDelay)
                rippleStart = start
                try? await Task.sleep(for: .seconds(TaskalkaDotsStyle.rippleDelay + TaskalkaDotsStyle.rippleDuration))
                rippleStart = nil
            }
    }
}

/// Свечение под пальцем — цветом настроения. Отдельным вью, а не в `Canvas` точек: рамки
/// у поля нет, и холст обрывал бы пятно прямоугольником по своему кадру, а вью рисуется
/// и за кадром родителя — под фразой, шторкой и баром. Позиция и яркость приходят теми же
/// анимациями, что точки (`TaskalkaMotion`), поэтому пятно идёт с ними одним движением.
private struct TaskalkaLight: View {
    let panel: CGRect

    private var session: TaskalkaSession { .shared }
    private typealias Style = TaskalkaDotsStyle

    var body: some View {
        let energy: Double = switch session.phase {
        case .idle: 0
        case .picking: 1
        case .chosen: 0.5
        }
        let point = session.point
        let tone = TaskalkaPalette.color(TaskalkaMap.color(at: point))
        let radius = panel.width * Style.glowReach
        Circle()
            .fill(RadialGradient(
                stops: Self.stops(tone),
                center: .center,
                startRadius: 0,
                endRadius: radius
            ))
            .frame(width: 2 * radius, height: 2 * radius)
            .position(x: panel.minX + point.x * panel.width, y: panel.minY + point.y * panel.height)
            .opacity(energy)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// Колокол прозрачности по радиусу; на самом крае — ровно ноль.
    private static func stops(_ tone: Color) -> [Gradient.Stop] {
        (0...Style.glowStops).map { index in
            let r = Double(index) / Double(Style.glowStops)
            let alpha = index == Style.glowStops ? 0 : Style.glowOpacity * exp(-Style.glowFalloff * r * r)
            return Gradient.Stop(color: tone.opacity(alpha), location: r)
        }
    }
}

/// Точки одним `Canvas`. Точка пальца и «энергия» (0 — покой, 1 — палец
/// на поле, 0.5 — место выбора) анимируемые: касание, ведение и отпускание приходят
/// своими кривыми (`TaskalkaMotion`), и рисунок интерполируется плавно.
/// Покадрово по времени — только вступительная волна, в покое таймлайн стоит.
private struct TaskalkaDots: View, Animatable {
    var point: CGPoint
    var energy: CGFloat
    let panel: CGRect
    let rippleStart: Date?
    let flow: TaskalkaFlow
    let isFlowing: Bool
    /// С «уменьшением движения» точки не расступаются и не качаются — только набухают.
    let pushesApart: Bool

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(point.x, point.y), energy) }
        set {
            point = CGPoint(x: newValue.first.first, y: newValue.first.second)
            energy = newValue.second
        }
    }

    private typealias Style = TaskalkaDotsStyle

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: rippleStart == nil && !isFlowing)) { context in
            let ripple = rippleProgress(at: context.date)
            let now = context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                draw(in: &canvas, size: size, ripple: ripple, now: now)
            }
            // Шире поля: крайние точки по кромке набухают и качаются за неё.
            .padding(-Style.bleed)
        }
    }

    private func rippleProgress(at date: Date) -> CGFloat? {
        guard let rippleStart else { return nil }
        let raw = date.timeIntervalSince(rippleStart) / Style.rippleDuration
        guard raw >= 0, raw < 1 else { return nil }
        return CGFloat(raw)
    }

    private func draw(in canvas: inout GraphicsContext, size: CGSize, ripple: CGFloat?, now: TimeInterval) {
        // Холст сдвинут на `bleed` влево-вверх — поле в его координатах.
        let panel = self.panel.offsetBy(dx: Style.bleed, dy: Style.bleed)
        let finger = CGPoint(x: panel.minX + point.x * panel.width, y: panel.minY + point.y * panel.height)
        // Течение: толчки последних `window` секунд; в покое их нет и считать нечего.
        let impulses = isFlowing ? flow.resolved(in: panel, now: now) : []
        let push = pushesApart ? Style.push : 0

        // Точки. Спокойные — одним путём, одной заливкой; задетые пальцем или волной —
        // по одной, своим цветом. Под подписями осей точек нет.
        let knockouts = TaskalkaAxisLabels.knockouts(in: panel)
        let grid = TaskalkaGrid.metrics(for: panel.size)
        let center = CGPoint(x: panel.midX, y: panel.midY)
        let rippleFront = ripple.map { $0 * hypot(panel.width, panel.height) / 2 }
        var rest = Path()
        for row in 0..<grid.rows {
            for column in 0..<TaskalkaGrid.columns {
                let dot = CGPoint(
                    x: panel.minX + TaskalkaGrid.edgeInset + CGFloat(column) * grid.pitchX,
                    y: panel.minY + (CGFloat(row) + 0.5) * grid.pitchY
                )
                let dx = dot.x - finger.x, dy = dot.y - finger.y
                let touch = exp(-(dx * dx + dy * dy) / (Style.reach * Style.reach)) * energy
                var wave: CGFloat = 0
                if let ripple, let rippleFront {
                    let distance = hypot(dot.x - center.x, dot.y - center.y) - rippleFront
                    wave = exp(-(distance * distance) / (Style.rippleWidth * Style.rippleWidth)) * (1 - ripple)
                }
                guard !knockouts.contains(where: { $0.contains(dot) }) else { continue }
                let sway = impulses.isEmpty
                    ? TaskalkaFlow.Sway()
                    : TaskalkaFlow.sway(at: Double(dot.x), Double(dot.y), impulses: impulses, now: now)
                // Своё место + «расступиться» от пальца + покачивание течением.
                let placed = CGPoint(
                    x: dot.x + dx * push * touch + CGFloat(sway.dx),
                    y: dot.y + dy * push * touch + CGFloat(sway.dy)
                )
                guard touch > 0.02 || wave > 0.02 else {
                    rest.addEllipse(in: CGRect(
                        x: placed.x - Style.restRadius, y: placed.y - Style.restRadius,
                        width: 2 * Style.restRadius, height: 2 * Style.restRadius
                    ))
                    continue
                }
                let radius = Style.restRadius + (Style.peakRadius - Style.restRadius) * touch + Style.rippleRadius * wave
                let own = CGPoint(x: (dot.x - panel.minX) / panel.width, y: (dot.y - panel.minY) / panel.height)
                let lit = TaskalkaMap.color(at: own) * (1 - Style.lighten) + SIMD3(repeating: Style.lighten)
                let share = Double(min(1, touch * 1.6))
                // От белого 30 % покоя — к цвету настроения; волна только чуть подсвечивает.
                let rgb = SIMD3<Double>(repeating: 1) * (1 - share) + lit * share
                let opacity = 0.3 + 0.7 * share + 0.35 * Double(wave)
                Self.drawBlob(
                    in: &canvas,
                    at: placed,
                    radius: radius,
                    sway: sway,
                    color: TaskalkaPalette.color(rgb, opacity: min(1, opacity))
                )
            }
        }
        canvas.fill(rest, with: .color(Color.fillSeven))
    }

    /// Точка в движении вытягивается вдоль своей скорости и сужается поперёк — площадь та же;
    /// в покое снова круг. Так качание читается как упругий лист, а не как сдвиг кружка.
    ///
    /// И размывается по скорости (просьба пользователя 2026-11-01): плотное ядро сужается,
    /// мягкий край растёт, а ядро сдвинуто вперёд по ходу — передний край чётче, хвост
    /// мягче, как прогрессивный блюр. Градиентом, а не фильтром `blur`: фильтр — отдельный
    /// проход по всему холсту на каждую точку, десятки проходов на кадре.
    private static func drawBlob(
        in canvas: inout GraphicsContext,
        at center: CGPoint,
        radius: CGFloat,
        sway: TaskalkaFlow.Sway,
        color: Color
    ) {
        typealias Flow = TaskalkaFlowStyle
        let speed = (sway.vx * sway.vx + sway.vy * sway.vy).squareRoot()
        let stretch = CGFloat(1 + min(Flow.maxStretch, speed / Flow.stretchSpeed))
        let blur = CGFloat(min(Flow.maxBlur, speed / Flow.blurSpeed))
        guard stretch > 1.02 || blur > 0.03 else {
            canvas.fill(
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius)),
                with: .color(color)
            )
            return
        }
        // Ось x — вдоль движения: растяжение и сдвиг ядра идут по ней.
        var blob = canvas
        blob.translateBy(x: center.x, y: center.y)
        blob.rotate(by: .radians(atan2(sway.vy, sway.vx)))
        blob.scaleBy(x: stretch, y: 1 / stretch.squareRoot())
        // Мягкий край наращивает круг — видимая масса точки та же.
        let outer = radius * (1 + Flow.blurGrowth * blur)
        let core = max(0, 1 - Flow.blurCore * blur)
        let lead = outer * Flow.blurLead * blur
        blob.fill(
            Path(ellipseIn: CGRect(x: -outer, y: -outer, width: 2 * outer, height: 2 * outer)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: color, location: 0),
                    .init(color: color, location: core),
                    .init(color: color.opacity(0), location: 1),
                ]),
                center: CGPoint(x: lead, y: 0),
                startRadius: 0,
                endRadius: outer + lead
            )
        )
    }
}

// MARK: - Касание

/// Зона пальца — поле точек. Шара под пальцем нет (правка пользователя 2026-10-31):
/// отвечают сами точки — под пальцем набухают до предела (`TaskalkaDots`), после
/// отпускания остаются набухшими вполовину на месте выбора.
private struct TaskalkaTouchArea: View {
    let panel: CGRect

    @Environment(ActionBarState.self) private var actionBar
    @Environment(KeyboardObserver.self) private var keyboard
    /// Палец на поле. `GestureState`, а не `onEnded`: сброс приходит и на отменённом
    /// жесте, и выбор не зависает в «ведении».
    @GestureState private var isPressing = false

    private var session: TaskalkaSession { .shared }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .frame(width: panel.width, height: panel.height)
                .contentShape(.rect)
                .gesture(drag)
                .offset(x: panel.minX, y: panel.minY)
                .accessibilityElement()
                .accessibilityLabel(TaskalkaCopy.fieldLabel)
                // Подпись настроения на экране больше не стоит — её читает VoiceOver.
                .accessibilityValue(session.mood.map { "\($0.word). \($0.note)" } ?? "")
                .accessibilityHint(TaskalkaCopy.fieldHint)
                .accessibilityActions {
                    ForEach(TaskalkaMood.all) { mood in
                        Button(mood.title) { session.choose(mood) }
                    }
                }
        }
        .onChange(of: isPressing) { _, pressing in
            if !pressing { session.release() }
        }
        // Пока палец водит — собираем подборку того настроения, на котором он задержался:
        // к отпусканию она часто уже готова. Задержка — не пролёт: зоны теперь вдвое
        // теснее, и на пролёте подборка собиралась бы на каждое слово.
        .task(id: session.phase == .picking ? session.mood?.id : nil) {
            guard session.phase == .picking, let mood = session.mood else { return }
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            TaskalkaCatalog.shared.prepare(mood)
        }
    }

    /// Ширина поля к высоте — по ней зоны сот круглые в пунктах (`TaskalkaMap`).
    private var aspect: CGFloat {
        panel.width / max(panel.height, 1)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .updating($isPressing) { _, state, _ in state = true }
            .onChanged { value in
                let raw = CGPoint(x: value.location.x / panel.width, y: value.location.y / panel.height)
                let point = CGPoint(x: min(max(raw.x, 0), 1), y: min(max(raw.y, 0), 1))
                let cell = TaskalkaGrid.cell(at: value.location, in: panel.size)
                if session.phase == .picking {
                    session.drag(to: point, cell: cell, overshoot: point != raw, aspect: aspect)
                } else {
                    // Касание опускает клавиатуру — поле открывается до самого бара.
                    if actionBar.isSearchFocused { keyboard.dismissSmoothly() }
                    session.touchDown(at: point, cell: cell, aspect: aspect)
                }
            }
    }
}
