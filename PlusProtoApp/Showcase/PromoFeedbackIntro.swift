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
    @Environment(\.promoFeedbackPressed) private var isPressed
    let expanded: Bool
    let isDone: Bool
    var usesPurpleSelection = false
    var showsSecondaryBorder = false
    var title = "Рекомендовать"
    var icon = "promoLike"
    private var expandedWidth: CGFloat {
        let font = UIFont(name: PlusFont.textSemibold, size: PlusTextSize.textM.size)
            ?? .systemFont(ofSize: PlusTextSize.textM.size, weight: .semibold)
        return 16 + 20 + 6 + ceil((title as NSString).size(withAttributes: [.font: font]).width) + 20
    }

    var body: some View {
        let selected = PromoFeedbackAppearance.isSelected(completed: isDone, pressed: isPressed,
                                                          purpleEnabled: usesPurpleSelection)
        Color.clear.frame(width: expanded ? expandedWidth : 40, height: 40)
            .overlay(alignment: .leading) {
                Text(title).plusText(.textM, .semibold)
                    .foregroundStyle(selected && !usesPurpleSelection ? Color.black : Color.fillOne).fixedSize()
                    .padding(.leading, 42)
                    .opacity(expanded ? 1 : 0)
                    .animation(.easeOut(duration: 0.18), value: expanded)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .leading) {
                Image(PromoFeedbackAppearance.icon(icon, selected: selected, purpleEnabled: usesPurpleSelection))
                    .renderingMode(.template).resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(selected && !usesPurpleSelection ? Color.black : Color.fillOne)
                    .padding(.leading, expanded ? 16 : 10)
            }
            .background {
                if selected && usesPurpleSelection { ActiveTabPill() }
                else { Capsule().fill(selected ? Color.white : .clear) }
            }
            .modifier(PromoIntroSurface(isDone: selected, showsBorder: showsSecondaryBorder))
            .clipShape(Capsule())
    }
}

extension EnvironmentValues {
    @Entry var promoFeedbackPressed = false
}

struct PromoFeedbackPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressScaleButtonStyle().makeBody(configuration: configuration)
            .environment(\.promoFeedbackPressed, configuration.isPressed)
    }
}

struct PromoIntroSurface: ViewModifier {
    var isDone = false
    var showsBorder = false

    func body(content: Content) -> some View {
        if isDone { content }
        else {
            content.glassSurface(Capsule(), blur: 20, fill: .buttonsSecondary,
                                 border: showsBorder ? SecondaryButtonBorder.color : .clear,
                                 borderWidth: showsBorder ? SecondaryButtonBorder.width : 0)
        }
    }
}

/// Figma 362:25524, исходный размер до поворота 53.34×20.
struct PromoAlbumBadge: View {
    static let boundsSize = CGSize(width: 53.34, height: 20)
    /// То же состояние, из которого пара рисует раскрытую капсулу.
    let feedback: ShowcaseFeedbackState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isHiddenByIntro: Bool {
        !feedback.isPairHidden && (PromoIntroSession.shared.isPending || feedback.isIntroExpanded)
    }

    var body: some View {
        Text("Новое").plusText(.textS, .semibold)
            .foregroundStyle(Color.fillOne)
            .frame(width: 53.34, height: 20)
            // Background blur 16 в макете = радиус 8 в конвенции GlassSurface.
            .glassSurface(RoundedRectangle(cornerRadius: 6), blur: 8,
                          fill: Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0.5), border: .clear, borderWidth: 0)
            // Рамка совпадает с видимыми границами баджа без поворота.
            .frame(width: Self.boundsSize.width, height: Self.boundsSize.height)
            .opacity(isHiddenByIntro ? 0 : 1)
            // Бадж возвращается после сужения капсулы, когда они уже не перекрываются.
            .animation(isHiddenByIntro ? .linear(duration: 0) : .easeOut(duration: PromoIntroMotion.badgeFadeDuration)
                .delay(reduceMotion ? PromoIntroMotion.reducedCollapseDuration : PromoIntroMotion.collapseDuration),
                value: isHiddenByIntro)
            .allowsHitTesting(false)
            .accessibilityLabel("Новый альбом")
            .accessibilityHidden(isHiddenByIntro)
    }
}
