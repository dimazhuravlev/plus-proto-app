//
//  ScrollScaleHeader.swift
//
//  Масштабирование элемента прибитой шапки по вертикальному скроллу:
//  уменьшение при скролле вверх и лёгкий рост на оттяге вниз.
//
//  Файл самодостаточный: параметры, логика, модификаторы и рабочий пример.
//  Требуется iOS 18+ (`onScrollGeometryChange`).
//

import SwiftUI

// MARK: - Параметры

struct ScrollScaleConfig {
    /// Масштаб в свёрнутом состоянии.
    var collapsedScale: CGFloat = 0.7
    /// Ход скролла (pt), за который масштаб доходит до `collapsedScale`.
    var collapseDistance: CGFloat = 240
    /// Ход оттяга (pt), за который масштаб вырос бы вдвое. Чем больше, тем мягче
    /// реакция: 2000 даёт около +6 % на оттяге в 120 pt.
    var stretchDistance: CGFloat = 2000
    /// Потолок роста — ограничивает длинный протяг.
    var maxStretchScale: CGFloat = 1.12

    static let `default` = ScrollScaleConfig()
}

// MARK: - Логика

extension ScrollScaleConfig {
    /// Масштаб для текущего смещения.
    /// `offset > 0` — контент ушёл вверх, `offset < 0` — оттяг, `0` — покой.
    ///
    /// Два хода перемножаются, а не выбираются ветвлением: при `offset > 0`
    /// множитель оттяга равен единице, при `offset < 0` — множитель свёртки,
    /// поэтому на переходе через ноль масштаб непрерывен.
    func scale(for offset: CGFloat) -> CGFloat {
        let collapse = min(1, max(0, offset / collapseDistance))
        let stretch = max(0, -offset)

        let collapseScale = 1 + (collapsedScale - 1) * collapse
        let stretchScale = min(maxStretchScale, 1 + stretch / stretchDistance)

        return collapseScale * stretchScale
    }
}

// MARK: - Применение

extension View {
    /// Масштаб как функция от смещения скролла. Без `withAnimation` и `.animation`:
    /// значение должно меняться кадр-в-кадр со скроллом, любая анимация здесь —
    /// это задержка между пальцем и элементом.
    ///
    /// `scaleEffect`, а не пересчёт размера: иначе раскладка шапки пересчитывается
    /// на каждом кадре и соседние элементы дёргаются.
    func scrollScale(
        offset: CGFloat,
        anchor: UnitPoint = .topLeading,
        config: ScrollScaleConfig = .default
    ) -> some View {
        scaleEffect(config.scale(for: offset), anchor: anchor)
    }

    /// Смещение скролла для шапки. Вешается на сам `ScrollView`.
    ///
    /// `onScrollGeometryChange`, а не `PreferenceKey` с датчиком-распоркой:
    /// датчику нужен свой проход раскладки на каждом кадре, а геометрия скролла
    /// уже посчитана. Значение сравнивается системой — состояние пишется только
    /// при реальном изменении.
    func trackScrollOffset(into offset: Binding<CGFloat>) -> some View {
        onScrollGeometryChange(for: CGFloat.self) { geometry in
            // Плюс верхний inset: у непрокрученного вью contentOffset.y
            // отрицательный на высоту инсета, а рампе нужен ноль в покое.
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, new in
            offset.wrappedValue = new
        }
    }
}

// MARK: - Пример

/// Экран с прибитой шапкой: логотип слева уменьшается по скроллу и подрастает
/// на оттяге, кнопки справа стоят на месте.
struct ScrollScaleHeaderExample: View {
    @State private var scrollOffset: CGFloat = 0

    private let config = ScrollScaleConfig.default

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                content
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)
            .trackScrollOffset(into: $scrollOffset)

            // Шапка прибита к верху и не скроллится — уезжает под неё только контент.
            header
        }
        .background(Color.black)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 0) {
            logo
                // Смещение передаётся параметром: вью не читает собственную
                // геометрию, иначе раскладка зависела бы от результата раскладки.
                .scrollScale(offset: scrollOffset, config: config)

            Spacer(minLength: 0)

            actions
        }
        .padding(.top, 63)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
    }

    private var logo: some View {
        Text("НАЗВАНИЕ")
            .font(.system(size: 34, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: 188, height: 64, alignment: .bottomLeading)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Circle().fill(.white.opacity(0.2)).frame(width: 32, height: 32)
            Circle().fill(.white.opacity(0.2)).frame(width: 32, height: 32)
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.gray, .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 480)

            ForEach(0..<20, id: \.self) { index in
                Text("Секция \(index + 1)")
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
        }
    }
}

#Preview {
    ScrollScaleHeaderExample()
}
