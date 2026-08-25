import SwiftUI
import UIKit

/// Тайминги и отдача таббара.
enum TabBarMotion {
    /// Одна анимация на все параметры таба: бордер тайла, заливка глифа, цвет лейбла,
    /// прозрачность и сдвиг свечения (решение 2026-08-22).
    ///
    /// Унаследованные от `BottomBarV2` MusicPlayer 0,42s вели там только цвет трёх иконок;
    /// здесь под ту же анимацию попадает свечение в 162pt, и на записи с симулятора оно
    /// заметно тянулось за мгновенной подменой контента таба. На 0,22s кроссфейд, наоборот,
    /// схлопывается в подмену: сдвиг свечения 7→11pt перестаёт читаться. 0,26s — нижняя
    /// граница, на которой переход ещё читается одним непрерывным движением.
    static let activation: Animation = .smooth(duration: 0.26)

    /// Хаптика тапа по табу — карта MusicPlayer (nav-chrome §11): impact medium
    static let tapHapticIntensity: CGFloat = 0.7
}

/// Числа таббара, которых нет в `Tokens.swift`: каждое встречается ровно здесь
/// («токен ради единственного вызова не заводим»). Источник — figma-tabbar §2/§5/§6.
private enum TabBarGeometry {
    /// Общая непрозрачность неактивного глифа — `fill-opacity="0.7"` из его SVG (§5).
    static let inactiveGlyphOpacity: Double = 0.7

    /// Бордер тайла: непрозрачность и толщина, неактивный → активный
    static let tileBorderOpacity: (inactive: Double, active: Double) = (0.04, 0.06)
    static let tileBorderWidth: (inactive: CGFloat, active: CGFloat) = (PlusMetrics.hairline, 0.733)

    /// Кадр спарка активного таба — макет `2004:9386`: бокс 80×67 с верхним левым
    /// углом на (−9.95, −8) от кнопки 60×62. По горизонтали центры совпадают
    /// (сдвиг 0.05pt — хвост округления в макете, не переносим), по вертикали
    /// центр спарка выше центра кнопки на 5.5.
    static let sparkSize = CGSize(width: 80, height: 67)
    static let sparkCenterOffset: CGFloat = -5.5
    /// Ход загорания: неактивная позиция на 3pt ниже активной, подъём едва заметен
    /// (правка пользователя 2026-08-25; раньше 4 — дельта контейнера старого свечения).
    static let sparkRise: CGFloat = 3
}

/// Ряд табов: 5 кнопок 60×62, поля 24, padding-top 4, распределение space-between
/// (figma-tabbar §2).
struct TabBarView: View {
    @Environment(AppNavigationState.self) private var navigation
    @State private var debugPressed: AppTab?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button { select(tab) } label: {
                    TabBarItem(tab: tab, isActive: navigation.activeTab == tab)
                        .contentShape(.rect)
                }
                .buttonStyle(PressScaleButtonStyle())
                .scaleEffect(debugPressed == tab ? GlassIconButtonConfig.pressedScale : 1)
                .animation(.smooth(duration: GlassIconButtonConfig.pressDuration), value: debugPressed)
                if tab != AppTab.allCases.last {
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, PlusMetrics.screenMargin)
        .padding(.top, PlusChromeMetrics.tabsRowTopPadding)
        .frame(height: PlusChromeMetrics.tabsRowHeight)
        .task { await debugTapCycle() }
    }

    /// ВРЕМЕННОЕ: шелл симулятор не тапает, поэтому тап воспроизводится синтетически —
    /// нажатие держится 110ms, отпускание и `select` уходят одним апдейтом, как у `Button`
    /// в `onEnded`. Пара «scaleEffect + animation(value:)» выше повторяет тело
    /// `PressScaleButtonStyle`, но снаружи кнопки — это заведомо более жёсткий случай.
    private func debugTapCycle() async {
        guard UserDefaults.standard.bool(forKey: "debugTapCycle") else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(1400))
            let next = AppTab(rawValue: (navigation.activeTab.rawValue + 1) % AppTab.allCases.count) ?? .plus
            debugPressed = next
            try? await Task.sleep(for: .milliseconds(110))
            debugPressed = nil
            select(next)
        }
    }

    private func select(_ tab: AppTab) {
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: TabBarMotion.tapHapticIntensity)
        navigation.select(tab)
    }
}

