import SwiftUI
import UIKit
import VariableBlur

/// Геометрия нижнего хрома. Все числа — из спек: figma-tabbar §2/§7, figma-screen1 §4.
enum PlusChromeMetrics {
    /// Ряд табов: padding-top 4 + кнопки 62 (figma-tabbar §2)
    static let tabsRowHeight: CGFloat = 66
    static let tabsRowTopPadding: CGFloat = 4

    /// Зазор между нижней кромкой action bar (y 2084) и фреймом таббара (y 2088) — figma-screen1 §4
    static let actionBarToTabsGap: CGFloat = 4

    /// Сколько хром занимает над safe area: 60 + 4 + 66. На iPhone с home indicator 34pt
    /// это те самые 164pt от низа экрана, которые в figma-screen1 §4 должна очистить лента.
    static var contentBottomInset: CGFloat {
        PlusMetrics.actionBarHeight + actionBarToTabsGap + tabsRowHeight
    }

    /// Радиус прогрессивного блюра под нижним хромом. В Figma слой блюра есть, но выставлен
    /// в 0 — значение взято из `BottomBarV2` MusicPlayer, где та же полоса поверх ленты.
    static let underlayBlurRadius: CGFloat = 10

    /// Отступ от клавиатуры до низа action bar при фокусе поиска (`2021:11248`).
    static let focusKeyboardGap: CGFloat = 12

    /// Высота слоя блюра — **ниже градиента**: размытие должно начинаться примерно
    /// с середины action bar, иначе лента мылится ещё до того, как заедет под хром.
    /// Считается от физического низа: safe area + ряд табов + зазор + половина бара.
    static var underlayBlurHeight: CGFloat {
        bottomSafeArea + tabsRowHeight + actionBarToTabsGap + PlusMetrics.actionBarHeight / 2
    }

    /// Нижняя безопасная зона — блюр отмеряется от физического низа экрана,
    /// а высота home indicator зависит от устройства.
    static var bottomSafeArea: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets.bottom ?? 0
    }

    // MARK: - Верхний скрим

    /// Высота верхнего скрима от физического верха экрана — `overlay bg` навбара
    /// (`2004:10781`, figma-screen1 §4): 72pt, чёрный 50% → прозрачный вниз.
    static let topScrimHeight: CGFloat = 72
    /// Два слоя блюра разной высоты и радиуса — приём `TopNavBarBackground` из MusicPlayer:
    /// слабый и высокий даёт мягкий заход, сильный и низкий — плотность у самого верха.
    /// Выше 72pt не поднимаемся: в MusicPlayer блюр перекрывал градиент, но там под ним
    /// был только скролл, а здесь на 72pt начинается заголовок витрины — более высокий
    /// слой мылил бы его в покое.
    static let topScrimBlurSoft: (radius: CGFloat, height: CGFloat) = (4, 72)
    static let topScrimBlurStrong: (radius: CGFloat, height: CGFloat) = (14, 54)
}

