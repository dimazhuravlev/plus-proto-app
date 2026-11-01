import SwiftUI
import UIKit

/// Флаг дебаг-меню: Таскалка вместо «Искали недавно» и рекомендаций пустого поиска
/// (задача пользователя 2026-10-31). Ключ `UserDefaults`, на один запуск —
/// `-taskalkaInSearch 1`.
enum TaskalkaDebug {
    static let enabledKey = "taskalkaInSearch"
}

/// Состояние Таскалки на процесс. Синглтон, а не `@State` вью: вью пересоздаётся, стоит
/// набрать запрос и стереть его, — выбор и открытая подборка обязаны пережить это.
/// Закрытый поиск начинает с чистого поля (`reset`).
@MainActor
@Observable
final class TaskalkaSession {
    static let shared = TaskalkaSession()

    enum Phase: Equatable {
        /// Поля ещё не касались — фраза-приглашение.
        case idle
        /// Палец на поле.
        case picking
        /// Палец отпущен — настроение выбрано, точки на месте выбора остаются набухшими.
        case chosen
    }

    private(set) var phase: Phase = .idle
    /// Точка пальца в долях поля. Пишется на каждое событие пальца — её читает только
    /// слой точек (`TaskalkaField`), фраза от неё не перерисовывается.
    private(set) var point = CGPoint(x: 0.5, y: 0.5)
    /// Настроение под пальцем, а после отпускания — выбранное. `nil` — поля не касались.
    private(set) var mood: TaskalkaMood?
    /// Выбранное отпусканием — его подборку показывает шторка. Отдельно от `mood`:
    /// пока палец водит, шторка за кадром не пересобирается на каждое слово.
    private(set) var chosen: TaskalkaMood?
    /// Подборка открыта.
    private(set) var isSheetShown = false
    /// Насколько шторку стянули вниз пальцем, 0…1: под открытой шторкой поле погашено
    /// и проявляется по этой доле (`TaskalkaCard`). Пишет шторка на каждое событие пальца.
    var sheetPull: CGFloat = 0
    /// Вступительная волна по точкам — раз за процесс (`TaskalkaField`).
    var didIntro = false

    let haptics = TaskalkaHaptics()
    /// Течение под пальцем — толчки для покачивания точек (`TaskalkaFlow`). Пишется
    /// по событиям касания, не наблюдается: читает его только кадр поля.
    let flow = TaskalkaFlow()

    private init() {}

    /// Касание. Набухание точек перетекает с места прошлого выбора к пальцу; подборка, если была открыта,
    /// уезжает — выбор начинается заново.
    func touchDown(at point: CGPoint, cell: TaskalkaGrid.Cell, aspect: CGFloat) {
        haptics.touchDown()
        flow.begin(at: point)
        let next = TaskalkaMap.mood(at: point, current: nil, aspect: aspect)
        // С «уменьшением движения» набухание не перетекает к пальцу — встаёт под ним сразу.
        if UIAccessibility.isReduceMotionEnabled {
            self.point = point
            withAnimation(TaskalkaMotion.word) {
                phase = .picking
                mood = next
            }
        } else {
            withAnimation(TaskalkaMotion.grab) {
                phase = .picking
                self.point = point
                mood = next
            }
        }
        if isSheetShown {
            withAnimation(TaskalkaMotion.sheetClose) {
                isSheetShown = false
                sheetPull = 0
            }
        }
        haptics.reset(cell: cell)
    }

    /// Палец ведёт. Точка — с короткой интерактивной пружиной: точки и свечение
    /// следуют за пальцем без рывков от неровных событий касания.
    func drag(to point: CGPoint, cell: TaskalkaGrid.Cell, overshoot: Bool, aspect: CGFloat) {
        flow.record(point)
        withAnimation(TaskalkaMotion.follow) { self.point = point }
        haptics.edge(overshoot)
        let next = TaskalkaMap.mood(at: point, current: mood, aspect: aspect)
        if next.id != mood?.id {
            // Слово сменилось — один «тук»; тик точки в этом событии не нужен.
            haptics.moodChanged()
            withAnimation(TaskalkaMotion.word) { mood = next }
            haptics.reset(cell: cell)
        } else {
            haptics.cell(cell)
        }
    }

    /// Палец отпущен — выбор сделан, подборка выезжает.
    func release() {
        flow.end()
        guard phase == .picking, let mood else { return }
        haptics.release()
        TaskalkaCatalog.shared.prepare(mood)
        chosen = mood
        withAnimation(TaskalkaMotion.settle) { phase = .chosen }
        withAnimation(TaskalkaMotion.sheetOpen) { isSheetShown = true }
    }

