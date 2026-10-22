import SwiftUI
import VariableBlur

/// Числа экрана профиля — макет `2701:30161` (кадр 375, статус-бар 54).
/// Герой стоит от центра экрана и от верха безопасной зоны: смещения его элементов
/// от центра и высоты под статус-баром — как в макете. Виджеты и островки — поля 16,
/// колонки делят остаток, виджеты держат пропорции макета (правило 4 CLAUDE.md).
enum ProfileLayout {
    static let side: CGFloat = 16
    /// Статус-бар кадра макета: вертикаль героя и свечения отмеряется от его низа,
    /// то есть от верха безопасной зоны устройства.
    static let designStatusBar: CGFloat = 54

    // MARK: Герой (`hero` `2701:30164`)

    /// 237 от верха кадра — 183 под статус-баром
    static let heroHeight: CGFloat = 237 - designStatusBar
    /// Аватар: кольцо 101 по центру экрана, центр на 122.5 от верха кадра (`2701:30196`)
    static let ringCenterY: CGFloat = 122.5 - designStatusBar
    /// Растр кольца с полями под его тени и блюр — 115.741 (`profileAvatarRing`)
    static let ringRaster: CGFloat = 115.741
    /// Фото 90.67 с бордером 1.519 × белый 15 % — по центру кольца
    static let photo: CGFloat = 90.67
    static let photoBorder: CGFloat = 1.519
    static let photoBorderColor = Color.fillEight
    /// Карандаш: круг 26.824, центр (+39.09, 156.588) — на кромке кольца справа снизу
    /// (`2701:30201`); растр с полями под тень и блюр — 30.35 (`profilePencilCircle`)
    static let pencil: CGFloat = 26.824
    static let pencilRaster: CGFloat = 30.3496
    static let pencilCenter = CGPoint(x: 39.09, y: 156.588 - designStatusBar)
    /// Иконка карандаша 16, белый 40 % (`2701:30298`)
    static let pencilIcon: CGFloat = 16
    /// Блюр фона под кругом: `BACKGROUND_BLUR` 4 в панели — 2 в единицах проекта
    static let pencilBackdropBlur: CGFloat = 2
    /// Зона нажатия карандаша шире круга — на 8 с каждой стороны
    static let pencilHitInset: CGFloat = 8
    /// Бабл баллов 61 × 59.948, центр (−95, 120.438) (`2701:30186`)
    static let pointsBubble = CGSize(width: 61, height: 59.948)
    static let pointsCenter = CGPoint(x: -95, y: 120.438 - designStatusBar)
    /// «617 +» — уменьшенная копия строки баллов UI kit (Headline 24, зазор 4, знак 18):
    /// в макете 17.43 / 2.905 / 13.07, масштаб 0.726. Центр строки — (−94.11, 119.656).
    static let pointsValueScale: CGFloat = 17.43 / 24
    static let pointsValueGap: CGFloat = 4
    static let pointsIcon: CGFloat = 18
    static let pointsValueCenter = CGPoint(x: -94.11, y: 119.656 - designStatusBar)
    /// Подпись «Баллы»: центр на −96 от центра экрана, верх на 154 (`2701:30199`)
    static let pointsLabelX: CGFloat = -96
    static let pointsLabelTop: CGFloat = 154 - designStatusBar
    /// Имя — по центру, верх на 196 (`2701:30165`)
    static let nameTop: CGFloat = 196 - designStatusBar

    // MARK: Виджеты (`widgets` `2701:30202`)

    /// Стекло виджетов: белый 8 %, бордер 0.67 × белый 15 %, блюр 20, скругление 24
    static let widgetGap: CGFloat = 8
    static let widgetRadius: CGFloat = 24
    static let widgetPadding: CGFloat = 12
    static let widgetBlur: CGFloat = 20
    static let widgetBorder = Color.fillEight
    static let borderWidth: CGFloat = 0.67
    static let textGap: CGFloat = 4

