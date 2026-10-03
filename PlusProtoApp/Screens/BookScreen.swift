import SwiftUI

// MARK: - Геометрия

/// Числа макета `2427:26464`. Холст макета — 375, у проекта 402: поля 16 остаются,
/// колонка становится шире, обложка и кнопка по высоте те же.
private enum BookScreenLayout {
    static let sideInset: CGFloat = 16
    /// Блок обложки: обложка 216×324 со скруглением 12, по 8 сверху и снизу.
    static let coverSize = CGSize(width: 216, height: 324)
    static let coverCorner: CGFloat = 12
    static let coverPadding: CGFloat = 8
    /// Название и автор: по 8 сверху и снизу, между ними 8.
    static let textPadding: CGFloat = 8
    static let titleToAuthor: CGFloat = 8
    /// Кнопка «Читать» — компонент `12:8770` (Size=xl, Type=accent, Icon=leading):
    /// глиф 24 и по 14 сверху и снизу, поля 22/26. Вокруг — 8 + 12 сверху и снизу
    /// и ряд с полями 10.
    static let buttonHeight: CGFloat = 52
    static let buttonIcon: CGFloat = 24
    static let buttonIconGap: CGFloat = 8
    static let buttonLeading: CGFloat = 22
    static let buttonTrailing: CGFloat = 26
    static let buttonRowInset: CGFloat = 10
    static let buttonsInnerPadding: CGFloat = 12
    static let buttonsOuterPadding: CGFloat = 8
    /// Описание: 8 сверху, 16 снизу, абзацы через 16.
    static let descriptionTop: CGFloat = 8
    static let descriptionBottom: CGFloat = 16
    static let paragraphGap: CGFloat = 16
    /// Свечение за обложкой — два градиента во всю ширину экрана, стык на середине
    /// обложки: вверх 164, вниз 160, каждый с прозрачностью 0.4.
    static let glowRise: CGFloat = 164
    static let glowFall: CGFloat = 160
    static let glowOpacity: Double = 0.4
    /// Цвет макета — если тон обложки снять не вышло (картинки нет вовсе).
    static let designGlow = Color(red: 1, green: 0, blue: 0)
    /// Навбар: подложка проявляется, когда обложка наполовину ушла под бар, а обложка
    /// с названием в баре — когда под него уходит название под обложкой
    /// (блок обложки 340, название начинается на 348).
    static let navBarThresholds = EntityNavBarThresholds(
        backgroundStart: 180,
        backgroundRamp: 80,
        titleStart: 340,
        titleRamp: 60
    )
}

enum BookScreenMotion {
    /// Свечение, автор и описание проявляются по приходу данных — одним фейдом,
    /// без движения: раскладка под ними уже стоит.
    static let appear: Animation = .easeOut(duration: 0.25)
}

// MARK: - Экран

