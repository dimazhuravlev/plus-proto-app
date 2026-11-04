import SwiftUI
import UIKit
import WebKit

/// Прозрачный web-контент в нативной шторке. Это URL предпросмотра, не SDK Отклика:
/// Watermark остаётся; системный footer скрыт по запросу пользователя.
/// Анкета не подменяется локальной копией.
struct SurveyPreviewWebView: UIViewRepresentable {
    let model: SurveyPreviewState
    let source: SurveyPreviewSource

    private static let messageName = "plusSurveyPreviewHeight"

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(WeakSurveyMessageHandler(context.coordinator), name: Self.messageName)
        controller.addUserScript(WKUserScript(source: Self.shellScript,
                                             injectionTime: .atDocumentEnd,
                                             forMainFrameOnly: true))
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.underPageBackgroundColor = .clear
        webView.overrideUserInterfaceStyle = .dark
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.keyboardDismissMode = .interactive
        webView.scrollView.alwaysBounceVertical = false
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.accessibilityLabel = "Опрос Отклика"
        context.coordinator.attach(webView)
        webView.load(URLRequest(url: source.url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Клавиатура, состояние загрузки и detent не должны перезапускать анкету.
        guard context.coordinator.reloadGeneration != model.reloadGeneration else { return }
        context.coordinator.reloadGeneration = model.reloadGeneration
        webView.load(URLRequest(url: source.url))
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.endEditing(true)
        webView.stopLoading()
        webView.evaluateJavaScript("window.__plusSurveyPreviewCleanup?.()", completionHandler: nil)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: messageName)
        webView.configuration.userContentController.removeAllUserScripts()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        coordinator.detach()
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let model: SurveyPreviewState
        var reloadGeneration = 0
        private weak var webView: WKWebView?
        private var keyboardObserver: NSObjectProtocol?

        init(model: SurveyPreviewState) { self.model = model }

        func attach(_ webView: WKWebView) {
            self.webView = webView
            keyboardObserver = NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardDidShowNotification, object: nil, queue: .main
            ) { [weak self] _ in
                // После системного resize WebKit прокручивает именно активное поле,
                // без сброса scroll position всего документа на каждом updateUIView.
                self?.webView?.evaluateJavaScript("""
                if (document.activeElement?.matches('input, textarea, [contenteditable="true"]')) {
                    document.activeElement.scrollIntoView({ block: 'nearest', inline: 'nearest' });
                }
                """, completionHandler: nil)
            }
        }

        func detach() {
            if let keyboardObserver { NotificationCenter.default.removeObserver(keyboardObserver) }
            keyboardObserver = nil
            webView = nil
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame,
                  Self.allowedHosts.contains(message.frameInfo.securityOrigin.host),
                  let body = message.body as? [String: Any],
                  let height = body["height"] as? Double
            else { return }
            model.updateDocumentHeight(height)
        }

