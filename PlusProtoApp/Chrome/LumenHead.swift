import SwiftUI

/// Где живёт голова Люмена — переключатель «Люмен в поиске» дебаг-меню (правка пользователя
/// 2026-10-16). Выключен (по умолчанию) — в навигации «Главной» рядом с аватаром; включён —
/// в поле поиска action bar вместо лупы (макет `2777:32103`) со своей серией фраз, а из
/// навигации уходит. Хранится в `UserDefaults`: бар живёт в нескольких копиях,
/// `@AppStorage` подхватывает значение во всех.
enum LumenDebug {
    static let inSearchKey = "lumenInSearch"
}

/// Один ролик на все копии головы. Бар живёт в нескольких копиях (корень и экраны слоя),
/// и свой плеер у каждой — это лишние декодеры, а пауза одной копии глушила бы остальные.
/// Поэтому счётчик зрителей: ролик идёт, пока на экране хоть одна копия.
@MainActor
final class LumenHeadPlayback {
    static let shared = LumenHeadPlayback()

    /// Между проходами ролика — 3 с покоя (правки пользователя 2026-10-16: было 5).
    private static let pauseBetweenPasses: Duration = .seconds(3)

    let playback = PausingLoopPlayback()
    private var viewers = 0

    func attach() {
        viewers += 1
        guard viewers == 1 else { return }
        playback.start(bundled: "lumenHead", extension: "mov", pause: Self.pauseBetweenPasses)
    }

    func detach() {
        viewers = max(0, viewers - 1)
        guard viewers == 0 else { return }
        playback.stop()
    }
}

/// Живая голова Люмена: зацикленный ролик с прозрачностью (`lumenHead.mov`, HEVC с альфой —
/// из `fox_loop_alpha_prores4444.mov` пользователя, 2026-10-16). Пока ролик не готов — его же
/// первый кадр картинкой (`lumenHeadPoster`), подмена не видна; ролик идёт по кругу с паузой
/// между проходами (`LumenHeadPlayback`) и только пока голова на экране. С «уменьшением
/// движения» — один первый кадр.
struct LumenHeadVideo: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isReady = false
    /// Эта копия числится зрителем общего ролика — чтобы снять её ровно один раз.
    @State private var isAttached = false

    var body: some View {
        ZStack {
            Image("lumenHeadPoster")
                .resizable()
                .opacity(isReady && !reduceMotion ? 0 : 1)
            if !reduceMotion {
                LoopingVideoLayer(player: LumenHeadPlayback.shared.playback.queue, videoGravity: .resizeAspect) {
                    isReady = true
                }
                .opacity(isReady ? 1 : 0)
            }
        }
        .animation(.easeOut(duration: 0.3), value: isReady)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { setWatching(!reduceMotion) }
        .onDisappear { setWatching(false) }
        .onChange(of: reduceMotion) { _, reduced in setWatching(!reduced) }
    }

    private func setWatching(_ watching: Bool) {
        guard watching != isAttached else { return }
        isAttached = watching
        if watching {
            LumenHeadPlayback.shared.attach()
        } else {
            LumenHeadPlayback.shared.detach()
        }
    }
}