    /// Выбор без пальца — VoiceOver: место выбора — центр зоны настроения.
    func choose(_ mood: TaskalkaMood) {
        TaskalkaCatalog.shared.prepare(mood)
        chosen = mood
        withAnimation(TaskalkaMotion.settle) {
            phase = .chosen
            point = mood.anchor
            self.mood = mood
        }
        withAnimation(TaskalkaMotion.sheetOpen) { isSheetShown = true }
    }

    /// Подборку смахнули или тапнули по фразе — назад к полю, место выбора остаётся.
    /// `haptic` — нет, когда шторку убирает другое действие со своим откликом (фокус поиска).
    func closeSheet(haptic: Bool = true) {
        guard isSheetShown else { return }
        if haptic { haptics.sheetClosed() }
        withAnimation(TaskalkaMotion.sheetClose) {
            isSheetShown = false
            sheetPull = 0
        }
    }

    /// Поиск закрыт — следующее открытие начинается с приглашения.
    func reset() {
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            phase = .idle
            point = CGPoint(x: 0.5, y: 0.5)
            mood = nil
            chosen = nil
            isSheetShown = false
            sheetPull = 0
        }
    }
}

// MARK: - Движение

/// Кривые Таскалки — одним местом.
enum TaskalkaMotion {
    /// Касание: набухание перетекает к пальцу и растёт — пружина без отскока.
    static let grab: Animation = .spring(response: 0.3, dampingFraction: 0.86)
    /// Ведение: короткая интерактивная пружина — сглаживает события касания, но не отстаёт.
    static let follow: Animation = .interactiveSpring(response: 0.12, dampingFraction: 0.92)
    /// Смена слова — через блюр, быстрее перехода списков: палец водит, слово отвечает.
    static let word: Animation = .easeOut(duration: 0.22)
    /// Отпускание: точки опадают вполовину, свечение притухает.
    static let settle: Animation = .timingCurve(0.23, 1, 0.32, 1, duration: 0.45)
    /// Подборка выезжает — кривая шторки iOS: быстрый старт, долгое торможение.
    static let sheetOpen: Animation = .timingCurve(0.32, 0.72, 0, 1, duration: 0.5)
    /// И уезжает — той же кривой, короче: закрыть легче, чем открыть.
    static let sheetClose: Animation = .timingCurve(0.32, 0.72, 0, 1, duration: 0.36)
    /// Разделы подборки встают лесенкой после старта шторки.
    static let sectionDelay: Double = 0.12
    static let sectionStagger: Double = 0.06
    static let section: Animation = .timingCurve(0.23, 1, 0.32, 1, duration: 0.4)
}

// MARK: - Хаптика

/// Хаптика Таскалки — по одной на действие, но действий много: касание — мягкий толчок,
/// каждая точка сетки под пальцем — лёгкий тик (трещотка, как у перемотки плеера),
/// смена настроения — заметный «тук», упор в край поля — жёсткий, отпускание — щелчок
/// выбора, закрытая подборка — мягкий.
@MainActor
final class TaskalkaHaptics {
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let tick = UIImpactFeedbackGenerator(style: .light)
    private let thud = UIImpactFeedbackGenerator(style: .medium)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)

    private enum Config {
        static let touchIntensity: CGFloat = 0.9
        static let tickIntensity: CGFloat = 0.4
        static let moodIntensity: CGFloat = 0.85
        static let edgeIntensity: CGFloat = 0.7
        static let releaseIntensity: CGFloat = 1
        static let closeIntensity: CGFloat = 0.6
        /// Чаще Taptic Engine всё равно не отыграет: быстрая протяжка — ровная очередь.
        static let tickInterval: TimeInterval = 0.035
    }

    private var lastCell: TaskalkaGrid.Cell?
    private var lastTick = Date.distantPast
    private var isPressedToEdge = false

    func touchDown() {
        soft.impactOccurred(intensity: Config.touchIntensity)
        tick.prepare()
        thud.prepare()
    }

    func reset(cell: TaskalkaGrid.Cell) {
        lastCell = cell
    }

    func cell(_ cell: TaskalkaGrid.Cell) {
        guard cell != lastCell else { return }
        lastCell = cell
        guard Date.now.timeIntervalSince(lastTick) >= Config.tickInterval else { return }
        tick.impactOccurred(intensity: Config.tickIntensity)
        lastTick = .now
        tick.prepare()
    }

    func moodChanged() {
        thud.impactOccurred(intensity: Config.moodIntensity)
        lastTick = .now
        thud.prepare()
    }

    /// Палец ушёл за край поля — один упор, пока не вернётся.
    func edge(_ overshoot: Bool) {
        defer { isPressedToEdge = overshoot }
        guard overshoot, !isPressedToEdge else { return }
        rigid.impactOccurred(intensity: Config.edgeIntensity)
    }

    func release() {
        isPressedToEdge = false
        rigid.impactOccurred(intensity: Config.releaseIntensity)
    }

    func sheetClosed() {
        soft.impactOccurred(intensity: Config.closeIntensity)
    }
}
