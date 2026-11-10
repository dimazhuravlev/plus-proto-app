import SwiftUI
import UIKit

// Стопка плееров над action bar (макет `3155:126768` файла «Sandbox ЯПС • Dima», задача
// пользователя 2026-11-07): долгое нажатие на компактный плеер бара — круг музыки, чип
// книги или чип кино — поднимает над ним остальные плееры, у каждого последний айтем.
// Стопка живёт, пока палец на экране: его ведут вверх к плееру и отпускают — плеер
// запускается; отпустили на текущем плеере бара или мимо — стопка закрывается (правка
// пользователя того же дня: тапа по открытой стопке нет). Кино и книга сразу открывают
// киноплеер и читалку; круг музыки садится на место компактного плеера в баре и затем
// разворачивается в пилюлю.

// MARK: - Motion

enum PlayerStackMotion {
    /// Долгое нажатие — как у шторки действий и системного контекстного меню.
    static var holdDuration: Duration { ActionSheetMotion.holdDuration }
    /// Веер (правка пользователя 2026-11-07: «помимо opacity — офсет снизу вверх, волной»):
    /// каждый плеер выезжает из-за текущего плеера бара, от его центра, на свой слот —
    /// дальний едет дальше, — растёт из `originScale` и проявляется.
    ///
    /// Подъём — сильный ease-out (правки пользователя 2026-11-07: «немного ускорить,
    /// ease out», затем «чуть-чуть быстрее»; было 0.42, потом 0.34). Проявление короче
    /// подъёма: плеер виден уже с первой трети пути.
    static let enterRise: Animation = .timingCurve(0.23, 1, 0.32, 1, duration: 0.3)
    /// Видна только последняя часть подъёма (правка пользователя 2026-11-07: «не весь
    /// транзишн, а финальную часть»): проявление ждёт, пока плеер пройдёт большую часть
    /// пути — сильный ease-out проходит ~70 % за первые 80 мс, — и проявляется на доезде.
    static let enterFadeDelay: Double = 0.08
    static let enterFade: Animation = .easeOut(duration: 0.14)
    /// Волна снизу вверх: следующий плеер трогается позже предыдущего.
    static let enterStagger: Double = 0.05
    /// Закрытие — тем же путём назад, в плеер бара, волной сверху вниз: плеер едет
    /// ease-in-out, сжимается к `originScale` и гаснет к трём четвертям пути. Прежде он
    /// доезжал до центра бара в полный размер и почти непрозрачным, и широкий чип кино
    /// ~0.3 с торчал из-за круга музыки по обе стороны (жалоба пользователя 2026-11-07).
    /// «Скрываем чуть быстрее» (правка пользователя 2026-11-07, было 0.3).
    static let exitDuration: Double = 0.24
    static let exitMove: Animation = .timingCurve(0.65, 0, 0.35, 1, duration: exitDuration)
    static let exitFade: Animation = .easeInOut(duration: 0.16)
    static let exitStagger: Double = 0.04
    /// Складываясь, плеер ещё и плавно размывается — к этому радиусу, вместе с угасанием
    /// (правка пользователя 2026-11-07). Порядок блюра смены плееров бара (`swapBlurRadius` 7).
    static let exitBlur: CGFloat = 8
    /// Размер плеера в точке, откуда веер выезжает и куда складывается: в плеер бара он
    /// уходит, умещаясь в него, а не торча из-за круга шириной чипа кино.
    static let originScale: CGFloat = 0.6
    /// Круг музыки едет на место компактного плеера в баре — движение по экрану, ease-in-out.
    /// Дольше морфа бара (0.32): чип под ним успевает уйти, зона — сжаться в круг.
    static let landingDuration: Double = 0.36
    static let landing: Animation = .timingCurve(0.645, 0.045, 0.355, 1, duration: landingDuration)
    /// Пауза между посадкой и разворотом в пилюлю: два шага читаются двумя, а не одним рывком.
    static let landingPause: Double = 0.05
    /// Reduce Motion — только прозрачность.
    static let reducedFade: Animation = .easeInOut(duration: 0.25)
    static let reducedDuration: Double = 0.25
    /// Сколько после отпускания пальца бар не принимает тап и оттяг: отпускание после
    /// долгого нажатия доходит до чипа или круга как тап.
    static let releaseGuard: Duration = .milliseconds(150)
}

