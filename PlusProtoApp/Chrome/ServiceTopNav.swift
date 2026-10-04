import SwiftUI
import UIKit
import VariableBlur

/// Числа верхней навигации — макет `2455:75953` (главная Кинопоиска).
enum ServiceTopNavLayout {
    /// Ряд под статус-баром: табы 40 и аватар 48 по центру
    static let rowHeight: CGFloat = 56

    /// Верхняя безопасная зона — витрине «Моей волны» вертикаль макета отмеряется
    /// от низа навигации, а лента у неё начинается от физического верха экрана.
    static var topSafeArea: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top ?? 0
    }
    static let side: CGFloat = 16
    static let tabHeight: CGFloat = 40
    static let tabPadding: CGFloat = 10
    /// Затухание ленты табов перед аватаром — под ним табы и уходят
    static let avatarFade: CGFloat = 32

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
    /// Лента табов: с этого хода палец её тянет (меньше — это тап по табу), отпущенная
    /// доезжает по инерции, за краями тянется вполсилы
    static let dragThreshold: CGFloat = 8
    static let stripSettle: Animation = .smooth(duration: 0.45)
    static let rubber: CGFloat = 0.35
    /// Оттяг ленты вниз: ряд навигации едет за ним вчетверо медленнее и упирается
    /// в мягкий потолок — отступ над баром тянется, но заметно меньше ленты (правки
    /// пользователя 2026-10-04: сначала 0.4 без потолка — «слишком далеко уходит»)
    static let pullFollow: CGFloat = 0.25
    static let pullLimit: CGFloat = 24

    /// Сдвиг ряда за оттягом ленты: четверть хода с мягким потолком — дальше ряд
    /// почти стоит. Общий с чипсами полной выдачи поиска (`SearchSectionView`).
    static func pullShift(for scrollOffset: CGFloat) -> CGFloat {
        let raw = max(0, -scrollOffset) * pullFollow
        return raw / (1 + raw / pullLimit)
    }
}

/// Верхняя навигация сервисного таба — табы-фильтры слева, аватар справа (макет
/// `2455:75953`). Общая: главная Кинопоиска — первая, дальше «Музыка» и «Книги»
/// со своими фильтрами (задача пользователя 2026-10-04).
///
/// Стоит поверх ленты и не уезжает с ней. Под ней — прогрессивный блюр без
/// затемнения, он проявляется по скроллу ленты.
struct ServiceTopNav: View {
    let filters: [String]
    @Binding var selection: Int
    /// Сколько ленты ушло под бар — от этого прозрачность подложки.
    var scrollOffset: CGFloat = 0
    /// Аватар профиля — из макета навигации (`userpics` `2455:75985`), кадр 40pt на ×3.
    var avatar: ArtworkSource = .asset("avatarProfile")

    @Namespace private var pill

