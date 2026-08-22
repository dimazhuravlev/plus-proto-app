import SwiftUI

// MARK: - Движение

/// Тайминги витрины. Значения стартовые — подтверждаются на симуляторе.
enum ShowcaseMotion {
    /// Каскадное появление карточки при въезде в экран.
    static let appear: Animation = .smooth(duration: 0.5)
    /// Насколько карточка приподнимается, пока проявляется.
    static let appearOffset: CGFloat = 24
    /// Доля карточки в кадре, с которой она считается показанной.
    static let appearThreshold: Double = 0.05

    /// Нажатие на карточку: подсаживаем её чуть слабее, чем кнопки хрома —
    /// у карточки большая площадь, и скейл 0.92 читался бы как прыжок.
    static let pressedScale: CGFloat = 0.97
    static let pressDuration: Double = 0.15
    /// Хаптика тапа — та же карта, что у табов (nav-chrome §11).
    static let tapHapticIntensity: CGFloat = 0.7

    /// Глубина параллакса по слоям, pt смещения на весь проход через экран.
    /// Эффект намеренно едва заметный: «лёгкий параллакс» из решения 2026-08-22.
    enum Depth {
        /// Обложка — самый дальний слой, отстаёт сильнее всех.
        static let artwork: CGFloat = 10
        /// Подпись идёт почти вровень с лентой.
        static let caption: CGFloat = 4
        /// Кнопки — ближний слой, слегка обгоняют.
        static let controls: CGFloat = -4
    }
}

// MARK: - Экран

/// Витрина «Плюс» — кросс-сервисная лента (`2004:10701`).
///
/// Раскладка абсолютная, а не стек с отступами: в макете карточки наезжают друг на друга
/// (орб «Моей Волны» начинается раньше, чем кончается книжный блок) и выходят за оба края
/// экрана. Каждый блок знает свой слот — см. `ShowcaseLayout`.
struct ShowcaseFeedView: View {
    let feed: ShowcaseFeed
    @Environment(ActionBarState.self) private var actionBar
    @State private var scrollPosition = ScrollPosition()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ShowcaseHeader(headline: feed.headline)
                    .frame(height: ShowcaseLayout.Slot.header.height)
                    .padding(.top, ShowcaseLayout.Slot.header.top)
                    .showcaseAppear()

                ForEach(Array(feed.blocks.enumerated()), id: \.element.id) { index, block in
                    Button {
                        open(block)
                    } label: {
                        blockView(block)
                            .frame(
                                width: ShowcaseLayout.designWidth,
                                height: block.slot.height,
                                alignment: .topLeading
                            )
                    }
                    .buttonStyle(ShowcaseCardButtonStyle())
                    .padding(.top, gap(before: index))
                    // Наезжающая карточка должна лечь поверх предыдущей, как в макете.
                    .zIndex(Double(index))
                    .showcaseAppear()
                }
            }
            .frame(width: ShowcaseLayout.designWidth)
        }
        .scrollIndicators(.hidden)
        .scrollPosition($scrollPosition)
        // Координаты макета отсчитываются от физического верха экрана, а не от safe area:
        // заголовок на 70.79 должен лечь сразу под статус-бар. Иначе лента съезжает вниз
        // на всю высоту выреза.
        .ignoresSafeArea(edges: .top)
        .background(alignment: .top) {
            ShowcaseBackdrop(source: feed.backdrop)
        }
        #if DEBUG
        .onAppear {
            // `-debugScrollTo <pt>` — стартовая прокрутка: свайпнуть симулятор из шелла нечем,
            // а карточки ниже сгиба иначе не сверить с макетом.
            let offset = UserDefaults.standard.double(forKey: "debugScrollTo")
            if offset > 0 { scrollPosition.scrollTo(y: offset) }

            // `-debugTapBlock <n>` — повторяет тап по n-й карточке: тапнуть по симулятору
            // из шелла нечем, а связь «карточка → плеер» иначе не проверить.
            let tapIndex = UserDefaults.standard.integer(forKey: "debugTapBlock")
            if tapIndex > 0, tapIndex <= feed.blocks.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    actionBar.open(feed.blocks[tapIndex - 1].player)
                }
            }
        }
        #endif
    }

    /// Тап по карточке открывает плеер её сервиса — action bar переезжает в нужный режим.
    private func open(_ block: ShowcaseBlock) {
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
        actionBar.open(block.player)
    }

    /// Зазор над блоком: для первого — от заголовка, дальше — от низа предыдущего.
    private func gap(before index: Int) -> CGFloat {
        let previous = index == 0 ? ShowcaseLayout.Slot.header : feed.blocks[index - 1].slot
        return ShowcaseLayout.gap(above: feed.blocks[index].slot, after: previous)
    }

    @ViewBuilder
    private func blockView(_ block: ShowcaseBlock) -> some View {
        switch block {
        case .movie(let item): MovieCard(block: item)
        case .album(let item): AlbumCard(block: item)
        case .book(let item): BookCard(block: item)
        case .vibe(let item): MyVibeCard(block: item)
        case .reading(let item): ContinueReadingCard(block: item)
        case .watching(let item): ContinueWatchingCard(block: item)
        }
    }
}

/// Нажатие на карточку витрины. Отдельный стиль, а не `PressScaleButtonStyle` хрома:
/// у карточки другой масштаб, и `.plain` нужен, чтобы SwiftUI не красил её содержимое
/// в акцентный цвет и не подсвечивал прямоугольником.
private struct ShowcaseCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? ShowcaseMotion.pressedScale : 1)
            .animation(.smooth(duration: ShowcaseMotion.pressDuration), value: configuration.isPressed)
    }
}

// MARK: - Появление и параллакс

/// Каскадное появление: карточка проявляется и подтягивается вверх, когда въезжает
/// в экран. Срабатывает один раз — обратно при уходе не гаснет, иначе лента мерцала бы
/// при быстром скролле туда-обратно.
private struct ShowcaseAppear: ViewModifier {
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : ShowcaseMotion.appearOffset)
            .onScrollVisibilityChange(threshold: ShowcaseMotion.appearThreshold) { visible in
                guard visible, !shown else { return }
                withAnimation(ShowcaseMotion.appear) { shown = true }
            }
    }
}

extension View {
    func showcaseAppear() -> some View {
        modifier(ShowcaseAppear())
    }

    /// Параллакс слоя внутри карточки: слой смещается тем сильнее, чем дальше карточка
    /// от центра экрана. Считается в `visualEffect` — это GPU-этап без перерасчёта
    /// раскладки, поэтому на скролле бесплатно (требование 120 fps).
    func showcaseParallax(_ depth: CGFloat) -> some View {
        visualEffect { content, proxy in
            let screen = proxy.bounds(of: .scrollView)?.height ?? proxy.size.height
            guard screen > 0 else { return content.offset(y: 0) }
            // −0.5…0.5 — путь карточки от нижней кромки экрана к верхней.
            let progress = (proxy.frame(in: .scrollView).midY - screen / 2) / screen
            return content.offset(y: progress * depth)
        }
    }
}