// MARK: - Geometry

enum PlayerStackGeometry {
    /// Ось веера, когда в баре кино, — 62 от правой кромки экрана: в макете на 375 книга
    /// и круг музыки над чипом кино стоят по центру x 313. От кромки, а не от ширины:
    /// бар прижат к правому полю на любой ширине.
    static let movieAxisTrailingInset: CGFloat = 62
    /// Слот — высота бара, между слотами и до бара 4 (макет).
    static let slotHeight: CGFloat = PlusMetrics.actionBarHeight
    static let slotGap: CGFloat = 4
    /// Насколько вбок от плеера палец ещё выбирает его, ведя по стопке.
    static let hoverSlop: CGFloat = 12

    /// Ось книги и круга музыки (правило пользователя 2026-11-07: «выровнены по вертикали»):
    /// центр плеера бара, если в баре книга или музыка, — веер стоит над ним; в баре кино —
    /// ось макета.
    @MainActor static func axisX(current: PlayerStackKind?, bookAspect: CGFloat?) -> CGFloat {
        switch current {
        case .music, .book: compactCenterX(of: current, bookAspect: bookAspect)
        case .movie, nil: PlusMetrics.screenWidth - movieAxisTrailingInset
        }
    }

    /// Центр плеера веера. Книга и музыка — на оси; чип кино шире, и по оси он вылез бы
    /// за правое поле — он прижат к полю и стоит левее оси (правка пользователя того же дня:
    /// «киноплеер может быть смещён, он шире»).
    @MainActor static func slotX(_ kind: PlayerStackKind, current: PlayerStackKind?, bookAspect: CGFloat?) -> CGFloat {
        let axis = axisX(current: current, bookAspect: bookAspect)
        guard kind == .movie else { return axis }
        return min(axis, PlusMetrics.screenWidth - PlusMetrics.screenMargin - ActionBarGeometry.movieChipAABBWidth / 2)
    }

    /// Центр слота от верхней кромки бара; слот 0 — ближний к бару.
    static func slotCenterY(_ index: Int) -> CGFloat {
        -(slotGap + slotHeight / 2 + CGFloat(index) * (slotHeight + slotGap))
    }

    /// Центр компактного плеера в баре: зона у правого поля шириной в сам плеер.
    @MainActor static func compactCenterX(of kind: PlayerStackKind?, bookAspect: CGFloat?) -> CGFloat {
        let width: CGFloat = switch kind {
        case .book: ActionBarGeometry.bookChipAABBWidth(aspect: bookAspect)
        case .movie: ActionBarGeometry.movieChipAABBWidth
        case .music, nil: PlusMetrics.actionBarCompact
        }
        return PlusMetrics.screenWidth - PlusMetrics.screenMargin - width / 2
    }

    /// Путь плеера `kind` из слота `index` в центр плеера бара `target`: оттуда веер
    /// выезжает и туда же складывается. `current` — плеер бара на открытии, от него ось.
    @MainActor static func originShift(
        _ kind: PlayerStackKind, from index: Int, current: PlayerStackKind?,
        to target: PlayerStackKind?, bookAspect: CGFloat?
    ) -> CGSize {
        CGSize(
            width: compactCenterX(of: target, bookAspect: bookAspect)
                - slotX(kind, current: current, bookAspect: bookAspect),
            height: PlusMetrics.actionBarHeight / 2 - slotCenterY(index)
        )
    }

    /// Путь круга музыки из слота `index` в бар — туда, где круг стоит в `.search`.
    @MainActor static func landingShift(from index: Int, current: PlayerStackKind?, bookAspect: CGFloat?) -> CGSize {
        originShift(.music, from: index, current: current, to: .music, bookAspect: bookAspect)
    }
}

// MARK: - State

enum PlayerStackKind: Hashable {
    case music, book, movie
}

