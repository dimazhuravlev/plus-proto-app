import Foundation

/// One mutually exclusive presentation; switching modes never changes history.
enum HomeRecentlyMode: String, CaseIterable, Identifiable {
    case hidden, standard, experiment
    var id: Self { self }
    var title: String {
        switch self {
        case .hidden: "Без ПП"
        case .standard: "Стандарт ПП"
        case .experiment: "Эксперимент ПП"
        }
    }

    static func restored(rawValue: String?, wasHidden: Bool, wasExperimental: Bool) -> Self {
        if let rawValue, let mode = Self(rawValue: rawValue) { return mode }
        if wasHidden { return .hidden }
        return wasExperimental ? .experiment : .standard
    }
}
