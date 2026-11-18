import SwiftUI

/// Process-only visual checks; never changes reactions, collection or settings.
enum HomePromoVerification {
    @MainActor static func record(_ items: [ShowcaseBlock]) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-debugPromoVerify") else { return }
        let result: [String: Any] = [
            "count": items.count,
            "uniqueCount": Set(items.map(\.id)).count,
            "kinds": Dictionary(grouping: items, by: { $0.homePromoKind.rawValue }).mapValues(\.count),
            "waveArtSize": ShowcasePromoLayout.geometry.wave.artSize,
            "purpleFeedback": HomePresentationSettings.shared.promoPurpleFeedbackEnabled,
            "albumsMissingArtistPortrait": items.compactMap { item -> String? in
                guard case .album(let album) = item, album.artistPicture == nil else { return nil }
                return album.id
            },
            "stationAssets": items.compactMap { item -> String? in
                guard case .vibe(let vibe) = item else { return nil }
                return vibe.promoStation.asset ?? "artist-photo"
            }
        ]
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("home-promo-verification.json")
            try? data.write(to: url, options: .atomic)
        }
        #endif
    }
}