    /// Семейная группа 343 × 167: колонки 60 / 40 с зазором 8, две строки поровну —
    /// подписи в первой, «Добавить» во второй (`2701:30204`)
    static let familyAspect: CGFloat = 343 / 167
    static let familyTextShare: CGFloat = 0.6
    /// Правая колонка — блок 124.4 × 143 с тремя «+» по 60.2 треугольником; на другой
    /// ширине блок масштабируется по ширине колонки
    static let familyAvatarsDesign = CGSize(width: 124.4, height: 143)
    static let familyAvatar: CGFloat = 60.2
    static let familyAvatarOrigins: [CGPoint] = [
        CGPoint(x: 31.2, y: 10.3),
        CGPoint(x: -1, y: 70.5),
        CGPoint(x: 63.2, y: 70.5),
    ]
    static let addIcon: CGFloat = 24

    /// Прогресс «Скачайте фильм»: три сегмента по 8, зазор 4, от 12.5 слева до 21 справа,
    /// низ на 65.5 от низа виджета (`2701:30230`)
    static let progressHeight: CGFloat = 8
    static let progressGap: CGFloat = 4
    static let progressLeading: CGFloat = 12.5
    static let progressTrailing: CGFloat = 21
    static let progressBottom: CGFloat = 65.5
    /// Знак Плюса в кнопке «Получить» — 16 (`2701:30229`)
    static let plusBadge: CGFloat = 16

    // MARK: Ячейки (`stack` `2701:30236`)

    /// Островки: белый 8 %, скругление 16, поля 4 сверху и снизу, между островками 8,
    /// блок — поля 16 сверху и снизу; строка — иконка 24, Text M, шеврон 16, поля 16 × 14
    static let cellsVertical: CGFloat = 16
    static let islandGap: CGFloat = 8
    static let islandRadius: CGFloat = 16
    static let islandPadding: CGFloat = 4
    static let cellHorizontal: CGFloat = 16
    static let cellVertical: CGFloat = 14
    static let cellGap: CGFloat = 12
    static let cellIcon: CGFloat = 24
    /// Заголовок и подпись строки «Подписка» — вплотную (в макете 2; минус 2 — правка
    /// пользователя 2026-10-13); строка остаётся 52, блок текста выходит за высоту иконки
    /// поровну вверх и вниз
    static let cellTextGap: CGFloat = 0
    static let chevron: CGFloat = 16
    /// Разделитель ячеек — 0.5 × белый 15 %, от 16 слева до правого края островка
    static let divider = Color.fillEight
    static let dividerInset: CGFloat = 16
    /// Шеврон и «+» — белый 40 %
    static let secondaryGlyph = Color.fillSix

    // MARK: Общее с дебаг-меню

    /// Заголовки секций дебаг-меню — поля 16 сверху и 12 снизу (`DebugMenuScreen`)
    static let titleTop: CGFloat = 16
    static let titleBottom: CGFloat = 12
    static let bottomPadding: CGFloat = 24
}

/// Экран профиля (макет `2701:30161`, задача пользователя 2026-10-13): открывается
/// с аватарки в навигации витрин, снизу вверх, поверх всего. Сверху — свечение Плюса
/// и герой: баллы слева, аватар с карандашом, имя; аватар, карандаш и баллы левитируют
/// (`ProfileLevitation`). Ниже — виджеты семейной группы, качества видео и «Скачайте
/// фильм», служебный островок «Дебаг меню» и островки ячеек. Данные — из макета, имя
/// и аватар — общие на приложение (`ProfileMock`).
/// Профиль в стеке таба — маршрут без данных: профиль один.
struct ProfileRoute: Hashable {}

struct ProfileScreen: View {
    @State private var scrollOffset: CGFloat = 0
    @State private var isDebugMenuShown = false

    var body: some View {
        // Пуш в стек таба (правка пользователя 2026-10-21): дебаг-меню — следующий экран
        // того же стека, «назад» возвращает к профилю.
        profile
            .toolbar(.hidden, for: .navigationBar)
            // Без таббара и action bar (правка пользователя 2026-10-21).
            .modifier(HidesBottomChrome())
            .navigationDestination(isPresented: $isDebugMenuShown) {
                DebugMenuScreen()
                    .modifier(HidesBottomChrome())
            }
        #if DEBUG
        // `-debugMenu 1` (с `-debugProfile 1`) — через 1 с открыть дебаг-меню, как тап
        // по ячейке.
        .task {
            guard UserDefaults.standard.bool(forKey: "debugMenu") else { return }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            isDebugMenuShown = true
        }
        #endif
        .preferredColorScheme(.dark)
    }

