import SwiftUI
import VariableBlur

// MARK: - Геометрия

/// Числа макета `2311:27488`. Координаты — от физического верха экрана, как у всех
/// экранов проекта: шапка и затемнение лежат поверх текста, текст уезжает под них.
private enum BookReaderLayout {
    /// Поля колонки текста: 354 из 402.
    static let textInset: CGFloat = 24
    /// Строка текста — Text L・18 / Medium из UI kit (в макете 16/25: кегля 16 в UI kit
    /// нет, а для длинного чтения из пяти кеглей подходит 18 — и его строка 24 ближе
    /// всего к макетным 25, ритм колонки почти не меняется).
    static let lineHeight: CGFloat = PlusTextSize.textL.lineHeight
    /// Абзацы разделены пустой строкой — в макете это пустой абзац высотой в строку.
    static let paragraphGap: CGFloat = lineHeight

    /// Затемнение под шапкой: от верхней кромки (с выносом на 1pt, как в макете)
    /// чёрный держится до 13 % высоты и сходит в ноль к низу.
    static let scrimHeight: CGFloat = 164
    static let scrimTop: CGFloat = -1
    static let scrimSolid: CGFloat = 0.12981
    /// Прогрессивный блюр под затемнением (просьба пользователя 2026-10-03): текст,
    /// уходящий под шапку, не только темнеет, но и расплывается. Полоса блюра короче
    /// затемнения — правило проекта: иначе там, где блюр кончается, резкость
    /// обрывалась бы на ровном месте посреди ещё видимого текста.
    static let scrimBlurRadius: CGFloat = 12
    /// Блюр сходит на нет у нижней кромки строки шапки — как подложка навбара
    /// экранов сущностей. Было 140: текст начинал расплываться ещё на подходе
    /// к шапке (правка пользователя 2026-10-03 — «начинается слишком низко»).
    static var scrimBlurHeight: CGFloat { headerTop + coverSize.height }

    /// Строка шапки — сразу под статус-баром: кнопка закрытия, обложка, подписи.
    static let headerTop: CGFloat = 57
    static let headerSide: CGFloat = 16
    static let closeToCover: CGFloat = 8
    static let coverSize = CGSize(width: 28, height: 40)
    static let coverCorner: CGFloat = 2
    static let coverToTitle: CGFloat = 8
    /// Подпись автора заходит на строку названия: 24 + 20 − 4 = 40, ровно высота обложки.
    static let titleToAuthor: CGFloat = -4

    /// Первая строка в покое стоит в хвосте затемнения — на последних 25pt градиента,
    /// где он уже почти прозрачен: выше она тонула бы в чёрном, ниже оставляла бы
    /// под шапкой пустую полосу. Макет рисует колонку уже прокрученной, покоя в нём нет.
    static var textTop: CGFloat { scrimTop + scrimHeight - lineHeight }

    /// Мини-плеер музыки — круг 60 в правом нижнем углу с полями 16.
    static let musicInset: CGFloat = 16
    /// Воздух под последней строкой, когда текст докручен до конца.
    static let textTail: CGFloat = 24
    /// Без мини-плеера последняя строка выходит из-под home indicator.
    static let homeIndicatorClearance: CGFloat = 34
}

enum BookReaderMotion {
    /// Текст проявляется целиком, когда готов, — одним фейдом, без движения:
    /// колонка не должна набираться на глазах абзац за абзацем.
    static let textAppear: Animation = .easeOut(duration: 0.2)
}

// MARK: - Читалка

/// Читалка — макет `2311:27488`: текст книги во всю колонку, вертикальная прокрутка,
/// шапка с книгой поверх затемнения.
///
/// Мини-плеер музыки в углу есть, только если музыка играла в момент запуска
/// (`ContentPlayer.reader(_, showsMusic:)`, правило пользователя 2026-10-03):
/// читать под музыку — штатный сценарий, и управлять ею надо не выходя из книги.
struct BookReaderView: View {
    let book: BookInProgress
    let showsMusic: Bool
    @Environment(ActionBarState.self) private var actionBar
    @State private var text = BookTextStore()
    @State private var isMusicExpanded = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black
            pages
            scrim
            header
            if showsMusic {
                ReaderMusicPlayer(isExpanded: $isMusicExpanded)
                    .padding(BookReaderLayout.musicInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .ignoresSafeArea()
        .task { await text.load(bookID: book.id) }
    }

    private var pages: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BookReaderLayout.paragraphGap) {
                ForEach(Array(text.pages.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .plusText(.textL, .medium)
                        // Fill 4 — цвет UI kit для текстовых блоков длиннее двух строк.
                        .foregroundStyle(Color.fillFour)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, BookReaderLayout.textInset)
            .padding(.top, BookReaderLayout.textTop)
            .padding(.bottom, textBottom)
            .opacity(text.isReady ? 1 : 0)
            .animation(BookReaderMotion.textAppear, value: text.isReady)
        }
        .scrollIndicators(.hidden)
        // Отступы колонки отмеряются от физических кромок, как в макете, —
        // системные поля безопасной зоны поверх них не нужны.
        .ignoresSafeArea()
        .onScrollPhaseChange { _, phase in
            // Вернулся к чтению — плеер сворачивается обратно в круг:
            // развёрнутый, он закрывает низ колонки.
            guard phase.isScrolling, isMusicExpanded else { return }
            isMusicExpanded = false
        }
    }

