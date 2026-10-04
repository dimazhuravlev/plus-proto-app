import SwiftUI

/// Скелетоны и плейсхолдеры картинок — **один** цвет и одно поведение на весь проект
/// (правка пользователя 2026-10-03: «единый цвет и поведение анимации для всех
/// скелетонов/плейсхолдеров»). Карусели выдачи, строки полного списка, колдунщик —
/// все берут отсюда, поэтому разъехаться им не в чем.
enum PlusSkeleton {
    /// Бледный серый — белый 8 % (`fillNine`): и сам скелетон, и подложка под ещё
    /// не приехавшей картинкой. Второго, яркого серого нет (решение 2026-10-03).
    static let fill = Color.fillNine
    /// Как картинка проявляется на месте скелетона: 150 мс ease-out. Из кэша — сразу.
    static let appear: Animation = .easeOut(duration: 0.15)
}

extension Shape {
    /// Скелетон этой формы: бледная заливка с хайрлайном той же краски по кромке —
    /// кромка видна и у пустого скелетона, и у загруженной картинки.
    func plusSkeleton() -> some View {
        fill(PlusSkeleton.fill)
            .overlay { stroke(PlusSkeleton.fill, lineWidth: PlusMetrics.hairline) }
    }
}

/// Живая картинка поверх скелетона: заливку под ней рисует вызывающий, сама картинка
/// проявляется на ней за 150 мс (из кэша — сразу), как обложки выдачи поиска.
///
/// Бандленный фолбэк живого источника здесь не рисуется: моковая обложка на месте
/// ещё не приехавшей — чужой альбом под чужим названием, и на каждой загрузке карусели
/// альбомов исполнителя мелькал «другой альбом» (жалоба пользователя 2026-10-04).
/// Бандленный ассет без сети (моковая витрина) — рисуется как есть; пустое имя —
/// «картинки нет», под ним остаётся скелетон.
struct SkeletonArtwork: View {
    let source: ArtworkSource

    var body: some View {
        if let shown {
            ResolvedArtwork(source: shown, appear: PlusSkeleton.appear) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.clear
            }
        }
    }

    private var shown: ArtworkSource? {
        if let url = source.remoteURL { return .remote(url) }
        guard let name = source.fallbackAsset, !name.isEmpty else { return nil }
        return source
    }
}
