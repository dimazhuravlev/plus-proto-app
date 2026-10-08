import UIKit

/// Свайп от левого края — назад, на всех экранах стека (жалоба пользователя 2026-10-06:
/// не работал). Навбар везде скрыт (`.toolbar(.hidden, for: .navigationBar)`), а со
/// скрытой панелью UIKit отключает жест возврата сам: его штатный делегат запрещает
/// старт. Делегат — сам навигационный контроллер: жест стартует, когда есть куда
/// возвращаться и не идёт другой переход.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === interactivePopGestureRecognizer else { return true }
        return viewControllers.count > 1 && transitionCoordinator == nil
    }

    /// Карусели у края ждут, пока жест возврата не откажется: иначе горизонтальная
    /// лента, начатая от кромки, забирала бы свайп назад себе. Касание не у края жест
    /// отклоняет сразу — лента не ждёт.
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        gestureRecognizer === interactivePopGestureRecognizer && otherGestureRecognizer.view is UIScrollView
    }
}
