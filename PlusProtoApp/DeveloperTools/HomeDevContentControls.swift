import SwiftUI

extension HomeDevControls {
    var contentControls: some View {
        VStack(alignment: .leading, spacing: 20) {
            section("Варианты контента") {
                Toggle("Экспериментальные полки на главной", isOn: $settings.shelvesEnabled)
                hint("Выключенные Figma-полки заменяются исходной витриной.")
            }
            section("Recently · Моя волна") {
                Picker("Источник Моей волны", selection: $settings.waveShaderEnabled) {
                    Text("Шейдер").tag(true)
                    Text("Видео").tag(false)
                }.pickerStyle(.segmented)
                if settings.waveShaderEnabled {
                    LazyVGrid(columns: columns, spacing: 8) {
                        sliderTile("Размер", value: "\(Int((settings.waveShaderScale * 100).rounded())) %") {
                            Slider(value: $settings.waveShaderScale, in: 0.75...1.5, step: 0.05)
                                .accessibilityLabel("Размер шейдера Моей волны")
                        }
                        sliderTile("Свечение", value: "\(Int((settings.waveShaderGlow * 100).rounded())) %") {
                            Slider(value: $settings.waveShaderGlow, in: 0...0.5, step: 0.01)
                                .accessibilityLabel("Свечение шейдера Моей волны")
                        }
                        sliderTile("Оттенок", value: "\(Int(settings.waveShaderHue))°") {
                            Slider(value: $settings.waveShaderHue, in: -180...180, step: 5)
                                .accessibilityLabel("Оттенок шейдера Моей волны")
                        }
                        sliderTile(
                            "Насыщенность", value: "\(Int((settings.waveShaderSaturation * 100).rounded())) %"
                        ) {
                            Slider(value: $settings.waveShaderSaturation, in: 0.5...2, step: 0.05)
                                .accessibilityLabel("Насыщенность шейдера Моей волны")
                        }
                        sliderTile("Контраст", value: "\(Int((settings.waveShaderContrast * 100).rounded())) %") {
                            Slider(value: $settings.waveShaderContrast, in: 0.8...1.5, step: 0.05)
                                .accessibilityLabel("Контраст шейдера Моей волны")
                        }
                        sliderTile("Деформация", value: String(format: "%.1f %%", settings.waveShaderWarp * 100)) {
                            Slider(value: $settings.waveShaderWarp, in: 0...0.12, step: 0.005)
                                .accessibilityLabel("Деформация шейдера Моей волны")
                        }
                        sliderTile("Общая скорость", value: String(format: "%.1f×", settings.waveShaderSpeed)) {
                            Slider(value: $settings.waveShaderSpeed, in: 0...3, step: 0.1)
                                .accessibilityLabel("Скорость шейдера Моей волны")
                        }
                        action("Исходный вид", icon: "arrow.counterclockwise") { settings.resetWaveShader() }
                    }
                    DisclosureGroup("Скорость отдельных частей") {
                        LazyVGrid(columns: columns, spacing: 8) {
                            sliderTile("Центр", value: String(format: "%.1f×", settings.waveShaderCoreSpeed)) {
                                Slider(value: $settings.waveShaderCoreSpeed, in: 0...2, step: 0.1)
                                    .accessibilityLabel("Скорость центра Моей волны")
                            }
                            sliderTile("Середина", value: String(format: "%.1f×", settings.waveShaderMiddleSpeed)) {
                                Slider(value: $settings.waveShaderMiddleSpeed, in: 0...2, step: 0.1)
                                    .accessibilityLabel("Скорость средней части Моей волны")
                            }
                            sliderTile("Края", value: String(format: "%.1f×", settings.waveShaderRimSpeed)) {
                                Slider(value: $settings.waveShaderRimSpeed, in: 0...2, step: 0.1)
                                    .accessibilityLabel("Скорость краёв Моей волны")
                            }
                        }
                        .padding(.top, 8)
                    }
                    hint(
                        "Центр, середина и края вращаются независимо. Общий темп замедлен; переходы между частями мягкие."
                    )
                    hint(
                        "На паузе — точная исходная картинка. Деформация и скорость меняют движение при Play. Настройки действуют только в recently."
                    )
                } else {
                    Toggle("Видео при воспроизведении", isOn: $settings.recentlyWaveVideoEnabled)
                    VStack(spacing: 8) {
                        sliderTile(
                            "Непрозрачность", value: "\(Int((settings.recentlyWaveOpacity * 100).rounded())) %"
                        ) {
                            Slider(value: $settings.recentlyWaveOpacity, in: 0.5...1, step: 0.05)
                                .accessibilityLabel("Непрозрачность Моей волны в recently")
                        }
                        LazyVGrid(columns: columns, spacing: 8) {
                            sliderTile(
                                "Насыщенность", value: "\(Int((settings.recentlyWaveSaturation * 100).rounded())) %"
                            ) {
                                Slider(value: $settings.recentlyWaveSaturation, in: 0.75...2, step: 0.05)
                                    .accessibilityLabel("Насыщенность Моей волны в recently")
                            }
                            sliderTile(
                                "Контраст", value: "\(Int((settings.recentlyWaveContrast * 100).rounded())) %"
                            ) {
                                Slider(value: $settings.recentlyWaveContrast, in: 0.8...1.5, step: 0.05)
                                    .accessibilityLabel("Контраст Моей волны в recently")
                            }
                            action("Как раньше", icon: "arrow.uturn.backward") {
                                settings.restoreWaveColors(boosted: false)
                            }
                            action("Яркий вариант", icon: "sparkles") { settings.restoreWaveColors(boosted: true) }
                        }
                    }
                    .disabled(!settings.recentlyWaveVideoEnabled)
                    hint("На паузе — прежняя картинка. При воспроизведении — увеличенное видео.")
                    hint("Цветовые настройки меняют только recently, вкладка Музыки сохраняет свой вид.")
                }
            }
            section("Recently · контент для примерки") {
                LazyVGrid(columns: columns, spacing: 8) {
                    action("Другой набор", icon: "arrow.triangle.2.circlepath") {
                        settings.recentlyPreviewIndex += 1
                    }
                    action("Из истории", icon: "clock") { settings.recentlyPreviewIndex = -1 }
                        .disabled(settings.recentlyPreviewIndex < 0)
                }
                if settings.recentlyPreviewIndex >= 0 {
                    sliderTile("Просмотрено · пример", value: "\(Int(settings.recentlyPreviewProgress * 100)) %") {
                        Slider(value: $settings.recentlyPreviewProgress, in: 0...1, step: 0.01)
                            .accessibilityLabel("Тестовый прогресс фильма recently")
                    }
                }
                hint("Новый набор меняет контент и место фильма в recently. История просмотра сохраняется.")
            }
            section("Подсказка реакции") {
                Button("Повторить подсказку") { PromoIntroSession.shared.replay() }
                    .buttonStyle(.bordered)
                hint(
                    "«Рекомендовать» остаётся на первой карточке до свайпа или реакции. Один раз за запуск приложения."
                )
            }
        }
    }
}
