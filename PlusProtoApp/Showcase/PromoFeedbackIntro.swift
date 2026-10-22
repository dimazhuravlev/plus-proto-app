import SwiftUI
import UIKit

private struct PromoIntroReadyKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var promoIntroReady: Bool {
        get { self[PromoIntroReadyKey.self] }
        set { self[PromoIntroReadyKey.self] = newValue }
    }
}

/// Ровно один показ за процесс, включая возвраты на таб и из фона.
/// Сохранение на диск не нужно: следующий запуск — новая сессия.
@MainActor @Observable final class PromoIntroSession {
    static let shared = PromoIntroSession()
    private var consumed = false
    private(set) var generation = 0
    private(set) var hasInteracted = false

    /// Скрываем бадж ещё до claim, чтобы он не мелькнул перед первым intro.
    var isPending: Bool { !consumed && !hasInteracted }

    func claim() -> Bool {
        guard !consumed, !hasInteracted else { return false }
        consumed = true
        return true
    }

    func replay() {
        consumed = false
        hasInteracted = false
        generation += 1
    }

    func interact() { hasInteracted = true }
}

struct PromoIntroTrigger: Equatable {
    let eligible: Bool
    let generation: Int
}

enum PromoIntroMotion {
    static let collapseDuration = 0.6
    static let reducedCollapseDuration = 0.15
    static let badgeFadeDuration = 0.2
}

/// Ширина зависит от текста; одна капсула сужается до 40, глиф не масштабируется.
struct PromoIntroDoneFace: View {
    let expanded: Bool
    let isDone: Bool
    private static let title = "Рекомендовать"
    private static var expandedWidth: CGFloat {
        let font = UIFont(name: PlusFont.textSemibold, size: PlusTextSize.textM.size)
            ?? .systemFont(ofSize: PlusTextSize.textM.size, weight: .semibold)
        return 16 + 20 + 6 + ceil((title as NSString).size(withAttributes: [.font: font]).width) + 20
    }

    var body: some View {
        Color.clear.frame(width: expanded ? Self.expandedWidth : 40, height: 40)
            .overlay(alignment: .leading) {
                Text(Self.title).plusText(.textM, .semibold)
                    .foregroundStyle(isDone ? Color.black : Color.fillOne).fixedSize()
                    .padding(.leading, 42)
                    .opacity(expanded ? 1 : 0)
                    .animation(.easeOut(duration: 0.18), value: expanded)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .leading) {
                Image("promoLike").renderingMode(.template).resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(isDone ? Color.black : Color.fillOne)
                    .padding(.leading, expanded ? 16 : 10)
            }
            .background { Capsule().fill(isDone ? Color.white : .clear) }
            .modifier(PromoIntroSurface(isDone: isDone))
            .clipShape(Capsule())
    }
}

struct PromoIntroSurface: ViewModifier {
    var isDone = false

    func body(content: Content) -> some View {
        if isDone { content }
        else {
            content.glassSurface(Capsule(), blur: 20, fill: .buttonsSecondary, border: .clear, borderWidth: 0)
        }
    }
}

/// Figma 362:25524, исходный размер до поворота 53.34×20.
struct PromoAlbumBadge: View {
    static let boundsSize = CGSize(width: 54.3136205206, height: 22.7641912586)
    @Environment(ShowcaseFeedbackState.self) private var feedback: ShowcaseFeedbackState?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isHiddenByIntro: Bool {
        PromoIntroSession.shared.isPending || (feedback?.isIntroExpanded ?? false)
    }

    var body: some View {
        Text("Новое").plusText(.textS, .semibold)
            .foregroundStyle(Color.fillOne)
            .frame(width: 53.34, height: 20)
            .glassSurface(RoundedRectangle(cornerRadius: 6), blur: 20,
                          fill: .fillNine, border: .fillNine, borderWidth: 0.67)
            .rotationEffect(.degrees(3))
            // Рамка учитывает поворот: отступы измеряются от видимых краёв баджа.
            .frame(width: Self.boundsSize.width, height: Self.boundsSize.height)
            .opacity(isHiddenByIntro ? 0 : 1)
            // Бадж возвращается после сужения капсулы, когда они уже не перекрываются.
            .animation(isHiddenByIntro ? nil : .easeOut(duration: PromoIntroMotion.badgeFadeDuration)
                .delay(reduceMotion ? PromoIntroMotion.reducedCollapseDuration : PromoIntroMotion.collapseDuration),
                value: isHiddenByIntro)
            .allowsHitTesting(false)
            .accessibilityLabel("Новый альбом")
            .accessibilityHidden(isHiddenByIntro)
    }
}
