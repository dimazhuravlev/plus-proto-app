import SwiftUI
import UIKit

/// Переключатель дебаг-меню: вид активного таба (правка пользователя 2026-10-10).
/// Хранится в `UserDefaults`; таббар живёт в нескольких копиях, `@AppStorage` в `TabBarItem`
/// подхватывает значение везде.
enum TabStyleDebug {
    /// Включён — глиф активного таба чисто белый (`fillOne`), без градиента и без свечения под
    /// тайлом. Выключен (по умолчанию) — макетный вид.
    static let whiteActiveKey = "tabActiveWhite"
}

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
    /// Общая непрозрачность неактивного глифа — `fill-opacity="0.9"` из его SVG
    /// (макет обновлён 2026-10-12; в §5 разведки было 0.7).
    static let inactiveGlyphOpacity: Double = 0.9

    /// Внутренние тени глифа — набор «service icon» `2004:9170` (глифы `2004:9175…9186`,
    /// `2004:9281/9356`, сердце `2463:79197/79223`); одни и те же у активных и неактивных.
    /// Значения — в координатах иконки 32×32, в тайле умножаются на `AppTab.glyphScale`.
    /// Радиус — σ из SVG-фильтра (stdDeviation), он же `radius` SwiftUI (конвенция проекта).
    /// Порядок как в макете: первая тень лежит под второй.
    /// Третий слой макета — inner shadow со spread 3.066 (y +0.511, белый 10 %) — в
    /// SVG-экспорте даёт ноль (dilate перекрывает исходник), поэтому не воспроизводим.
    static let glyphInnerShadows: [(opacity: Double, radius: CGFloat, y: CGFloat)] = [
        (0.1, 1.022, 1.022),
        (0.2, 0.511, -0.204),
    ]

    /// Миниатюра добавленной обложки вместо сердца на табе «Моё». Четыре инстанса
    /// `Tab=Collection-*, State=inactive`, 32×32 (бокс сердца), миниатюра — по центру
    /// бокса, то есть по центру тайла 40×40; бордер у всех внутрь, 0.67 белый 8 %,
    /// у картинки такой же радиус:
    /// - `2560:27996` Collection-album — 24×24, радиус 3 (так же рисуем трек и плейлист:
    ///   отдельных нод у них нет);
    /// - `2560:28006` Collection-artist — 24×24, круг (радиус 1000);
    /// - `2560:28002` Collection-book — 20×28, радиус 3 только справа (корешок слева прямой);
    /// - `2560:28004` Collection-movie — 20×28, радиус 3.
    /// Макет даёт только `inactive`: у активного таба миниатюра та же, без своих значений.
    static let peekSquareSize: CGFloat = 24
    static let peekPosterSize = CGSize(width: 20, height: 28)
    static let peekCornerRadius: CGFloat = 3
    static let peekBorderOpacity: Double = 0.08
    static let peekBorderWidth: CGFloat = PlusMetrics.hairline

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

/// Хит-зоны табов (правка пользователя 2026-10-05): между кнопками 60×62 — пустые
/// зазоры, и тап мимо кнопки простреливал таббар в ленту под ним. Таб ловит палец
/// до середины зазора к соседям, крайние — до кромки экрана; по высоте — от низа бара
/// до низа экрана (зона home indicator — тоже таббар). Раскладка не едет: зона —
/// `contentShape` под отрицательным отступом, кадр кнопки остаётся 60×62.
@MainActor
private enum TabBarHitArea {
    /// Зазор между кнопками при space-between — от ширины экрана, а не замером ряда.
    static var gap: CGFloat {
        let count = CGFloat(AppTab.allCases.count)
        let free = PlusMetrics.screenWidth - 2 * PlusMetrics.screenMargin - count * PlusMetrics.tabItemWidth
        return max(0, free / (count - 1))
    }

    static func insets(for tab: AppTab) -> EdgeInsets {
        EdgeInsets(
            // padding-top ряда и зазор до бара: зона доходит до низа бара
            top: PlusChromeMetrics.tabsRowTopPadding + PlusChromeMetrics.actionBarToTabsGap,
            leading: tab == AppTab.allCases.first ? PlusMetrics.screenMargin : gap / 2,
            bottom: PlusChromeMetrics.chromeBottom,
            trailing: tab == AppTab.allCases.last ? PlusMetrics.screenMargin : gap / 2
        )
    }
}