    private var profile: some View {
        ZStack(alignment: .top) {
            // Свечение — от верха экрана, уезжает вместе с лентой; при оттяге чуть сползает вниз.
            // Оверлеем на фоне, а не слоем стопки: кадр свечения шире экрана, и слоем
            // он раздвигал бы всю стопку (кадр 2026-10-04).
            Color.surfaceOne
                .overlay(alignment: .top) {
                    ProfileGlow()
                        // При оттяге — немного вниз, как ряд навбара: четверть хода с мягким
                        // потолком (правка пользователя 2026-10-13).
                        .offset(y: ServiceTopNavLayout.topSafeArea - ProfileLayout.designStatusBar
                                - max(0, scrollOffset) + ServiceTopNavMotion.pullShift(for: scrollOffset))
                        .allowsHitTesting(false)
                }
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    ProfileHero(scrollOffset: scrollOffset)
                    widgets
                    cells
                }
            }
            .scrollIndicators(.hidden)
            .trackNavBarScroll(into: $scrollOffset)
        }
        .overlay(alignment: .top) { header }
    }

    // MARK: Шапка

    /// Обычный навбар экранов стека — «назад» без названия (правка пользователя
    /// 2026-10-21; прежде — крестик справа на своей подложке). Подложка проявляется
    /// с первых пунктов скролла, как у списков.
    private var header: some View {
        EntityNavBar(title: "", scrollOffset: scrollOffset, thresholds: Self.navThresholds)
    }

    private static let navThresholds = EntityNavBarThresholds(
        backgroundStart: 0,
        backgroundRamp: ServiceTopNavMotion.backdropRamp,
        titleStart: .greatestFiniteMagnitude,
        titleRamp: 1
    )

    // MARK: Виджеты

    /// Семейная группа во всю ширину, под ней ряд из двух квадратов.
    private var widgets: some View {
        VStack(spacing: ProfileLayout.widgetGap) {
            ProfileFamilyWidget()
            HStack(spacing: ProfileLayout.widgetGap) {
                ProfileVideoQualityWidget()
                ProfileDownloadWidget()
            }
        }
        .padding(.horizontal, ProfileLayout.side)
        .padding(.bottom, ProfileLayout.widgetGap)
    }

    // MARK: Ячейки

    /// Островки макета: подписка и ТВ; настройки, поддержка, о приложении, выход.
    /// Первым — служебный «Дебаг меню», в макете его нет. Переход есть только
    /// у дебаг-меню, остальные строки в прототипе просто откликаются.
    private var cells: some View {
        VStack(spacing: ProfileLayout.islandGap) {
            // Отдельным островком первым, над «Подпиской» (правки пользователя 2026-10-13
            // и 2026-10-17). Глиф системный: в ДС «🦄 Графика» отладочной иконки нет.
            ProfileIsland(rows: [
                ProfileCell(icon: "ladybug", title: "Дебаг меню", isSymbol: true) {
                    isDebugMenuShown = true
                },
            ])
            ProfileIsland(rows: [
                ProfileCell(icon: "iconSubscriptions", title: "Подписка",
                            subtitle: "Активна до \(ProfileMock.subscriptionEnd)"),
                ProfileCell(icon: "iconTvKinopoisk", title: "Смотрите и слушайте на ТВ"),
            ])
            ProfileIsland(rows: [
                ProfileCell(icon: "iconSettings", title: "Настройки"),
                ProfileCell(icon: "iconComment", title: "Чат с поддержкой"),
                ProfileCell(icon: "iconInfo", title: "О приложении"),
                ProfileCell(icon: "iconExit", title: "Выйти"),
            ])
        }
        .padding(.horizontal, ProfileLayout.side)
        .padding(.vertical, ProfileLayout.cellsVertical)
    }
}

