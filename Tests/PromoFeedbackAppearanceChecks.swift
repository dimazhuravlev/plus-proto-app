import Foundation

@main enum PromoFeedbackAppearanceChecks {
    static func main() {
        // Idle → synchronous save → 800ms receipt → fade; restored saved items stay hidden.
        precondition(!PromoFeedbackAppearance.isHidden(saved: false, completed: false, pairHidden: false, contentHidden: false))
        precondition(PromoFeedbackAppearance.isHidden(saved: true, completed: false, pairHidden: false, contentHidden: false))
        for saved in [false, true] {
            precondition(!PromoFeedbackAppearance.isHidden(saved: saved, completed: true, pairHidden: false, contentHidden: false))
            precondition(PromoFeedbackAppearance.isHidden(saved: saved, completed: true, pairHidden: true, contentHidden: false))
            precondition(PromoFeedbackAppearance.isHidden(saved: saved, completed: true, pairHidden: false, contentHidden: true))
        }
        for purple in [false, true] {
            for completed in [false, true] {
                for pressed in [false, true] {
                    let selected = PromoFeedbackAppearance.isSelected(completed: completed, pressed: pressed, purpleEnabled: purple)
                    precondition(selected == (completed || (purple && pressed)))
                    for (normal, filled) in [("promoLike", "promoLikeFilled"), ("promoSaveMovie", "promoSaveMovieFilled"), ("promoSaveMusic", "promoSaveMusicFilled")] {
                        precondition(PromoFeedbackAppearance.icon(normal, selected: selected, purpleEnabled: purple) == (selected && purple ? filled : normal))
                    }
                    for plus in ["iconAdd", "promoSaveBook"] {
                        precondition(PromoFeedbackAppearance.icon(plus, selected: selected, purpleEnabled: purple) == plus)
                    }
                }
            }
        }
        precondition(PromoReserveSynopsis.movies["kp-2000461"]!.contains("курорта"))
        precondition(PromoReserveSynopsis.books["gb-E_xrEAAAQBAJ"]!.contains("Уинстон"))
        for summary in Array(PromoReserveSynopsis.movies.values) + Array(PromoReserveSynopsis.books.values) {
            precondition(summary.split(separator: " ").count >= 12, "Reserve descriptions must be synopses, not metadata")
        }
        print("PASS: idle/pressed/completed feedback, independent purple flag, filled icons, unchanged plus, reserve synopses")
    }
}