private extension EdgeInsets {
    var negated: EdgeInsets {
        EdgeInsets(top: -top, leading: -leading, bottom: -bottom, trailing: -trailing)
    }
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
                let hit = TabBarHitArea.insets(for: tab)
                Button { select(tab) } label: {
                    TabBarItem(tab: tab, isActive: navigation.activeTab == tab)
                        .padding(hit)
                        .contentShape(.rect)
                        .padding(hit.negated)
                }
                .buttonStyle(PressScaleButtonStyle())
                .scaleEffect(debugPressed == tab ? PressMotion.buttonScale : 1)
                .animation(debugPressed == tab ? PressMotion.pressIn : PressMotion.release, value: debugPressed)
                if tab != AppTab.allCases.last {
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, PlusMetrics.screenMargin)
        .padding(.top, PlusChromeMetrics.tabsRowTopPadding)
        .frame(height: PlusChromeMetrics.tabsRowHeight)
        // Страховка под зонами табов: тап в щель, которую они не накрыли, гасится здесь,
        // а не уходит в ленту под таббаром. Та же площадь — от низа бара до низа экрана.
        .background {
            Color.clear
                .contentShape(.rect)
                .onTapGesture {}
                .padding(.top, -PlusChromeMetrics.actionBarToTabsGap)
                .padding(.bottom, -PlusChromeMetrics.chromeBottom)
        }
        .task { await debugTapCycle() }
        #if DEBUG
        // `-debugCollectionPeek 1` — через 2 с лайк сид-альбома тем же путём, что тап по
        // сердцу экрана: на табе «Моё» сердце сменяется миниатюрой. Если альбом уже в
        // избранном, лайк сперва снимается.
        .task {
            guard UserDefaults.standard.bool(forKey: "debugCollectionPeek"), chromeLayer == nil else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            let store = CollectionStore.shared
            guard let album = store.items.first(where: { $0.kind == .album }) else { return }
            if store.isFavorite(album.id) { store.setFavorite(album, false) }
            store.setFavorite(album, true)
        }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Дебаг-переключатель: активный глиф белый, свечения нет (`TabStyleDebug`).
    @AppStorage(TabStyleDebug.whiteActiveKey) private var whiteActive = false

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

    /// Заливка глифа с белыми внутренними тенями макета (`TabBarGeometry.glyphInnerShadows`),
    /// смещение и радиус — в масштабе глифа. Глиф остаётся векторным template.
    private func glyphFill<Base: ShapeStyle>(_ base: Base) -> AnyShapeStyle {
        let scale = tab.glyphScale
        let shadows = TabBarGeometry.glyphInnerShadows
        return AnyShapeStyle(
            base
                .shadow(.inner(
                    color: .white.opacity(shadows[0].opacity),
                    radius: shadows[0].radius * scale, x: 0, y: shadows[0].y * scale
                ))
                .shadow(.inner(
                    color: .white.opacity(shadows[1].opacity),
                    radius: shadows[1].radius * scale, x: 0, y: shadows[1].y * scale
                ))
        )
    }

