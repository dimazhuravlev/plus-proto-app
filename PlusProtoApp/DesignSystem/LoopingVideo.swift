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
        prepare(url: url)
        queue.play()
    }

    /// Зарядить ролик, но не запускать: слой покажет его первый кадр неподвижной
    /// картинкой. Нужно там, где остановленное видео стоит **вместо** постера
    /// (видеокарточки экрана фильма): без этого карточка до своей очереди играть
    /// показывала бы пустоту, а `start` + немедленная пауза дёргали бы кадром.
    func prepare(url: URL) {
        guard source != url else { return }
        source = url
        AppAudioSession.useAmbientForSilentVideo()
        queue.isMuted = true
        queue.preventsDisplaySleepDuringVideoPlayback = false
        looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
    }

    func start(bundled name: String) {
        guard let url = Self.bundled(name) else { return }
        start(url: url)
    }

    func prepare(bundled name: String) {
        guard let url = Self.bundled(name) else { return }
        prepare(url: url)
    }

    func pause() {
        queue.pause()
    }

    static func bundled(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "mp4")
    }
}

/// Видео как `AVPlayerLayer`: `VideoPlayer` тянет за собой системный контрол-оверлей,
/// которого в фоне экрана быть не должно.
struct LoopingVideoLayer: UIViewRepresentable {
    let player: AVQueuePlayer
    /// Как кадр ложится в рамку. Фоновым роликам нужен кроп, а киноплеер умеет
    /// переключаться на «вписать» кнопкой из макета.
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill
    /// Первый готовый кадр — по нему постер уступает место видео.
    let onReadyForDisplay: () -> Void

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.backgroundColor = .clear
        view.playerLayer.player = player
        view.playerLayer.videoGravity = videoGravity
        context.coordinator.observe(view.playerLayer, onReadyForDisplay)
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        guard uiView.playerLayer.videoGravity != videoGravity else { return }
        uiView.playerLayer.videoGravity = videoGravity
    }

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
