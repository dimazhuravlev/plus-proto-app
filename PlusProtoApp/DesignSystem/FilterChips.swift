import SwiftUI
import VariableBlur

/// Числа ряда чипсов — `chips-row` макета: чипсы 40 с полями 8 сверху и снизу,
/// поля ленты 16, шаг 6 (правка пользователя 2026-10-03; в макете 8).
enum FilterChipsLayout {
    static let side: CGFloat = 16
    static let vertical: CGFloat = 8
    static let gap: CGFloat = 6
    static let chipHeight: CGFloat = 40
    static var rowHeight: CGFloat { chipHeight + 2 * vertical }
}

enum FilterChipsMotion {
    /// Подкрутка ленты к выбранному чипсу — 0.3 с, сильный ease-out: лента отвечает
    /// сразу и мягко встаёт.
    static let center: Animation = .timingCurve(0.23, 1, 0.32, 1, duration: 0.3)
}

/// Ряд чипсов-фильтров — общий для полной выдачи музыки в поиске и полных списков
/// коллекции «Моё» (2026-10-04) — фильтры второго уровня: лента вбок, выбранный чипс
/// доезжает в центр, тап — хаптик таббара. Активная капсула **не переезжает** с чипса
/// на чипс, как пилюля верхней навигации витрин: прежняя гаснет, новая загорается на
/// месте (правка пользователя 2026-10-04).
struct FilterChipsRow<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String

    /// Сколько ждать раскладки ленты, прежде чем ставить стартовый чипс в центр.
    private static var layoutDelay: Duration { .milliseconds(50) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: FilterChipsLayout.gap) {
                    ForEach(options, id: \.self) { option in
                        FilterChip(title: title(option), isActive: option == selection) {
                            select(option)
                        }
                        .id(option)
                    }
                }
                .padding(.horizontal, FilterChipsLayout.side)
                .padding(.vertical, FilterChipsLayout.vertical)
            }
            // Высота — явно: горизонтальная лента сама тянется по вертикали на всё
            // предложенное (замер `-debugHitSweep` 2026-10-06: 186 при содержимом 56).
            // Ряд — внутри вертикальной ленты (закреплённым заголовком): в оверлее экрана
            // UIKit раздувает его скролл до кромок соседей, и прозрачный низ забирал
            // касания первой строки списка.
            .frame(height: FilterChipsLayout.rowHeight)
            .scrollIndicators(.hidden)
            // Выбранный чипс — в центр экрана; у краёв лента упирается в свои поля.
            .onChange(of: selection) { _, active in
                withAnimation(FilterChipsMotion.center) {
                    proxy.scrollTo(active, anchor: .center)
                }
            }
            // Экран, открытый сразу на дальнем фильтре (полный список коллекции), встаёт
            // с выбранным чипсом на виду — мгновенно, без подкрутки. Ни `scrollTo`
            // на появлении, ни стартовая позиция по id ленту не двигали: приходили раньше
            // раскладки, и выбранный чипс торчал из-за края (кадры 2026-10-04). Лента
            // доезжает ровно настолько, чтобы чипс стал виден, — без центровки: та
            // уводила за левый край первые чипсы, хотя выбранный и так был на виду.
            .task {
                guard selection != options.first else { return }
                try? await Task.sleep(for: Self.layoutDelay)
                guard !Task.isCancelled else { return }
                var instant = Transaction()
                instant.disablesAnimations = true
                withTransaction(instant) { proxy.scrollTo(selection) }
            }
        }
    }

    /// Тап по чипсу — как по табу навигации витрин: хаптик таббара; смена капсулы —
    /// той же пружиной 0.3 с, но прозрачностью на месте (правки пользователя 2026-10-04).
    private func select(_ option: Option) {
        guard option != selection else { return }
        TabBarMotion.tapHaptic()
        withAnimation(ServiceTopNavMotion.select) { selection = option }
    }
}

