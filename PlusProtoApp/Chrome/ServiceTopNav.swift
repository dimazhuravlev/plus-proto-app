import SwiftUI
import UIKit
import VariableBlur

/// Числа верхней навигации — макет `2455:75953` (главная Кинопоиска).
enum ServiceTopNavLayout {
    /// Затемнение сверху (тест 2026-10-10): высота от физического верха, пик и путь
    /// скролла, за который оно проявляется от нуля до пика.
    static let topShadeHeight: CGFloat = 100
    static let topShadePeak: Double = 0.5
    static let topShadeRamp: CGFloat = 300
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
    static let pillBorder = Color.fillSeven
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

    /// Кнопка-аксессуар справа от табов — «Моё», `. / top navigation / buttons`
    /// `17778:34241` файла «ЯПС · Mobile · Current State»: `PlusButton` plain M — круг 40
    /// в раскладке целиком, иконка 20 по центру, до кадра аватара 8 (прежний макет
    /// `2584:26578` ставил голую иконку 20 с полями 2 и 12 — иконка стояла на 6 правее).
    /// Лента табов заходит под пустое поле кнопки на 14, как в макете (табы — до x 277,
    /// кнопка — с 263 на кадре 375): ширина ленты та же, что при голой иконке, и
    /// «Скачанное» не уходит в затухание. Кнопка лежит выше ленты — тап по полю её.
    static let accessoryLeading: CGFloat = -14
    static let accessoryTrailing: CGFloat = 8

    static let avatarFrame: CGFloat = 48
    static let avatarSize: CGFloat = 40
    static let auraWidth: CGFloat = 2
    /// Ореол аватара — кольцо 2pt внутрь, градиент слева направо: коралловый → малиновый →
    /// фиолетовый → синий (`aura` навигации «Моего» `17778:34241`, обводка ноды — 2026-10-21;
    /// экспорт SVG ноды отдавал прежний вертикальный фиолетово-розовый).
    static let aura = LinearGradient(
        stops: [
            .init(color: Color(red: 0xFF / 255, green: 0x5C / 255, blue: 0x4D / 255), location: 0),
            .init(color: Color(red: 0xEB / 255, green: 0x46 / 255, blue: 0x9F / 255), location: 0.2656),
            .init(color: Color(red: 0x83 / 255, green: 0x41 / 255, blue: 0xEF / 255), location: 0.75),
            .init(color: Color(red: 0x3F / 255, green: 0x68 / 255, blue: 0xF9 / 255), location: 1),
        ],
        startPoint: .leading,
        endPoint: .trailing
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
    /// Подложка, которую держит блок в руке («Моё»): входит и выходит плавно.
    static let backdropHold: Animation = .easeInOut(duration: 0.2)
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
    /// Затемнение сверху по скроллу — у витрин; у «Моей волны» и «Моего» его нет.
    var showsTopShade = true
    /// Подложка (прогрессивный блюр) держится полностью независимо от скролла — «Моё»,
    /// пока блок в руке: он поднимается под навбар, а лента при этом стоит у верха, где
    /// подложки по скроллу нет. Вход и выход — плавно; сам скролл по-прежнему без анимации.
    var holdsBackdrop = false
    /// Аватар профиля — из макета навигации (`userpics` `2455:75985`), кадр 40pt на ×3.
    var avatar: ArtworkSource = .asset(ProfileMock.avatar)
    /// Кнопка между табами и аватаром (plain M 40, макет «Моего» `17778:34241`):
    /// у остальных экранов её нет и раскладка прежняя.
    var trailingAccessory: AnyView? = nil

    var body: some View {
        HStack(spacing: 0) {
            TopNavTabStrip(titles: filters, selection: $selection)
            if let trailingAccessory {
                trailingAccessory
                    .padding(.leading, ServiceTopNavLayout.accessoryLeading)
                    .padding(.trailing, ServiceTopNavLayout.accessoryTrailing)
                    // Над аватаром: подсказка под кнопкой «Моего» заходит на низ его кадра.
                    .zIndex(1)
            }
            ProfileAvatarButton(avatar: avatar)
                .padding(.trailing, ServiceTopNavLayout.side)
        }
        .modifier(TopNavRow(scrollOffset: scrollOffset, showsTopShade: showsTopShade, holdsBackdrop: holdsBackdrop))
    }
}

// MARK: - Лента табов

/// Табы-фильтры навигации — текстом Headline S, выбранный в стеклянной пилюле, которая
/// переезжает с таба на таб. Общая у навигации витрин (`ServiceTopNav`) и табов первого
/// уровня выдачи поиска (`SearchMosaicView`, макеты 2026-10-31).
struct TopNavTabStrip: View {
    let titles: [String]
    @Binding var selection: Int
    /// Затухание ленты справа: перед аватаром витрин — 32, без аватара (поиск) — поле экрана.
    var trailingFade: CGFloat = ServiceTopNavLayout.avatarFade

