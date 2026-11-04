import SwiftUI

extension HomeDevControls {
    var layoutControls: some View {
        VStack(alignment: .leading, spacing: 20) {
            section("Recently") {
                Toggle("Скрыть Recently", isOn: $settings.hideRecently)
                hint("Высота — 64 pt. При оттяге карточки раскрываются до 112 pt и показывают подписи.")
            }
            section("Геометрия карусели") {
                Toggle("Объём и параллакс при свайпе", isOn: $settings.promoDepthEnabled)
                    .accessibilityIdentifier("promo-depth-enabled")
                Toggle("Волна по лепестку при запуске", isOn: $settings.promoLiftWaveEnabled)
                    .accessibilityIdentifier("promo-lift-wave-enabled")
                hint("Два независимых эксперимента. Дыхание лепестка работает и без них.")
                Toggle("Центр без наклона", isOn: $settings.uprightEnabled)
                Toggle("Лента всех сочетаний типов", isOn: $settings.promoPairPreviewEnabled)
                hint("Отдельная тестовая лента: все 25 пар пяти типов, включая одинаковые рядом.")
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
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(HomePromoKind.allCases) { kind in
                        let width = settings.width(for: kind)
                        sliderTile(
                            kind.title,
                            value: "\(Int(width)) pt · на 440 pt"
                        ) {
                            Slider(
                                value: Binding(
                                    get: { settings.width(for: kind) },
                                    set: { settings.setWidth($0, for: kind) }
                                ), in: 160...400, step: 4
                            )
                            .accessibilityLabel("Ширина: \(kind.title)")

                        }
                    }
                }
                hint("Шаг 4 pt. Ширины основной карточки на экране 440 pt.")
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
