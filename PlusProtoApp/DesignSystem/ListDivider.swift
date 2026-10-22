import SwiftUI

/// Разделитель строк списка — ровно один физический пиксель. Макетные 0.5 pt на @3x —
/// полтора пикселя, и система округляла их то в один, то в два: верхняя черта списка
/// выходила вдвое толще и ярче остальных (жалоба пользователя 2026-10-22, замер кадром).
struct ListDivider: View {
    var color: Color = CollectionLayout.divider

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1 / displayScale)
    }
}
