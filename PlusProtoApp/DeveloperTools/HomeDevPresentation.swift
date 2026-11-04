import SwiftUI

/// Общий вход в отдельный компонент девменю из главной и профиля.
extension View {
    func homeDevMenu(isPresented: Binding<Bool>) -> some View {
        modifier(HomeDevMenuPresentation(isPresented: isPresented))
    }
}

private struct HomeDevMenuPresentation: ViewModifier {
    @Binding var isPresented: Bool
    @State private var presentedSurvey: SurveyPreviewSource?
    @State private var pendingSurvey: SurveyPreviewSource?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented, onDismiss: presentPendingSurvey) {
                HomeDevSheet(onOpenSurvey: openSurvey)
            }
            .sheet(item: $presentedSurvey) { source in
                SurveyPreviewSheet(source: source)
            }
            #if DEBUG
            .task {
                guard let source = SurveyPreviewLaunch.claim() else { return }
                openSurvey(source)
            }
            #endif
    }

    private func openSurvey(_ source: SurveyPreviewSource) {
        if isPresented {
            // Вторую sheet презентуем только после завершения закрытия первой:
            // иначе UIKit ещё занят dev-меню и теряет новую презентацию.
            pendingSurvey = source
            isPresented = false
        } else {
            presentedSurvey = source
        }
    }

    private func presentPendingSurvey() {
        guard let source = pendingSurvey else { return }
        pendingSurvey = nil
        presentedSurvey = source
    }
}

#if DEBUG
@MainActor
private enum SurveyPreviewLaunch {
    private static var wasClaimed = false

    static func claim() -> SurveyPreviewSource? {
        guard !wasClaimed,
              ProcessInfo.processInfo.arguments.contains("-debugSurveySheet") ||
                ProcessInfo.processInfo.arguments.contains("-debugSurveyTiles")
        else { return nil }
        wasClaimed = true
        return ProcessInfo.processInfo.arguments.contains("-debugSurveyTiles") ? .tiles : .standard
    }
}
#endif

struct HomeDevMenuEntry<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action, label: label)
            .buttonStyle(.plain)
            .accessibilityLabel("Открыть девменю главной")
    }
}