        private static let allowedHosts: Set<String> = [
            "preview.surveys.yandex.ru", "preview.surveys.yandex-team.ru"
        ]

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            model.phase = .loading
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // UserScript уже добавил shell-CSS и observer; повтор — страховка для
            // восстановленного процесса WebKit и изменившегося DOM оболочки.
            webView.evaluateJavaScript(SurveyPreviewWebView.shellScript) { [weak self] _, error in
                self?.model.phase = error == nil ? .ready : .failed
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            failUnlessCancelled(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            failUnlessCancelled(error)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            model.phase = .failed
        }

        private func failUnlessCancelled(_ error: Error) {
            guard (error as NSError).code != NSURLErrorCancelled else { return }
            model.phase = .failed
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            guard ["https", "http"].contains(url.scheme?.lowercased() ?? "") else {
                decisionHandler(.cancel)
                return
            }
            if navigationAction.navigationType == .linkActivated,
               !Self.allowedHosts.contains(url.host ?? "") {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            guard navigationAction.targetFrame == nil,
                  let url = navigationAction.request.url,
                  ["https", "http"].contains(url.scheme?.lowercased() ?? "")
            else { return nil }
            // Privacy/terms используют target=_blank: ссылка остаётся доступна,
            // но Safari не заменяет собой анкету с уже введёнными ответами.
            UIApplication.shared.open(url)
            return nil
        }
    }

    private static let shellScript = """
    (() => {
        const allowedHosts = ['preview.surveys.yandex.ru', 'preview.surveys.yandex-team.ru'];
        if (!allowedHosts.includes(location.hostname)) return;
        window.__plusSurveyPreviewCleanup?.();
        const styleID = 'plus-native-survey-shell';
        let style = document.getElementById(styleID);
        if (!style) {
            style = document.createElement('style');
            style.id = styleID;
            document.head.appendChild(style);
        }
        // Оболочка preview и согласованные Hug-размеры и центрирование плиток.
        // Цвета и состояния контролов формы настраиваются только через JSON;
        // декоративный крестик preview заменяет нативная кнопка закрытия.
        style.textContent = `
            :root { color-scheme: dark; }
            html, body, .app, .app__body, .pages, .page {
                background-color: transparent !important;
            }
            .app > .footer { display: none !important; }
            .feedback-demo-close { display: none !important; }
            /* JSON не предоставляет выравнивание рядов auto-плиток. */
            .tile-options.tile-options_layout_auto {
                justify-content: center;
            }
            /* Отклик задаёт min-width 120/160px и inline height по самой
               высокой плитке. Hug должен следовать содержимому каждой плитки. */
            .tile-options.tile-options_layout_auto > .tile {
                flex: 0 1 auto;
                width: fit-content;
                min-width: 0 !important;
                max-width: 100% !important;
                height: auto !important;
                min-height: 0 !important;
            }
            /* Строка текста берёт lineHeight плитки из JSON, а не markdown. */
            .tile-options.tile-options_layout_auto > .tile .markdown p {
                line-height: inherit;
            }
            /* Preview фиксирует страницу на 320px. В нативной шторке шириной
               владеет host с собственными боковыми отступами. */
            .app_theme_default.app_surveyPreset_yandexActiveFeedback .page,
            .app_theme_default.app_surveyPreset_yandexMorda .page {
                width: 100% !important;
            }
        `;
        let lastHeight = 0;
        let timer = null;
        let stopped = false;
        const watched = new Set();
        const number = value => Number.parseFloat(value) || 0;
        const verticalInsets = style => number(style.paddingTop) + number(style.paddingBottom)
            + number(style.borderTopWidth) + number(style.borderBottomWidth);
        const visibleBox = element => {
            const style = getComputedStyle(element);
            return style.display !== 'none' && element.getClientRects().length > 0
                && style.position !== 'absolute' && style.position !== 'fixed';
        };
        const marginHeight = element => {
            const style = getComputedStyle(element);
            return number(style.marginTop) + number(style.marginBottom);
        };
        const contentsHeight = element => {
            const children = Array.from(element.children).filter(visibleBox);
            if (!children.length) return element.getBoundingClientRect().height;
            const boxes = children.map(child => child.getBoundingClientRect());
            // Реальные промежутки учитывают collapsing margins. Высоту самой
            // table-cell / 100vh-оболочки не берём, поэтому detent не меряет себя.
            const content = Math.max(...boxes.map(box => box.bottom))
                - Math.min(...boxes.map(box => box.top));
            const first = children[0], last = children[children.length - 1];
            return content + number(getComputedStyle(first).marginTop)
                + number(getComputedStyle(last).marginBottom)
                + verticalInsets(getComputedStyle(element));
        };
        const contentHeight = () => {
            const page = Array.from(document.querySelectorAll('.page')).find(visibleBox);
            const questions = page?.querySelector(':scope > .page__questions');
            if (!page || !questions) {
                const fallback = document.querySelector('.app__body') || document.body;
                return contentsHeight(fallback);
            }
            const button = page.querySelector(':scope > .page__button');
            let height = contentsHeight(questions) + marginHeight(questions);
            if (button && visibleBox(button)) height += contentsHeight(button) + marginHeight(button);
            const pageStyle = getComputedStyle(page);
            height += verticalInsets(pageStyle) + number(pageStyle.rowGap);
            // Только вертикальные поля оболочки — её viewport-sized rect не
            // участвует. Footer уже display:none и не входит в эту цепочку.
            for (let element = page; element; element = element.parentElement) {
                height += marginHeight(element);
                if (element !== page) height += verticalInsets(getComputedStyle(element));
                if (element === document.body) break;
            }
            return height;
        };
        const report = () => {
            timer = null;
            if (stopped) return;
            const targets = new Set(document.querySelectorAll(
                '.app, .page__questions, .page__component, .page__button'
            ));
            for (const element of watched) {
                if (!targets.has(element)) { resizeObserver.unobserve(element); watched.delete(element); }
            }
            for (const element of targets) {
                if (!watched.has(element)) { resizeObserver.observe(element); watched.add(element); }
            }
            const height = Math.ceil(contentHeight());
            if (Number.isFinite(height) && height > 0 && Math.abs(height - lastHeight) > 1) {
                lastHeight = height;
                window.webkit?.messageHandlers?.plusSurveyPreviewHeight?.postMessage({ height });
            }
        };
        const schedule = () => {
            if (stopped) return;
            if (timer !== null) clearTimeout(timer);
            timer = setTimeout(report, 120);
        };
        const resizeObserver = new ResizeObserver(schedule);
        const mutationObserver = new MutationObserver(schedule);
        mutationObserver.observe(document.body, {
            childList: true, subtree: true, attributes: true,
            attributeFilter: ['class', 'style', 'hidden', 'aria-hidden']
        });
        window.addEventListener('resize', schedule);
        document.addEventListener('input', schedule, true);
        document.fonts?.ready.then(schedule);
        schedule();
        window.__plusSurveyPreviewCleanup = () => {
            stopped = true;
            if (timer !== null) clearTimeout(timer);
            resizeObserver.disconnect();
            watched.clear();
            mutationObserver.disconnect();
            window.removeEventListener('resize', schedule);
            document.removeEventListener('input', schedule, true);
        };
    })();
    """
}

enum SurveyPreviewSource: String, Identifiable {
    case standard
    case tiles
    case surveyThree
    case surveyFour
    case surveyFive
    case arabic
    case emoji

