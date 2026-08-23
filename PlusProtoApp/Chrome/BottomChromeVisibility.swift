import SwiftUI

/// Экран может попросить убрать нижний хром приложения — action bar и таббар.
///
/// Нужно карточке тайтла: у неё своя панель действий, прибитая к низу, и по макету
/// под ней экрана нет вовсе. Общий хром там читался бы вторым дном.
///
/// Именно `PreferenceKey`, а не флаг в `AppNavigationState`: значение собирается из
/// текущего дерева вью, поэтому когда экран снимается — хром возвращается сам.
/// Ставить и снимать флаг руками в `onAppear`/`onDisappear` пришлось бы вручную,
/// а их порядок при push/pop не гарантирован: на попе новый экран успевает появиться
/// раньше, чем старый исчезнет, и снятие затирает установку.
struct BottomChromeHiddenKey: PreferenceKey {
    static let defaultValue = false

    /// `||`, а не присваивание: если хром прячет хоть один экран в стеке, он спрятан.
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension View {
    /// Спрятать нижний хром приложения, пока этот экран в дереве.
    func hidesBottomChrome(_ hidden: Bool = true) -> some View {
        preference(key: BottomChromeHiddenKey.self, value: hidden)
    }
}