/// Состояние стопки — своё у каждого нижнего хрома (корень и слой фильма), как и бар.
@Observable
final class PlayerStackState {
    enum Phase: Equatable {
        case closed
        case open
        /// Уходит после выбора кино или книги, отпускания мимо — гаснет и опускается.
        case closing
        /// Круг музыки едет в бар, остальные уходят.
        case landing
    }

    private(set) var phase: Phase = .closed
    /// Слоты снизу вверх, пока стопка на экране, — те, что были на открытии: бар под ней
    /// меняет режим (посадка музыки), а слоты на ходу пересобираться не должны.
    private(set) var presented: [PlayerStackKind] = []
    /// Компактный плеер бара на открытии — из него веер выезжает и в него складывается.
    private(set) var origin: PlayerStackKind?
    /// Плеер под пальцем, который ведут по стопке от бара.
    private(set) var hovered: PlayerStackKind?
    /// Круг музыки в баре спрятан, пока на его место едет круг стопки: встаёт он
    /// в момент посадки, без анимации, — тот же рисунок в той же точке.
    private(set) var hidesBarMusic = false
    /// Палец, открывший стопку, ещё на экране (и `releaseGuard` после): его отпускание
    /// доходит до чипа или круга бара как тап, а подъём к стопке — как оттяг пилюли.
    private(set) var isHoldActive = false

    @ObservationIgnored private var frames: [PlayerStackKind: CGRect] = [:]
    @ObservationIgnored private var phaseTask: Task<Void, Never>?
    @ObservationIgnored private var holdTask: Task<Void, Never>?

    /// Бар не отвечает на тап и оттяг, пока стопка над ним или палец её ещё держит.
    var blocksBar: Bool { isHoldActive || phase == .open || phase == .landing }
    /// Новое долгое нажатие — когда стопки нет или она уходит.
    var acceptsHold: Bool { phase == .closed || phase == .closing }

    /// Текущий компактный плеер бара и остальные снизу вверх. Порядок сверху вниз —
    /// музыка, книга, кино (в макете над чипом кино книга, над ней круг музыки). В стопке
    /// только то, что слушали, читали или смотрели. Развёрнутая пилюля музыки — не компакт.
    static func kinds(of bar: ActionBarState) -> (current: PlayerStackKind?, others: [PlayerStackKind]) {
        let current: PlayerStackKind? = switch bar.mode {
        case .search: bar.music != nil ? .music : nil
        case .book: bar.book != nil ? .book : nil
        case .movie: bar.movie != nil ? .movie : nil
        case .music: nil
        }
        guard let current else { return (nil, []) }
        let others = [PlayerStackKind.movie, .book, .music].filter { kind in
            guard kind != current else { return false }
            return switch kind {
            case .music: bar.music != nil
            case .book: bar.book != nil
            case .movie: bar.movie != nil
            }
        }
        return (current, others)
    }

    /// Слоты на экране: в покое — по бару (вью стоят заранее, прозрачными, чтобы появиться
    /// движением), на экране — замороженные на открытии.
    func slots(live: [PlayerStackKind]) -> [PlayerStackKind] {
        phase == .closed ? live : presented
    }

    // MARK: Палец

    @MainActor
    func open(_ kinds: [PlayerStackKind], from current: PlayerStackKind?) {
        guard !kinds.isEmpty else { return }
        phaseTask?.cancel()
        holdTask?.cancel()
        presented = kinds
        origin = current
        hovered = nil
        hidesBarMusic = false
        isHoldActive = true
        phase = .open
        PlayerStackHaptics.opened()
    }

    @MainActor
    func hover(at point: CGPoint) {
        guard phase == .open else { return }
        let kind = kind(at: point)
        guard kind != hovered else { return }
        hovered = kind
        // Палец зашёл на плеер веера — тик выбора.
        if kind != nil { PlayerStackHaptics.hovered() }
    }

