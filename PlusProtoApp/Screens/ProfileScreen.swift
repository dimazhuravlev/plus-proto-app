import SwiftUI
import VariableBlur

/// Числа экрана профиля — макет `2463:78551`. Кадр макета 375: поля и размеры
/// перенесены как есть, виджеты тянутся по ширине (квадраты подписки и баллов,
/// семейная группа — в пропорции макета 343 × 167).
enum ProfileLayout {
    static let side: CGFloat = 16
    /// Шапка: ряд 56 под статус-баром — аватар 40, имя и «Редактировать», крестик 40
    static let headerRow: CGFloat = 56
    static let avatar: CGFloat = 40
    static let avatarToName: CGFloat = 8
    static let nameGap: CGFloat = 2
    static let closeButton: CGFloat = 40
    static let closeIcon: CGFloat = 20
    static let closeBlur: CGFloat = 17
    /// Подложка шапки проявляется по скроллу за 24 и сходит на нет на 24 ниже ряда
    static let headerRamp: CGFloat = 24
    static let headerTail: CGFloat = 24

    /// «Вы в Яндекс Плюсе» — поля 16 сверху и 12 снизу
    static let titleTop: CGFloat = 16
    static let titleBottom: CGFloat = 12

    /// Виджеты — стекло: белый 8 %, бордер 0.67 × белый 15 %, блюр 20, скругление 16
    static let widgetGap: CGFloat = 8
    static let widgetRadius: CGFloat = 16
    static let widgetPadding: CGFloat = 12
    static let widgetBlur: CGFloat = 20
    static let widgetBorder = Color.white.opacity(0.15)
    static let borderWidth: CGFloat = 0.67
    static let textGap: CGFloat = 4
    static let pointsIcon: CGFloat = 18
    /// Блок виджетов заканчивается полем 16, промо стоит в рамке с полями 16
    static let widgetsBottom: CGFloat = 16

    /// Семейная группа: колонки 60 / 40 с зазором 8, справа аватарки 2 × 2 через 4
    static let familyAspect: CGFloat = 343 / 167
    static let familyAvatarsShare: CGFloat = 0.4
    static let familyAvatarGap: CGFloat = 4
    static let addIcon: CGFloat = 24

    /// Промо «Плюс близким»: высота 170, картинка 300 справа, текст 200 слева
    static let promoHeight: CGFloat = 170
    static let promoImageWidth: CGFloat = 300
    static let promoTextWidth: CGFloat = 200
    /// Текст и кнопка — 16 от края карточки, то есть 15.33 внутри бордера
    static let promoInset: CGFloat = 16 - borderWidth

    /// Кнопки виджетов — капсула 32: поля 16 × 8, Text S Semibold
    static let pillHorizontal: CGFloat = 16
    static let pillVertical: CGFloat = 8

    /// Ячейки меню — островки: белый 8 %, скругление 16, поля 4 сверху и снизу;
    /// строка — иконка 24, Text M, шеврон 16, поля 16 × 14, между островками 8
    static let cellsVertical: CGFloat = 16
    static let islandGap: CGFloat = 8
    static let islandRadius: CGFloat = 16
    static let islandPadding: CGFloat = 4
    static let cellHorizontal: CGFloat = 16
    static let cellVertical: CGFloat = 14
    static let cellGap: CGFloat = 12
    static let cellIcon: CGFloat = 24
    static let chevron: CGFloat = 16
    /// Разделитель ячеек — 0.5 × белый 15 %, от 16 слева до правого края островка
    static let divider = Color.white.opacity(0.15)
    static let dividerInset: CGFloat = 16
    /// Шеврон и плюс «добавить» — белый 40 %
    static let secondaryGlyph = Color.white.opacity(0.4)

    static let bottomPadding: CGFloat = 24
}

