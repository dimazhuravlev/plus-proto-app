import SwiftUI

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
/// коллекции «Моё» (2026-10-04): лента вбок, выбранный чипс доезжает в центр,
/// фиолетовая капсула переезжает за выбором пружиной навигации витрин, тап — хаптик
/// таббара. Ведёт себя как верхняя навигация витрин (`ServiceTopNav`).
struct FilterChipsRow<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String

    /// Фиолетовая капсула активного чипса переезжает с чипса на чипс.
    @Namespace private var pill

    /// Сколько ждать раскладки ленты, прежде чем ставить стартовый чипс в центр.
    private static var layoutDelay: Duration { .milliseconds(50) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: FilterChipsLayout.gap) {
                    ForEach(options, id: \.self) { option in
                        FilterChip(title: title(option), isActive: option == selection, pill: pill) {
                            select(option)
                        }
                        .id(option)
                    }
                }
                .padding(.horizontal, FilterChipsLayout.side)
                .padding(.vertical, FilterChipsLayout.vertical)
            }
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
            // раскладки, и выбранный чипс торчал из-за края (кадры 2026-10-04).
            .task {
                guard selection != options.first else { return }
                try? await Task.sleep(for: Self.layoutDelay)
                guard !Task.isCancelled else { return }
                var instant = Transaction()
                instant.disablesAnimations = true
                withTransaction(instant) { proxy.scrollTo(selection, anchor: .center) }
            }
        }
    }

    /// Тап по чипсу — как по табу навигации витрин: хаптик таббара, капсула переезжает
    /// той же пружиной (правка пользователя 2026-10-04).
    private func select(_ option: Option) {
        guard option != selection else { return }
        TabBarMotion.tapHaptic()
        withAnimation(ServiceTopNavMotion.select) { selection = option }
    }
}

/// Чипс фильтра — `chips-row` макета: 15/20 Semibold, поля 16 × 10, капсула.
/// Активный — фиолетовый с подсветкой снизу, остальные — заливка кнопок. Внутри обоих —
/// размытие фона, как у пилюли навигации витрин (правка пользователя 2026-10-04).
private struct FilterChip: View {
    let title: String
    let isActive: Bool
    /// Общий у ряда: фиолетовая капсула переезжает с чипса на чипс.
    let pill: Namespace.ID
    let action: () -> Void

    /// Фиолетовый активного чипса — #A332FF макета, общий с лейблом тайтла.
    private static let accent = Color.moviesAccent

    var body: some View {
        Button(action: action) {
            Text(title)
                .plusText(.textM, .semibold)
                .foregroundStyle(isActive ? Color.fillOne : Color.fillFour)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                // Фиолетовая капсула — над стеклом, под текстом. Переезжает на выбранный
                // чипс, как пилюля навигации витрин (`ServiceTopNav`); общей обрезки
                // у чипса нет — иначе в пути её срезало бы по его кромке.
                .background {
                    if isActive {
                        activeFill
                            .matchedGeometryEffect(id: "activeChip", in: pill)
                    }
                }
                .background {
                    ZStack {
                        BackdropBlurView(radius: ServiceTopNavLayout.pillBlur)
                        Color.buttonsSecondary.opacity(isActive ? 0 : 1)
                    }
                    .clipShape(Capsule())
                }
                .overlay {
                    Capsule().strokeBorder(
                        Color.white.opacity(isActive ? 0.3 : 0.15),
                        lineWidth: PlusMetrics.hairline
                    )
                }
                .contentShape(Capsule())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    /// Заливка активного: фиолетовый 50 % с внутренней тенью и подсветкой снизу.
    private var activeFill: some View {
        ZStack {
            Capsule().fill(
                Self.accent.opacity(0.5)
                    .shadow(.inner(color: Self.accent.opacity(0.5), radius: 1, y: 1))
            )
            // Подсветка снизу — эллипс макета: центр под нижней кромкой
            // (0.505 ширины, 1.15 высоты), радиусы 0.696 ширины и 0.8875 высоты.
            GeometryReader { proxy in
                let size = proxy.size
                let center = UnitPoint(x: 0.505, y: 1.15)
                RadialGradient(
                    colors: [Self.accent.opacity(0.4), Self.accent.opacity(0)],
                    center: center,
                    startRadius: 0,
                    endRadius: 0.8875 * size.height
                )
                .scaleEffect(
                    x: (0.696 * size.width) / max(0.8875 * size.height, 1),
                    y: 1,
                    anchor: center
                )
            }
        }
        .clipShape(Capsule())
    }
}
