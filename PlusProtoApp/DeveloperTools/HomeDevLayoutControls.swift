import SwiftUI

extension HomeDevControls {
    var layoutControls: some View {
        VStack(alignment: .leading, spacing: 20) {
            section("Размер Recently") {
                sliderTile("Высота в свёрнутом виде", value: "\(Int(settings.recentlyHeight)) pt") {
                    Slider(value: $settings.recentlyHeight, in: 48...96, step: 4)
                        .accessibilityLabel("Высота карточек Recently, шаг 4 пункта")
                }
                hint(
                    "При оттяге карточки раскрываются до 96 pt и показывают подписи. Прокрутка возвращает выбранную высоту."
                )
            }
            section("Размер промокарточек") {
                LazyVGrid(columns: columns, spacing: 8) {
                    toggleTile("Менять размер", isOn: $settings.sizesEnabled)
                    toggleTile("Центр без наклона", isOn: $settings.uprightEnabled)
                }
            }
            section("Ширина по типу контента") {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(HomePromoKind.allCases) { kind in
                        let width = settings.width(for: kind)
                        sliderTile(
                            kind.title,
                            value: "\(Int(width)) pt · \(String(format: "%.2f", width / kind.originalWidth))×"
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
                .disabled(!settings.sizesEnabled)
                .opacity(settings.sizesEnabled ? 1 : 0.45)
                hint("Шаг 4 pt. Значения для базового экрана 402 pt.")
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
                Text("Поднять полки под промоблоком").plusText(.textS, .medium)
                Picker("Поднять полки", selection: $settings.shelfLift) {
                    ForEach(HomeShelfLift.allCases) { value in
                        Text(value.title).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!settings.shelvesEnabled)
            }
        }
    }
}