/// Экран профиля (макет `2463:78551`, задача пользователя 2026-10-04): открывается
/// с аватарки в навигации витрин, снизу вверх, поверх всего — таббара и бара в макете
/// нет. Сверху — свечение Плюса и шапка: аватар, имя, «Редактировать», крестик. Ниже —
/// «Вы в Яндекс Плюсе» с виджетами подписки, баллов и семейной группы, промо «Плюс
/// близким» и островки ячеек. Данные — из макета: профиль в прототипе моковый.
struct ProfileScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scrollOffset: CGFloat = 0
    @State private var isDebugMenuShown = false

    var body: some View {
        // Стек — ради дебаг-меню: оно пушится из ячейки и уходит назад к профилю.
        // `dismiss` взят снаружи стека — крестик закрывает весь профиль.
        NavigationStack {
            profile
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: $isDebugMenuShown) {
                    DebugMenuScreen()
                }
        }
        .preferredColorScheme(.dark)
    }

    private var profile: some View {
        ZStack(alignment: .top) {
            // Свечение — от верха экрана, уезжает вместе с лентой; при оттяге стоит.
            // Оверлеем на фоне, а не слоем стопки: кадр 600 шире экрана, и слоем
            // он раздвигал всю стопку — лента вставала шириной 600 (кадр 2026-10-04).
            Color.black
                .overlay(alignment: .top) {
                    ProfileGlow()
                        .offset(y: -max(0, scrollOffset))
                        .allowsHitTesting(false)
                }
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    plusSection
                    ProfilePromo()
                        .padding(ProfileLayout.side)
                    cells
                }
                .padding(.top, ProfileLayout.headerRow)
                .padding(.bottom, ProfileLayout.bottomPadding)
            }
            .scrollIndicators(.hidden)
            .trackNavBarScroll(into: $scrollOffset)
        }
        .overlay(alignment: .top) { header }
    }

    // MARK: Шапка

    /// Аватар, имя и «Редактировать», справа крестик. Подложка — прогрессивный блюр
    /// без затемнения, как у навигации витрин: проявляется, когда лента уходит под шапку.
    private var header: some View {
        HStack(spacing: ProfileLayout.avatarToName) {
            Image(ProfileMock.avatar)
                .resizable()
                .scaledToFill()
                .frame(width: ProfileLayout.avatar, height: ProfileLayout.avatar)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: ProfileLayout.nameGap) {
                Text(ProfileMock.name)
                    .plusHeadline(.m)
                    .foregroundStyle(Color.fillOne)
                Text("Редактировать")
                    .plusText(.textS, .medium)
                    .foregroundStyle(Color.fillSubtitle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button { dismiss() } label: {
                Image("iconCross")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: ProfileLayout.closeIcon, height: ProfileLayout.closeIcon)
                    .foregroundStyle(Color.fillOne)
                    .frame(width: ProfileLayout.closeButton, height: ProfileLayout.closeButton)
                    .secondaryButtonSurface(Circle(), fill: .buttonsSecondary, blur: ProfileLayout.closeBlur)
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("Закрыть")
        }
        .padding(.horizontal, ProfileLayout.side)
        .frame(height: ProfileLayout.headerRow)
        // Оттяг — как у навигации витрин: ряд едет за лентой вчетверо медленнее
        // и упирается в мягкий потолок (правка пользователя 2026-10-04). Сдвиг —
        // только у ряда: подложка стоит на месте, а при оттяге она прозрачна.
        .offset(y: ServiceTopNavMotion.pullShift(for: scrollOffset))
        .background(alignment: .top) {
            VariableBlurView(
                maxBlurRadius: EntityNavBarGeometry.backdropBlurRadius,
                direction: .blurredTopClearBottom
            )
            .frame(height: ServiceTopNavLayout.topSafeArea + ProfileLayout.headerRow + ProfileLayout.headerTail)
            .opacity(NavBarRamp.progress(scrollOffset, start: 0, length: ProfileLayout.headerRamp))
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
    }

    // MARK: Плюс

    /// «Вы в Яндекс Плюсе», виджеты подписки и баллов, семейная группа.
    private var plusSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Вы в Яндекс Плюсе")
                .plusHeadline(.m)
                .foregroundStyle(Color.fillOne)
                .padding(.top, ProfileLayout.titleTop)
                .padding(.bottom, ProfileLayout.titleBottom)
                .padding(.horizontal, ProfileLayout.side)

            HStack(spacing: ProfileLayout.widgetGap) {
                ProfileWidget(button: "Управлять") {
                    Text("Подписка")
                        .plusText(.textS, .medium)
                        .foregroundStyle(Color.fillOne)
                    Text("Активна до \(ProfileMock.subscriptionEnd)")
                        .plusText(.textS, .medium)
                        .foregroundStyle(Color.fillSubtitle)
                }
                .aspectRatio(1, contentMode: .fit)

                ProfileWidget(button: "Как потратить") {
                    Text("Баллы Плюса")
                        .plusText(.textS, .medium)
                        .foregroundStyle(Color.fillOne)
                    HStack(spacing: ProfileLayout.textGap) {
                        Text(ProfileMock.points)
                            .plusHeadline(.m)
                            .foregroundStyle(Color.fillOne)
                        Image("iconPlusPoints")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: ProfileLayout.pointsIcon, height: ProfileLayout.pointsIcon)
                            .foregroundStyle(Color.fillOne)
                    }
                    Text("1 балл = 1 рубль")
                        .plusText(.textS, .medium)
                        .foregroundStyle(Color.fillSubtitle)
                }
                .aspectRatio(1, contentMode: .fit)
            }
            .padding(.horizontal, ProfileLayout.side)
            .padding(.bottom, ProfileLayout.widgetGap)

            ProfileFamilyWidget()
                .aspectRatio(ProfileLayout.familyAspect, contentMode: .fit)
                .padding(.horizontal, ProfileLayout.side)
                .padding(.bottom, ProfileLayout.widgetGap)
        }
        .padding(.bottom, ProfileLayout.widgetsBottom)
    }

    // MARK: Ячейки

    /// Островки ячеек: «на ТВ» отдельно, ниже — дебаг-меню, настройки, поддержка,
    /// о приложении, соглашение и выход. Переход есть только у дебаг-меню, остальные
    /// строки в прототипе просто откликаются.
    private var cells: some View {
        VStack(spacing: ProfileLayout.islandGap) {
            ProfileIsland(rows: [
                ProfileCell(icon: "iconTvKinopoisk", title: "Смотрите и слушайте на ТВ"),
            ])
            ProfileIsland(rows: [
                // Над «Настройками», в той же секции (задача пользователя 2026-10-05).
                // Глиф системный: в ДС «🦄 Графика» отладочной иконки нет.
                ProfileCell(icon: "ladybug", title: "Дебаг меню", isSymbol: true) {
                    isDebugMenuShown = true
                },
                ProfileCell(icon: "iconSettings", title: "Настройки"),
                ProfileCell(icon: "iconComment", title: "Чат с поддержкой"),
                ProfileCell(icon: "iconInfo", title: "О приложении"),
                ProfileCell(icon: "iconLicense", title: "Лицензионное соглашение"),
                ProfileCell(icon: "iconExit", title: "Выйти"),
            ])
        }
        .padding(.horizontal, ProfileLayout.side)
        .padding(.vertical, ProfileLayout.cellsVertical)
    }
}