    /// Палец отпустили: над плеером стопки — выбор; на текущем плеере бара, мимо
    /// или касание отменено (`nil`) — стопка закрывается.
    @MainActor
    func release(at point: CGPoint?, bar: ActionBarState, reduceMotion: Bool) {
        defer { endHold() }
        guard phase == .open else { return }
        if let point, let kind = kind(at: point) {
            select(kind, bar: bar, reduceMotion: reduceMotion)
        } else {
            close(reduceMotion: reduceMotion)
        }
    }

    /// Название айтема плеера — имя действия VoiceOver на компактном плеере бара.
    static func title(of kind: PlayerStackKind, in bar: ActionBarState) -> String? {
        switch kind {
        case .music: bar.music?.title
        case .book: bar.book?.title
        case .movie: bar.movie?.title
        }
    }

    func setFrame(_ frame: CGRect, for kind: PlayerStackKind) {
        frames[kind] = frame
    }

    @MainActor
    private func kind(at point: CGPoint) -> PlayerStackKind? {
        presented.first { kind in
            frames[kind]?
                .insetBy(dx: -PlayerStackGeometry.hoverSlop, dy: -PlayerStackGeometry.slotGap / 2)
                .contains(point) == true
        }
    }

    private func endHold() {
        holdTask?.cancel()
        holdTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: PlayerStackMotion.releaseGuard)
            guard !Task.isCancelled else { return }
            self?.isHoldActive = false
        }
    }

    // MARK: Выбор

    /// Кино и книга — сразу киноплеер и читалка, тем же входом, что тап по чипу бара;
    /// бар меняется под выехавшим плеером. Музыка — посадка в бар и разворот.
    @MainActor
    func select(_ kind: PlayerStackKind, bar: ActionBarState, reduceMotion: Bool) {
        guard phase == .open else { return }
        hovered = nil
        switch kind {
        case .movie:
            guard let movie = bar.movie else { return close(reduceMotion: reduceMotion) }
            Self.launchHaptic()
            close(reduceMotion: reduceMotion)
            bar.watch(movie)
        case .book:
            guard let book = bar.book else { return close(reduceMotion: reduceMotion) }
            Self.launchHaptic()
            close(reduceMotion: reduceMotion)
            bar.read(book)
        case .music:
            land(bar: bar, reduceMotion: reduceMotion)
        }
    }

    func close(reduceMotion: Bool) {
        guard phase == .open else { return }
        hovered = nil
        phase = .closing
        let duration = reduceMotion
            ? PlayerStackMotion.reducedDuration
            : PlayerStackMotion.exitDuration + PlayerStackMotion.exitStagger * Double(max(0, presented.count - 1))
        phaseTask?.cancel()
        phaseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled, let self, self.phase == .closing else { return }
            self.phase = .closed
        }
    }

    /// Круг музыки едет на место компактного плеера: бар в том же апдейте сжимает зону
    /// в круг и гасит чип (свой круг держит спрятанным), круг стопки садится в неё, бар
    /// показывает свой круг вместо него и только потом разворачивает пилюлю.
    @MainActor
    private func land(bar: ActionBarState, reduceMotion: Bool) {
        guard bar.music != nil else { return close(reduceMotion: reduceMotion) }
        // Как у разворота круга тапом.
        PlayerHaptics.tap()
        guard !reduceMotion else {
            close(reduceMotion: true)
            bar.expandMiniPlayer()
            return
        }
        hidesBarMusic = true
        phase = .landing
        bar.showMusicCompact()
        phaseTask?.cancel()
        phaseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(PlayerStackMotion.landingDuration))
            guard !Task.isCancelled, let self else { return }
            // Своим апдейтом, без анимации и без смены раскладки бара: под морфом разворота
            // круг бара проявлялся бы поверх уже исчезнувшего круга стопки.
            self.hidesBarMusic = false
            self.phase = .closed
            try? await Task.sleep(for: .seconds(PlayerStackMotion.landingPause))
            guard !Task.isCancelled else { return }
            bar.expandMiniPlayer()
        }
    }

    /// «Включить контент» — та же хаптика, что у чипов бара и «Смотреть» / «Читать».
    private static func launchHaptic() {
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
    }
}

// MARK: - Haptics

