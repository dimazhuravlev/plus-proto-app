import SwiftUI
import UIKit.UIGestureRecognizerSubclass

// MARK: - Движение

/// Отклик на нажатие — общий у кнопок, карточек и строк.
///
/// Системный `isPressed` в скролле запаздывает: скролл придерживает касание
/// (`delaysContentTouches`, ~150 мс), пока не поймёт, не прокрутка ли это, и быстрый тап
/// заканчивался раньше, чем карточка успевала просесть (жалоба пользователя 2026-10-05).
/// Поэтому палец ловит пассивный UIKit-распознаватель — он видит касание сразу, —
/// а короткий тап держит просадку не меньше `minimumHold`.
enum PressMotion {
    /// Карточки: площадь большая, и просадка кнопок (0.92) читалась бы прыжком.
    static let cardScale: CGFloat = 0.97
    /// Строки во всю ширину экрана — ещё мягче: у строки в 402 pt и 0.97 — это 12 pt.
    static let rowScale: CGFloat = 0.98
    /// Пауза перед просадкой. Свайп, начатый на карточке, за неё успевает стать скроллом,
    /// и карточка не вздрагивает; на глаз отклик всё ещё мгновенный.
    static let pressDelay: Duration = .milliseconds(30)
    /// Минимум просадки у быстрого тапа: к этому моменту `pressIn` почти дошёл.
    static let minimumHold: Duration = .milliseconds(100)
    /// Сдвиг пальца, после которого касание — уже скролл, а не тап.
    static let slop: CGFloat = 10
    /// Просадка — быстрый сильный ease-out: движение видно с первого кадра.
    static let pressIn: Animation = .timingCurve(0.23, 1, 0.32, 1, duration: 0.12)
    /// Возврат мягче и дольше просадки: нажатие — отклик, отпускание — без спешки.
    static let release: Animation = .smooth(duration: 0.24)
}

// MARK: - Стили и модификаторы

/// Пресс-стейт кнопок: просадка сразу под пальцем. Системный `isPressed` — второй
/// источник: им приходит нажатие не пальцем, и он же снимает просадку, когда касание
/// забрало контекстное меню.
struct PressScaleButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = GlassIconButtonConfig.pressedScale

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(PressScaleEffect(scale: pressedScale, isButtonPressed: configuration.isPressed))
    }
}

/// Ячейка островка (профиль, дебаг-меню) — подсветка белым 6 %, как у системных таблиц,
/// а не просадка: строка внутри общей подложки проседала бы отдельно от неё.
struct CellHighlightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        CellHighlight(configuration: configuration)
    }
}

/// Кнопка, у которой отклик рисует само содержимое (`pressScale` внутри строки,
/// мимо разделителей). Стиль ничего не добавляет — даже притухания `.plain`.
struct BareButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

extension View {
    /// Просадка того, что нажимается жестом, а не кнопкой: строка трека (внутри своя
    /// кнопка «ещё»), карточка ролика. Ставится после `contentShape` — по нему ловится палец.
    func pressScale(_ scale: CGFloat, isEnabled: Bool = true) -> some View {
        modifier(PressScaleEffect(scale: scale, isTrackingEnabled: isEnabled))
    }
}

extension EnvironmentValues {
    /// Сколько нажимаемых вью вокруг — касание достаётся самой глубокой.
    @Entry var pressDepth: Int = 0
}

private struct PressScaleEffect: ViewModifier {
    let scale: CGFloat
    var isButtonPressed = false
    var isTrackingEnabled = true

    @State private var isTouched = false

    func body(content: Content) -> some View {
        let isPressed = isTouched || isButtonPressed
        content
            // Анимация — только у масштаба: смена содержимого (активный таб, глиф)
            // едет своей кривой, а не кривой нажатия.
            .animation(isPressed ? PressMotion.pressIn : PressMotion.release) {
                $0.scaleEffect(isPressed ? scale : 1)
            }
            .modifier(PressTracking(
                isTouched: $isTouched,
                isButtonPressed: isButtonPressed,
                isEnabled: isTrackingEnabled
            ))
    }
}

