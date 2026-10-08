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
    /// Скругление полос на месте текста — небольшое, одно на всё приложение
    /// (правка пользователя 2026-10-04; прежде углы были прямые). У скелетонов
    /// карточек скругление своё — то же, что у загруженной карточки.
    static let textRadius: CGFloat = 4
}

/// Полоса скелетона на месте строки текста.
struct SkeletonBar: View {
    let width: CGFloat
    var height: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: PlusSkeleton.textRadius, style: .continuous)
            .fill(PlusSkeleton.fill)
            .frame(width: width, height: height)
    }
}

extension Shape {
    /// Скелетон этой формы: бледная заливка с той же кромкой, что у обложки
    /// (`coverBorder`), — карточка встаёт на его место без смены рисунка.
    func plusSkeleton() -> some View {
        fill(PlusSkeleton.fill)
            .coverBorder(self)
    }
}

/// Бордер обложки — один у всех карточек-айтемов, всех видов: белый 8 % толщиной
/// 0.67 внутрь кадра (правка пользователя 2026-10-05; прежде было то 0.66, то 1,
/// то обводка по центру кромки, а у части обложек бордера не было вовсе).
/// Кромка видна и у пустого скелетона, и у загруженной картинки.
enum CoverBorder {
    static let color = Color.fillNine
    static let width: CGFloat = 0.67
}

extension View {
    /// Бордер обложки по её форме — внутрь кадра, как у стекла.
    func coverBorder<S: InsettableShape>(_ shape: S) -> some View {
        overlay {
            shape
                .strokeBorder(CoverBorder.color, lineWidth: CoverBorder.width)
                .allowsHitTesting(false)
        }
    }

    /// То же для формы без вставки (`AnyShape`, свой контур): обводка вдвое толще
    /// по центру кромки, обрезанная самой формой, — та же полоса внутрь кадра.
    func coverBorder<S: Shape>(_ shape: S) -> some View {
        overlay {
            shape
                .stroke(CoverBorder.color, lineWidth: 2 * CoverBorder.width)
                .clipShape(shape)
                .allowsHitTesting(false)
        }
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