/// Хаптика веера (просьба пользователя 2026-11-07, сверх правила «одна на действие»):
/// появление веера — удар medium, как у системного контекстного меню; палец зашёл на плеер
/// веера — тик выбора, другой по характеру, как при переборе пунктов системных меню.
/// Генераторы просыпаются, когда палец лёг на плеер бара (`prepare`): через 0.5 с удержания
/// и на ведении по вееру отклик без задержки.
@MainActor
enum PlayerStackHaptics {
    private static let open = UIImpactFeedbackGenerator(style: .medium)
    private static let hover = UISelectionFeedbackGenerator()

    static func prepare() {
        open.prepare()
        hover.prepare()
    }

    static func opened() {
        open.impactOccurred()
        hover.prepare()
    }

    static func hovered() {
        hover.selectionChanged()
        hover.prepare()
    }
}

// MARK: - Views

/// Плееры стопки над баром. Стоит подложкой нижнего хрома от верхней кромки бара — под баром:
/// веер выезжает из-за текущего плеера. Слоты уходят вверх отрицательной координатой. Вью стоят всегда, в покое прозрачными: появление —
/// движение живых вью, а не вставка (правило «Движение»). Касаний не ловят никогда — плеер
/// выбирает палец, открывший стопку (`PlayerStackHold`), по рамкам слотов.
struct PlayerStackOverlay: View {
    @Environment(PlayerStackState.self) private var stack
    @Environment(ActionBarState.self) private var actionBar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let live = PlayerStackState.kinds(of: actionBar)
        let slots = stack.slots(live: live.others)
        let origin = stack.phase == .closed ? live.current : stack.origin
        ZStack {
            ForEach(Array(slots.enumerated()), id: \.element) { index, kind in
                PlayerStackFace(kind: kind)
                .modifier(PlayerStackSlotMotion(
                    phase: stack.phase,
                    isLanding: kind == .music && stack.phase == .landing,
                    isHovered: stack.hovered == kind,
                    index: index,
                    count: slots.count,
                    originShift: PlayerStackGeometry.originShift(
                        kind, from: index, current: origin, to: origin, bookAspect: actionBar.bookCoverAspect
                    ),
                    landingShift: PlayerStackGeometry.landingShift(
                        from: index, current: origin, bookAspect: actionBar.bookCoverAspect
                    ),
                    reduceMotion: reduceMotion
                ))
                // Рамка слота — до сдвигов движения: по ней палец выбирает плеер.
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                    stack.setFrame(frame, for: kind)
                }
                .position(
                    x: PlayerStackGeometry.slotX(kind, current: origin, bookAspect: actionBar.bookCoverAspect),
                    y: PlayerStackGeometry.slotCenterY(index)
                )
                // Чем ниже плеер, тем он выше (правило пользователя 2026-11-07): дальний
                // выезжает из-за ближнего и складывается за него. Последним модификатором —
                // `ZStack` видит z только у своего прямого ребёнка.
                .zIndex(Double(-index))
            }
        }
        .frame(width: PlusMetrics.screenWidth, height: 0)
        .allowsHitTesting(false)
        // VoiceOver выбирает плеер действиями самого компактного плеера (`TrailingSlot`).
        .accessibilityHidden(true)
    }
}

/// Плеер стопки — тот же компактный, что в баре: круг музыки, чип книги, чип кино.
private struct PlayerStackFace: View {
    let kind: PlayerStackKind
    @Environment(ActionBarState.self) private var actionBar

    var body: some View {
        switch kind {
        case .music:
            if let music = actionBar.music {
                PlayerStackMusicCircle(cover: music.cover)
            }
        case .book:
            if let book = actionBar.book {
                BookChip(cover: book.cover, aspect: actionBar.bookCoverAspect)
            }
        case .movie:
            if let movie = actionBar.movie {
                MovieChip(still: movie.still)
            }
        }
    }
}

/// Круг музыки — рисунок свёрнутой пилюли бара (`MiniPlayerPill` в круге 60): стекло
/// капсулой, обложка 52 по центру. Угол обложки — ноль, как у пилюли, показанной на паузе
/// (`MiniPlayerPill.isShown`): посадка в бар не меняет картинку.
private struct PlayerStackMusicCircle: View {
    let cover: ArtworkSource

