import Foundation

/// DTO Google Books. Ответ уже camelCase — конвертер из snake_case не нужен.

struct GoogleBooksResponse: Decodable {
    let totalItems: Int?
    let items: [GoogleBook]?
}

struct GoogleBookImageLinks: Decodable {
    let smallThumbnail: String?
    let thumbnail: String?
}

/// Что Google умеет показать из тома. Это **единственный надёжный признак живой
/// обложки** (замер по восьми запросам 2026-08-23): при `image == true` у Google есть
/// постраничный скан, и `frontcover` отдаёт настоящую обложку 575×~820 весом 20–130 КБ.
/// Без него приезжает либо серая заглушка «image not available» 575×750 на 8 КБ, либо
/// полоска корешка 575×92 на 0–3 КБ. Наличие самого `imageLinks` ничего не гарантирует —
/// он есть у всех.
struct GoogleBookReadingModes: Decodable {
    let text: Bool?
    let image: Bool?
}

struct GoogleBookVolumeInfo: Decodable {
    let title: String?
    let subtitle: String?
    let authors: [String]?
    let description: String?
    let publishedDate: String?
    let pageCount: Int?
    let categories: [String]?
    let language: String?
    let readingModes: GoogleBookReadingModes?
    let imageLinks: GoogleBookImageLinks?
}

struct GoogleBook: Decodable, Identifiable {
    let id: String
    let volumeInfo: GoogleBookVolumeInfo

    var title: String { volumeInfo.title ?? "" }
    var author: String { volumeInfo.authors?.first ?? "" }

    /// Обложка нормального размера. `imageLinks.thumbnail` — это 128px, для карточки
    /// в 186pt (558px на ×3) он размыт в кашу. У Google Books размер задаётся `zoom`:
    /// `zoom=3` отдаёт ~575×820 при верном соотношении сторон, а `fife=w800` растягивает
    /// картинку в разворот (замер: 800×721 вместо 575×820) — не использовать.
    /// У тома есть постраничный скан — значит и настоящая обложка. См. `GoogleBookReadingModes`.
    var hasScannedCover: Bool {
        volumeInfo.imageLinks?.thumbnail != nil && volumeInfo.readingModes?.image == true
    }

    var coverURL: URL? {
        guard volumeInfo.imageLinks?.thumbnail != nil else { return nil }
        // Собираем ссылку сами, а не правим thumbnail: у него бывает `edge=curl`,
        // подрисовывающий загнутый угол страницы — на карточке это читается как дефект.
        return URL(string:
            "https://books.google.com/books/content?id=\(id)&printsec=frontcover&img=1&zoom=3&source=gbs_api"
        )
    }
}
