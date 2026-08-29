import SwiftUI

// MARK: - Персоны тайтла

/// `2101:22652` — 393×287.5: шапка 52 + карусель 219.5 (`padding-x 16`, gap 8).
/// Карточка 109 шириной: фото 2:3, под ним белое имя и серое пояснение под ним.
///
/// Одна вью на обе карусели экрана — «В главных ролях» и «Съёмочная группа»
/// (решение пользователя 2026-08-29). Вёрстка у них общая до пикселя, различаются
/// только заголовок и то, что стоит серой строкой: у актёра — его герой, у съёмочной
/// группы — специальность. Роль актёра API отдаёт не всегда (в списочном роуте её нет
/// вовсе — замер 2026-08-29), поэтому карточка с одной строкой — норма, а не пустое
/// место: подписи выровнены по верху.
///
/// **Высота подписи считается по всей секции, а не по карточке.** `LazyHStack` меряет
/// ряд по тем карточкам, которые успел создать, — то есть по первым видимым. Если у
/// первого в ряду имя влезло в строку, ряд получал высоту в одну строку, и всем, кто
/// въезжал следом, `lineLimit(2)` уже нечего было раскрывать: SwiftUI ужимал имя под
/// предложенную высоту и резал многоточием в конце **первой** строки (жалоба
/// пользователя 2026-08-29). Поэтому число строк меряется заранее по всем персонам
/// секции — тем же шрифтом, которым текст и рисуется.
struct MoviePersonSection: View {
    let title: String
    let people: [MovieCastMember]

    private enum Layout {
        static let cardWidth: CGFloat = 109
        static let photoAspect: CGFloat = 2.0 / 3.0
        static let gap: CGFloat = 8
        /// Отступ подписи от фотографии (решение пользователя 2026-08-29, было 8)
        static let captionGap: CGFloat = 6
        /// Максимум строк на имя и на пояснение, дальше — многоточие
        static let captionLines = 2
        /// Высота одной строки подписи. Стиль добирает натуральный интервал шрифта до
        /// макетного симметричным вертикальным отступом, поэтому строка занимает ровно
        /// интерлиньяж, а n строк — ровно n интерлиньяжей.
        static var captionLineHeight: CGFloat { MovieTileCaptionType.lineHeight }
    }