/// Верхний скрим: лента уезжает под статус-бар, поэтому его надо притенить и размыть.
/// Отдельный слой поверх контента, вне `NavigationStack` — как и нижний хром.
struct TopScrim: View {
    var body: some View {
        ZStack(alignment: .top) {
            VariableBlurView(
                maxBlurRadius: PlusChromeMetrics.topScrimBlurSoft.radius,
                direction: .blurredTopClearBottom
            )
            .frame(height: PlusChromeMetrics.topScrimBlurSoft.height)

            VariableBlurView(
                maxBlurRadius: PlusChromeMetrics.topScrimBlurStrong.radius,
                direction: .blurredTopClearBottom
            )
            .frame(height: PlusChromeMetrics.topScrimBlurStrong.height)

            LinearGradient(
                colors: [.black.opacity(0.5), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: PlusChromeMetrics.topScrimHeight)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea(edges: .top)
    }
}

/// Фиксированный нижний хром. Живёт в ZStack корня, **вне** `NavigationStack` — внутри
/// он ездил бы вместе с пушами.
struct BottomChrome: View {
    @Environment(ActionBarState.self) private var actionBar
    @Environment(KeyboardObserver.self) private var keyboard

    var body: some View {
        VStack(spacing: PlusChromeMetrics.actionBarToTabsGap) {
            // Поднимается только бар. Таббар остаётся на своём месте и уходит
            // под клавиатуру — гасить его не нужно (решение пользователя 2026-08-23).
            // Подъём уехал ВНУТРЬ бара: он обязан висеть на общем предке обеих зон
            // под той же единственной анимацией, что и ширины зон и уезд плеера.
            ActionBarView(raise: raise)

            TabBarView()
                .allowsHitTesting(!actionBar.isSearchFocused)
        }
        // Системный подъём над клавиатурой выключен: SwiftUI поднял бы весь хром
        // вместе с таббаром, да ещё и сложился бы с нашим сдвигом — бар улетал вдвое выше.
        .ignoresSafeArea(.keyboard)
    }

    /// Единственный источник фокусной геометрии бара: и подъём, и ширины зон, и уезд
    /// плеера считаются отсюда, из ОДНОГО предиката. Драйвер — состояние клавиатуры,
    /// а не флаг фокуса: так оба края перехода (подъём и опускание) начинаются ровно
    /// тогда, когда трогается клавиатура, и всё меняется одним апдейтом.
    /// В приложении одно текстовое поле — поиск; если появится второе, добавить
    /// `&& actionBar.isSearchFocused`.
    ///
    /// Подъём: низ бара встаёт на 12pt над клавиатурой (`2021:11248` — бар 775..835
    /// при клавиатуре с 847).
    private var raise: ActionBarRaise {
        guard keyboard.isUp else { return .none }
        let barBottomFromScreenBottom = PlusChromeMetrics.bottomSafeArea
            + PlusChromeMetrics.tabsRowHeight
            + PlusChromeMetrics.actionBarToTabsGap
        // min(0,) обязателен: с аппаратной клавиатурой overlap == 0 (или 55pt панели
        // шорткатов) — бар не должен уезжать ВНИЗ.
        let lift = min(0, -(keyboard.overlap + PlusChromeMetrics.focusKeyboardGap - barBottomFromScreenBottom))
        return ActionBarRaise(isRaised: true, lift: lift)
    }
}

/// Подложка нижнего хрома: прогрессивный блюр под 16-стоповым градиентом, высота 210,
/// уходит под home indicator (figma-tabbar §7). Накрывает и таббар, и action bar —
/// поэтому это отдельный слой, а не фон ряда табов.
///
/// Живёт не внутри `BottomChrome`, а слоем в `AppRootView`: хром висит в
/// `overlay(alignment: .bottom)`, а тот прижат к границе safe area и `ignoresSafeArea`
/// изнутри наружу не пробивает — подложка обрезалась, и в зоне home indicator контент
/// оставался неприкрытым.
///
/// В Figma у подложки есть слой `backdrop-blur`, выставленный в 0 — размытие заложено,
/// но не настроено. Берём приём из MusicPlayer (`BottomBarV2.chromeBackground`):
/// `VariableBlurView` размывает по нарастающей к низу, поэтому у полосы нет видимой
/// кромки, с которой резко начинается размытие.
struct TabBarUnderlay: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            VariableBlurView(
                maxBlurRadius: PlusChromeMetrics.underlayBlurRadius,
                direction: .blurredBottomClearTop
            )
            .frame(height: PlusChromeMetrics.underlayBlurHeight)

            PlusGradient.tabBarUnderlay
                .frame(height: PlusMetrics.tabBarUnderlayHeight)
        }
        .allowsHitTesting(false)
    }
}

/// Клавиатура: насколько она перекрывает экран снизу. Хром при фокусе поиска встаёт
/// над ней, поэтому нужна **полная** высота перекрытия от нижней кромки экрана,
/// а не остаток над safe area — отступ до бара отмеряется от верха клавиатуры.
@Observable
final class KeyboardObserver {
    private(set) var overlap: CGFloat = 0
    /// Клавиатура на экране. Отдельный флаг, а не `overlap > 0`: с аппаратной
    /// клавиатурой (⌘K в симуляторе) overlap равен нулю или высоте панели шорткатов,
    /// а раскладка бара обязана раскрыться — иначе не появится крест и фокус нечем снять.
    /// Меняется в том же `withAnimation`, что и `overlap`: обе величины приходят во вью
    /// одним апдейтом.
    private(set) var isUp = false
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        observers.append(
            center.addObserver(
                forName: UIResponder.keyboardWillChangeFrameNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                guard
                    let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                    let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
                else { return }
                let screenHeight = UIScreen.main.bounds.height
                let next = max(0, screenHeight - frame.origin.y)
                withAnimation(.smooth(duration: duration)) {
                    self?.overlap = next
                    self?.isUp = true
                }
            }
        )
        observers.append(
            center.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                // Длительность — из самой клавиатуры, а не константой: обратный переход
                // обязан совпасть с её кривой так же, как прямой.
                let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
                withAnimation(.smooth(duration: duration)) {
                    self?.overlap = 0
                    self?.isUp = false
                }
            }
        )
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

}