/// Моковый профиль — данные макета.
enum ProfileMock {
    /// Аватарка пользователя — одна на всё приложение: навигация витрин, герой профиля
    /// (правка пользователя 2026-10-04). Фото — из макета навигации (`userpics` `2455:75985`).
    static let avatar = "avatarProfile"
    /// Имя задано пользователем 2026-10-12 (в макете — «Мила Йовович»).
    static let name = "Джет Ли Виноградов"
    static let subscriptionEnd = "29 декабря 2026"
    static let points = "617"
}

// MARK: - Свечение

/// Свечение Плюса за героем — `bg` макета (`2701:30162`): прямоугольник 580 × 333
/// у верха кадра с радиальным градиентом по матрице макета (центр за аватаром:
/// красно-оранжевый → розовый → фиолетовый → чёрный), размытый на 58.649.
/// Рисуется по числам вектора: размытая нода экспортируется пустой.
private struct ProfileGlow: View {
    private static let rect = CGSize(width: 580, height: 333)
    private static let blur: CGFloat = 58.649
    /// Поле под разлёт блюра — три радиуса сверху и снизу. По бокам поля нет: края
    /// прямоугольника (580) за кромками экрана на любой ширине, разлёт там не виден,
    /// а растр без него на треть легче.
    private static let spill: CGFloat = 3 * blur
    /// Матрица градиента из макета: единичный круг радиуса 10 → скошенный эллипс
    /// с центром (279.53, 147.63) в координатах прямоугольника.
    private static let gradientTransform = CGAffineTransform(
        a: 24.865, b: 19.795,
        c: -25.677, d: 11.214,
        tx: 279.53, ty: 147.63
    )
    private static let gradientRadius: CGFloat = 10
    private static let gradient = Gradient(stops: [
        .init(color: Color(red: 255 / 255, green: 92 / 255, blue: 77 / 255), location: 0),
        .init(color: Color(red: 245 / 255, green: 81 / 255, blue: 118 / 255), location: 0.053942),
        .init(color: Color(red: 235 / 255, green: 70 / 255, blue: 159 / 255), location: 0.10788),
        .init(color: Color(red: 183 / 255, green: 68 / 255, blue: 199 / 255), location: 0.22017),
        .init(color: Color(red: 131 / 255, green: 65 / 255, blue: 239 / 255), location: 0.33245),
        .init(color: Color(red: 98 / 255, green: 49 / 255, blue: 179 / 255), location: 0.49934),
        .init(color: Color(red: 66 / 255, green: 33 / 255, blue: 120 / 255), location: 0.66623),
        .init(color: Color(red: 49 / 255, green: 24 / 255, blue: 90 / 255), location: 0.74967),
        .init(color: Color(red: 33 / 255, green: 16 / 255, blue: 60 / 255), location: 0.83311),
        .init(color: Color(red: 16 / 255, green: 8 / 255, blue: 30 / 255), location: 0.91656),
        .init(color: Color(red: 8 / 255, green: 4 / 255, blue: 15 / 255), location: 0.95828),
        .init(color: .black, location: 1),
    ])

    var body: some View {
        Canvas { context, _ in
            context.addFilter(.blur(radius: Self.blur))
            // Слой целиком — одна операция рисования: блюр ложится на прямоугольник
            // вместе с его краями, как размытие слоя в Фигме.
            context.drawLayer { layer in
                layer.translateBy(x: 0, y: Self.spill)
                let rect = Path(CGRect(origin: .zero, size: Self.rect))
                layer.clip(to: rect)
                // За радиусом градиент — чёрный: подложка вместо продления крайнего цвета.
                layer.fill(rect, with: .color(.black))
                layer.concatenate(Self.gradientTransform)
                let reach = 20 * Self.gradientRadius
                layer.fill(
                    Path(CGRect(x: -reach, y: -reach, width: 2 * reach, height: 2 * reach)),
                    with: .radialGradient(
                        Self.gradient,
                        center: .zero,
                        startRadius: 0,
                        endRadius: Self.gradientRadius
                    )
                )
            }
        }
        .frame(width: Self.rect.width, height: Self.rect.height + 2 * Self.spill)
        // Растр — до сдвига: после сдвига он срезал бы поле блюра над прямоугольником.
        .drawingGroup()
        // Прямоугольник — у верха кадра, по центру по горизонтали (+0.5 макета —
        // хвост округления, не переносим).
        .offset(y: -Self.spill)
    }
}

