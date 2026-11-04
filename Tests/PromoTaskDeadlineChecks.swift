import Foundation

@main enum PromoTaskDeadlineChecks {
    @MainActor static func main() async {
        let clock = ContinuousClock()
        let slow = Task<Int?, Never> {
            try? await Task.sleep(for: .milliseconds(400))
            return 42
        }
        let start = clock.now
        let timedOut = await PromoTaskDeadline.value(of: slow, within: .milliseconds(30))
        precondition(timedOut == nil && start.duration(to: clock.now) < .milliseconds(250), "Deadline waits for dependency")
        let completed = await slow.value
        precondition(completed == 42 && !slow.isCancelled, "Timeout must not cancel shared work")
        let quick = Task<Int?, Never> { 7 }
        let value = await PromoTaskDeadline.value(of: quick, within: .seconds(1))
        precondition(value == 7)
        let failed = Task<Int?, Never> { nil }
        let missing = await PromoTaskDeadline.value(of: failed, within: .seconds(1))
        precondition(missing == nil)
        let pending = Task<Int?, Never> {
            try? await Task.sleep(for: .milliseconds(400))
            return 9
        }
        let waiter = Task { await PromoTaskDeadline.value(of: pending, within: .seconds(3)) }
        try? await Task.sleep(for: .milliseconds(10))
        let cancelStart = clock.now
        waiter.cancel()
        let cancelled = await waiter.value
        precondition(cancelled == nil && cancelStart.duration(to: clock.now) < .milliseconds(250))
        let late = await pending.value
        precondition(late == 9 && !pending.isCancelled)
        for _ in 0..<20 {
            let task = Task<Int?, Never> { 1 }
            let waiter = Task { await PromoTaskDeadline.value(of: task, within: .zero) }
            waiter.cancel()
            _ = await waiter.value
        }
        print("PASS: actual deadline, early success/nil, prompt cancellation, safe late completion and immediate races")
    }
}
