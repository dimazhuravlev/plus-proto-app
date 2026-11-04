import Foundation

/// Ограничивает ожидание промозамены. Отмена наблюдателя не отменяет общую заготовку.
/// Поздний результат после таймаута больше не может возобновить вызов или попасть в UI.
@MainActor enum PromoTaskDeadline {
    static func value<Value>(of task: Task<Value?, Never>, within limit: Duration) async -> Value? {
        let waiter = Waiter<Value>()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                waiter.start(continuation, task: task, limit: limit)
            }
        } onCancel: {
            Task { @MainActor in waiter.finish(nil) }
        }
    }

    private final class Waiter<Value> {
        private var continuation: CheckedContinuation<Value?, Never>?
        private var observer: Task<Void, Never>?
        private var timer: Task<Void, Never>?

        func start(_ continuation: CheckedContinuation<Value?, Never>, task: Task<Value?, Never>, limit: Duration) {
            self.continuation = continuation
            guard !Task.isCancelled else { finish(nil); return }
            observer = Task { @MainActor [weak self] in
                let value = await task.value
                self?.finish(value)
            }
            timer = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: limit) }
                catch { return }
                self?.finish(nil)
            }
        }

        func finish(_ value: Value?) {
            guard let continuation else { return }
            self.continuation = nil
            observer?.cancel()
            timer?.cancel()
            observer = nil
            timer = nil
            continuation.resume(returning: value)
        }
    }
}