    @Namespace private var pill

    var body: some View {
        tabs
    }

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
                    ForEach(titles.indices, id: \.self) { index in
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
                .padding(.trailing, trailingFade)
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
                        .frame(width: trailingFade)
                }
            }
            .contentShape(.rect)
            // Одновременно с кнопками табов: обычный жест на родителе кнопки перебивали —
            // палец, попавший на таб, ленту не тянул (жалоба пользователя 2026-10-04).
            // Влезли целиком — жеста нет: в ленте выдачи поиска он забирал бы палец
            // у вертикального скролла.
            .simultaneousGesture(stripDrag, including: minOffset < 0 ? .all : .subviews)
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
        if right > visibleWidth - trailingFade {
            target -= right - (visibleWidth - trailingFade)
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
                Text(titles[index])
                    .plusHeadline(.s)
                    .foregroundStyle(Color.fillOne)
                    .opacity(isActive ? 0 : 1)
                Text(titles[index])
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

}

// MARK: - Общее у навигаций витрин

/// Ряд навигации витрины под статус-баром: высота 56, оттяг ленты тянет ряд вчетверо
/// медленнее, под ним — прогрессивный блюр, проявляется по скроллу. Один у сервисных
/// табов и «Главной» — аватар у всех встаёт в одну точку.
struct TopNavRow: ViewModifier {
    let scrollOffset: CGFloat
    var showsTopShade = true
    /// Подложка держится на полной силе поверх скролла (`ServiceTopNav.holdsBackdrop`).
    var holdsBackdrop = false

    func body(content: Content) -> some View {
        content
            .frame(height: ServiceTopNavLayout.rowHeight)
            // Сдвиг — только у ряда: подложка стоит на месте, а она в покое прозрачна.
            .offset(y: ServiceTopNavMotion.pullShift(for: scrollOffset))
            .frame(maxWidth: .infinity)
            .background(alignment: .top) {
                // Только прогрессивный блюр, без затемнения: тёмный градиент подложки
                // навбаров сущностей проявлялся на начале скролла и был лишним (правка
                // пользователя 2026-10-04).
                VariableBlurView(
                    maxBlurRadius: EntityNavBarGeometry.backdropBlurRadius,
                    direction: .blurredTopClearBottom
                )
                .frame(height: EntityNavBarGeometry.backdropHeight)
                .allowsHitTesting(false)
                .modifier(NavBackdropOpacity(
                    scroll: NavBarRamp.progress(scrollOffset, start: 0, length: ServiceTopNavMotion.backdropRamp),
                    hold: holdsBackdrop ? 1 : 0
                ))
                // Анимируется только «держим ↔ нет»: изменение `hold` приходит с этой кривой
                // и проходит под внешним `transaction` ниже, а скролл анимации не получает.
                .animation(ServiceTopNavMotion.backdropHold, value: holdsBackdrop)
                // Подложка — чистая функция скролла: анимация выбора таба её не касается.
                // Иначе смена таба уносила её прозрачность в пружину 0.3 с — фон проявлялся
                // и гас на глазах, пока лента нового таба докладывала свой сдвиг (жалоба
                // пользователя 2026-10-04: «моргает при переключении Любимое — Скачанное»).
                .transaction { $0.animation = nil }
                .ignoresSafeArea(edges: .top)
            }
            // Затемнение сверху — как под таббаром, только перевёрнутое (тест, правки
            // пользователя 2026-10-10): 100 от физического верха, пик 50 %, те же 16 стопов.
            // В покое его нет, проявляется по скроллу к 300 — плавно, smoothstep. Только
            // на витринах: у «Моей волны» и «Моего» выключено (`showsTopShade`).
            .background(alignment: .top) {
                PlusGradient.bottomUnderlay(peak: ServiceTopNavLayout.topShadePeak)
                    .scaleEffect(y: -1)
                    .frame(height: ServiceTopNavLayout.topShadeHeight)
                    .opacity(showsTopShade
                        ? NavBarRamp.progress(scrollOffset, start: 0, length: ServiceTopNavLayout.topShadeRamp)
                        : 0)
                    .allowsHitTesting(false)
                    // Чистая функция скролла — анимация выбора таба её не касается.
                    .transaction { $0.animation = nil }
                    .ignoresSafeArea(edges: .top)
            }
    }
}

/// Прозрачность подложки навбара: большее из скролла (чистая функция, без анимации) и
/// удержания (анимируется — `animatableData`). Один `opacity`, а не два слоя блюра.
private struct NavBackdropOpacity: ViewModifier, Animatable {
    let scroll: Double
    var hold: Double

