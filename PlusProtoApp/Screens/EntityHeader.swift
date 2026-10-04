import SwiftUI

// MARK: - Резиновая шапка

/// Числа шапки экранов альбома и книги — одни на оба (правка пользователя 2026-10-04:
/// «логично сделать единый шерред компонент»). Сняты с альбома `2079:11226`: холст
/// макета 375, прототип 402, кавер стоит под навбаром.
enum EntityCoverLayout {
    /// Верх обложки в покое — под навбаром. У альбома это был центр квадратной зоны
    /// 402, опущенный на 29 (`top: calc(50% + 29px)`), при кавере 247: 106.5.
    static let coverTop: CGFloat = 106.5
    /// Зазор от низа обложки до названия — 16, в линию с полями экрана (правки
    /// пользователя 2026-08-29).
    static let coverToTitle: CGFloat = 16
    /// Фон уходит ниже обложки на 48.5 — там градиент уже довёл его до чёрного.
    /// У альбома ровно столько оставалось от квадрата 402 под кавером.
    static let backdropTail: CGFloat = 48.5
    /// Фон — сама обложка: blur 30 + чёрный 30 % + градиент к чёрному снизу.
    static let backdropBlur: CGFloat = 30
    static let backdropDim: Double = 0.3
    /// Поля контента — 16, как у всего контента экранов сущностей.
    static let side: CGFloat = 16

    /// Сколько шапка занимает в потоке: от верха экрана до названия.
    static func zoneHeight(coverHeight: CGFloat) -> CGFloat {
        coverTop + coverHeight + coverToTitle
    }

    /// Высота фона. Рисуется больше зоны и заходит под блок названия — там он уже
    /// чёрный по градиенту, и захода не видно.
    static func backdropHeight(coverHeight: CGFloat) -> CGFloat {
        coverTop + coverHeight + backdropTail
    }

    /// Обложка растёт за оттягом до ширины экрана минус поля 16, дальше стоит.
    static func maxCoverScale(coverWidth: CGFloat) -> CGFloat {
        (PlusMetrics.designWidth - side * 2) / max(coverWidth, 1)
    }

    /// Пороги навбара: подложка приезжает, когда шапка почти ушла под бар,
    /// название — когда под бар уходит сам заголовок. Отсчёт — от верха названия
    /// (низ зоны): у альбома это были 247.5 и 347.5 при зоне 369.5.
    static func navBarThresholds(coverHeight: CGFloat) -> EntityNavBarThresholds {
        let titleTop = zoneHeight(coverHeight: coverHeight)
        return EntityNavBarThresholds(
            backgroundStart: titleTop - 122,
            backgroundRamp: 80,
            titleStart: titleTop - 22,
            titleRamp: 90
        )
    }
}

/// Резиновая шапка экрана сущности: фон — размытая копия обложки — и сама обложка
/// тянутся за оттягом вниз (альбом и книга, общий компонент с 2026-10-04).
///
/// Резина — на чистых transform'ах, ни одного пересчёта layout на кадр. Оба слоя
/// компенсируют оттяг `offset(y: -pull)` (контент едет вниз, слой — нет), а рост даёт
/// `scaleEffect` с якорем в верхней кромке:
/// - фон тянется ровно на величину оттяга — его низ остаётся приклеен к блоку названия;
/// - обложка растёт пункт-в-пункт с пальцем по высоте до ширины экрана минус поля 16,
///   дальше стоит.
/// Порядок `scaleEffect → offset` обязателен: наоборот скейл умножил бы и смещение.
struct EntityCoverHeader<Cover: View>: View {
    let artwork: ArtworkSource
    /// Габарит обложки в покое — от него считаются зона, фон и рост.
    let coverSize: CGSize
    /// Скролл экрана (`trackNavBarScroll`): отрицательный — оттяг.
    let scrollOffset: CGFloat
    /// Прозрачность фона: у книги он проявляется вместе с обложкой.
    var backdropOpacity: Double = 1
    @ViewBuilder var cover: Cover

    /// Оттяг вниз. Скролл вверх шапку не трогает — она обычным образом уезжает.
    private var pull: CGFloat { max(0, -scrollOffset) }