/// Чипс фильтра — `chips-row` макета `19151:18648`: 15/20 Semibold, поля 16 × 10, капсула
/// с размытием фона. Активный — та же стеклянная пилюля, что у табов первого уровня
/// (`ActiveTabPill`: фиолетовый 50 %, розовое свечение снизу, бордер белый 30 %), и текст
/// тем же градиентом; остальные — заливка кнопок, бордер белый 15 %, текст Fill/Four
/// (правка пользователя 2026-10-31: прежде активный был акцентным #A332FF с бордером 8 %).
private struct FilterChip: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Два слоя текста, а не смена заливки: градиент и белый друг в друга
                // не анимируются, а прозрачность — да (как у табов первого уровня).
                Text(title)
                    .plusText(.textM, .semibold)
                    .foregroundStyle(Color.fillFour)
                    .opacity(isActive ? 0 : 1)
                Text(title)
                    .plusText(.textM, .semibold)
                    .foregroundStyle(ServiceTopNavLayout.activeText)
                    .opacity(isActive ? 1 : 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            // Своя пилюля у каждого чипса и всегда в дереве: смена — прозрачностью
            // на месте, без переезда.
            .background {
                ActiveTabPill(showsHighlight: false)
                    .opacity(isActive ? 1 : 0)
            }
            .background {
                ZStack {
                    BackdropBlurView(radius: ServiceTopNavLayout.pillBlur)
                    Color.buttonsSecondary
                }
                .clipShape(Capsule())
                .overlay {
                    Capsule().strokeBorder(Color.fillEight, lineWidth: SecondaryButtonBorder.width)
                }
                .opacity(isActive ? 0 : 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

// MARK: - Закреплённый ряд

enum PinnedFilterChipsLayout {
    /// Подложка навбара и чипсов — на 24 ниже чипсов, проявляется за первые 24 скролла
    static let backdropTail: CGFloat = 24
    static let backdropRamp: CGFloat = 24

    /// Навбар над закреплёнными чипсами: своей подложки у бара нет — она общая
    /// с чипсами; название — всегда, и при оттяге тоже.
    static let navThresholds = EntityNavBarThresholds(
        backgroundStart: .greatestFiniteMagnitude,
        backgroundRamp: 1,
        titleStart: -.greatestFiniteMagnitude,
        titleRamp: 0
    )
}

/// Ряд чипсов, закреплённый под навбаром экрана со списком, — заголовком секции
/// внутри ленты (`pinnedViews: [.sectionHeaders]`), а не оверлеем экрана: там UIKit
/// раздувал скролл ряда до кромок соседей, и его прозрачный низ забирал касания первой
/// строки (жалоба пользователя 2026-10-06). Подложка одна на навбар и чипсы:
/// прогрессивный блюр без затемнения от верха экрана до чуть ниже чипсов, проявляется
/// по скроллу. При оттяге ряд едет за лентой вчетверо медленнее — как навигация витрин.
/// Общий у списка плейлистов «Моего» и экрана всех серий сериала.
struct PinnedFilterChips<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    /// Сдвиг ленты экрана (`trackNavBarScroll`)
    let scrollOffset: CGFloat

    var body: some View {
        FilterChipsRow(options: options, selection: $selection, title: title)
            .background(alignment: .top) { backdrop }
            .offset(y: ServiceTopNavMotion.pullShift(for: scrollOffset) - max(0, -scrollOffset))
    }

    private var backdrop: some View {
        let above = ServiceTopNavLayout.topSafeArea + EntityNavBarGeometry.barHeight
        return VariableBlurView(
            maxBlurRadius: EntityNavBarGeometry.backdropBlurRadius,
            direction: .blurredTopClearBottom
        )
        .frame(height: above + FilterChipsLayout.rowHeight + PinnedFilterChipsLayout.backdropTail)
        .offset(y: -above)
        .opacity(NavBarRamp.progress(scrollOffset, start: 0, length: PinnedFilterChipsLayout.backdropRamp))
        .allowsHitTesting(false)
    }
}

/// Скелетон ряда чипсов — капсулы на месте чипсов, пока варианты едут: ряд держит
/// своё место, и список под ним не прыгает, когда чипсы появляются.
struct FilterChipsSkeleton: View {
    var count = 2
    var chipWidth: CGFloat = EntitySectionLayout.skeletonHeaderWidth

    var body: some View {
        HStack(spacing: FilterChipsLayout.gap) {
            ForEach(0..<count, id: \.self) { _ in
                Capsule()
                    .fill(PlusSkeleton.fill)
                    .frame(width: chipWidth, height: FilterChipsLayout.chipHeight)
            }
        }
        .padding(.horizontal, FilterChipsLayout.side)
        .padding(.vertical, FilterChipsLayout.vertical)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }
}