    var id: Self { self }

    var url: URL {
        switch self {
        case .standard:
            URL(string: "https://preview.surveys.yandex.ru/poll/feedback/SSvm9D9Qan7NJMiH3vYJ1L")!
        case .tiles:
            URL(string: "https://preview.surveys.yandex.ru/poll/feedback/2LJqQNXusqradxN9iHK6Pe")!
        case .surveyThree:
            URL(string: "https://preview.surveys.yandex.ru/poll/feedback/Qd9hwCrVuX5m4s8fyGV7SN")!
        case .surveyFour:
            URL(string: "https://preview.surveys.yandex.ru/poll/feedback/GDXGNPj8gRrPDSYcUgutg5")!
        case .surveyFive:
            URL(string: "https://preview.surveys.yandex.ru/poll/feedback/WVMiNiFtQcCV2wy3z6gWPT")!
        case .arabic:
            URL(string: "https://preview.surveys.yandex.ru/poll/feedback/E73K85rts1fEtmA4QUKQcv")!
        case .emoji:
            URL(string: "https://preview.surveys.yandex.ru/poll/feedback/RpJeitnznc719kJMJxSZ12")!
        }
    }
}

/// WKUserContentController удерживает handler: слабый посредник разрывает цикл
/// controller → handler → coordinator и позволяет убрать observer при закрытии.
private final class WeakSurveyMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var target: (any WKScriptMessageHandler)?

    init(_ target: any WKScriptMessageHandler) { self.target = target }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