    var body: some View {
        Color.clear
            .frame(width: PlusMetrics.actionBarCompact, height: PlusMetrics.actionBarHeight)
            .glassPill()
            .overlay {
                ArtworkImage(source: cover)
                    .scaledToFill()
                    .frame(width: PlusMetrics.miniPlayerCover, height: PlusMetrics.miniPlayerCover)
                    .clipShape(Circle())
                    .coverBorder(Circle())
            }
            .clipShape(Capsule(style: .continuous))
    }
}

/// Движение слота: веер из плеера бара волной снизу вверх, складывание назад волной сверху
/// вниз, посадка круга музыки в бар. Сдвиг и прозрачность — каждый своей кривой; кривая
/// считается от фазы, в которую стопка пришла.
private struct PlayerStackSlotMotion: ViewModifier {
    let phase: PlayerStackState.Phase
    let isLanding: Bool
    let isHovered: Bool
    let index: Int
    let count: Int
    /// Путь до центра плеера бара: в покое слот стоит там, прозрачным.
    let originShift: CGSize
    let landingShift: CGSize
    let reduceMotion: Bool

    /// Анимации — по значению, слоями: внутренняя перекрывает внешнюю для своего поддерева,
    /// поэтому сдвиг с масштабом едут своей кривой, а прозрачность — своей. Сдвиг внутри
    /// `.animation(_:body:)` здесь не анимировался вовсе — плеер прыгал на место и только
    /// проявлялся (запись 2026-11-07), — работала одна прозрачность.
    func body(content: Content) -> some View {
        content
            // Палец ведут по стопке — плеер под ним проседает, как нажатая кнопка.
            .scaleEffect(isHovered ? PressMotion.buttonScale : 1)
            .animation(isHovered ? PressMotion.pressIn : PressMotion.release, value: isHovered)
            .scaleEffect(scale)
            .offset(offset)
            .animation(moveAnimation, value: phase)
            // Блюр — той же кривой, что угасание: размывается, пока гаснет.
            .blur(radius: blur, opaque: false)
            .opacity(opacity)
            .animation(fadeAnimation, value: phase)
    }

    /// Только у складывания: появление чистое. В покое — ноль (мгновенно, плеер уже
    /// прозрачный), чтобы следующее раскрытие не начиналось из размытия.
    private var blur: CGFloat {
        guard !reduceMotion else { return 0 }
        let isFolding = phase == .closing || (phase == .landing && !isLanding)
        return isFolding ? PlayerStackMotion.exitBlur : 0
    }

    private var isShown: Bool { phase == .open || isLanding }

    private var scale: CGFloat {
        isShown || reduceMotion ? 1 : PlayerStackMotion.originScale
    }

    private var offset: CGSize {
        if isLanding { return landingShift }
        if phase == .open || reduceMotion { return .zero }
        return originShift
    }

    private var opacity: Double { isShown ? 1 : 0 }

    private var enterDelay: Double { Double(index) * PlayerStackMotion.enterStagger }
    private var exitDelay: Double { Double(count - 1 - index) * PlayerStackMotion.exitStagger }

    private var moveAnimation: Animation? {
        guard !reduceMotion else { return nil }
        switch phase {
        case .open: return PlayerStackMotion.enterRise.delay(enterDelay)
        case .closing: return PlayerStackMotion.exitMove.delay(exitDelay)
        case .landing: return isLanding ? PlayerStackMotion.landing : PlayerStackMotion.exitMove.delay(exitDelay)
        // Покой: из посадки — мгновенно (круг бара уже встал на место круга стопки),
        // из складывания — менять уже нечего.
        case .closed: return nil
        }
    }

    private var fadeAnimation: Animation? {
        switch phase {
        case .open:
            return reduceMotion
                ? PlayerStackMotion.reducedFade
                : PlayerStackMotion.enterFade.delay(enterDelay + PlayerStackMotion.enterFadeDelay)
        case .closing: return reduceMotion ? PlayerStackMotion.reducedFade : PlayerStackMotion.exitFade.delay(exitDelay)
        // Выбранный посреди проявления круг доигрывает его, а не вспыхивает.
        case .landing: return isLanding ? PlayerStackMotion.enterFade : PlayerStackMotion.exitFade.delay(exitDelay)
        case .closed: return nil
        }
    }
}