/// Экран книги — макет `2427:26464`: обложка со свечением её цвета, название
/// и автор, акцентная «Читать», описание. Сверху — общий навбар с «назад»
/// и «поделиться»; обложка с названием приезжают в него по скроллу, как на альбоме.
struct BookScreen: View {
    let entity: EntityRef
    @Environment(ActionBarState.self) private var actionBar
    /// Автор и описание — из того же захода в Google Books, что и текст читалки.
    @State private var text = BookTextStore()
    @State private var glow: Color?
    @State private var scrollOffset: CGFloat = 0
    #if DEBUG
    /// `-debugTapPlay` уже нажал «Читать» на этом экране: читалка открывается
    /// поверх, и на её закрытии экран возвращается в окно — `.task` стартует заново.
    @State private var didDebugTapPlay = false
    #endif

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                readButton
                description
            }
            .animation(BookScreenMotion.appear, value: text.isReady)
        }
        .scrollIndicators(.hidden)
        .trackNavBarScroll(into: $scrollOffset)
        .background(Color.black.ignoresSafeArea())
        // Верх освобождён под навбар: он висит оверлеем и контент не поджимает.
        .safeAreaPadding(.top, EntityNavBarGeometry.barHeight)
        .overlay(alignment: .top) {
            // Общий навбар как есть: кнопки 40, поля 16 с обеих сторон — правка
            // пользователя 2026-10-03 поверх макета, где кнопки 32 (`Size=sm`).
            EntityNavBar(
                title: entity.title,
                artwork: entity.artwork,
                scrollOffset: scrollOffset,
                thresholds: BookScreenLayout.navBarThresholds
            ) {
                // Поделиться пока нечем — кнопка из макета, с пресс-стейтом.
                GlassIconButton(icon: "iconShare", accessibilityTitle: "Поделиться")
            }
        }
        // Системный бар выключен: на пуше он рисовал бы свой back поверх нашего.
        .toolbar(.hidden, for: .navigationBar)
        .task { await text.load(bookID: entity.id) }
        .task(id: entity.artwork) {
            let color = await ArtworkLoader.shared.glow(for: entity.artwork)
            glow = color ?? BookScreenLayout.designGlow
        }
        #if DEBUG
        // `-debugTapPlay` — нажать «Читать»: из шелла тапнуть нечем.
        .task {
            guard UserDefaults.standard.bool(forKey: "debugTapPlay"), !didDebugTapPlay else { return }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            didDebugTapPlay = true
            startReading()
        }
        #endif
    }

    // MARK: Шапка

    private var header: some View {
        VStack(spacing: 0) {
            cover
                .padding(.vertical, BookScreenLayout.coverPadding)
            titles
                .padding(.vertical, BookScreenLayout.textPadding)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, BookScreenLayout.sideInset)
        // Свечение — во всю ширину экрана, а не колонки, и под обложкой.
        .background(alignment: .top) { glowBand }
    }

    /// Кадр задаёт распорка, картинка его заполняет — идиома проекта: наоборот
    /// `scaledToFill` отдал бы наверх размер картинки, а не обложки.
    private var cover: some View {
        let shape = RoundedRectangle(cornerRadius: BookScreenLayout.coverCorner, style: .continuous)
        return Color.clear
            .frame(width: BookScreenLayout.coverSize.width, height: BookScreenLayout.coverSize.height)
            .overlay { ArtworkImage(source: entity.artwork).scaledToFill() }
            .clipShape(shape)
    }

    /// Полоса свечения: от прозрачного к цвету и обратно, стык — на середине обложки.
    /// Пока тон обложки не снят, полосы нет: подмена красного макетного на настоящий
    /// цвет на глазах читалась бы миганием.
    private var glowBand: some View {
        let color = glow ?? .clear
        return VStack(spacing: 0) {
            LinearGradient(colors: [color.opacity(0), color], startPoint: .top, endPoint: .bottom)
                .frame(height: BookScreenLayout.glowRise)
            LinearGradient(colors: [color, color.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: BookScreenLayout.glowFall)
        }
        .opacity(glow == nil ? 0 : BookScreenLayout.glowOpacity)
        .offset(y: BookScreenLayout.coverPadding + BookScreenLayout.coverSize.height / 2 - BookScreenLayout.glowRise)
        .animation(BookScreenMotion.appear, value: glow)
        .allowsHitTesting(false)
    }

    private var titles: some View {
        VStack(spacing: BookScreenLayout.titleToAuthor) {
            Text(entity.title)
                .plusHeadline(EntityTitleType.style(for: entity.title))
                .foregroundStyle(Color.fillOne)
            // Строка автора держит место и до ответа API: иначе кнопка и описание
            // съехали бы вниз на её высоту прямо на глазах.
            Text(author ?? " ")
                .plusText(.textM, .medium)
                .foregroundStyle(Color.fillSubtitle)
                .opacity(author == nil ? 0 : 1)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    /// Из поиска книга приходит с автором, с витрины — без: тогда он из API.
    private var author: String? {
        entity.subtitle.isEmpty ? text.author : entity.subtitle
    }

    // MARK: Кнопка

    private var readButton: some View {
        Button(action: startReading) {
            HStack(spacing: BookScreenLayout.buttonIconGap) {
                MovieIcon(name: "iconRead", box: BookScreenLayout.buttonIcon)
                Text("Читать")
                    .plusText(.textM, .semibold)
                    .foregroundStyle(Color.fillOne)
                    .fixedSize()
            }
            .padding(.leading, BookScreenLayout.buttonLeading)
            .padding(.trailing, BookScreenLayout.buttonTrailing)
            .frame(maxWidth: .infinity)
            .frame(height: BookScreenLayout.buttonHeight)
            // Общий акцентный стиль ДС — тот же, что у «Смотреть» и «Слушать»:
            // это одна и та же кнопка «включить контент».
            .accentButtonSurface()
        }
        .buttonStyle(PressScaleButtonStyle())
        .padding(.horizontal, BookScreenLayout.buttonRowInset)
        .padding(.vertical, BookScreenLayout.buttonsInnerPadding)
        .padding(.horizontal, BookScreenLayout.sideInset)
        .padding(.vertical, BookScreenLayout.buttonsOuterPadding)
    }

    // MARK: Описание

    @ViewBuilder
    private var description: some View {
        if !text.annotation.isEmpty {
            VStack(alignment: .leading, spacing: BookScreenLayout.paragraphGap) {
                ForEach(Array(text.annotation.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillFour)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, BookScreenLayout.descriptionTop)
            .padding(.bottom, BookScreenLayout.descriptionBottom)
            .padding(.horizontal, BookScreenLayout.sideInset)
            .transition(.opacity)
        }
    }

    // MARK: Действия

    /// «Читать» открывает читалку и кладёт книгу в бар: переход на экран
    /// ни того, ни другого не делает (правка пользователя 2026-08-28).
    private func startReading() {
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
        actionBar.open(.book(BookInProgress(
            id: entity.id,
            cover: entity.artwork,
            title: entity.title,
            author: author
        )))
    }
}