    /// Сколько «роста» получают фон и обложка. В жизни равно оттягу; в дебаге
    /// (`-debugAlbumPull <pt>`) к нему добавляется подставной, а компенсация смещения
    /// остаётся на реальном: подставной оттяг контент вниз не сдвигал.
    private var growth: CGFloat {
        #if DEBUG
        pull + CGFloat(UserDefaults.standard.double(forKey: "debugAlbumPull"))
        #else
        pull
        #endif
    }

    var body: some View {
        let backdropHeight = EntityCoverLayout.backdropHeight(coverHeight: coverSize.height)
        let backdropScale = (backdropHeight + growth) / backdropHeight
        let coverScale = min(
            EntityCoverLayout.maxCoverScale(coverWidth: coverSize.width),
            1 + growth / coverSize.height
        )

        ZStack(alignment: .top) {
            backdrop(height: backdropHeight)
                .scaleEffect(backdropScale, anchor: .top)
                .offset(y: -pull)
                .opacity(backdropOpacity)

            cover
                .frame(width: coverSize.width, height: coverSize.height)
                .scaleEffect(coverScale, anchor: .top)
                .offset(y: EntityCoverLayout.coverTop - pull)
        }
        .frame(maxWidth: .infinity)
        // По верху обязательно: содержимое зоны выше её кадра (фон рисуется на всю
        // свою высоту), а `frame(height:)` по умолчанию центрирует переполнение —
        // обложка уезжала вверх на половину разницы.
        .frame(height: EntityCoverLayout.zoneHeight(coverHeight: coverSize.height), alignment: .top)
    }

    /// Фон — сама обложка: blur 30, чёрный 30 % и 16-стоповый градиент к чёрному
    /// снизу (профиль общий с панелями карточки фильма — в макете те же стопы).
    private func backdrop(height: CGFloat) -> some View {
        ArtworkImage(source: artwork)
            .scaledToFill()
            .frame(width: PlusMetrics.designWidth, height: height)
            .clipped()
            .blur(radius: EntityCoverLayout.backdropBlur, opaque: true)
            .overlay(Color.black.opacity(EntityCoverLayout.backdropDim))
            .overlay(MovieScrim.gradient(peak: 1, from: .top, to: .bottom))
            .allowsHitTesting(false)
    }
}

// MARK: - Блок названия

/// Числа блока названия альбома `736:108141` — общие с книгой.
enum EntityTitleLayout {
    static let blockGap: CGFloat = 12
    static let titleToPerson: CGFloat = 4
    static let blockBottom: CGFloat = 24
    static let personRowGap: CGFloat = 8
    static let avatarSize: CGFloat = 40
    /// Отрицательный зазор двухстрочного текстового лейбла (`mb-[-2px]` в макете)
    static let textStackGap: CGFloat = -2
    /// Пилюля главного действия `736:106975`
    static let primaryLeading: CGFloat = 16
    static let primaryTrailing: CGFloat = 20
    static let primaryVertical: CGFloat = 10
    static let primaryGap: CGFloat = 6
    static let primaryIconBox: CGFloat = 20
    /// Скелетоны строки персоны — `PlusSkeleton`, полосы 12 по центрам строк Text M.
    static let skeletonBar: CGFloat = 12
    static let skeletonNameWidth: CGFloat = 120
    static let skeletonDetailWidth: CGFloat = 44
}

/// Блок под шапкой: название (кегль ступенью от длины, `EntityTitleType`), строка
/// персоны — исполнитель или автор, — и ряд действий: пилюля главного действия
/// и круглые «нравится», «скачать», «поделиться». Альбом и книга (2026-10-04).
struct EntityTitleBlock<Person: View, Primary: View>: View {
    let title: String
    @ViewBuilder var person: Person
    @ViewBuilder var primary: Primary