    private var textBottom: CGFloat {
        let clearance = showsMusic
            ? BookReaderLayout.musicInset + PlusMetrics.actionBarCompact
            : BookReaderLayout.homeIndicatorClearance
        return clearance + BookReaderLayout.textTail
    }

    private var scrim: some View {
        ZStack(alignment: .top) {
            VariableBlurView(
                maxBlurRadius: BookReaderLayout.scrimBlurRadius,
                direction: .blurredTopClearBottom
            )
            .frame(height: BookReaderLayout.scrimBlurHeight)

            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: BookReaderLayout.scrimSolid),
                    .init(color: .black.opacity(0), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(height: BookReaderLayout.scrimHeight, alignment: .top)
        .offset(y: BookReaderLayout.scrimTop)
        .allowsHitTesting(false)
    }

    private var header: some View {
        HStack(spacing: BookReaderLayout.closeToCover) {
            GlassIconButton(icon: "iconCross", accessibilityTitle: "Закрыть") {
                actionBar.closeContentPlayer()
            }
            HStack(spacing: BookReaderLayout.coverToTitle) {
                cover
                titles
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.top, BookReaderLayout.headerTop)
        .padding(.horizontal, BookReaderLayout.headerSide)
    }

    /// Кадр задаёт распорка, картинка его заполняет — идиома проекта: наоборот
    /// `scaledToFill` отдал бы наверх размер картинки, а не обложки.
    private var cover: some View {
        let shape = RoundedRectangle(cornerRadius: BookReaderLayout.coverCorner, style: .continuous)
        return Color.clear
            .frame(width: BookReaderLayout.coverSize.width, height: BookReaderLayout.coverSize.height)
            .overlay { ArtworkImage(source: book.cover).scaledToFill() }
            .clipShape(shape)
    }

    /// Подписи прижаты к верху бокса обложки, а не центрированы по ней: автор может
    /// доехать из API позже названия, и центрированное название прыгнуло бы вверх.
    private var titles: some View {
        VStack(alignment: .leading, spacing: BookReaderLayout.titleToAuthor) {
            Text(book.title)
                .plusText(.textL, .semibold)
                .foregroundStyle(Color.fillOne)
            if let author = book.author ?? text.author {
                Text(author)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillSubtitle)
                    .transition(.opacity)
            }
        }
        .lineLimit(1)
        .frame(height: BookReaderLayout.coverSize.height, alignment: .top)
        .animation(BookReaderMotion.textAppear, value: text.author)
    }
}

// MARK: - Музыка в читалке

/// Мини-плеер музыки — тот же компонент, что в action bar, в компактном варианте
/// (`2338:18126`): круг 60 с обложкой. Тап разворачивает его в пилюлю с подписями
/// и play/pause, как круг в баре (правило 2026-08-29). Свернуть — тапом по пилюле
/// или прокруткой текста: полноэкранного плеера музыки поверх читалки нет, поэтому
/// широкая пилюля здесь ведёт обратно в круг, а не дальше.
private struct ReaderMusicPlayer: View {
    @Environment(ActionBarState.self) private var actionBar
    @Binding var isExpanded: Bool

    var body: some View {
        if let music = actionBar.music {
            MiniPlayerPill(
                item: music,
                trackInfoOpacity: isExpanded ? 1 : 0,
                progressOpacity: isExpanded ? 1 : 0,
                progress: actionBar.musicProgress,
                isPlaying: actionBar.isMusicPlaying,
                isLiked: actionBar.isMusicLiked,
                onTogglePlay: { actionBar.toggleMusicPlayback() },
                onToggleLike: { actionBar.toggleMusicLike() },
                onExpand: { isExpanded.toggle() }
            )
            // Ширина и кривая — те же, что у пилюли в баре: правый край стоит,
            // левый уезжает, внутренности только проявляются.
            .frame(width: isExpanded ? ActionBarGeometry.miniPlayerExpandedWidth : PlusMetrics.actionBarCompact)
            .animation(ActionBarMotion.morph, value: isExpanded)
        }
    }
}