    var animatableData: Double {
        get { hold }
        set { hold = newValue }
    }

    func body(content: Content) -> some View {
        content.opacity(max(scroll, hold))
    }
}

/// Аватар — вход в профиль: пуш в стек таба, справа налево (`AppNavigationState.openProfile`).
/// Кольцо-ореол 2pt и фото 40 в кадре 48.
struct ProfileAvatarButton: View {
    var avatar: ArtworkSource = .asset(ProfileMock.avatar)

    @Environment(AppNavigationState.self) private var navigation

    var body: some View {
        Button { navigation.openProfile() } label: {
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
            .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Профиль")
    }
}

/// Навигация «Главной» — мультивитрины (макет `2532:26495`, задача пользователя
/// 2026-10-08): логотип «Яндекс Плюс» слева, справа голова Люмена и аватар. Ряд —
/// тот же, что у сервисных табов (`TopNavRow`): аватар стоит ровно там же.
struct HomeTopNav: View {
    var scrollOffset: CGFloat = 0
    /// «Люмен в поиске» (дебаг-меню): голова уходит в поле поиска, аватар остаётся на месте.
    @AppStorage(LumenDebug.inSearchKey) private var lumenInSearch = false
    var openDevMenu: () -> Void = {}

    private enum Layout {
        /// Логотип — 161.52 × 24 (`.header-logo`)
        static let logo = CGSize(width: 161.52, height: 24)
        /// Голова Люмена — живое видео 72×72 вплотную к рамке аватара, по центру ряда
        /// (макет `2768:36304`: кадр видео в группе `right` с аватаром, 2026-10-16).
        /// Голова внутри кадра меньше: вокруг — прозрачное поле ролика.
        static let lumenVideo: CGFloat = 72
        /// Высота места в ряду — как у аватара: кадр видео выходит за ряд поровну
        /// сверху и снизу и раскладку ряда не меняет.
        static let lumenSlotHeight: CGFloat = 48
    }

    var body: some View {
        HStack(spacing: 0) {
            Image("logoYandexPlus")
                .resizable()
                .frame(width: Layout.logo.width, height: Layout.logo.height)
                .accessibilityLabel("Яндекс Плюс")
                .padding(.leading, ServiceTopNavLayout.side)
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                // Видео не принимает касания; явная область нажатия покрывает весь слот.
                // Тап открывает локальное девменю.
                if !lumenInSearch {
                    HomeDevMenuEntry(action: openDevMenu) {
                        Color.clear
                        .frame(width: Layout.lumenVideo, height: Layout.lumenSlotHeight)
                        .overlay {
                            LumenHeadVideo()
                                .frame(width: Layout.lumenVideo, height: Layout.lumenVideo)
                        }
                        .contentShape(Rectangle())
                    }
                }
                ProfileAvatarButton()
            }
            .padding(.trailing, ServiceTopNavLayout.side)
        }
        .modifier(TopNavRow(scrollOffset: scrollOffset))
    }
}

/// Стеклянная пилюля активного таба. Она же — активный чипс второго уровня
/// (`FilterChip`, макет `19151:18648`, правка пользователя 2026-10-31), но без светлой
/// кромки сверху: в чипсах её нет.
struct ActiveTabPill: View {
    var showsHighlight = true

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
                if showsHighlight {
                    shape
                        .stroke(ServiceTopNavLayout.pillHighlight, lineWidth: 2)
                        .offset(y: 1)
                        .blur(radius: 1)
                        .mask(shape)
                }
            }
            .clipShape(shape)
    }
}