    var body: some View {
        VStack(alignment: .leading, spacing: EntityTitleLayout.blockGap) {
            VStack(alignment: .leading, spacing: EntityTitleLayout.titleToPerson) {
                Text(title)
                    .plusHeadline(EntityTitleType.style(for: title))
                    .foregroundStyle(Color.fillOne)
                person
            }

            HStack(spacing: 0) {
                primary
                Spacer(minLength: 8)
                // Действия в прототипе не спроектированы — кнопки только откликаются.
                HStack(spacing: PlusMetrics.circleButtonGap) {
                    GlassIconButton(icon: "iconLove", accessibilityTitle: "Нравится")
                    GlassIconButton(icon: "iconDownload", accessibilityTitle: "Скачать")
                    GlassIconButton(icon: "iconShare", accessibilityTitle: "Поделиться")
                }
            }
        }
        .padding(.horizontal, EntityCoverLayout.side)
        .padding(.bottom, EntityTitleLayout.blockBottom)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Пилюля главного действия — «Слушать», «Читать»: глиф 20 и Text M Semibold
/// в общем акцентном стиле ДС (`accentButtonSurface`, `2103:15149`).
struct EntityPrimaryButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: EntityTitleLayout.primaryGap) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: EntityTitleLayout.primaryIconBox, height: EntityTitleLayout.primaryIconBox)
                    .foregroundStyle(Color.fillOne)

                Text(title)
                    .plusText(.textM, .semibold)
                    .foregroundStyle(Color.fillOne)
            }
            .padding(.leading, EntityTitleLayout.primaryLeading)
            .padding(.trailing, EntityTitleLayout.primaryTrailing)
            .padding(.vertical, EntityTitleLayout.primaryVertical)
            .accentButtonSurface()
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

/// Строка персоны: круглое фото 40 и две строки — имя и подпись (год). Всё, чего ещё
/// нет, стоит скелетоном и проявляется на месте (у книги — из сети, у альбома всё
/// известно сразу).
struct EntityPersonRow: View {
    enum Picture: Equatable {
        /// Фото ещё ищется — скелетон круга
        case loading
        case artwork(ArtworkSource)
        /// Фото нет — первая буква имени на круге
        case monogram(String)
    }

    let picture: Picture
    /// `nil` — имя ещё едет (скелетон)
    let name: String?
    let detail: String?
    /// Подпись ещё едет — на её месте скелетон
    var isDetailLoading = false

    var body: some View {
        HStack(spacing: EntityTitleLayout.personRowGap) {
            avatar

            VStack(alignment: .leading, spacing: EntityTitleLayout.textStackGap) {
                ZStack(alignment: .leading) {
                    if let name {
                        Text(name)
                            .plusText(.textM, .medium)
                            .foregroundStyle(Color.fillOne)
                            .lineLimit(1)
                            .transition(.opacity)
                    } else {
                        skeletonLine(width: EntityTitleLayout.skeletonNameWidth)
                    }
                }

                ZStack(alignment: .leading) {
                    if isDetailLoading {
                        skeletonLine(width: EntityTitleLayout.skeletonDetailWidth)
                    } else if let detail {
                        Text(detail)
                            .plusText(.textM, .medium)
                            .foregroundStyle(Color.fillSubtitle)
                            .transition(.opacity)
                    }
                }
            }
        }
    }

    private var avatar: some View {
        let size = EntityTitleLayout.avatarSize
        return ZStack {
            switch picture {
            case .loading:
                Circle().fill(PlusSkeleton.fill)
                    .transition(.opacity)
            case .artwork(let source):
                ArtworkImage(source: source)
                    .scaledToFill()
                    .transition(.opacity)
            case .monogram(let letter):
                Circle().fill(Color.buttonsPrimary)
                    .overlay {
                        Text(letter)
                            .plusText(.textM, .semibold)
                            .foregroundStyle(Color.fillSubtitle)
                    }
                    .transition(.opacity)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay { Circle().stroke(Color.fillNine, lineWidth: PlusMetrics.hairline) }
    }

    /// Полоса скелетона по центру строки Text M — того же габарита, что текст.
    private func skeletonLine(width: CGFloat) -> some View {
        Rectangle()
            .fill(PlusSkeleton.fill)
            .frame(width: width, height: EntityTitleLayout.skeletonBar)
            .frame(height: PlusTextSize.textM.lineHeight)
            .transition(.opacity)
            .accessibilityHidden(true)
    }
}