    private var tile: some View {
        let shape = RoundedRectangle(cornerRadius: PlusRadius.iconTile, style: .continuous)
        let glyph = tab.glyphFrame
        // Пик читает только «Моё»: у остальных табов объект не попадает в зависимости вью.
        let peekItem = tab == .collection ? CollectionTabPeek.shared.item : nil
        let peeking = peekItem != nil
        // Кросс-поп тот же, что у play/pause и сердца (`ActionBarMotion.iconSwap`);
        // Reduce Motion — только прозрачность.
        let peekAnimation: Animation = reduceMotion ? .easeInOut(duration: 0.2) : ActionBarMotion.iconSwap
        let peekScale: CGFloat = reduceMotion ? 1 : ActionBarMotion.iconSwapScale
        // Один вектор на оба состояния: форма общая, меняется только заливка.
        // Позиция абсолютная — глифы в макете не центрированы и подрезаются краем тайла.
        return ZStack(alignment: .topLeading) {
            Color.clear
            Image(tab.glyphAsset)
                .renderingMode(.template)
                .resizable()
                .frame(width: glyph.size.width, height: glyph.size.height)
                .foregroundStyle(glyphFill(PlusGradient.inactiveTabGlyph))
                .opacity(isActive ? 0 : TabBarGeometry.inactiveGlyphOpacity)
                .overlay {
                    Image(tab.glyphAsset)
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: glyph.size.width, height: glyph.size.height)
                        .foregroundStyle(whiteActive ? glyphFill(Color.fillOne) : glyphFill(PlusGradient.activeTabGlyph))
                        .opacity(isActive ? 1 : 0)
                }
                // Сердце уступает миниатюре: прозрачность и утопление, оба слоя всегда в дереве.
                .opacity(peeking ? 0 : 1)
                .scaleEffect(peeking ? peekScale : 1)
                .animation(peekAnimation, value: peekItem?.id)
                .offset(x: glyph.origin.x, y: glyph.origin.y)
            // Анимация — на контейнере, снаружи вставки/смены миниатюры: её транзакция
            // и ведёт переход кроссфейда.
            ZStack {
                if tab == .collection, let shown = CollectionTabPeek.shared.displayed {
                    CollectionPeekThumbnail(
                        item: shown, isShown: peeking, hiddenScale: peekScale, reduceMotion: reduceMotion
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(peekAnimation, value: peekItem?.id)
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
            // Белый активный таб (дебаг): свечение остаётся в дереве, но не видно.
            .opacity(isActive && !whiteActive ? 1 : 0)
            // Своя кривая поверх общей у кнопки: внутренняя анимация перебивает внешнюю
            // для своего поддерева.
            .animation(isActive ? TabBarMotion.glowAppear : TabBarMotion.activation, value: isActive)
            .allowsHitTesting(false)
    }
}

/// Миниатюра обложки в тайле «Моё»: форма и размер по виду сущности (константы и ноды —
/// в `TabBarGeometry`). Смена сущности (`.id`) — кроссфейд двух миниатюр тем же попом,
/// что сердце ↔ миниатюра; гаснет она так же, не снимаясь с экрана.
private struct CollectionPeekThumbnail: View {
    let item: CollectionItem
    let isShown: Bool
    let hiddenScale: CGFloat
    let reduceMotion: Bool

    var body: some View {
        thumbnail
            .opacity(isShown ? 1 : 0)
            .scaleEffect(isShown ? 1 : hiddenScale)
            .transition(reduceMotion
                ? .opacity
                : .scale(scale: hiddenScale).combined(with: .opacity))
            // После `.transition`: смена `id` снимает старую миниатюру и вставляет новую
            // по этому переходу.
            .id(item.id)
    }

    @ViewBuilder
    private var thumbnail: some View {
        let radius = TabBarGeometry.peekCornerRadius
        switch item.kind {
        case .artist:
            cover(Circle(), size: CGSize(width: TabBarGeometry.peekSquareSize, height: TabBarGeometry.peekSquareSize))
        case .movie:
            cover(RoundedRectangle(cornerRadius: radius, style: .continuous), size: TabBarGeometry.peekPosterSize)
        case .book:
            cover(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0, bottomLeadingRadius: 0,
                    bottomTrailingRadius: radius, topTrailingRadius: radius,
                    style: .continuous
                ),
                size: TabBarGeometry.peekPosterSize
            )
        case .album, .track, .playlist:
            cover(
                RoundedRectangle(cornerRadius: radius, style: .continuous),
                size: CGSize(width: TabBarGeometry.peekSquareSize, height: TabBarGeometry.peekSquareSize)
            )
        }
    }

    /// Распорка задаёт кадр, картинка — `scaledToFill` в оверлее, обводка — внутрь.
    private func cover<S: InsettableShape>(_ shape: S, size: CGSize) -> some View {
        Color.clear
            .frame(width: size.width, height: size.height)
            .overlay {
                if let artwork = item.artwork {
                    ArtworkImage(source: artwork).scaledToFill()
                }
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(
                    .white.opacity(TabBarGeometry.peekBorderOpacity),
                    lineWidth: TabBarGeometry.peekBorderWidth
                )
            }
    }
}
