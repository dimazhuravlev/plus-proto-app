import SwiftUI

struct HomeDevSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var detent: PresentationDetent = .fraction(0.5)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Девменю").plusText(.textL, .semibold)
                Spacer()
                Button("Закрыть", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            HomeDevControls()
        }
        .foregroundStyle(Color.fillOne)
        .preferredColorScheme(.dark)
        .presentationDetents([.fraction(0.5), .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
        .presentationBackground(.ultraThinMaterial)
        // Открывается наполовину; за пилюлю раскрывается до large без затемнения фона.
        .presentationBackgroundInteraction(.enabled)
        .presentationCornerRadius(24)
    }
}

/// Одинаковые вкладки для входа через Люмена и профиль.
enum HomeDevTab: String, CaseIterable, Identifiable {
    case layout = "Макет"
    case content = "Контент"
    case general = "Общее"
    var id: Self { self }
}

struct HomeDevControls: View {
    @Bindable var settings = HomePresentationSettings.shared
    @State private var tab: HomeDevTab = .layout
    let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(spacing: 12) {
            Picker("Раздел настроек", selection: $tab) {
                ForEach(HomeDevTab.allCases) { item in Text(item.rawValue).tag(item) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch tab {
                    case .layout: layoutControls
                    case .content: contentControls
                    case .general: DebugGeneralControls()
                    }

                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            // Новая вкладка начинается сверху; переключатель остаётся виден при скролле.
            .id(tab)
        }
        .plusText(.textS, .medium)
        .tint(Color.accentPrimary)
    }

}
