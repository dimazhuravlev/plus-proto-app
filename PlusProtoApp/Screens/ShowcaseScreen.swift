import SwiftUI

/// Витрина «Плюс» — главный экран супераппа.
struct ShowcaseScreen: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ShowcaseFeedView(feed: .personal)
        }
    }
}