/// Моковый профиль — данные макета.
enum ProfileMock {
    /// Аватарка пользователя — одна на всё приложение: навигация витрин, шапка профиля,
    /// его круг в семейной группе (правка пользователя 2026-10-04). Фото — из макета
    /// навигации (`userpics` `2455:75985`).
    static let avatar = "avatarProfile"
    /// Имя — сербское и короткое, под мужскую аватарку (правка пользователя 2026-10-04;
    /// в макете — «Мила Йовович» с другим фото).
    static let name = "Марко Илич"
    static let subscriptionEnd = "29 декабря 2026"
    static let points = "5000"
}

// MARK: - Свечение

/// Свечение Плюса за шапкой — `Profile bg` макета: эллипс с градиентом
/// оранжевый → розовый → фиолетовый → в ноль, повёрнутый и размытый на 50, в кадре
/// 600 × 600 по центру сверху. Рисуется по числам вектора: экспорт его растром
/// из макета приходит пустым (фильтр размытия не отрисовывается).
private struct ProfileGlow: View {
    private static let size: CGFloat = 600
    private static let gradient = Gradient(stops: [
        .init(color: Color(red: 1, green: 0x5C / 255, blue: 0x4D / 255), location: 0),
        .init(color: Color(red: 0xEB / 255, green: 0x46 / 255, blue: 0x9F / 255), location: 0.65537),
        .init(color: Color(red: 0x83 / 255, green: 0x41 / 255, blue: 0xEF / 255), location: 0.793583),
        .init(color: Color(red: 0x34 / 255, green: 0x1A / 255, blue: 0x5F / 255), location: 0.918269),
        .init(color: .black.opacity(0), location: 1),
    ])

