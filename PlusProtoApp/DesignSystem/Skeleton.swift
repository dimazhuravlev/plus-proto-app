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
    /// Скелетон этой формы — бледная заливка без кромки: у скелетонов бордера нет нигде
    /// (правка пользователя 2026-10-31). Кромка обложки встаёт вместе с картинкой
    /// (`coverBorder`).
    func plusSkeleton() -> some View {
        fill(PlusSkeleton.fill)
    }
}

/// Бордер обложки — один у всех карточек-айтемов, всех видов: белый 8 % толщиной
/// 0.67 внутрь кадра (правка пользователя 2026-10-05; прежде было то 0.66, то 1,
/// то обводка по центру кромки, а у части обложек бордера не было вовсе).
/// Только у показанной картинки: у скелетона и у обложки, чья картинка ещё едет или
/// которой нет, кромки нет — она проявляется вместе с картинкой (правка пользователя
/// 2026-10-31: «не должно быть бордера в каверах скелетона нигде»).
enum CoverBorder {
    static let color = Color.fillNine
    static let width: CGFloat = 0.67
}

/// Показана ли картинка под бордером обложки: `ResolvedArtwork` сообщает, на месте ли
/// картинка, `coverArtworkMissing` — что её нет вовсе. Ничего не сообщено (обложка
/// не картинкой — градиент, иконка) — бордер стоит.
struct CoverArtworkShownKey: PreferenceKey {
    static let defaultValue: Bool? = nil

    static func reduce(value: inout Bool?, nextValue: () -> Bool?) {
        guard let next = nextValue() else { return }
        value = (value ?? false) || next
    }
}

extension View {
    /// Бордер обложки по её форме — внутрь кадра, как у стекла. Проявляется вместе
    /// с картинкой обложки (`CoverArtworkShownKey`).
    func coverBorder<S: InsettableShape>(_ shape: S) -> some View {
        overlayPreferenceValue(CoverArtworkShownKey.self) { shown in
            shape
                .strokeBorder(CoverBorder.color, lineWidth: CoverBorder.width)
                .opacity(shown == false ? 0 : 1)
                .animation(PlusSkeleton.appear, value: shown)
                .allowsHitTesting(false)
        }
    }

    /// Картинки у обложки нет вовсе — источник пуст: на месте обложки скелетон, и бордера нет.
    func coverArtworkMissing(_ isMissing: Bool) -> some View {
        preference(key: CoverArtworkShownKey.self, value: isMissing ? false : nil)
    }

    /// То же для формы без вставки (`AnyShape`, свой контур): обводка вдвое толще
    /// по центру кромки, обрезанная самой формой, — та же полоса внутрь кадра.
    func coverBorder<S: Shape>(_ shape: S) -> some View {
        overlayPreferenceValue(CoverArtworkShownKey.self) { shown in
            shape
                .stroke(CoverBorder.color, lineWidth: 2 * CoverBorder.width)
                .clipShape(shape)
                .opacity(shown == false ? 0 : 1)
                .animation(PlusSkeleton.appear, value: shown)
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
    /// Как проявляется картинка из сети; по умолчанию — общий фейд скелетона.
    var appear: Animation = PlusSkeleton.appear

    var body: some View {
        if let shown {
            ResolvedArtwork(source: shown, appear: appear) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.clear
            }
        } else {
            // Рисовать нечего — для бордера обложки это скелетон.
            Color.clear.coverArtworkMissing(true)
        }
    }

    private var shown: ArtworkSource? {
        if let url = source.remoteURL { return .remote(url) }
        guard let name = source.fallbackAsset, !name.isEmpty else { return nil }
        return source
    }
}
