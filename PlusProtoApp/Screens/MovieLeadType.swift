import SwiftUI
import UIKit

/// Кегль лида карточки тайтла и его замер.
///
/// **Почему не 32, как в макете.** Лид — это «аргумент» Кинопоиска (`shortDescription`),
/// редакционная однострочка с жёстким потолком: замер по 100 тайтлам топ-250 дал
/// 81…111 символов, медиана 106. Макет рассчитан ровно на такую длину (его собственный
/// лимит копирайта — 100 символов) и укладывает её в 4 строки по 297pt.
///
/// Но макет набран **Yango Group Headline**, а у нас его нет — бандлится YS Display,
/// и он заметно шире: на 32 кегле Yango вмещает ~23 символа в строку, YS Display — ~14.
/// Тот же аргумент разворачивается в 6–10 строк (замер по метрикам бандленного
/// `YS Display-Bold.ttf`, сверен с рендером на симуляторе — разбивка совпала слово в слово).
/// Инфо-блок при этом раздувается втрое и съедает кавер целиком.
///
/// Поэтому компенсируем кеглем: узкий шрифт заменён широким — размер уменьшен так,
/// чтобы в строку влезало столько же символов, сколько в макете. Резать лид нельзя:
/// аргумент — законченная фраза из двух частей, и обрыв убивает вторую.
enum MovieLeadType {
    /// Кегль лида. 32 × (14 / 23) ≈ 20 вернуло бы ровно макетную раскладку;
    /// 24 оставляет лиду вес заголовка ценой одной-двух лишних строк.
    static let size: CGFloat = 24
    /// Интерлиньяж макета — 110 % кегля
    static let lineHeight: CGFloat = size * 1.1

    /// Высота отрисованного лида в колонке `MovieLayout.leadWidth`.
    ///
    /// Замер строки, а не вью: обратной связи нет — высота зависит только от текста
    /// и фиксированной ширины колонки, поэтому запрет «не читать собственный размер»
    /// сюда не относится. Считается один раз на смену текста, не на кадр.
    static var font: UIFont {
        UIFont(name: PlusFont.displaySemibold, size: size) ?? .systemFont(ofSize: size)
    }

    static func height(of text: String) -> CGFloat {
        let font = Self.font
        let natural = font.lineHeight
        let measured = (text as NSString).boundingRect(
            with: CGSize(width: MovieLayout.leadWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        let lines = max(1, Int((measured.height / natural).rounded()))

        // Так же, как считает `FigmaTextStyle`: `lineSpacing` умеет только прибавлять,
        // поэтому при межстрочном меньше натурального строки встают на натуральном,
        // а разница уходит в вертикальный отступ (он же и отрицательный).
        let gap = max(0, lineHeight - natural)
        return CGFloat(lines) * natural + CGFloat(lines - 1) * gap + (lineHeight - natural)
    }
}
