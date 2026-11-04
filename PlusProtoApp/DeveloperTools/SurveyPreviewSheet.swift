import SwiftUI
import UIKit

/// Контейнер только для dev-превью. Анкету и отправку ответов по-прежнему ведёт Отклик.
struct SurveyPreviewSheet: View {
    let source: SurveyPreviewSource
    @Environment(\.dismiss) private var dismiss
    @State private var model = SurveyPreviewState()
    @State private var selectedDetent: PresentationDetent = .height(Layout.minimumHeight)
    @State private var followsContentHeight = true
    @State private var detentBeforeKeyboard: PresentationDetent?

    private enum Layout {
        static let headerHeight: CGFloat = 56
        static let horizontalInset: CGFloat = 10
        static let bottomGap: CGFloat = 24
        static let minimumHeight: CGFloat = 280
        static let cornerRadius: CGFloat = 30
        static let grabber = CGSize(width: 36, height: 3)
        static let grabberTop: CGFloat = 6
        /// Длинная анкета сразу large; короткая сохраняет компактную высоту.
        static let compactScreenFraction: CGFloat = 0.7
    }

    private var compactHeight: CGFloat {
        min(max(model.documentHeight + Layout.headerHeight + Layout.bottomGap,
                Layout.minimumHeight), compactLimit)
    }

    private var compactLimit: CGFloat {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let screenHeight = scene?.effectiveGeometry.coordinateSpace.bounds.height ?? PlusMetrics.designWidth * 2
        return max(Layout.minimumHeight, screenHeight * Layout.compactScreenFraction)
    }

    private var detentSelection: Binding<PresentationDetent> {
        Binding {
            selectedDetent
        } set: { value in
            guard value != selectedDetent else { return }
            // Автовысота следит за условными вопросами, пока человек сам не
            // потянул шторку. Его выбор large не отменяем при исчезновении плиток.
            followsContentHeight = false
            selectedDetent = value
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                // Единственный scroll — UIScrollView самого WKWebView. Внешний
                // ScrollView ломал бы передачу pan между документом и sheet.
                SurveyPreviewWebView(model: model, source: source)
                    .padding(.horizontal, Layout.horizontalInset)
                    .opacity(model.phase == .ready ? 1 : 0)
                    .allowsHitTesting(model.phase == .ready)
                    .accessibilityHidden(model.phase != .ready)

                switch model.phase {
                case .loading:
                    VStack(spacing: 12) {
                        ProgressView().tint(Color.fillOne)
                        Text("Загружаем опрос")
                            .plusText(.textM, .medium)
                            .foregroundStyle(Color.fillSubtitle)
                    }
                    .accessibilityElement(children: .combine)
                case .failed:
                    VStack(spacing: 16) {
                        Text("Не удалось загрузить опрос")
                            .plusText(.textL, .semibold)
                        Text("Проверьте подключение и попробуйте ещё раз")
                            .plusText(.textM, .medium)
                            .foregroundStyle(Color.fillSubtitle)
                            .multilineTextAlignment(.center)
                        PlusButton("Повторить", type: .accent, size: .l) {
                            model.reloadGeneration += 1
                        }
                    }
                    .padding(.horizontal, 24)
                case .ready:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, Layout.bottomGap)
        }
        .foregroundStyle(Color.fillOne)
        .preferredColorScheme(.dark)
        .presentationDetents([.height(compactHeight), .large], selection: detentSelection)
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(Layout.cornerRadius)
        .presentationContentInteraction(.scrolls)
        .presentationBackground {
            ZStack {
                BackdropBlurView(radius: PlusMetrics.glassBlur)
                Color.surfaceFive
            }
        }
        // Сначала свайп прячет клавиатуру, затем снова может закрывать sheet.
        // Крестик доступен и при открытой клавиатуре.
        .interactiveDismissDisabled(model.keyboardIsVisible)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            if !model.keyboardIsVisible { detentBeforeKeyboard = selectedDetent }
            model.keyboardIsVisible = true
            selectedDetent = .large
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            model.keyboardIsVisible = false
            if followsContentHeight {
                updateContentDetent()
            } else if detentBeforeKeyboard != .large {
                selectedDetent = .height(compactHeight)
            }
            detentBeforeKeyboard = nil
        }
        .onChange(of: model.documentHeight) { _, height in
            guard height > 0, !model.keyboardIsVisible else { return }
            updateContentDetent()
        }
    }

    private func updateContentDetent() {
        if followsContentHeight {
            selectedDetent = model.documentHeight + Layout.headerHeight + Layout.bottomGap > compactLimit
                ? .large : .height(compactHeight)
        } else if selectedDetent != .large {
            selectedDetent = .height(compactHeight)
        }
    }

    private var header: some View {
        ZStack(alignment: .topTrailing) {
            Capsule()
                .fill(Color.fillEight)
                .frame(width: Layout.grabber.width, height: Layout.grabber.height)
                .frame(maxWidth: .infinity)
                .padding(.top, Layout.grabberTop)
                .accessibilityHidden(true)

            PlusButton(icon: "iconCross", type: .secondary, size: .s,
                       accessibilityTitle: "Закрыть опрос", action: { dismiss() })
                .padding(.trailing, 16)
                .padding(.top, 12)
        }
        .frame(height: Layout.headerHeight)
        .frame(maxWidth: .infinity)
    }
}

@MainActor
@Observable
final class SurveyPreviewState {
    enum Phase: Equatable { case loading, ready, failed }
    var phase: Phase = .loading
    var documentHeight: CGFloat = 0
    var reloadGeneration = 0
    var keyboardIsVisible = false

    func updateDocumentHeight(_ height: Double) {
        guard height.isFinite, height > 0, height < 100_000,
              abs(CGFloat(height) - documentHeight) > 1
        else { return }
        documentHeight = CGFloat(height)
    }
}