// MARK: - Герой

/// Герой: баллы слева, аватар с карандашом по центру, имя. Аватар, карандаш и баллы —
/// отдельными слоями во всю ширину: каждый слой левитирует своим смещением.
private struct ProfileHero: View {
    let scrollOffset: CGFloat

    var body: some View {
        // Резиновый отступ до имени: при оттяге ленты баллы, аватар и карандаш отстают от
        // имени на сдвиг навбаров — четверть хода с мягким потолком (правка пользователя
        // 2026-10-13), так что зазор чуть растёт и упирается; в покое — ноль.
        let lag = -ServiceTopNavMotion.pullShift(for: scrollOffset)
        ProfileLevitation { offsets in
            ZStack(alignment: .top) {
                Text(ProfileMock.name)
                    .plusHeadline(.s)
                    .foregroundStyle(Color.fillOne)
                    .lineLimit(1)
                    .padding(.horizontal, ProfileLayout.side)
                    .padding(.top, ProfileLayout.nameTop)

                ProfilePointsBadge()
                    .offset(offsets.points)
                    .offset(y: lag)
                ProfileAvatar()
                    .offset(offsets.avatar)
                    .offset(y: lag)
                ProfilePencilButton()
                    .offset(offsets.pencil)
                    .offset(y: lag)
            }
            .frame(maxWidth: .infinity)
            .frame(height: ProfileLayout.heroHeight, alignment: .top)
        }
    }
}

private extension View {
    /// Элемент героя: кадр `size`, центр в `center` — x от центра экрана, y от верха героя.
    /// Сдвигом, а не раскладкой: герою задана своя высота, слои её не меняют.
    func heroPlaced(_ size: CGSize, center: CGPoint) -> some View {
        frame(width: size.width, height: size.height)
            .offset(x: center.x, y: center.y - size.height / 2)
    }
}

/// Аватар: фото с бордером и поверх — стеклянное кольцо макета (`Ellipse 29155`). Кольцо —
/// растр: у него две внутренние тени, блюр и повёрнутый эллиптический градиент, iOS рисует
/// такой SVG плоско. Смешение «осветление» — как в макете, кольцо светлит фото и свечение.
private struct ProfileAvatar: View {
    var body: some View {
        let raster = ProfileLayout.ringRaster
        ZStack {
            Image(ProfileMock.avatar)
                .resizable()
                .scaledToFill()
                .frame(width: ProfileLayout.photo, height: ProfileLayout.photo)
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(ProfileLayout.photoBorderColor, lineWidth: ProfileLayout.photoBorder)
                }
            Image("profileAvatarRing")
                .resizable()
                .frame(width: raster, height: raster)
                .blendMode(.lighten)
        }
        .heroPlaced(CGSize(width: raster, height: raster), center: CGPoint(x: 0, y: ProfileLayout.ringCenterY))
        .accessibilityHidden(true)
    }
}

/// Карандаш на кромке аватара: стеклянный круг (растр — тень и блюр) над блюром фона,
/// иконка белым 40 %. Действия в прототипе нет — откликается нажатием.
private struct ProfilePencilButton: View {
    var body: some View {
        let size = ProfileLayout.pencil
        let raster = ProfileLayout.pencilRaster
        Button(action: PlayerHaptics.tap) {
            ZStack {
                BackdropBlurView(radius: ProfileLayout.pencilBackdropBlur)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                Image("profilePencilCircle")
                    .resizable()
                    .frame(width: raster, height: raster)
                Image("iconPencil")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: ProfileLayout.pencilIcon, height: ProfileLayout.pencilIcon)
                    .foregroundStyle(ProfileLayout.secondaryGlyph)
            }
            .frame(width: size, height: size)
            .padding(ProfileLayout.pencilHitInset)
            .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .padding(-ProfileLayout.pencilHitInset)
        .accessibilityLabel("Редактировать профиль")
        .heroPlaced(CGSize(width: size, height: size), center: ProfileLayout.pencilCenter)
    }
}

