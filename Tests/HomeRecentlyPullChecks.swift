import Foundation

@main enum HomeRecentlyPullChecks {
    struct Gesture {
        var policy = HomeRecentlyPullPolicy()
        var progress: CGFloat = 0
        var feedback: [HomeRecentlyPullPolicy.Feedback] = []

        mutating func phase(_ phase: HomeRecentlyPullPolicy.Phase, _ offset: CGFloat = 0) {
            policy.setPhase(phase, offset: offset, progress: progress)
        }
        @discardableResult mutating func move(_ offset: CGFloat) -> CGFloat? {
            guard let update = policy.move(to: offset, progress: progress) else { return nil }
            progress = update.progress
            if let event = update.feedback { feedback.append(event) }
            return update.scrollOffset
        }
        @discardableResult mutating func consume(_ travel: CGFloat) -> CGFloat? {
            guard let update = policy.consume(travel, progress: progress) else { return nil }
            progress = update.progress
            if let event = update.feedback { feedback.append(event) }
            return update.scrollOffset
        }
        func expect(_ expected: CGFloat) {
            precondition(abs(progress - expected) < 0.000001, "Expected \(expected), got \(progress)")
        }
    }

    static func main() {
        var pull = Gesture()
        pull.phase(.tracking)
        pull.phase(.interacting)
        pull.move(-0.1)
        pull.expect(0.1 / 64) // Нет мёртвой зоны даже до первого полного пункта.
        pull.move(-32)
        pull.expect(0.5)
        pull.move(-64)
        pull.move(-80)
        pull.expect(1)
        precondition(pull.feedback == [.expanded], "Хаптика достижения максимума только один раз")
        pull.phase(.settling)
        pull.move(12)
        pull.phase(.idle)
        pull.expect(1) // Отскок исходного оттяга не сворачивает.

        pull.phase(.tracking)
        pull.phase(.interacting)
        precondition(pull.move(16) == 0)
        pull.expect(0.75)
        precondition(pull.move(40) == 0)
        pull.expect(0.125)
        precondition(pull.move(12) == 4, "Остаток свайпа после сворачивания идёт в скролл")
        pull.expect(0)
        precondition(pull.feedback == [.expanded, .collapsed])
        pull.move(-80)
        pull.expect(0) // Нельзя заново раскрыть в том же жесте.

        var deep = Gesture()
        deep.phase(.tracking, 150)
        deep.phase(.interacting, 150)
        deep.move(0)
        deep.move(-80)
        deep.expect(0)
        deep.phase(.idle)
        deep.phase(.tracking)
        deep.phase(.interacting)
        deep.move(-64)
        deep.expect(1) // Следующий отдельный жест от нуля разрешён.

        for offset: CGFloat in [2, 2.01] {
            var boundary = Gesture()
            boundary.phase(.tracking, offset)
            boundary.phase(.interacting, offset)
            boundary.move(-64)
            boundary.expect(offset == 2 ? 1 : 0)
            precondition(boundary.feedback == (offset == 2 ? [.expanded] : []),
                         "Раскрытие разрешено до границы допуска включительно")
        }

        var partial = Gesture()
        partial.phase(.tracking)
        partial.phase(.interacting)
        partial.move(-24)
        partial.phase(.idle)
        partial.phase(.tracking)
        partial.phase(.interacting)
        precondition(partial.move(10) == 0)
        partial.phase(.settling)
        precondition(partial.move(20) == 6) // Инерция тоже сначала закрывает остаток.
        partial.expect(0)
        precondition(partial.feedback == [.collapsed])

        // Закрытие не требует точного offset=0: он может отличаться после
        // перераскладки или незавершённого отскока предыдущего жеста.
        for offset: CGFloat in [3, 12, 150] {
            var active = Gesture()
            active.progress = 1
            active.phase(.tracking, offset)
            active.phase(.interacting, offset)
            precondition(active.move(64) == 0)
            active.expect(0)
            precondition(active.feedback == [.collapsed])
        }

        var reversal = Gesture()
        reversal.progress = 1
        reversal.phase(.tracking, -1)
        reversal.phase(.interacting, -1)
        reversal.move(-1) // Небольшое обратное движение не блокирует закрытие.
        precondition(reversal.consume(64) == 0)
        reversal.expect(0)
        precondition(reversal.consume(64) == nil)
        reversal.move(-80)
        reversal.expect(0)
        precondition(reversal.feedback == [.collapsed], "Повторное закрытие не дублирует хаптику")

        var short = Gesture()
        short.progress = 1
        short.phase(.tracking)
        short.phase(.interacting)
        precondition(short.consume(4) == 0)
        short.expect(0.9375)
        precondition(short.feedback.isEmpty)
        short.phase(.idle)
        // Контроллер завершает остаток короткого свайпа при idle через consume.
        precondition(short.consume(short.progress * HomeRecentlyPullConfig.travel) == 0)
        short.expect(0)
        precondition(short.feedback == [.collapsed])

        // Повторный оттяг уже раскрытой ленты и его отскок не закрывают режим.
        pull.phase(.idle)
        pull.phase(.tracking)
        pull.phase(.interacting)
        pull.move(-64)
        pull.phase(.idle)
        pull.phase(.tracking)
        pull.phase(.interacting)
        pull.move(-20)
        pull.phase(.settling)
        pull.move(12)
        pull.expect(1)

        var cancelled = Gesture()
        cancelled.phase(.tracking)
        cancelled.phase(.interacting)
        cancelled.move(-20)
        cancelled.policy.reset()
        cancelled.progress = 0
        cancelled.move(-80)
        cancelled.expect(0)
        print("PASS: first-pixel response, continuous progress, collapse before scroll, residual travel, one-shot feedback, bounce and repeat gesture")
    }
}