    /// Высота подписи под фотографией: строки самого длинного имени секции плюс строки
    /// самого длинного пояснения. Одинакова у всех карточек ряда — иначе ряд снова
    /// поедет за первой видимой карточкой.
    private var captionHeight: CGFloat {
        let name = people.map { TileCaptionRuler.lines($0.name, width: Layout.cardWidth) }.max() ?? 1
        let role = people.map { TileCaptionRuler.lines($0.role ?? "", width: Layout.cardWidth) }.max() ?? 0
        return CGFloat(name + role) * Layout.captionLineHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MovieSectionHeader(title: title)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: Layout.gap) {
                    ForEach(people) { person in
                        card(person)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, MovieLayout.sectionSide, for: .scrollContent)
        }
    }

    private func card(_ person: MovieCastMember) -> some View {
        VStack(alignment: .leading, spacing: Layout.captionGap) {
            photo(person)

            // Зазор между строками ровно нулевой: интерлиньяж до макетных 18 стиль
            // добирает симметричным вертикальным отступом, и шаг на стыке белой
            // и серой строки получается такой же, как внутри самого имени.
            VStack(alignment: .leading, spacing: 0) {
                Text(person.name)
                    .plusMovieTileCaption()
                    .foregroundStyle(Color.fillOne)
                    .lineLimit(Layout.captionLines)
                    // Строка обязана занять свою полную высоту: без этого её ужимает
                    // предложенная сверху, и многоточие встаёт раньше второй строки —
                    // ровно та же засада, что у абзацев описания.
                    .fixedSize(horizontal: false, vertical: true)

                if let role = person.role, !role.isEmpty {
                    Text(role)
                        .plusMovieTileCaption()
                        .foregroundStyle(Color.fillSubtitle)
                        .lineLimit(Layout.captionLines)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(height: captionHeight, alignment: .top)
        }
        .frame(width: Layout.cardWidth, alignment: .leading)
    }

    @ViewBuilder
    private func photo(_ person: MovieCastMember) -> some View {
        let shape = RoundedRectangle(cornerRadius: PlusRadius.card, style: .continuous)

        Color.buttonsSecondary
            .frame(width: Layout.cardWidth)
            .frame(height: Layout.cardWidth / Layout.photoAspect)
            .overlay {
                if let photo = person.photo {
                    // Без бандленного фолбэка: чужое лицо на месте актёра — ложь о контенте.
                    //
                    // Обесцвечивание (решение пользователя 2026-08-29): портреты у КП
                    // разных лет и цветокоррекции, и цветной ряд читался разнобоем.
                    // Плашке-подложке фильтр не нужен — она и так серая.
                    ArtworkImage(source: .remote(photo))
                        .scaledToFill()
                        .grayscale(1)
                }
            }
            .clipShape(shape)
            // Волосяная обводка (решение пользователя 2026-08-29): у обесцвеченных
            // портретов светлый фон, и без неё карточка растворялась в чёрном экране.
            .overlay { shape.strokeBorder(Color.fillNine, lineWidth: PlusMetrics.hairline) }
    }
}

/// Линейка подписи: сколько строк займёт текст в колонке плитки — и под
/// фотографией персоны, и под постером «Похожего».
///
/// Меряет тем же шрифтом и кеглем, которыми текст и рисуется (`MovieTileCaptionType`),
/// поэтому расходиться с раскладкой ей нечем. Потолок подписи — две строки, так что
/// вопрос сводится к «влезает ли в одну»: всё, что длиннее строки, занимает две и
/// дальше режется многоточием, и точная раскладка длинного имени не нужна.
private enum TileCaptionRuler {
    static func lines(_ text: String, width: CGFloat) -> Int {
        guard !text.isEmpty else { return 0 }
        let font = UIFont(name: MovieTileCaptionType.family, size: MovieTileCaptionType.size)
            ?? .systemFont(ofSize: MovieTileCaptionType.size)
        let singleLine = (text as NSString).size(withAttributes: [.font: font]).width
        return singleLine <= width ? 1 : 2
    }
}

// MARK: - Похожее

#if DEBUG
/// Одноразовость `-debugOpenSimilar` на процесс (см. задачу в секции).
private enum MovieSimilarDebug {
    static var fired = false
}
#endif

/// `2104:22862` «You Might Also Like» — сетка 3×N: постер 2:3, подпись 18pt.
/// Ширина карточки считается от ширины холста прототипа (402), а не от замера вью:
/// читать размер вью, от которого зависит её же раскладка, запрещено (DECISIONS).
///
/// **Высота карточки — своя у каждой** (правка пользователя 2026-08-29): однострочное
/// название занимает одну строку, год прижат к нему, и карточка на строку ниже той,
/// где название перенеслось. Общей высоты, как у каруселей персон, здесь не нужно:
/// сетка кладёт ряд целиком, поэтому строка карточек и так меряется по своей самой
/// высокой, а прижимает их к верху `GridItem(alignment: .top)`.
///
/// Тап по карточке открывает экран того тайтла **поверх текущего** — вложенным
/// слоем (`coveredPath` + `CoveredEntityScreen`), текущий фильм не закрывается.
/// Карточка помечает себя источником зума: экран разворачивается из неё, а
/// свайп-назад и крестик сворачивают обратно — к предыдущему фильму.
struct MovieSimilarSection: View {
    let titles: [MovieSimilarTitle]
    @Environment(AppNavigationState.self) private var navigation
    @Environment(\.entityZoomNamespace) private var zoomNamespace

    private enum Layout {
        static let columns = 3
        static let columnGap: CGFloat = 6
        static let rowGap: CGFloat = 8
        static let posterAspect: CGFloat = 2.0 / 3.0
        static let captionGap: CGFloat = 6
        /// Максимум строк на название, дальше — многоточие
        static let titleLines = 2

        static var cardWidth: CGFloat {
            let available = PlusMetrics.designWidth - MovieLayout.sectionSide * 2
            return (available - columnGap * CGFloat(columns - 1)) / CGFloat(columns)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MovieSectionHeader(title: "Похожее")

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.fixed(Layout.cardWidth), spacing: Layout.columnGap, alignment: .top),
                    count: Layout.columns
                ),
                alignment: .leading,
                spacing: Layout.rowGap
            ) {
                ForEach(titles) { title in
                    card(title)
                }
            }
            .padding(.horizontal, MovieLayout.sectionSide)
        }
        #if DEBUG
        // `-debugOpenSimilar <n>` — открыть n-й похожий тайтл: тапнуть симулятор из
        // шелла нечем, а подмену слоя иначе не сверить. Срабатывает один раз на
        // запуск — у нового экрана своя секция «Похожее» с этой же задачей, и без
        // гашения переходы шли бы по цепочке. Гасится статикой, а не снятием ключа:
        // ключ запуска живёт в argument domain и перекрывает постоянный домен.
        .task {
            let index = UserDefaults.standard.integer(forKey: "debugOpenSimilar")
            guard index > 0, index <= titles.count, !MovieSimilarDebug.fired else { return }
            MovieSimilarDebug.fired = true
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let route = titles[index - 1].route else { return }
            navigation.open(route)
        }
        #endif
    }

    /// Карточка с маршрутом — кнопка, без него (нет постера) — просто вью:
    /// прецедент «переходить некуда» ведёт себя так же у «Моей Волны» на витрине.
    @ViewBuilder
    private func card(_ title: MovieSimilarTitle) -> some View {
        if let route = title.route {
            let button = Button { navigation.open(route) } label: { cardBody(title) }
                .buttonStyle(PressScaleButtonStyle())
            // Источник зума вложенного слоя. Namespace приходит от `CoveredEntityScreen`;
            // его может не быть только вне слоя, где секции не бывает, — но падать
            // из-за этого инварианта вёрстке не положено.
            if let zoomNamespace {
                button.matchedTransitionSource(id: route, in: zoomNamespace)
            } else {
                button
            }
        } else {
            cardBody(title)
        }
    }

    private func cardBody(_ title: MovieSimilarTitle) -> some View {
        let shape = RoundedRectangle(cornerRadius: PlusRadius.card, style: .continuous)

        return VStack(alignment: .leading, spacing: Layout.captionGap) {
            Color.buttonsSecondary
                .frame(width: Layout.cardWidth)
                .frame(height: Layout.cardWidth / Layout.posterAspect)
                .overlay {
                    if let poster = title.poster {
                        ArtworkImage(source: .remote(poster)).scaledToFill()
                    }
                }
                .clipShape(shape)
                // Та же волосяная обводка, что у карточек персон
                .overlay { shape.strokeBorder(Color.fillNine, lineWidth: PlusMetrics.hairline) }

            // Подпись набрана как у карточек персон: один стиль на обе строки,
            // зазор между ними нулевой (решение пользователя 2026-08-29).
            VStack(alignment: .leading, spacing: 0) {
                Text(title.title)
                    .plusMovieTileCaption()
                    .foregroundStyle(Color.fillOne)
                    .lineLimit(Layout.titleLines)
                    // Название обязано занять свою полную высоту: без этого его ужимает
                    // предложенная сверху, и многоточие встаёт в конце первой строки.
                    .fixedSize(horizontal: false, vertical: true)

                if let year = title.year {
                    Text(year)
                        .plusMovieTileCaption()
                        .foregroundStyle(Color.fillSubtitle)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(width: Layout.cardWidth, alignment: .leading)
    }
}
