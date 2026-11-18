import SwiftUI

extension HomeDevControls {
    var layoutControls: some View {
        VStack(alignment: .leading, spacing: 20) {
            section("Recently") {
                Picker("Режим ПП", selection: $settings.recentlyMode) {
                    ForEach(HomeRecentlyMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("recently-mode")
                HomeDevFlowLayout(spacing: 8) {
                    Button("Очистить Recently") {
                        RecentlyConsumed.shared.clear()
                        HomeRecentlyPullState.shared.reset()
                    }.accessibilityIdentifier("recently-clear")
                    Button("Быстро заполнить Recently") {
                        RecentlyConsumed.shared.fillExamples()
                        if settings.recentlyMode == .hidden { settings.recentlyMode = .standard }
                    }.accessibilityIdentifier("recently-fill")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
            }
            section("Реакции карусели") {
                Toggle("Фиолетовое состояние кнопок", isOn: $settings.promoPurpleFeedbackEnabled)
                    .accessibilityIdentifier("promo-purple-feedback-enabled")
                hint("Выключено по умолчанию. При нажатии — фиолетовая поверхность табов и залитая иконка; плюс остаётся плюсом. В покое кнопки обычные. Работает со всеми карточками.")
                Toggle("V2: сохранение вместо лайка", isOn: $settings.promoSaveV2Enabled)
                    .accessibilityIdentifier("promo-save-v2-enabled")
                hint("Выключено по умолчанию. Книги — плюс, кино — закладка с плюсом, музыка — сердце. Нажатие сразу сохраняет в «Моё».")
            }
            section("Геометрия карусели") {
                Toggle("Объём и параллакс при свайпе", isOn: $settings.promoDepthEnabled)
                    .accessibilityIdentifier("promo-depth-enabled")
                Toggle("Волна по лепестку при запуске", isOn: $settings.promoLiftWaveEnabled)
                    .accessibilityIdentifier("promo-lift-wave-enabled")
                hint("Оба эффекта включены по умолчанию. Дыхание лепестка работает независимо от них.")
                Toggle("Центр без наклона", isOn: $settings.uprightEnabled)
                Toggle("Настраивать offset соседей", isOn: $settings.legacySideOffsetEnabled)
                if settings.legacySideOffsetEnabled {
                    sliderTile("Offset соседей", value: "\(Int(settings.legacySideOffset)) pt") {
                        Slider(value: $settings.legacySideOffset, in: -96...96, step: 4)
                            .accessibilityLabel("Вертикальный offset соседей карусели")
                    }
                    hint("Минус — выше, плюс — ниже. Центральная карточка остаётся на месте.")
                }
            }
            section("Ширина по типу контента") {
                ForEach(HomePromoKind.allCases.filter { $0 != .station }) { kind in
                    let widths = settings.widths(for: kind)
                    Text(kind.title).plusText(.textM, .medium)
                    LazyVGrid(columns: columns, spacing: 8) {
                        sliderTile("Экран до 375 pt", value: "\(Int(widths.minimum)) pt") {
                            Slider(value: Binding(
                                get: { Double(settings.widths(for: kind).minimum) },
                                set: { settings.setMinimumWidth($0, for: kind) }
                            ), in: 160...400, step: 1)
                            .accessibilityLabel("Минимальная ширина: \(kind.title)")
                            .accessibilityIdentifier("promo-min-width-" + kind.rawValue)
                        }
                        sliderTile("Экран от 528 pt", value: "\(Int(widths.maximum)) pt") {
                            Slider(value: Binding(
                                get: { Double(settings.widths(for: kind).maximum) },
                                set: { settings.setMaximumWidth($0, for: kind) }
                            ), in: 160...400, step: 1)
                            .accessibilityLabel("Максимальная ширина: \(kind.title)")
                            .accessibilityIdentifier("promo-max-width-" + kind.rawValue)
                        }
                    }
                }
                hint("Между 375 и 528 pt ширина меняется плавно. Пропорции книг сохраняются. Картинка станции использует размеры артиста.")
            }
            section("Наклон боковых карточек") {
                sliderTile("Один угол для обеих сторон", value: "±\(Int(settings.sideAngle))°") {
                    Slider(value: $settings.sideAngle, in: 0...20, step: 1)
                        .accessibilityLabel("Общий угол боковых карточек")
                }
                .disabled(!settings.uprightEnabled)
            }
            section("Порядок и отступы") {

                Toggle("Настраивать отступ от хедера", isOn: $settings.headerGapEnabled)
                sliderTile("Хедер ↔ верхняя секция", value: "\(Int(settings.headerGap)) px") {
                    Slider(value: $settings.headerGap, in: -24...160, step: 4)
                        .accessibilityLabel("Отступ от хедера до верхней секции")
                }
                .disabled(!settings.headerGapEnabled)
                hint("Порядок закреплён: сначала Recently, затем промоблок.")
                Toggle("Настраивать зазор между секциями", isOn: $settings.heroGapEnabled)
                sliderTile("Recently ↔ промоблок", value: "\(Int(settings.heroGap)) px") {
                    Slider(value: $settings.heroGap, in: -24...96, step: 4)
                        .accessibilityLabel("Зазор между recently и промоблоком")
                }
                .disabled(!settings.heroGapEnabled)
                sliderTile("Поднять полки под промоблоком", value: "\(Int(settings.shelfLift)) pt") {
                    Slider(value: $settings.shelfLift, in: -128...320, step: 4)
                        .accessibilityLabel("Подъём полок, шаг 4 пункта")
                }
                .disabled(!settings.shelvesEnabled)
            }
        }
    }
}