// MARK: - Долгое нажатие

/// Долгое нажатие на компактный плеер бара. Распознаватель пассивный, как у шторки
/// действий (`ActionSheetHold`): касание ни у кого не отнимает, тап и оттяг бара работают
/// как без него. После срабатывания он ведёт тот же палец дальше — по стопке к плееру:
/// отпускание над плеером его выбирает, в любом другом месте — закрывает стопку.
struct PlayerStackHold: UIGestureRecognizerRepresentable {
    let isEnabled: Bool
    /// Палец на плеере и пока держит веер: `true` — вжать, `false` — отпустить.
    let onPress: @MainActor (Bool) -> Void
    /// Сработало удержание; `false` — стопку открыть нечем, палец дальше не ведём.
    let onHold: @MainActor () -> Bool
    /// Палец двигается, в координатах окна.
    let onMove: @MainActor (CGPoint) -> Void
    /// Палец отпустили (координаты окна) или касание отменено (`nil`).
    let onEnd: @MainActor (CGPoint?) -> Void

    func makeUIGestureRecognizer(context: Context) -> PlayerStackHoldRecognizer {
        PlayerStackHoldRecognizer(target: nil, action: nil)
    }

    func updateUIGestureRecognizer(_ recognizer: PlayerStackHoldRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
        recognizer.onPress = onPress
        recognizer.onHold = onHold
        recognizer.onMove = onMove
        recognizer.onEnd = onEnd
    }
}

final class PlayerStackHoldRecognizer: UIGestureRecognizer {
    var onPress: @MainActor (Bool) -> Void = { _ in }
    var onHold: @MainActor () -> Bool = { false }
    var onMove: @MainActor (CGPoint) -> Void = { _ in }
    var onEnd: @MainActor (CGPoint?) -> Void = { _ in }

    private weak var touch: UITouch?
    private var origin = CGPoint.zero
    private var timer: Task<Void, Never>?
    /// Удержание сработало, палец ведёт по стопке.
    private var isHolding = false
    /// Плеер бара вжат этим касанием.
    private var isPressing = false

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesEnded = false
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        // Второй палец не в счёт — ведём первый.
        guard touch == nil, let first = touches.first else { return }
        touch = first
        origin = first.location(in: nil)
        setPressing(true)
        timer = Task { @MainActor [weak self] in
            try? await Task.sleep(for: PlayerStackMotion.holdDuration)
            guard !Task.isCancelled, let self, self.touch != nil else { return }
            // Веер не открылся (показать нечего) — касание остаётся обычным нажатием
            // до отпускания или ухода пальца.
            self.isHolding = self.onHold()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let touch, touches.contains(touch) else { return }
        let point = touch.location(in: nil)
        if isHolding {
            onMove(point)
        } else if hypot(point.x - origin.x, point.y - origin.y) > PressMotion.slop {
            // Палец ушёл до удержания — это оттяг или свайп, не долгое нажатие.
            finish()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        guard let touch, touches.contains(touch) else { return }
        if isHolding {
            isHolding = false
            onEnd(touch.location(in: nil))
        }
        finish()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        guard let touch, touches.contains(touch) else { return }
        if isHolding {
            isHolding = false
            onEnd(nil)
        }
        finish()
    }

    override func reset() {
        super.reset()
        // Сюда же приходит отключение распознавателя посреди удержания.
        if isHolding {
            isHolding = false
            onEnd(nil)
        }
        setPressing(false)
        timer?.cancel()
        timer = nil
        touch = nil
    }

    private func finish() {
        setPressing(false)
        timer?.cancel()
        timer = nil
        touch = nil
        state = .failed
    }

    private func setPressing(_ pressing: Bool) {
        guard pressing != isPressing else { return }
        isPressing = pressing
        onPress(pressing)
    }
}
