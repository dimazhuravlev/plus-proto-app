import AVFoundation
import SwiftUI

/// Беззвучный зацикленный клип. Один плеер на вью: пересобирать `AVQueuePlayer`
/// на каждое появление дороже, чем держать его и ставить на паузу.
///
/// Источник — либо файл из бандла, либо ссылка: карточке тайтла нужен второй вариант
/// на случай, если API однажды отдаст ролик файлом, а не страницей плеера.
@MainActor
final class LoopingVideoPlayback {
    let queue = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var source: URL?

    /// Идемпотентно: повторный вызов с тем же источником просто снимает с паузы.
    func start(url: URL) {
        if source != url {
            source = url
            AmbientAudio.configureOnce()
            queue.isMuted = true
            queue.preventsDisplaySleepDuringVideoPlayback = false
            looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
        }
        queue.play()
    }

    func start(bundled name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp4") else { return }
        start(url: url)
    }

    func pause() {
        queue.pause()
    }
}

/// Клип беззвучный, но без категории `.ambient` его старт всё равно оборвёт музыку
/// у пользователя — категорию ставим один раз на приложение.
enum AmbientAudio {
    private static var isConfigured = false

    static func configureOnce() {
        guard !isConfigured else { return }
        isConfigured = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
    }
}

/// Видео как `AVPlayerLayer`: `VideoPlayer` тянет за собой системный контрол-оверлей,
/// которого в фоне экрана быть не должно.
struct LoopingVideoLayer: UIViewRepresentable {
    let player: AVQueuePlayer
    /// Первый готовый кадр — по нему постер уступает место видео.
    let onReadyForDisplay: () -> Void

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.backgroundColor = .clear
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        context.coordinator.observe(view.playerLayer, onReadyForDisplay)
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var token: NSKeyValueObservation?

        func observe(_ layer: AVPlayerLayer, _ onReady: @escaping () -> Void) {
            token = layer.observe(\.isReadyForDisplay, options: [.initial, .new]) { layer, _ in
                guard layer.isReadyForDisplay else { return }
                DispatchQueue.main.async(execute: onReady)
            }
        }
    }

    /// Слой плеера — сам корневой слой вью, без вложенного `CALayer` и ручного ресайза.
    final class PlayerLayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }

        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