/// Кнопка таба: тайл 40×40 r14 + лейбл 11/14, зазор 2, кадр 60×62 (figma-tabbar §2).
/// Оба состояния всегда в дереве — активация меняет только прозрачности и смещение.
private struct TabBarItem: View {
    let tab: AppTab
    let isActive: Bool

    var body: some View {
        VStack(spacing: PlusMetrics.tabIconLabelGap) {
            tile
            Text(tab.title)
                .plusTabLabel()
                .foregroundStyle(isActive ? Color.fillOne : Color.fillSix)
        }
        .frame(width: PlusMetrics.tabItemWidth, height: PlusMetrics.tabItemHeight)
        // Свечение — фоном, чтобы его 155pt не раздували кнопку до своей высоты.
        // Заодно оно попадает под scale пресс-стейта вместе с тайлом и лейблом.
        .background { pulse }
        // Кроссфейд живёт на кнопке, а не на ряде: `PressScaleButtonStyle` несёт свою
        // `.animation(value: isPressed)`, и снаружи она на отпускании перебивала бы
        // транзакцию нажатого таба — он загорался бы за 0,15s, пока предыдущий гаснет 0,26s.
        .animation(TabBarMotion.activation, value: isActive)
    }

    private var tile: some View {
        let shape = RoundedRectangle(cornerRadius: PlusRadius.iconTile, style: .continuous)
        let glyph = tab.glyphFrame
        // Один вектор на оба состояния: форма общая, меняется только заливка.
        // Позиция абсолютная — глифы в макете не центрированы и подрезаются краем тайла.
        return ZStack(alignment: .topLeading) {
            Color.clear
            Image(tab.glyphAsset)
                .renderingMode(.template)
                .resizable()
                .frame(width: glyph.size.width, height: glyph.size.height)
                .foregroundStyle(PlusGradient.inactiveTabGlyph)
                .opacity(isActive ? 0 : TabBarGeometry.inactiveGlyphOpacity)
                .overlay {
                    Image(tab.glyphAsset)
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: glyph.size.width, height: glyph.size.height)
                        .foregroundStyle(PlusGradient.activeTabGlyph)
                        .opacity(isActive ? 1 : 0)
                }
                .offset(x: glyph.origin.x, y: glyph.origin.y)
        }
        .frame(width: PlusMetrics.tabIconTile, height: PlusMetrics.tabIconTile)
        .clipShape(shape)
        .glassIconTile(
            border: .white.opacity(
                isActive ? TabBarGeometry.tileBorderOpacity.active : TabBarGeometry.tileBorderOpacity.inactive
            ),
            borderWidth: isActive ? TabBarGeometry.tileBorderWidth.active : TabBarGeometry.tileBorderWidth.inactive
        )
    }

    /// Спарк — экспорт из макета (`tab_spark.png`), а не рисование кодом: лучистую
    /// вспышку из макета `2004:9386` эллипсом с блюром не собрать. Кадр 80×67
    /// растягивает пиксели ассета (99×84 натуральных) — как image-fill в макете;
    /// расхождение пропорций 1.3 % на глаз не существует.
    private var pulse: some View {
        Image("tabSpark")
            .resizable()
            .frame(width: TabBarGeometry.sparkSize.width, height: TabBarGeometry.sparkSize.height)
            .offset(y: TabBarGeometry.sparkCenterOffset + (isActive ? 0 : TabBarGeometry.sparkRise))
            .opacity(isActive ? 1 : 0)
            .allowsHitTesting(false)
    }
}
