import SwiftUI

/// Числа «Открытого плейлиста» — `card / music / open playlist` (`17168:26867` файла
/// «ЯПС · Mobile · Current State», холст 375): карточка во всю ширину за полями 16,
/// шапка «▶ + название», под ней колонки по три трека.
enum MusicOpenPlaylistLayout {
    static let side: CGFloat = 16
    static let radius: CGFloat = 24
    /// Поля карточки сверху и снизу (`py-[16px]`)
    static let verticalPadding: CGFloat = 16
    static let headerBottom: CGFloat = 12
    static let headerGap: CGFloat = 8
    static let playButton = PlusButtonSize.l
    static let tracksPerColumn = 3
    /// Строка трека — 64: обложка 48 и по 8 сверху и снизу. У крайних строк колонки поле
    /// со стороны края снято (`pb-[8px]` у первой, `pt-[8px]` у последней) — колонка 176.
    static let rowInset: CGFloat = 8
    static var columnHeight: CGFloat {
        CGFloat(tracksPerColumn) * EntityTrackRow.height - 2 * rowInset
    }
    /// Колонка — 303 при карточке 343: следующая выглядывает из-за правой кромки карточки
    /// на 40 на любой ширине, колонка растёт с экраном. Поля 16 — внутри колонки.
    static let peek: CGFloat = 40
    @MainActor
    static var columnWidth: CGFloat { PlusGrid.columnWidth(side: side, peek: side + peek) }
}

/// «Открытый плейлист» — общая карточка Музыки (задача пользователя 2026-10-31): название
/// с ▶ и треки колонками по три (`EntityTrackRow`, как «Популярные треки» исполнителя).
/// ▶ включает плейлист с первого трека, на играющем — пауза и продолжение; тап по строке —
/// этот трек, дальше очередь плейлиста. Пока стоит только на «Главной».
struct MusicOpenPlaylistCard: View {
    let title: String
    let tracks: [MusicNowPlaying]

    @Environment(ActionBarState.self) private var actionBar

    private typealias Layout = MusicOpenPlaylistLayout

    /// Трек плейлиста в баре — на нём ▶ работает паузой.
    private var current: MusicNowPlaying? {
        guard let music = actionBar.music else { return nil }
        return tracks.first { $0.id == music.id }
    }

    private var isPlaying: Bool { current != nil && actionBar.isMusicPlaying }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Layout.radius, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            header
            columns
        }
        .padding(.vertical, Layout.verticalPadding)
        .frame(maxWidth: .infinity)
        .background(Color.fillNine, in: shape)
        .clipShape(shape)
        .coverBorder(shape)
        .padding(Layout.side)
    }

    private var header: some View {
        HStack(spacing: Layout.headerGap) {
            PlusButton(
                type: .secondary,
                size: Layout.playButton,
                accessibilityTitle: isPlaying ? "Пауза" : "Слушать «\(title)»",
                haptic: .inAction
            ) {
                playAll()
            } icon: {
                PlayPauseGlyph(isPlaying: isPlaying, box: Layout.playButton.iconBox)
            }
            Text(title)
                .plusHeadline(.l)
                .foregroundStyle(Color.fillOne)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.horizontal, Layout.side)
        .padding(.bottom, Layout.headerBottom)
    }

    private var columns: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 0) {
                ForEach(columnStarts, id: \.self) { start in
                    column(from: start)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .frame(height: Layout.columnHeight)
    }

    private var columnStarts: [Int] {
        Array(stride(from: 0, to: tracks.count, by: Layout.tracksPerColumn))
    }

    private func column(from start: Int) -> some View {
        let end = min(start + Layout.tracksPerColumn, tracks.count)
        return VStack(spacing: 0) {
            ForEach(start..<end, id: \.self) { index in
                let track = tracks[index]
                EntityTrackRow(
                    cover: track.cover,
                    title: track.title,
                    artist: track.artist,
                    isExplicit: track.isExplicit ?? false,
                    showsDivider: index < end - 1
                )
                .onTapGesture { play(at: index) }
            }
        }
        // Строки — по 64, у колонки крайние поля сняты: обложки встают по её кромкам.
        .padding(.vertical, -Layout.rowInset)
        .padding(.horizontal, Layout.side)
        .frame(width: Layout.columnWidth)
    }

    private func playAll() {
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
        if let current {
            // Тот же трек — `open` ставит паузу или продолжает.
            actionBar.open(.music(current))
        } else if let first = tracks.first {
            actionBar.open(.music(first), queue: tracks, at: 0)
        }
    }

    /// Тот же вход, что у треклиста: `open` с тем же id — пауза/продолжение, с другим — запуск.
    private func play(at index: Int) {
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
        actionBar.open(.music(tracks[index]), queue: tracks, at: index)
    }
}