private struct CellHighlight: View {
    let configuration: ButtonStyleConfiguration

    @State private var isTouched = false

    var body: some View {
        let isPressed = isTouched || configuration.isPressed
        configuration.label
            .background(Color.white.opacity(isPressed ? 0.06 : 0))
            .animation(.easeOut(duration: 0.15), value: isPressed)
            .modifier(PressTracking(isTouched: $isTouched, isButtonPressed: configuration.isPressed))
    }
}

/// Касание → «нажато»: с паузой `pressDelay`, не короче `minimumHold`, без просадки,
/// если касание ушло в скролл.
private struct PressTracking: ViewModifier {
    @Binding var isTouched: Bool
    var isButtonPressed = false
    var isEnabled = true

    @Environment(\.isEnabled) private var isEnvironmentEnabled
    @Environment(\.pressDepth) private var depth
    @State private var phase = Phase.idle
    @State private var pressedAt = ContinuousClock.now
    @State private var timer: Task<Void, Never>?

    private enum Phase {
        case idle
        /// Палец на месте, пауза перед просадкой
        case waiting
        /// Просадка, палец на месте
        case held
        /// Палец отпущен, просадка дотягивает свой минимум
        case lifting
    }

    func body(content: Content) -> some View {
        content
            // Вложенная нажимаемая вью глубже — палец на кнопке «ещё» достаётся ей.
            .environment(\.pressDepth, depth + 1)
            .gesture(PressTouchTracker(
                depth: depth,
                isEnabled: isEnabled && isEnvironmentEnabled,
                onTouch: touchChanged
            ))
            .onChange(of: isButtonPressed) { wasPressed, isPressed in
                // Кнопка сняла нажатие, а палец ещё на ней — касание забрало контекстное
                // меню. Просадку — следом, не дожидаясь отпускания.
                if wasPressed, !isPressed, phase == .waiting || phase == .held { cancel() }
            }
            // Ушедшая из ленты карточка не должна вернуться нажатой.
            .onDisappear(perform: cancel)
    }

    private func touchChanged(_ change: PressTouchChange) {
        switch change {
        case .began:
            if phase == .lifting {
                // Второй тап, пока первый дотягивает просадку, — держим её дальше.
                press()
            } else {
                phase = .waiting
                schedule(after: PressMotion.pressDelay) { press() }
            }
        case .ended:
            // Тап короче паузы — просадка на отпускании, и всё равно на полный минимум.
            if phase == .waiting { press() }
            if phase == .held { lift() }
        case .cancelled:
            cancel()
        }
    }

    private func press() {
        timer?.cancel()
        phase = .held
        pressedAt = .now
        isTouched = true
    }

    private func lift() {
        phase = .lifting
        schedule(after: PressMotion.minimumHold - (ContinuousClock.now - pressedAt)) {
            phase = .idle
            isTouched = false
        }
    }

    private func cancel() {
        timer?.cancel()
        timer = nil
        phase = .idle
        isTouched = false
    }

    private func schedule(after delay: Duration, _ action: @escaping () -> Void) {
        timer?.cancel()
        timer = Task {
            if delay > .zero { try? await Task.sleep(for: delay) }
            guard !Task.isCancelled else { return }
            action()
        }
    }
}

// MARK: - Касание

private enum PressTouchChange {
    case began, ended, cancelled
}

/// Мост к UIKit: распознаватель на вью, который видит палец без задержки скролла.
private struct PressTouchTracker: UIGestureRecognizerRepresentable {
    /// `-debugSystemPress` — без распознавателя, на одном системном `isPressed`:
    /// сравнить с прежним поведением или исключить распознаватель из подозреваемых.
    static let isDisabledForDebug = UserDefaults.standard.bool(forKey: "debugSystemPress")

    let depth: Int
    let isEnabled: Bool
    let onTouch: (PressTouchChange) -> Void

