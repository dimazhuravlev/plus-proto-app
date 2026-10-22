import SwiftUI

/// Исходная картинка — точная текстура формы и цвета; Metal меняет её геометрию.
/// В покое нет покадровых обновлений, на паузе — исходные пиксели.
struct RecentWaveShader: View {
    let isPlaying: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var epoch = Date()
    private var settings: HomePresentationSettings { .shared }
    private var baseScale: CGFloat { CGFloat(settings.recentlyHeight) / 80 }

    private var moving: Bool {
        isPlaying && !reduceMotion && settings.waveShaderSpeed > 0
    }

    var body: some View {
        // Один видимый слой: никакого кроссфейда, скрывающего первые кадры вращения.
        // На паузе тот же прогретый Metal pipeline возвращает исходную текстуру.
        TimelineView(.animation(minimumInterval: 1 / 120, paused: !moving)) { context in
            artwork(time: moving ? max(0, context.date.timeIntervalSince(epoch)) * settings.waveShaderSpeed : 0)
        }
        // Время шейдера не должно интерполироваться внешней анимацией масштаба.
        .transaction { $0.animation = nil }
        .scaleEffect(x: isPlaying ? 177.5 / 107.1 : 1,
                     y: isPlaying ? 176.25 / 107.1 : 1)
        .offset(x: 6 * baseScale, y: -0.5 * baseScale)
        .animation(.easeOut(duration: reduceMotion ? 0 : 0.45), value: isPlaying)
        // Pull-to growth is an outer transform. It must not enter the shader's
        // non-animated time transaction or rebuild its texture frame at every size.
        .scaleEffect(HomeQuickAccessLayout.scale / baseScale)
        .onChange(of: isPlaying) { _, playing in
            if playing { epoch = .now }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func artwork(time: Double) -> some View {
        let scale = baseScale * settings.waveShaderScale
        let width = 107.1 * scale
        let height = 107.1 * scale
        return ZStack {
            Image("quickAccessWave").resizable()
                .frame(width: 138 * scale, height: 137 * scale)
                .blur(radius: 6 * scale)
                .opacity(settings.waveShaderGlow)
            Image("quickAccessWave").resizable()
                .frame(width: width, height: height)
                .layerEffect(ShaderLibrary.recentWaveFlow(
                    .float2(Float(width), Float(height)), .float(Float(time)),
                    .float(Float(settings.waveShaderWarp)),
                    .float(Float(settings.waveShaderCoreSpeed)),
                    .float(Float(settings.waveShaderMiddleSpeed)),
                    .float(Float(settings.waveShaderRimSpeed))
                ), maxSampleOffset: CGSize(width: width, height: height))
        }
        .hueRotation(.degrees(settings.waveShaderHue))
        .saturation(settings.waveShaderSaturation)
        .contrast(settings.waveShaderContrast)
    }
}
