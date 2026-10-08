import SwiftUI
import UIKit

/// Пара ✕/✓ под карточкой витрины — фидбек на айтем (задача пользователя 2026-10-03).
///
/// - **✕ — «покажи другое»**: весь айтем со всеми атрибутами и самой парой гаснет
///   (прозрачность, блюр, масштаб до 0.95) за 400 мс, на его месте встаёт такой же
///   айтем с новым контентом и проявляется так же — вместе с новой парой (поправка
///   пользователя тем же днём: сперва пара стояла на месте). Кнопкой крест блок
///   обновляется.
/// - **✓ — «то, что надо»**: хаптик success, кнопка резко белеет, через 800 мс пара
///   гаснет (прозрачность, блюр, масштаб до 0.9). Айтем остаётся.
///
/// Общая у четырёх карточек с парой — кино, альбом, книга, «Моя Волна». Состояние —
/// одно на карточку (`ShowcaseFeedbackHost`), новый контент готовит каталог витрины
/// (`ShowcaseCatalog.prepareReplacement`).
enum ShowcaseFeedbackMotion {
    /// Уход и появление айтема — по 400 мс (задача пользователя). Кривая — стандартная
    /// ease-in-out «движение по экрану»: айтем не уезжает и не въезжает, а сменяется
    /// на месте, и обе половины смены должны быть одного характера.
    static let swap: Duration = .milliseconds(400)
    static let swapOut: Animation = .timingCurve(0.4, 0, 0.2, 1, duration: 0.4)
    static let swapIn: Animation = .timingCurve(0.4, 0, 0.2, 1, duration: 0.4)
    /// Масштаб погасшего айтема и погасшей пары — числа задачи
    static let hiddenContentScale: CGFloat = 0.95
    static let hiddenPairScale: CGFloat = 0.9
    /// Блюр погасшего — в пределах «не больше 20», иначе дорого: поверх постера
    /// уже лежит блюр его ореола.
    static let hiddenBlur: CGFloat = 10
    /// Белая ✓ держится столько, прежде чем пара начнёт гаснуть (задача пользователя)
    static let doneHold: Duration = .milliseconds(800)
    /// Уход пары после ✓ — системный отклик на выбор, короче смены айтема
    static let pairOut: Animation = .easeOut(duration: 0.3)
}

/// Состояние пары и смены айтема — одно на карточку.
@MainActor
@Observable
final class ShowcaseFeedbackState {
    /// Айтем погашен — идёт смена контента
    var isContentHidden = false
    /// Смена в пути: пара не нажимается, повторный ✕ не запускает вторую смену
    var isSwapping = false
    /// ✓ нажата — кнопка белая
    var isDone = false
    /// Пара погасла после ✓
    var isPairHidden = false
    /// Отладочные нажатия ✕ и ✓ (`-debugShowcaseDismiss`, `-debugShowcaseDone`):
    /// тапнуть по симулятору из шелла нечем, а смену айтема иначе не снять на видео.
    var debugDismisses = 0
    var debugDones = 0
}

/// Как карточке получить новый контент: готовит замену и возвращает, чем её поставить.
/// `nil` — замены нет (моковая лента без сети, сеть не ответила вовремя) — тогда айтем
/// проявляется прежним.
struct ShowcaseRefresh {
    var prepare: @MainActor () async -> (@MainActor () -> Void)?
    /// Своя смена по ✕ вместо стандартной: промо «Главной» не подменяет айтем, а убирает
    /// его из круга (`ShowcasePromo`). Пара только помечает смену начатой и зовёт её —
    /// гасит контент и снимает `isSwapping` уже вызванный.
    var custom: (@MainActor () -> Void)? = nil

    static let none = ShowcaseRefresh { nil }
}

extension EnvironmentValues {
    @Entry var showcaseRefresh: ShowcaseRefresh = .none
}

/// Держатель состояния пары для одной карточки. Живёт в ленте на слот, а не на контент
/// (см. `ShowcaseFeedView`): смена айтема меняет блок, но не пересоздаёт карточку —
/// иначе карточка вставала бы заново, с появлением ленты, а смену ведёт состояние,
/// которое обязано пережить подмену блока.
struct ShowcaseFeedbackHost<Content: View>: View {
    /// Номер блока в ленте, с единицы, — для отладочных нажатий.
    var debugIndex: Int = 0
    @ViewBuilder var content: Content
    @State private var state = ShowcaseFeedbackState()

    var body: some View {
        content
            .environment(state)
            #if DEBUG
            // `-debugShowcaseDismiss <n>` / `-debugShowcaseDone <n>` — ✕ или ✓ у n-го блока
            // ленты через 6 с (живые данные и заготовки замен к этому времени готовы).
            // ✕ — дважды, с паузой: видно и смену, и вторую замену из заготовки.
            .task {
                let defaults = UserDefaults.standard
                let dismissIndex = defaults.integer(forKey: "debugShowcaseDismiss")
                let doneIndex = defaults.integer(forKey: "debugShowcaseDone")
                guard debugIndex > 0, dismissIndex == debugIndex || doneIndex == debugIndex else { return }
                try? await Task.sleep(for: .seconds(6))
                if doneIndex == debugIndex {
                    state.debugDones += 1
                    return
                }
                state.debugDismisses += 1
                try? await Task.sleep(for: .seconds(3))
                state.debugDismisses += 1
            }
            #endif
    }
}

