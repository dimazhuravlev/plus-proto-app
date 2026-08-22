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
    static let underlayBlurRadius: CGFloat = 12

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
            ActionBarView()
            TabBarView()
                .opacity(actionBar.isSearchFocused ? 0 : 1)
                .allowsHitTesting(!actionBar.isSearchFocused)
        }
        .animation(ActionBarMotion.morph, value: actionBar.isSearchFocused)
        .offset(y: actionBar.isSearchFocused ? -keyboard.height : 0)
        .animation(.smooth(duration: 0.25), value: keyboard.height)
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
            .frame(height: PlusMetrics.tabBarUnderlayHeight)

            PlusGradient.tabBarUnderlay
                .frame(height: PlusMetrics.tabBarUnderlayHeight)
        }
        .allowsHitTesting(false)
    }
}

/// Высота клавиатуры над home indicator — поднимает нижний хром при фокусе поиска.
@Observable
final class KeyboardObserver {
    private(set) var height: CGFloat = 0
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
                let overlap = max(0, screenHeight - frame.origin.y)
                let bottomInset = Self.bottomSafeAreaInset
                let next = overlap > 0 ? max(0, overlap - bottomInset) : 0
                withAnimation(.smooth(duration: duration)) {
                    self?.height = next
                }
            }
        )
        observers.append(
            center.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                withAnimation(.smooth(duration: 0.25)) {
                    self?.height = 0
                }
            }
        )
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    private static var bottomSafeAreaInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets.bottom ?? 0
    }
}
