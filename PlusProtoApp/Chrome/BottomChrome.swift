import SwiftUI
import UIKit

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
}

/// Фиксированный нижний хром. Живёт в ZStack корня, **вне** `NavigationStack` — внутри
/// он ездил бы вместе с пушами.
struct BottomChrome: View {
    @Environment(ActionBarState.self) private var actionBar
    @Environment(KeyboardObserver.self) private var keyboard

    var body: some View {
        ZStack(alignment: .bottom) {
            TabBarUnderlay()
            VStack(spacing: PlusChromeMetrics.actionBarToTabsGap) {
                ActionBarView()
                TabBarView()
                    .opacity(actionBar.isSearchFocused ? 0 : 1)
                    .allowsHitTesting(!actionBar.isSearchFocused)
            }
            .animation(ActionBarMotion.morph, value: actionBar.isSearchFocused)
        }
        .offset(y: actionBar.isSearchFocused ? -keyboard.height : 0)
        .animation(.smooth(duration: 0.25), value: keyboard.height)
    }
}

/// Скрим таббара: 16-стоповый градиент высотой 210, прижат к физическому низу экрана
/// и уходит под home indicator (figma-tabbar §7). Накрывает и таббар, и action bar —
/// поэтому это отдельный слой хрома, а не фон ряда табов.
private struct TabBarUnderlay: View {
    var body: some View {
        PlusGradient.tabBarUnderlay
            .frame(height: PlusMetrics.tabBarUnderlayHeight)
            .allowsHitTesting(false)
            .ignoresSafeArea(edges: .bottom)
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
