import UIKit

/// Единые параметры жестов Recently и реакций промокарусели.
@MainActor enum HomeInteractionHaptics {
    private static let intensity: CGFloat = 0.7
    private static let actionDelay: Duration = .milliseconds(70)
    private static let recentlyGenerator = UIImpactFeedbackGenerator(style: .soft)
    static func prepareRecently() { recentlyGenerator.prepare() }
    static func recently(expanded: Bool) {
        recentlyGenerator.impactOccurred(intensity: expanded ? 0.55 : 0.3)
    }

    private static let carouselGenerator = UIImpactFeedbackGenerator(style: .soft)

    static func prepareCarousel() { carouselGenerator.prepare() }

    static func carouselStep() {
        carouselGenerator.impactOccurred(intensity: intensity)
    }

    static func action() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred(intensity: intensity)
        generator.prepare()
        Task { @MainActor in
            try? await Task.sleep(for: actionDelay)
            guard !Task.isCancelled else { return }
            generator.impactOccurred(intensity: intensity)
        }
    }
}
