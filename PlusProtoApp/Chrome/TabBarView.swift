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

    /// Свечение под иконкой проявляется дольше остального таба — 0.6s против 0.26
    /// (правка пользователя 2026-10-03: «появлялось плавнее, дольше»). Гаснет оно вместе
    /// с табом за 0.26s: старое свечение не должно висеть, пока загорается новое.
    static let glowAppear: Animation = .smooth(duration: 0.6)

    /// Хаптика тапа по табу — карта MusicPlayer (nav-chrome §11): impact medium
    static let tapHapticIntensity: CGFloat = 0.7

    /// Отклик тапа по табу. Тот же — у верхних табов витрин (`ServiceTopNav`, правка
    /// пользователя 2026-10-04: «такие же, как в табах снизу»).
    @MainActor static func tapHaptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: tapHapticIntensity)
    }
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
    /// центр макетного бокса выше центра кнопки на 5.5.
    static let sparkBaseSize = CGSize(width: 80, height: 67)
    /// Увеличение поверх макетного бокса (правка пользователя 2026-08-25):
    /// кадр растёт от **нижней кромки** вверх и в стороны — она остаётся там же,
    /// где стояла у макетного бокса.
    static let sparkScale: CGFloat = 1.15
    static var sparkSize: CGSize {
        CGSize(width: sparkBaseSize.width * sparkScale, height: sparkBaseSize.height * sparkScale)
    }
    /// Нижняя кромка макетного бокса: центр (−5.5 от центра кнопки) + полвысоты
    private static var sparkBaseBottom: CGFloat { -5.5 + sparkBaseSize.height / 2 }
    /// Центр увеличенного кадра пересчитан от неподвижной нижней кромки
    static var sparkCenterOffset: CGFloat { sparkBaseBottom - sparkSize.height / 2 }
    /// Ход загорания: неактивная позиция на 3pt ниже активной, подъём едва заметен
    /// (правка пользователя 2026-08-25; раньше 4 — дельта контейнера старого свечения).
    static let sparkRise: CGFloat = 3
}

/// Ряд табов: 5 кнопок 60×62, поля 24, padding-top 4, распределение space-between
/// (figma-tabbar §2).
struct TabBarView: View {
    @Environment(AppNavigationState.self) private var navigation
    @Environment(SearchState.self) private var search
    /// Чей это таббар: корня или экрана слоя фильма (`SearchNavigationSync`).
    @Environment(\.chromeLayer) private var chromeLayer
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
                .animation(debugPressed == tab ? PressMotion.pressIn : PressMotion.release, value: debugPressed)
                if tab != AppTab.allCases.last {
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, PlusMetrics.screenMargin)
        .padding(.top, PlusChromeMetrics.tabsRowTopPadding)
        .frame(height: PlusChromeMetrics.tabsRowHeight)
        .task { await debugTapCycle() }
        #if DEBUG
        // `-debugRetapTab <сек>` — через столько секунд тап по уже активному табу:
        // поп до корня (или скролл к началу) не проверить без тапа, а шелл не тапает.
        // Только у корневого таббара: его отсчёт идёт от запуска, и слой фильма, открытый
        // к тому времени, он снимает так же, как таббар самого слоя.
        .task {
            let delay = UserDefaults.standard.double(forKey: "debugRetapTab")
            guard delay > 0, chromeLayer == nil else { return }
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            select(navigation.activeTab)
        }
        #endif
    }

    /// ВРЕМЕННОЕ: шелл симулятор не тапает, поэтому тап воспроизводится синтетически —
    /// нажатие держится 110ms, отпускание и `select` уходят одним апдейтом, как у `Button`
    /// в `onEnded`. Пара «scaleEffect + animation(value:)» выше повторяет просадку
    /// `PressScaleButtonStyle` (те же кривые `PressMotion`), но снаружи кнопки — это заведомо
    /// более жёсткий случай: анимация не ограничена масштабом.
    private func debugTapCycle() async {
        guard UserDefaults.standard.bool(forKey: "debugTapCycle"), chromeLayer == nil else { return }
        // Два круга и стоп: цикл существует для записи анимаций, а не вечной жизни.
        // Бесконечный отбирал таббар у пользователя до перезапуска приложения —
        // дебаг-флоу обязан заканчиваться сам (жалоба 2026-08-25).
        for _ in 0..<(AppTab.allCases.count * 2) {
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .milliseconds(1400))
            let next = AppTab(rawValue: (navigation.activeTab.rawValue + 1) % AppTab.allCases.count) ?? .plus
            debugPressed = next
            try? await Task.sleep(for: .milliseconds(110))
            debugPressed = nil
            select(next)
        }
    }

    private func select(_ tab: AppTab) {
        TabBarMotion.tapHaptic()
        // Тап по своему табу — домой, к его контенту: стек уходит на корень, и поиск,
        // из которого сюда пришли, на корне не встаёт (правка пользователя 2026-10-03).
        // Прежде поп до корня читался возвратом из карточки, и вместо витрины вставала
        // выдача. Отметка ухода гаснет **до** попа: возврат её уже не найдёт.
        // Так же, как при уходе на другой таб (`AppRootView`, onChange таба).
        // Сброс — мгновенный: карточку стек снимает срезом, и гаснущий 0.3 с поиск
        // лёг бы поверх контента таба (второе ревью 2026-10-03). Только когда есть что
        // снимать: на корне тап — уезд к началу экрана, и ему анимация нужна.
        //
        // Из слоя фильма (таббар его экранов, 2026-10-04) — так же мгновенно и на любой
        // таб: слой снимается срезом, а не сворачивается зумом в карточку, которой
        // на новом табе нет.
        if navigation.coveredRoute != nil || (tab == navigation.activeTab && navigation.stackDepth > 0) {
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                search.dropSuspension()
                search.isBrowsing = false
                search.collapse()
                navigation.select(tab)
            }
            return
        }
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
                .plusText(.textXS, .medium)
                .foregroundStyle(isActive ? Color.fillOne : Color.fillSix)
        }
        .frame(width: PlusMetrics.tabItemWidth, height: PlusMetrics.tabItemHeight)
        // Свечение — фоном, чтобы его 155pt не раздували кнопку до своей высоты.
        // Заодно оно попадает под scale пресс-стейта вместе с тайлом и лейблом.
        .background { pulse }
        // Кроссфейд живёт на кнопке, а не на ряде: снаружи на кнопке висит
        // `.animation(value: debugPressed)` синтетического тапа, и на отпускании она
        // перебивала бы транзакцию нажатого таба — он загорался бы кривой нажатия, пока
        // предыдущий гаснет 0,26s. Анимация самого `PressScaleButtonStyle` — только у масштаба.
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
            // Своя кривая поверх общей у кнопки: внутренняя анимация перебивает внешнюю
            // для своего поддерева.
            .animation(isActive ? TabBarMotion.glowAppear : TabBarMotion.activation, value: isActive)
            .allowsHitTesting(false)
    }
}