/// Баллы: бабл, внутри «617 +», под ним подпись «Баллы».
private struct ProfilePointsBadge: View {
    var body: some View {
        ZStack(alignment: .top) {
            ProfilePointsBubble()
                .heroPlaced(ProfileLayout.pointsBubble, center: ProfileLayout.pointsCenter)

            HStack(spacing: ProfileLayout.pointsValueGap) {
                Text(ProfileMock.points)
                    .plusHeadline(.s)
                Image("iconPlusPoints")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: ProfileLayout.pointsIcon, height: ProfileLayout.pointsIcon)
            }
            .foregroundStyle(Color.fillOne)
            .fixedSize()
            .frame(height: PlusHeadline.s.lineHeight)
            .scaleEffect(ProfileLayout.pointsValueScale)
            .offset(
                x: ProfileLayout.pointsValueCenter.x,
                y: ProfileLayout.pointsValueCenter.y - PlusHeadline.s.lineHeight / 2
            )

            Text("Баллы")
                .plusText(.textXS, .medium)
                .foregroundStyle(Color.fillSix)
                .fixedSize()
                .offset(x: ProfileLayout.pointsLabelX, y: ProfileLayout.pointsLabelTop)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Баллы: \(ProfileMock.points)")
    }
}

/// Бабл баллов (`2701:30187`): капсула 61 × 59.948, заливка серый 1 %, бордер
/// 0.855 × белый 20 %, две внутренние розовые тени, блюр 2.656, прозрачность 0.4,
/// смешение «осветление». Тени из CSS макета: блюр тени — вдвое больше радиуса
/// в единицах проекта, как у всех блюров.
private struct ProfilePointsBubble: View {
    private static let pink = Color(red: 1, green: 158 / 255, blue: 1) // #FF9EFF
    private static let fill = Color(white: 189 / 255).opacity(0.01)
    private static let border = Color.white.opacity(0.2)
    private static let borderWidth: CGFloat = 0.855
    private static let blur: CGFloat = 2.656
    private static let opacity: Double = 0.4

    var body: some View {
        let size = ProfileLayout.pointsBubble
        ZStack {
            Capsule().fill(Self.fill)
            ProfileInnerShadow(
                shape: Capsule(), size: size,
                color: Self.pink.opacity(0.29), radius: 18.431 / 2, x: 5.977, y: 5.123
            )
            ProfileInnerShadow(
                shape: Capsule(), size: size,
                color: Self.pink, radius: 11.089 / 2, x: -0.664, y: -3.985
            )
            Capsule().strokeBorder(Self.border, lineWidth: Self.borderWidth)
        }
        .frame(width: size.width, height: size.height)
        .compositingGroup()
        .blur(radius: Self.blur)
        .opacity(Self.opacity)
        .blendMode(.lighten)
        .allowsHitTesting(false)
    }
}

/// Внутренняя тень формы: всё вне формы залито цветом тени, сдвинуто, размыто
/// и видно только внутри формы. Поле вокруг — с запасом на блюр и сдвиг, иначе
/// размытие у кромки брало бы пустоту и тень там слабела.
private struct ProfileInnerShadow<S: Shape>: View {
    let shape: S
    let size: CGSize
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    var body: some View {
        let margin = 3 * radius + max(abs(x), abs(y))
        ZStack {
            Rectangle().fill(color)
            shape
                .fill(Color.black)
                .frame(width: size.width, height: size.height)
                .offset(x: x, y: y)
                .blendMode(.destinationOut)
        }
        .frame(width: size.width + 2 * margin, height: size.height + 2 * margin)
        .compositingGroup()
        .blur(radius: radius)
        .frame(width: size.width, height: size.height)
        .mask(shape)
    }
}

