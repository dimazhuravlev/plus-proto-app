import SwiftUI
import UIKit

/// Числа верхней навигации — макет `2455:75953` (главная Кинопоиска).
enum ServiceTopNavLayout {
    /// Ряд под статус-баром: табы 40 и аватар 48 по центру
    static let rowHeight: CGFloat = 56
    static let side: CGFloat = 16
    static let tabHeight: CGFloat = 40
    static let tabPadding: CGFloat = 10

    /// Активный таб — стеклянная пилюля: фиолетовая заливка 50 %, розовое свечение
    /// снизу, бордер white 30 % и светлая внутренняя кромка сверху.
    static let pillFill = Color(red: 92 / 255, green: 40 / 255, blue: 177 / 255).opacity(0.5)
    static let pillGlow = Color(red: 241 / 255, green: 175 / 255, blue: 224 / 255).opacity(0.3)
    /// Свечение — эллипс от нижней кромки: полуширина пилюли по горизонтали,
    /// 74 % её высоты по вертикали (матрица градиента макета: 34.2 × 29.5 на 69 × 40).
    static let pillGlowHeightShare: CGFloat = 29.5 / 40
    static let pillBorder = Color.white.opacity(0.3)
    static let pillBorderWidth: CGFloat = 0.67
    static let pillHighlight = Color.white.opacity(0.2)
    static let pillBlur: CGFloat = 20
    /// Текст активного таба — градиент сверху вниз: сиреневый 90 % → белый 80 %
    static let activeText = LinearGradient(
        colors: [
            Color(red: 229 / 255, green: 179 / 255, blue: 253 / 255).opacity(0.9),
            Color.white.opacity(0.8),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let avatarFrame: CGFloat = 48
    static let avatarSize: CGFloat = 40
    static let auraWidth: CGFloat = 2
    /// Ореол аватара — кольцо 2pt сверху вниз: фиолетовый → розовый (`aura` макета)
    static let aura = LinearGradient(
        stops: [
            .init(color: Color(red: 0x5C / 255, green: 0x28 / 255, blue: 0xB1 / 255), location: 0),
            .init(color: Color(red: 0x92 / 255, green: 0x27 / 255, blue: 0xD5 / 255), location: 0.2577),
            .init(color: Color(red: 0xE6 / 255, green: 0x68 / 255, blue: 0xE5 / 255), location: 0.61),
            .init(color: Color(red: 0xF4 / 255, green: 0xBB / 255, blue: 0xE5 / 255), location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

enum ServiceTopNavMotion {
    /// Пилюля переезжает на выбранный таб — короткой пружиной без отскока.
    static let select: Animation = .smooth(duration: 0.3)
    /// Подложка проявляется, как только лента заезжает под бар: в покое под ним
    /// чёрный фон, и затемнять там нечего.
    static let backdropRamp: CGFloat = 24
}

/// Верхняя навигация сервисного таба — табы-фильтры слева, аватар справа (макет
/// `2455:75953`). Общая: главная Кинопоиска — первая, дальше «Музыка» и «Книги»
/// со своими фильтрами (задача пользователя 2026-10-04).
///
/// Стоит поверх ленты и не уезжает с ней. Под ней — та же подложка, что у навбаров
/// экранов сущностей (`NavBarBackdrop`: затемнение и прогрессивный блюр), она
/// проявляется по скроллу ленты.
struct ServiceTopNav: View {
    let filters: [String]
    @Binding var selection: Int
    /// Сколько ленты ушло под бар — от этого прозрачность подложки.
    var scrollOffset: CGFloat = 0
    var avatar: ArtworkSource = .asset("mockAvatar")

    @Namespace private var pill

    var body: some View {
        HStack(spacing: 0) {
            tabs
            avatarView
                .padding(.horizontal, ServiceTopNavLayout.side)
        }
        .frame(height: ServiceTopNavLayout.rowHeight)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            NavBarBackdrop()
                .opacity(NavBarRamp.progress(scrollOffset, start: 0, length: ServiceTopNavMotion.backdropRamp))
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: Табы

    /// Табы — ряд без прокрутки: у сервисов их два-три, и они влезают с запасом
    /// (до аватара ~320pt). Горизонтальный `ScrollView` здесь не годится: у верхней
    /// кромки безопасной зоны он растягивается в неё и рисует табы поверх статус-бара
    /// (первый прогон 2026-10-04).
    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(filters.indices, id: \.self) { index in
                tab(index)
            }
        }
        .padding(.leading, ServiceTopNavLayout.side)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tab(_ index: Int) -> some View {
        let isActive = index == selection
        return Button {
            guard !isActive else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(ServiceTopNavMotion.select) { selection = index }
        } label: {
            ZStack {
                // Два слоя текста, а не смена заливки: градиент и белый друг в друга
                // не анимируются, а прозрачность — да.
                Text(filters[index])
                    .plusHeadline(.s)
                    .foregroundStyle(Color.fillOne)
                    .opacity(isActive ? 0 : 1)
                Text(filters[index])
                    .plusHeadline(.s)
                    .foregroundStyle(ServiceTopNavLayout.activeText)
                    .opacity(isActive ? 1 : 0)
            }
            .fixedSize()
            .padding(.horizontal, ServiceTopNavLayout.tabPadding)
            .frame(height: ServiceTopNavLayout.tabHeight)
            .background {
                if isActive {
                    ActiveTabPill()
                        .matchedGeometryEffect(id: "pill", in: pill)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    // MARK: Аватар

    private var avatarView: some View {
        ZStack {
            Circle()
                .strokeBorder(ServiceTopNavLayout.aura, lineWidth: ServiceTopNavLayout.auraWidth)
            ArtworkImage(source: avatar)
                .scaledToFill()
                .frame(width: ServiceTopNavLayout.avatarSize, height: ServiceTopNavLayout.avatarSize)
                .clipShape(Circle())
                .overlay { Circle().strokeBorder(Color.fillNine, lineWidth: PlusMetrics.hairline) }
        }
        .frame(width: ServiceTopNavLayout.avatarFrame, height: ServiceTopNavLayout.avatarFrame)
        .accessibilityLabel("Профиль")
    }
}

/// Стеклянная пилюля активного таба.
private struct ActiveTabPill: View {
    var body: some View {
        let shape = Capsule(style: .continuous)
        Color.clear
            .overlay {
                // Свечение — эллипс от нижней кромки: ширина пилюли его и задаёт.
                GeometryReader { proxy in
                    let rx = proxy.size.width / 2
                    let ry = proxy.size.height * ServiceTopNavLayout.pillGlowHeightShare
                    RadialGradient(
                        colors: [ServiceTopNavLayout.pillGlow, ServiceTopNavLayout.pillGlow.opacity(0)],
                        center: .bottom,
                        startRadius: 0,
                        endRadius: rx
                    )
                    .scaleEffect(x: 1, y: ry / max(rx, 1), anchor: .bottom)
                }
            }
            .glassSurface(
                shape,
                blur: ServiceTopNavLayout.pillBlur,
                fill: ServiceTopNavLayout.pillFill,
                border: ServiceTopNavLayout.pillBorder,
                borderWidth: ServiceTopNavLayout.pillBorderWidth
            )
            // Внутренняя светлая кромка сверху — `inset 0 1 2 white 20%`.
            .overlay {
                shape
                    .stroke(ServiceTopNavLayout.pillHighlight, lineWidth: 2)
                    .offset(y: 1)
                    .blur(radius: 1)
                    .mask(shape)
            }
            .clipShape(shape)
    }
}