/// Гаснет и проявляется вместе со сменой айтема. Вешается на каждый слой контента
/// карточки отдельно (постер, подпись, орб) — до его расстановки по макету, чтобы
/// масштаб шёл от центра самого слоя. Пара гаснет с ними сама (`ShowcaseFeedbackPair`).
struct ShowcaseContentSwap: ViewModifier {
    @Environment(ShowcaseFeedbackState.self) private var state: ShowcaseFeedbackState?

    func body(content: Content) -> some View {
        content.modifier(ShowcaseHideEffect(
            isHidden: state?.isContentHidden ?? false,
            scale: ShowcaseFeedbackMotion.hiddenContentScale
        ))
    }
}

/// Прозрачность, блюр и масштаб погасшего. С «уменьшением движения» — одна
/// прозрачность: блюр и масштаб — это движение.
private struct ShowcaseHideEffect: ViewModifier {
    let isHidden: Bool
    let scale: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let moves = isHidden && !reduceMotion
        content
            .blur(radius: moves ? ShowcaseFeedbackMotion.hiddenBlur : 0)
            .scaleEffect(moves ? scale : 1)
            .opacity(isHidden ? 0 : 1)
    }
}

extension View {
    /// Слой контента карточки с парой ✕/✓ — см. `ShowcaseContentSwap`.
    func showcaseSwappable() -> some View {
        modifier(ShowcaseContentSwap())
    }
}

/// Пара ✕/✓: крест слева, галочка справа (задача пользователя; прежде ♥ слева, ✕ справа).
/// Кадр пары прежний — 40 + 6 + 40, и стоит она там же, где стояла. При смене айтема
/// гаснет вместе с ним — тем же движением и до того же масштаба 0.95.
struct ShowcaseFeedbackPair: View {
    @Environment(ShowcaseFeedbackState.self) private var state: ShowcaseFeedbackState?
    @Environment(\.showcaseRefresh) private var refresh

    var body: some View {
        HStack(spacing: PlusMetrics.circleButtonGap) {
            GlassIconButton(icon: "iconCross", accessibilityTitle: "Показать другое", action: dismiss)
            doneButton
        }
        .modifier(ShowcaseHideEffect(
            isHidden: (state?.isPairHidden ?? false) || (state?.isContentHidden ?? false),
            scale: (state?.isPairHidden ?? false)
                ? ShowcaseFeedbackMotion.hiddenPairScale
                : ShowcaseFeedbackMotion.hiddenContentScale
        ))
        .allowsHitTesting(!(state?.isSwapping ?? false) && !(state?.isDone ?? false))
        .accessibilityHidden(state?.isPairHidden ?? false)
        .onChange(of: state?.debugDismisses) { dismiss() }
        .onChange(of: state?.debugDones) { done() }
    }

    /// ✓ — стеклянный круг, после нажатия белый с чёрной галочкой. Белеет резко,
    /// без анимации (задача пользователя): это отметка, а не переход.
    private var doneButton: some View {
        let isDone = state?.isDone ?? false
        return Button(action: done) {
            Image("iconDone")
                .renderingMode(.template)
                .resizable()
                .frame(width: GlassIconButtonConfig.iconBox, height: GlassIconButtonConfig.iconBox)
                .foregroundStyle(isDone ? Color.black : Color.fillOne)
                .frame(width: GlassIconButtonConfig.size, height: GlassIconButtonConfig.size)
                .background {
                    if isDone {
                        Circle().fill(Color.white)
                    }
                }
                .modifier(GlassUnlessDone(isDone: isDone))
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("То, что надо")
        .accessibilityAddTraits(isDone ? .isSelected : [])
    }

    /// ✕: айтем гаснет, каталог тем временем готовит замену; новый контент встаёт,
    /// когда старый погас и замена готова, — и проявляется. Хаптик — обычный одиночный.
    private func dismiss() {
        guard let state, !state.isSwapping, !state.isDone else { return }
        state.isSwapping = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if let custom = refresh.custom {
            custom()
            return
        }
        withAnimation(ShowcaseFeedbackMotion.swapOut) { state.isContentHidden = true }
        let prepare = refresh.prepare
        Task { @MainActor in
            async let replacement = prepare()
            try? await Task.sleep(for: ShowcaseFeedbackMotion.swap)
            let apply = await replacement
            apply?()
            withAnimation(ShowcaseFeedbackMotion.swapIn) { state.isContentHidden = false }
            try? await Task.sleep(for: ShowcaseFeedbackMotion.swap)
            state.isSwapping = false
        }
    }

    /// ✓: хаптик success (двойное вибро), кнопка белеет сразу, через 800 мс пара гаснет.
    private func done() {
        guard let state, !state.isSwapping, !state.isDone else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        state.isDone = true
        Task { @MainActor in
            try? await Task.sleep(for: ShowcaseFeedbackMotion.doneHold)
            withAnimation(ShowcaseFeedbackMotion.pairOut) { state.isPairHidden = true }
        }
    }
}

/// Стекло у ✓ — пока она не нажата; белый круг стеклом не накрывается.
private struct GlassUnlessDone: ViewModifier {
    let isDone: Bool

    func body(content: Content) -> some View {
        if isDone {
            content
        } else {
            content.glassCircle()
        }
    }
}
