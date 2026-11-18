import Foundation

enum PromoFeedbackAppearance {
    /// A save becomes persistent immediately, but its receipt stays visible until pairOut.
    static func isHidden(saved: Bool, completed: Bool, pairHidden: Bool, contentHidden: Bool) -> Bool {
        (saved && !completed) || pairHidden || contentHidden
    }

    static func isSelected(completed: Bool, pressed: Bool, purpleEnabled: Bool) -> Bool {
        completed || (purpleEnabled && pressed)
    }

    static func icon(_ normal: String, selected: Bool, purpleEnabled: Bool) -> String {
        guard selected && purpleEnabled else { return normal }
        switch normal {
        case "promoLike": return "promoLikeFilled"
        case "promoSaveMovie": return "promoSaveMovieFilled"
        case "promoSaveMusic": return "promoSaveMusicFilled"
        default: return normal // Both plus variants retain their glyph.
        }
    }
}