    func makeUIGestureRecognizer(context: Context) -> PressTouchRecognizer {
        PressTouchRecognizer(target: nil, action: nil)
    }

    func updateUIGestureRecognizer(_ recognizer: PressTouchRecognizer, context: Context) {
        recognizer.depth = depth
        recognizer.isEnabled = isEnabled && !Self.isDisabledForDebug
        recognizer.onTouch = onTouch
    }
}

/// Пассивный распознаватель: сам никогда не срабатывает — значит, не отнимает касание
/// ни у скролла, ни у кнопки, ни у контекстного меню, — и ими не отменяется. Что касание
/// стало скроллом, он решает сам: по сдвигу пальца и по тяге скролла.
private final class PressTouchRecognizer: UIGestureRecognizer {
    var depth = 0
    var onTouch: (PressTouchChange) -> Void = { _ in }

    private(set) weak var touch: UITouch?
    private var origin = CGPoint.zero
    /// Касание за этим распознавателем, а не за вложенным (кнопка «ещё» в строке).
    private var isOwner = false

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
        guard touch == nil, let first = touches.first else { return }
        // Этим касанием останавливают инерцию скролла: кнопка под ним не сработает,
        // и проседать ей незачем.
        guard !Self.isScrolling(under: first) else {
            state = .failed
            return
        }
        touch = first
        origin = first.location(in: nil)
        isOwner = PressTouchArbiter.claim(first, by: self)
        if isOwner { onTouch(.began) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let touch, touches.contains(touch) else { return }
        let point = touch.location(in: nil)
        if hypot(point.x - origin.x, point.y - origin.y) > PressMotion.slop || Self.isScrolling(under: touch) {
            finish(.cancelled)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        guard let touch else {
            state = .failed
            return
        }
        if touches.contains(touch) { finish(.ended) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        guard let touch else {
            state = .failed
            return
        }
        if touches.contains(touch) { finish(.cancelled) }
    }

    override func reset() {
        super.reset()
        // Сюда же приходит отключение распознавателя посреди касания.
        end(.cancelled)
    }

    /// Касание забрал вложенный распознаватель.
    func cede() {
        guard isOwner else { return }
        isOwner = false
        onTouch(.cancelled)
    }

    private func finish(_ change: PressTouchChange) {
        end(change)
        state = .failed
    }

    private func end(_ change: PressTouchChange) {
        guard let touch else { return }
        PressTouchArbiter.leave(touch, by: self)
        self.touch = nil
        if isOwner {
            isOwner = false
            onTouch(change)
        }
    }

    private static func isScrolling(under touch: UITouch) -> Bool {
        guard let view = touch.view else { return false }
        return sequence(first: view, next: \.superview).contains { view in
            guard let scroll = view as? UIScrollView else { return false }
            return scroll.isDragging || scroll.isDecelerating
        }
    }
}

/// Палец над вложенными нажимаемыми вью видят все их распознаватели. Касание достаётся
/// самому глубокому: в строке с кнопкой «ещё» проседает кнопка, а не строка.
@MainActor
private enum PressTouchArbiter {
    private struct Owner {
        weak var recognizer: PressTouchRecognizer?
    }

    private static var owners: [ObjectIdentifier: Owner] = [:]

    /// `true` — касание теперь за `recognizer`.
    static func claim(_ touch: UITouch, by recognizer: PressTouchRecognizer) -> Bool {
        let key = ObjectIdentifier(touch)
        if let owner = owners[key]?.recognizer, owner !== recognizer, owner.touch === touch {
            guard recognizer.depth > owner.depth else { return false }
            owner.cede()
        }
        owners[key] = Owner(recognizer: recognizer)
        return true
    }

    static func leave(_ touch: UITouch, by recognizer: PressTouchRecognizer) {
        let key = ObjectIdentifier(touch)
        if owners[key]?.recognizer === recognizer { owners[key] = nil }
    }
}