    var body: some View {
        Canvas { context, _ in
            context.addFilter(.blur(radius: 50))
            // Матрица эллипса из вектора: поворот с отражением и сдвиг в кадр 600.
            context.concatenate(CGAffineTransform(
                a: -0.918046, b: 0.396474,
                c: -0.386134, d: -0.922443,
                tx: 1033.06, ty: 551.026
            ))
            let ellipse = Path(ellipseIn: CGRect(x: 0, y: 0, width: 2 * 559.849, height: 2 * 587.934))
            context.fill(ellipse, with: .linearGradient(
                Self.gradient,
                startPoint: CGPoint(x: -19.2779, y: 1759.27),
                endPoint: CGPoint(x: 195.789, y: 329.061)
            ))
        }
        .frame(width: Self.size, height: Self.size)
        .clipped()
        // По центру по горизонтали, как в макете (+0.5 — хвост округления, не переносим).
        .frame(maxWidth: .infinity)
        .drawingGroup()
    }
}

// MARK: - Виджеты

/// Виджет Плюса — стеклянная карточка: подписи сверху, кнопка-капсула в левом нижнем углу.
private struct ProfileWidget<Content: View>: View {
    let button: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: ProfileLayout.textGap) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(ProfileLayout.widgetPadding)
        .overlay(alignment: .bottomLeading) {
            ProfilePill(title: button)
                .padding(ProfileLayout.widgetPadding - ProfileLayout.borderWidth)
        }
        .profileGlass()
    }
}

/// Семейная группа: слева подписи, справа аватарки 2 × 2 — трое и «добавить».
private struct ProfileFamilyWidget: View {
    var body: some View {
        HStack(alignment: .center, spacing: ProfileLayout.widgetGap) {
            VStack(alignment: .leading, spacing: ProfileLayout.textGap) {
                Text("Семейная группа")
                    .plusText(.textS, .medium)
                    .foregroundStyle(Color.fillOne)
                Text("Пригласите близких, это бесплатно")
                    .plusText(.textS, .medium)
                    .foregroundStyle(Color.fillSubtitle)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .layoutPriority(1)

            avatars
                .containerRelativeFrame(.horizontal) { length, _ in
                    // Правая колонка — 40 % ширины карточки за вычетом полей и зазора.
                    (length - 2 * ProfileLayout.side - 2 * ProfileLayout.widgetPadding - ProfileLayout.widgetGap)
                        * ProfileLayout.familyAvatarsShare
                }
        }
        .padding(ProfileLayout.widgetPadding)
        .overlay(alignment: .bottomLeading) {
            ProfilePill(title: "Добавить")
                .padding(ProfileLayout.widgetPadding - ProfileLayout.borderWidth)
        }
        .profileGlass()
    }

    private var avatars: some View {
        Grid(horizontalSpacing: ProfileLayout.familyAvatarGap, verticalSpacing: ProfileLayout.familyAvatarGap) {
            GridRow {
                // Пользователь в своей семье — его аватарка, с бордером, как в макете.
                avatar(ProfileMock.avatar, bordered: true)
                avatar("profileFamilyYoung")
            }
            GridRow {
                avatar("profileFamilyElder")
                Button {} label: {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                        .secondaryButtonSurface(Circle(), fill: .fillNine)
                        .overlay {
                            Image("iconAdd")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: ProfileLayout.addIcon, height: ProfileLayout.addIcon)
                                .foregroundStyle(ProfileLayout.secondaryGlyph)
                        }
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel("Добавить в семью")
            }
        }
    }

    private func avatar(_ asset: String, bordered: Bool = false) -> some View {
        Color.fillNine
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Image(asset)
                    .resizable()
                    .scaledToFill()
            }
            .clipShape(Circle())
            .overlay {
                if bordered {
                    Circle().strokeBorder(ProfileLayout.widgetBorder, lineWidth: ProfileLayout.borderWidth)
                }
            }
    }
}

/// Кнопка виджета — капсула 32, белый 10 %, Text S Semibold. Действий в прототипе
/// нет — откликается нажатием.
private struct ProfilePill: View {
    let title: String
    var isInverted = false