// MARK: - Виджеты

/// Семейная группа: слева подписи и «Добавить», справа три «+» треугольником.
private struct ProfileFamilyWidget: View {
    var body: some View {
        let padding = ProfileLayout.widgetPadding
        let width = PlusGrid.column(columns: 1, side: ProfileLayout.side, gap: 0)
        let height = width / ProfileLayout.familyAspect
        let columns = width - 2 * padding - ProfileLayout.widgetGap
        let textColumn = columns * ProfileLayout.familyTextShare
        let avatarsScale = (columns - textColumn) / ProfileLayout.familyAvatarsDesign.width
        // Вторая строка сетки — вторая половина высоты за вычетом полей
        let rowHeight = (height - 2 * padding) / 2

        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: ProfileLayout.textGap) {
                Text("Семейная группа")
                    .plusText(.textS, .medium)
                    .foregroundStyle(Color.fillOne)
                Text("Пригласите близких, это бесплатно")
                    .plusText(.textS, .medium)
                    .foregroundStyle(Color.fillSubtitle)
            }
            .frame(width: textColumn, alignment: .leading)
            .padding(padding)

            PlusButton("Добавить", type: .secondary, size: .s) {}
                .padding(.leading, padding)
                .padding(.top, padding + rowHeight)

            avatars(scale: avatarsScale)
                .padding(.leading, padding + textColumn + ProfileLayout.widgetGap)
                .padding(.top, padding)
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .profileGlass()
    }

    private func avatars(scale: CGFloat) -> some View {
        let design = ProfileLayout.familyAvatarsDesign
        let diameter = ProfileLayout.familyAvatar * scale
        return ZStack(alignment: .topLeading) {
            ForEach(ProfileLayout.familyAvatarOrigins.indices, id: \.self) { index in
                let origin = ProfileLayout.familyAvatarOrigins[index]
                Button(action: PlayerHaptics.tap) {
                    Image("iconAdd")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: ProfileLayout.addIcon, height: ProfileLayout.addIcon)
                        .foregroundStyle(ProfileLayout.secondaryGlyph)
                        .frame(width: diameter, height: diameter)
                        .secondaryButtonSurface(Circle(), fill: .fillNine)
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel("Добавить в семью")
                .offset(x: origin.x * scale, y: origin.y * scale)
            }
        }
        .frame(width: design.width * scale, height: design.height * scale, alignment: .topLeading)
    }
}

/// Квадратный виджет ряда: подписи сверху, снизу — то, что прибито к низу (кнопка, прогресс).
private struct ProfileSquareWidget<Content: View, Footer: View>: View {
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        let side = PlusGrid.column(columns: 2, side: ProfileLayout.side, gap: ProfileLayout.widgetGap)
        VStack(alignment: .leading, spacing: ProfileLayout.textGap) {
            content
        }
        .padding(ProfileLayout.widgetPadding)
        .frame(width: side, height: side, alignment: .topLeading)
        .overlay(alignment: .bottomLeading) { footer }
        .profileGlass()
    }
}

/// «Качество видео / 4K UHD» (`2701:30221`).
private struct ProfileVideoQualityWidget: View {
    var body: some View {
        ProfileSquareWidget {
            Text("Качество видео")
                .plusText(.textS, .medium)
                .foregroundStyle(Color.fillOne)
            Text("4K UHD")
                .plusHeadline(.s)
                .foregroundStyle(Color.fillOne)
                .lineLimit(1)
            Text("Кино на большом экране")
                .plusText(.textS, .medium)
                .foregroundStyle(Color.fillSubtitle)
        } footer: {
            PlusButton("Подключить ТВ", type: .secondary, size: .s) {}
                .padding(ProfileLayout.widgetPadding)
        }
    }
}

