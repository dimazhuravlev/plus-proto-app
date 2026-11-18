import SwiftUI
import UIKit

/// Контейнер только для dev-превью. Анкету и отправку ответов по-прежнему ведёт Отклик.
struct SurveyPreviewSheet: View {
    let source: SurveyPreviewSource
    @Environment(\.dismiss) private var dismiss
    @State private var model = SurveyPreviewState()
    @State private var demoIndex = 0
    @State private var selectedDetent: PresentationDetent = .height(Layout.minimumHeight)
    @State private var followsContentHeight = true
    @State private var detentBeforeKeyboard: PresentationDetent?

    private enum Layout {
        static let headerHeight: CGFloat = 56
        static let demoNavigationHeight: CGFloat = 44
        static let horizontalInset: CGFloat = 10
        static let bottomGap: CGFloat = 24
        static let minimumHeight: CGFloat = 280
        static let cornerRadius: CGFloat = 30
        static let grabber = CGSize(width: 36, height: 3)
        static let grabberTop: CGFloat = 6
        /// Длинная анкета сразу large; короткая сохраняет компактную высоту.
        static let compactScreenFraction: CGFloat = 0.7
    }

    private var isDemo: Bool { source == .demo }
    private var activeSource: SurveyPreviewSource {
        isDemo ? SurveyPreviewSource.demoOrder[demoIndex] : source
    }
    private var chromeHeight: CGFloat { Layout.headerHeight }

    private var demoExpandedHeight: CGFloat {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene?.windows.first { $0.isKeyWindow }
        let screenHeight = scene?.effectiveGeometry.coordinateSpace.bounds.height ?? PlusMetrics.designWidth * 2
        let insets = window?.safeAreaInsets ?? .zero
        // Панель демо находится в отдельном окне над шторкой: резервируем ей место
        // даже при ручном раскрытии опроса. Detent не включает нижнюю safe area.
        return max(Layout.minimumHeight,
                   screenHeight - insets.top - insets.bottom - Layout.demoNavigationHeight - 24)
    }

    private var expandedDetent: PresentationDetent {
        isDemo ? .height(demoExpandedHeight) : .large
    }

    private var compactHeight: CGFloat {
        min(max(model.documentHeight + chromeHeight + Layout.bottomGap,
                Layout.minimumHeight), compactLimit)
    }

    private var compactLimit: CGFloat {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let screenHeight = scene?.effectiveGeometry.coordinateSpace.bounds.height ?? PlusMetrics.designWidth * 2
        return min(max(Layout.minimumHeight, screenHeight * Layout.compactScreenFraction),
                   isDemo ? demoExpandedHeight : screenHeight)
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
                SurveyPreviewWebView(model: model, source: activeSource)
                    // Каждый пример получает чистую форму и собственный scroll.
                    .id(activeSource)
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
        .background {
            if isDemo {
                SurveyDemoNavigationHost { demoNavigation }
            }
        }
        .presentationDetents([.height(compactHeight), expandedDetent], selection: detentSelection)
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
            selectedDetent = expandedDetent
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            model.keyboardIsVisible = false
            if followsContentHeight {
                updateContentDetent()
            } else if detentBeforeKeyboard != expandedDetent {
                selectedDetent = .height(compactHeight)
            }
            detentBeforeKeyboard = nil
        }
        .onChange(of: model.documentHeight) { _, height in
            guard height > 0, !model.keyboardIsVisible else { return }
            updateContentDetent()
        }
        #if DEBUG
        .task { await checkDemoTransitionsIfRequested() }
        #endif
    }

    #if DEBUG
    /// Регрессия краша при dismantle WebView: тот же путь, что у кнопок панели,
    /// включая проход назад, перезагрузку и закрытие последнего примера.
    @MainActor
    private func checkDemoTransitionsIfRequested() async {
        guard isDemo, ProcessInfo.processInfo.arguments.contains("-debugSurveyDemoCycle") else { return }
        do {
            try await Task.sleep(for: .seconds(2))
            for step in 1..<SurveyPreviewSource.demoOrder.count {
                moveDemo(by: 1)
                try await Task.sleep(for: .seconds(1))
                print("[survey-demo-check] next \(demoIndex + 1) \(activeSource.demoTitle)")
                guard demoIndex == step else { return }
            }
            for step in (0..<(SurveyPreviewSource.demoOrder.count - 1)).reversed() {
                moveDemo(by: -1)
                try await Task.sleep(for: .seconds(1))
                print("[survey-demo-check] back \(demoIndex + 1) \(activeSource.demoTitle)")
                guard demoIndex == step else { return }
            }
            model.reloadGeneration += 1
            try await Task.sleep(for: .seconds(1))
            print("[survey-demo-check] reloaded first")
            for _ in 1..<SurveyPreviewSource.demoOrder.count {
                moveDemo(by: 1)
                try await Task.sleep(for: .seconds(1))
            }
            moveDemo(by: 1)
            print("[survey-demo-check] completed and dismissed")
        } catch { /* Закрытие шторки отменяет проверку. */ }
    }
    #endif

    private func updateContentDetent() {
        if followsContentHeight {
            selectedDetent = model.documentHeight + chromeHeight + Layout.bottomGap > compactLimit
                ? expandedDetent : .height(compactHeight)
        } else if selectedDetent != expandedDetent {
            selectedDetent = .height(compactHeight)
        }
    }

    private var demoNavigation: some View {
        HStack(spacing: 12) {
            Button { moveDemo(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 32, height: Layout.demoNavigationHeight)
            }
            .disabled(demoIndex == 0)
            .accessibilityLabel("Предыдущий опрос")

            Text("\(demoIndex + 1)/\(SurveyPreviewSource.demoOrder.count) · \(activeSource.demoTitle)")
                .plusText(.textS, .medium)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)

            Button {
                // Перечитывает живую форму после изменений в админке, не меняя шаг.
                model.reloadGeneration += 1
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 32, height: Layout.demoNavigationHeight)
            }
            .accessibilityLabel("Обновить текущий опрос")

            Button(demoIndex == SurveyPreviewSource.demoOrder.count - 1 ? "Готово" : "Далее") {
                moveDemo(by: 1)
            }
            .plusText(.textS, .semibold)
            .frame(minHeight: Layout.demoNavigationHeight)
            .accessibilityLabel(demoIndex == SurveyPreviewSource.demoOrder.count - 1
                ? "Завершить демонстрацию" : "Следующий опрос")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .frame(height: Layout.demoNavigationHeight)
    }

    private func moveDemo(by offset: Int) {
        let next = demoIndex + offset
        guard next >= 0 else { return }
        guard next < SurveyPreviewSource.demoOrder.count else {
            dismiss()
            return
        }
        // Автовысота и выбор large относятся только к текущему примеру.
        // Переход доступен даже без ответа или при ошибке загрузки формы.
        model = SurveyPreviewState()
        followsContentHeight = true
        detentBeforeKeyboard = nil
        selectedDetent = .height(Layout.minimumHeight)
        demoIndex = next
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
