import SwiftUI

/// Экраны сущностей, которые сейчас на экране, — по маршруту (задача пользователя
/// 2026-10-30). Зум-переход прячет на исходном экране только миниатюру-источник,
/// а подпись под ней оставалась: на медленном свайпе назад название висело в пустоте
/// под местом обложки. Подпись карточки читает отсюда, открыт ли её экран
/// (`zoomSourceCaption`), и прячется вместе с обложкой.
///
/// Пишет сам экран сущности (`ZoomPresenceTracker` в `EntityScreen`). Счётчик, а не
/// множество: один маршрут бывает в стопке дважды (альбом → исполнитель → тот же альбом).
@MainActor
@Observable
final class ZoomPresence {
    static let shared = ZoomPresence()

    private var counts: [EntityRoute: Int] = [:]

    private init() {}

    func isOpen(_ route: EntityRoute) -> Bool {
        (counts[route] ?? 0) > 0
    }

    func appeared(_ route: EntityRoute) {
        counts[route, default: 0] += 1
        #if DEBUG
        trace("appear", route)
        #endif
    }

    func disappeared(_ route: EntityRoute) {
        let count = (counts[route] ?? 0) - 1
        counts[route] = count > 0 ? count : nil
        #if DEBUG
        trace("disappear", route)
        #endif
    }

    #if DEBUG
    /// `-debugZoomTrace 1` — строки `[zoom] appear/disappear <маршрут>` с временем в лог:
    /// сверить момент возврата подписи с кадрами видео обратного зума.
    private static let tracesZoom = UserDefaults.standard.bool(forKey: "debugZoomTrace")

    private func trace(_ event: String, _ route: EntityRoute) {
        guard Self.tracesZoom else { return }
        NSLog("[zoom] %@ %@ t=%.3f", event, String(describing: route.id), CACurrentMediaTime())
    }
    #endif
}

/// Отмечает экран сущности открытым, пока он показан, — по событиям перехода UIKit.
/// Открыт — с начала перехода внутрь: подпись уходит вместе с обложкой. Закрыт — когда
/// обратный зум кладёт обложку на место: через `landing` после начала его доводки
/// (кнопка «назад» — сразу, свайп — с момента, как палец отпустил и переход не отменён).
/// Ни `onDisappear`, ни завершение перехода для этого не годятся: пружина зума
/// дотухает долго, и они приходят через 1.8 и 0.65 с после того, как обложка уже
/// встала (замер по кадрам 2026-10-30) — подпись всё это время её ждала. У отменённого
/// свайпа назад подпись не мигает.
/// Экран, накрытый следующим пушем или плеером, тоже «закрыт» — исходного экрана в этот
/// момент не видно, а на возврате он снова откроется раньше, чем тот покажется.
struct ZoomPresenceTracker: UIViewControllerRepresentable {
    let route: EntityRoute

    func makeUIViewController(context: Context) -> Controller {
        Controller(route: route)
    }

    func updateUIViewController(_ controller: Controller, context: Context) {}

    static func dismantleUIViewController(_ controller: Controller, coordinator: ()) {
        controller.close()
    }

    final class Controller: UIViewController {
        private let route: EntityRoute
        private var isOpen = false
        private var pendingClose: DispatchWorkItem?

        init(route: EntityRoute) {
            self.route = route
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override func loadView() {
            view = UIView()
            view.isUserInteractionEnabled = false
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            pendingClose?.cancel()
            open()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            guard let coordinator = transitionCoordinator else {
                close()
                return
            }
            if coordinator.isInteractive {
                coordinator.notifyWhenInteractionChanges { [weak self] context in
                    guard !context.isCancelled else { return }
                    self?.scheduleClose()
                }
            } else {
                scheduleClose()
            }
            // Запасной путь — конец перехода; отменённый переход снимает отложенное.
            coordinator.animate(alongsideTransition: nil) { [weak self] context in
                if context.isCancelled {
                    self?.pendingClose?.cancel()
                } else {
                    self?.close()
                }
            }
        }

        private func scheduleClose() {
            pendingClose?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.close() }
            pendingClose = work
            DispatchQueue.main.asyncAfter(deadline: .now() + ZoomSourceCaptionMotion.landing, execute: work)
        }

        private func open() {
            guard !isOpen else { return }
            isOpen = true
            ZoomPresence.shared.appeared(route)
        }

        func close() {
            pendingClose?.cancel()
            pendingClose = nil
            guard isOpen else { return }
            isOpen = false
            ZoomPresence.shared.disappeared(route)
        }
    }
}

enum ZoomSourceCaptionMotion {
    /// Уходит сразу за обложкой: система снимает её с первого кадра зума.
    static let hide: Animation = .easeOut(duration: 0.15)
    /// Обратный зум кладёт обложку на место примерно за 0.25 с от начала доводки
    /// (замер по кадрам 2026-10-30): подпись начинает проявляться чуть раньше
    /// и становится видна, когда обложка встаёт.
    static let landing: TimeInterval = 0.15
    /// Возвращается мягко, вслед за обложкой.
    static let show: Animation = .easeInOut(duration: 0.25)
}

extension View {
    /// Подпись карточки — название, подзаголовок, всё, что стоит рядом с миниатюрой-
    /// источником зума: пока экран её маршрута открыт, подпись спрятана вместе
    /// с обложкой. `nil` — карточка никуда не ведёт, подпись всегда видна.
    func zoomSourceCaption(_ route: EntityRoute?) -> some View {
        modifier(ZoomSourceCaption(route: route))
    }

    /// То же для карточек витрины: маршрут — из контекста миниатюры (`showcaseThumbnail`),
    /// который лента ставит на карточку целиком.
    func showcaseCaption() -> some View {
        modifier(ShowcaseCaption())
    }
}

private struct ZoomSourceCaption: ViewModifier {
    let route: EntityRoute?

    func body(content: Content) -> some View {
        let isHidden = route.map { ZoomPresence.shared.isOpen($0) } ?? false
        content
            .opacity(isHidden ? 0 : 1)
            .animation(isHidden ? ZoomSourceCaptionMotion.hide : ZoomSourceCaptionMotion.show, value: isHidden)
    }
}

private struct ShowcaseCaption: ViewModifier {
    @Environment(\.showcaseThumbnail) private var context

    func body(content: Content) -> some View {
        content.zoomSourceCaption(context?.route)
    }
}