/// «Скачайте фильм» (`2701:30222`): подписи, прогресс из трёх шагов, «Получить [Плюс] 100».
private struct ProfileDownloadWidget: View {
    /// Пройденный шаг — градиент макета под 149.46°, переведённый в юнит-спейс сегмента
    /// 41 × 8 (CSS-угол → ручки). Видимые стопы — розово-фиолетовые, как на рендере макета.
    private static let doneStep = LinearGradient(
        stops: [
            .init(color: Color(red: 156 / 255, green: 59 / 255, blue: 233 / 255), location: 0.19554),
            .init(color: Color(red: 230 / 255, green: 104 / 255, blue: 229 / 255), location: 0.69348),
            .init(color: Color(red: 244 / 255, green: 187 / 255, blue: 229 / 255), location: 1),
        ],
        startPoint: UnitPoint(x: 0.32818, y: -0.99238),
        endPoint: UnitPoint(x: 0.67182, y: 1.99238)
    )

    var body: some View {
        ProfileSquareWidget {
            Text("Скачайте фильм")
                .plusText(.textS, .medium)
                .foregroundStyle(Color.fillOne)
            Text("Настройте опыт\nв\u{00A0}3 шага и получите баллы")
                .plusText(.textS, .medium)
                .foregroundStyle(Color.fillSubtitle)
        } footer: {
            ZStack(alignment: .bottomLeading) {
                HStack(spacing: ProfileLayout.progressGap) {
                    Capsule().fill(Self.doneStep)
                    Capsule().fill(Color.fillNine)
                    Capsule().fill(Color.fillNine)
                }
                .frame(height: ProfileLayout.progressHeight)
                .padding(.leading, ProfileLayout.progressLeading)
                .padding(.trailing, ProfileLayout.progressTrailing)
                .padding(.bottom, ProfileLayout.progressBottom)

                PlusButton(type: .secondary, size: .s, accessibilityTitle: "Получить 100 баллов") {
                    HStack(spacing: ProfileLayout.textGap) {
                        Text("Получить")
                        ProfilePlusBadge()
                        Text("100")
                    }
                } action: {}
                .padding(ProfileLayout.widgetPadding)
            }
        }
    }
}

/// Знак Плюса на градиенте бренда (`2701:30229`): круг 16 с градиентом слева направо
/// и белый знак поверх.
private struct ProfilePlusBadge: View {
    private static let gradient = LinearGradient(
        stops: [
            .init(color: Color(hex: 0xFF5C4D), location: 0),
            .init(color: Color(hex: 0xEB469F), location: 0.265625),
            .init(color: Color(hex: 0x8341EF), location: 0.75),
            .init(color: Color(hex: 0x3F68F9), location: 1),
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        Image("iconPlusSign")
            .renderingMode(.template)
            .resizable()
            .foregroundStyle(Color.fillOne)
            .frame(width: ProfileLayout.plusBadge, height: ProfileLayout.plusBadge)
            .background(Self.gradient)
            .clipShape(Circle())
    }
}

// MARK: - Ячейки

private struct ProfileCell: Identifiable {
    let icon: String
    let title: String
    /// Подпись под заголовком — Text S, белый 40 %, как в макете
    var subtitle: String? = nil
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
        // Подсветка нажатия — прямоугольник во всю строку: у первой и последней строки
        // углы вылезали за скругление островка
        .clipShape(RoundedRectangle(cornerRadius: ProfileLayout.islandRadius, style: .continuous))
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
                VStack(alignment: .leading, spacing: ProfileLayout.cellTextGap) {
                    Text(cell.title)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillOne)
                    if let subtitle = cell.subtitle {
                        Text(subtitle)
                            .plusText(.textS, .medium)
                            .foregroundStyle(Color.fillSix)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                // Высота строки — по иконке: с подписью строка та же 52, блок текста
                // выходит за неё поровну, как в макете
                .frame(height: ProfileLayout.cellIcon)
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
        // Без нажатого состояния (правка пользователя 2026-10-13): строки профиля не
        // подсвечиваются и не проседают.
        .buttonStyle(ProfileCellButtonStyle())
    }
}

/// Кнопка без отклика нажатия — для строк островков профиля.
private struct ProfileCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label }
}

private extension View {
    /// Стекло виджетов профиля — белый 8 %, бордер 0.67 × белый 15 %, блюр 20, r24.
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