    var body: some View {
        HStack(spacing: 0) {
            tabs
            avatarView
                .padding(.trailing, ServiceTopNavLayout.side)
        }
        .frame(height: ServiceTopNavLayout.rowHeight)
        // Сдвиг — только у ряда: подложка стоит на месте, а она в покое прозрачна.
        .offset(y: ServiceTopNavMotion.pullShift(for: scrollOffset))
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            // Только прогрессивный блюр, без затемнения: тёмный градиент подложки
            // навбаров сущностей проявлялся на начале скролла и был лишним (правка
            // пользователя 2026-10-04) — как у скрима витрины «Плюс».
            VariableBlurView(
                maxBlurRadius: EntityNavBarGeometry.backdropBlurRadius,
                direction: .blurredTopClearBottom
            )
            .frame(height: EntityNavBarGeometry.backdropHeight)
            .allowsHitTesting(false)
            .opacity(NavBarRamp.progress(scrollOffset, start: 0, length: ServiceTopNavMotion.backdropRamp))
            // Подложка — чистая функция скролла: анимация выбора таба её не касается.
            // Иначе смена таба уносила её прозрачность в пружину 0.3 с — фон проявлялся
            // и гас на глазах, пока лента нового таба докладывала свой сдвиг (жалоба
            // пользователя 2026-10-04: «моргает при переключении Любимое — Скачанное»).
            .transaction { $0.animation = nil }
            .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: Табы

    /// Табы — лента до самого аватара: не влезли — листаются пальцем и уходят под маску
    /// перед ним (правка пользователя 2026-10-04: у Музыки четыре таба). Слева, когда
    /// ленту сдвинули, — такое же затухание; в покое оно лежит на поле и пилюлю не трогает.
    ///
    /// **Без `ScrollView`.** Горизонтальный скролл у верхней кромки безопасной зоны
    /// растягивался в неё: в первом прогоне табы встали поверх статус-бара, а с маской
    /// и явной высотой исчезали вовсе — содержимое рисовалось выше своей рамки. Поэтому
    /// лента — ряд со сдвигом за пальцем: с инерцией, резиновыми краями и выездом
    /// выбранного таба из-под маски.
    private var tabs: some View {
        Color.clear
            .frame(height: ServiceTopNavLayout.tabHeight)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .leading) {
                HStack(spacing: 0) {
                    ForEach(filters.indices, id: \.self) { index in
                        tab(index)
                            .onGeometryChange(for: CGRect.self) { proxy in
                                proxy.frame(in: .named(Self.stripSpace))
                            } action: { frame in
                                tabFrames[index] = frame
                            }
                    }
                }
                .fixedSize()
                .padding(.leading, ServiceTopNavLayout.side)
                .padding(.trailing, ServiceTopNavLayout.avatarFade)
                .coordinateSpace(name: Self.stripSpace)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { stripWidth = $0 }
                .offset(x: stripOffset)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { visibleWidth = $0 }
            .mask {
                HStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                        .frame(width: ServiceTopNavLayout.side)
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: ServiceTopNavLayout.avatarFade)
                }
            }
            .contentShape(.rect)
            // Одновременно с кнопками табов: обычный жест на родителе кнопки перебивали —
            // палец, попавший на таб, ленту не тянул (жалоба пользователя 2026-10-04).
            .simultaneousGesture(stripDrag)
            .onChange(of: selection) { _, index in
                reveal(index)
            }
    }

    private static let stripSpace = "serviceTopNavStrip"

    /// Сдвиг ленты: 0 — в покое, отрицательный — пролистана влево.
    @State private var stripOffset: CGFloat = 0
    @State private var dragStart: CGFloat?
    @State private var stripWidth: CGFloat = 0
    @State private var visibleWidth: CGFloat = 0
    @State private var tabFrames: [Int: CGRect] = [:]
    /// Ленту тянули — отпускание пальца на табе его не выбирает.
    @State private var isDraggingStrip = false

    /// Дальше этого лента не уходит: последний таб встаёт у маски.
    private var minOffset: CGFloat {
        min(0, visibleWidth - stripWidth)
    }

    private var stripDrag: some Gesture {
        DragGesture(minimumDistance: ServiceTopNavMotion.dragThreshold)
            .onChanged { value in
                guard minOffset < 0 else { return }
                isDraggingStrip = true
                let start = dragStart ?? stripOffset
                dragStart = start
                stripOffset = rubberBand(start + value.translation.width)
            }
            .onEnded { value in
                // Сброс — следующим тактом: тап кнопки приходит тем же отпусканием,
                // и он должен застать отметку перетаскивания.
                DispatchQueue.main.async { isDraggingStrip = false }
                guard let start = dragStart else { return }
                dragStart = nil
                let target = min(0, max(minOffset, start + value.predictedEndTranslation.width))
                withAnimation(ServiceTopNavMotion.stripSettle) { stripOffset = target }
            }
    }

    /// За краями лента тянется вполсилы — резина, а не стена.
    private func rubberBand(_ offset: CGFloat) -> CGFloat {
        if offset > 0 { return offset * ServiceTopNavMotion.rubber }
        if offset < minOffset { return minOffset + (offset - minOffset) * ServiceTopNavMotion.rubber }
        return offset
    }

    /// Выбранный таб, ушедший под маску или за левый край, выезжает на место.
    private func reveal(_ index: Int) {
        guard let frame = tabFrames[index], minOffset < 0 else { return }
        let left = frame.minX + stripOffset
        let right = frame.maxX + stripOffset
        var target = stripOffset
        if right > visibleWidth - ServiceTopNavLayout.avatarFade {
            target -= right - (visibleWidth - ServiceTopNavLayout.avatarFade)
        } else if left < ServiceTopNavLayout.side {
            target += ServiceTopNavLayout.side - left
        }
        target = min(0, max(minOffset, target))
        guard target != stripOffset else { return }
        withAnimation(ServiceTopNavMotion.select) { stripOffset = target }
    }

    private func tab(_ index: Int) -> some View {
        let isActive = index == selection
        return Button {
            guard !isActive, !isDraggingStrip else { return }
            TabBarMotion.tapHaptic()
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
