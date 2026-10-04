import SwiftUI

/// Другие книги автора — карусель «Книги писателя» на экране книги (задача пользователя
/// 2026-10-04).
///
/// **`inauthor:` у Google Books не работает**: замер 2026-10-04 — ноль томов и по-русски,
/// и латиницей, и с кавычками, и без ограничения языка. Поэтому обычный поиск по имени
/// автора и отбор по полю `authors` — тот же приём, что у витрины (`isShowcaseBook`):
/// выдача по имени наполовину состоит из книг **о** писателе (биографии, пособия).
/// Остаются его собственные тома со сканом обложки — на писателя их 1–4.
@MainActor
@Observable
final class AuthorBooksStore {
    struct Book: Identifiable, Hashable {
        let id: String
        let title: String
        let year: String?
        let cover: URL
        /// Пропорции обложки — ширина книги в карусели идёт от них.
        let aspect: CGFloat?
    }

    private(set) var books: [Book] = []
    /// Ответ пришёл (пустой — тоже): карусель либо встаёт, либо её нет вовсе.
    private(set) var isLoaded = false

    /// Сколько книг держит карусель
    private static let limit = 10
    /// Сколько ждём обложки, чтобы знать их пропорции. Дольше — книга встаёт
    /// с пропорциями по умолчанию, а обложка доедет на месте.
    private static let coverWait: Duration = .seconds(3)

    /// Книги `author`, кроме открытой: ни этого тома, ни других изданий той же книги.
    func load(author: String, excludingVolume volumeID: String, title: String) async {
        guard !isLoaded else { return }
        let surname = author.split(separator: " ").last.map(String.init) ?? author
        let volumes = (try? await BooksService.shared.search(author, limit: 40)) ?? []
        guard !Task.isCancelled else { return }

        var seenTitles: Set<String> = [title.lowercased()]
        let own = volumes.filter { volume in
            guard volume.id != volumeID,
                  (volume.volumeInfo.authors ?? []).contains(where: { $0.localizedCaseInsensitiveContains(surname) }),
                  !volume.title.isEmpty,
                  volume.coverURL != nil
            else { return false }
            return seenTitles.insert(volume.title.lowercased()).inserted
        }
        let picked = Array(own.prefix(Self.limit))
        let aspects = await Self.aspects(of: picked)
        guard !Task.isCancelled else { return }

        books = picked.compactMap { volume in
            guard let cover = volume.coverURL else { return nil }
            return Book(
                id: volume.id,
                title: volume.title,
                year: volume.volumeInfo.publishedDate.map { String($0.prefix(4)) },
                cover: cover,
                aspect: aspects[volume.id]
            )
        }
        isLoaded = true
    }

    /// Нечего грузить (моковая книга без тома) — карусели не будет.
    func markEmpty() {
        isLoaded = true
    }

    /// Пропорции обложек — по самим картинкам, с потолком ожидания. Заодно они уже
    /// в кэше загрузчика, и карусель встаёт с обложками, а не с пустыми книгами.
    private static func aspects(of volumes: [GoogleBook]) async -> [String: CGFloat] {
        let urls = volumes.compactMap { volume in volume.coverURL.map { (volume.id, $0) } }
        guard !urls.isEmpty else { return [:] }
        return await withTaskGroup(of: (String, CGFloat?).self) { group in
            for (id, url) in urls {
                group.addTask { @MainActor in
                    let image = await ArtworkLoader.shared.image(for: url)
                    return (id, image.map { $0.size.width / max($0.size.height, 1) })
                }
            }
            group.addTask {
                try? await Task.sleep(for: coverWait)
                return ("", nil)
            }
            var aspects: [String: CGFloat] = [:]
            var answered = 0
            for await (id, aspect) in group {
                // Пустой id — истёк потолок ожидания.
                guard !id.isEmpty else { break }
                answered += 1
                if let aspect { aspects[id] = aspect }
                if answered == urls.count { break }
            }
            group.cancelAll()
            return aspects
        }
    }
}
