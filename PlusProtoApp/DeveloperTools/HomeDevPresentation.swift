import SwiftUI

/// Общий вход в отдельный компонент девменю из главной и профиля.
extension View {
    func homeDevMenu(isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) { HomeDevSheet() }
    }
}

struct HomeDevMenuEntry<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action, label: label)
            .buttonStyle(.plain)
            .accessibilityLabel("Открыть девменю главной")
    }
}