    var body: some View {
        Button {} label: {
            Text(title)
                .plusText(.textS, .semibold)
                .foregroundStyle(isInverted ? Color.black : Color.fillOne)
                .padding(.horizontal, ProfileLayout.pillHorizontal)
                .padding(.vertical, ProfileLayout.pillVertical)
                .background { if isInverted { Capsule().fill(Color.white) } }
                // Серая — стекло серых кнопок; инвертированная белая — без него.
                .modifier(ProfilePillSurface(isInverted: isInverted))
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

/// Поверхность капсулы: серая — общее стекло серых кнопок (блюр, бордер 0.67 × 8 %).
private struct ProfilePillSurface: ViewModifier {
    let isInverted: Bool

    func body(content: Content) -> some View {
        if isInverted {
            content
        } else {
            content.secondaryButtonSurface(Capsule(style: .continuous))
        }
    }
}

/// Промо «Плюс близким» — `Communication / Micro promoblock`: подарок справа,
/// заголовок и подпись слева сверху, «Выбрать» — инвертированной капсулой внизу.
private struct ProfilePromo: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Image("profilePromoGift")
                .resizable()
                .frame(width: ProfileLayout.promoImageWidth, height: ProfileLayout.promoHeight)
                .frame(maxWidth: .infinity, alignment: .trailing)

            VStack(alignment: .leading, spacing: ProfileLayout.textGap) {
                Text("Плюс близким")
                    .plusHeadline(.m)
                    .foregroundStyle(Color.fillOne)
                Text("Выберите сертификат, дизайн\nи напишите поздравление")
                    .plusText(.textS, .medium)
                    .foregroundStyle(Color.fillSubtitle)
            }
            .frame(width: ProfileLayout.promoTextWidth, alignment: .leading)
            .padding(ProfileLayout.promoInset)
        }
        .frame(height: ProfileLayout.promoHeight)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottomLeading) {
            ProfilePill(title: "Выбрать", isInverted: true)
                .padding(ProfileLayout.promoInset)
        }
        .background(Color.fillNine)
        .clipShape(RoundedRectangle(cornerRadius: ProfileLayout.widgetRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ProfileLayout.widgetRadius, style: .continuous)
                .strokeBorder(ProfileLayout.widgetBorder, lineWidth: ProfileLayout.borderWidth)
        }
    }
}

// MARK: - Ячейки

private struct ProfileCell: Identifiable {
    let icon: String
    let title: String
    /// `icon` — имя SF Symbol, а не ассета
    var isSymbol = false
    /// `nil` — перехода нет, строка только откликается
    var action: (() -> Void)? = nil
    var id: String { title }
}

/// Островок ячеек — `cell / cell-table / grouped-island`: белый 8 %, скругление 16,
/// между строками разделители 0.5 от 16 слева до правого края.
private struct ProfileIsland: View {
    let rows: [ProfileCell]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows.indices, id: \.self) { index in
                row(rows[index])
                    .overlay(alignment: .top) {
                        if index > 0 {
                            Rectangle()
                                .fill(ProfileLayout.divider)
                                .frame(height: 0.5)
                                .padding(.leading, ProfileLayout.dividerInset)
                        }
                    }
            }
        }
        .padding(.vertical, ProfileLayout.islandPadding)
        .background(
            RoundedRectangle(cornerRadius: ProfileLayout.islandRadius, style: .continuous)
                .fill(Color.fillNine)
        )
    }

    private func row(_ cell: ProfileCell) -> some View {
        Button { cell.action?() } label: {
            HStack(spacing: ProfileLayout.cellGap) {
                (cell.isSymbol ? Image(systemName: cell.icon) : Image(cell.icon))
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: ProfileLayout.cellIcon, height: ProfileLayout.cellIcon)
                    .foregroundStyle(Color.fillOne)
                Text(cell.title)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillOne)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image("iconChevronRight")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: ProfileLayout.chevron, height: ProfileLayout.chevron)
                    .foregroundStyle(ProfileLayout.secondaryGlyph)
            }
            .padding(.horizontal, ProfileLayout.cellHorizontal)
            .padding(.vertical, ProfileLayout.cellVertical)
            .contentShape(.rect)
        }
        .buttonStyle(ProfileCellButtonStyle())
    }
}

/// Нажатая ячейка подсвечивается, как строка системной таблицы, — без сжатия.
private struct ProfileCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.white.opacity(configuration.isPressed ? 0.06 : 0))
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private extension View {
    /// Стекло виджетов профиля — белый 8 %, бордер 0.67 × белый 15 %, блюр 20, r16.
    func profileGlass() -> some View {
        glassSurface(
            RoundedRectangle(cornerRadius: ProfileLayout.widgetRadius, style: .continuous),
            blur: ProfileLayout.widgetBlur,
            fill: .fillNine,
            border: ProfileLayout.widgetBorder,
            borderWidth: ProfileLayout.borderWidth
        )
    }
}
