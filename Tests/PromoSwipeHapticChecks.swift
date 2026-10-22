import Foundation

@main enum PromoSwipeHapticChecks {
    static func main() {
        let policy = PromoSwipeHapticPolicy()
        precondition(!policy.moved(to: 10)) // Загрузка и программный переход.
        policy.begin(at: 10)
        precondition(!policy.interact(at: 10.1))
        precondition(!policy.moved(to: 10.49))
        precondition(policy.moved(to: 10.51)) // До idle, сразу при смене центра.
        precondition(!policy.moved(to: 11))
        precondition(!policy.moved(to: 10)) // Не дублировать при обратном движении.
        policy.reset()
        policy.begin(at: 11)
        precondition(!policy.moved(to: 10.4)) // Геометрия пришла раньше interacting.
        precondition(policy.interact(at: 10.4))
        precondition(!policy.moved(to: 10))
        policy.reset()
        policy.begin(at: 10)
        precondition(!policy.interact(at: 10))
        precondition(!policy.moved(to: 10.2))
        precondition(policy.moved(to: 11)) // Финальная геометрия из context фазы idle.
        policy.reset()
        precondition(!policy.moved(to: 31)) // Перенос на среднюю копию карусели.
        policy.begin(at: 31)
        precondition(!policy.interact(at: 31.2))
        precondition(!policy.moved(to: 31)) // Недостаточный свайп.
        print("PASS: soft haptic per user swipe, early geometry, final phase geometry, no duplicates or programmatic feedback")
    }
}
