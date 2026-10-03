import Foundation

/// Текст книги для читалки.
///
/// **Самого текста Google Books не отдаёт.** Замер 2026-10-03 по книгам витрины:
/// у тома есть `description` (аннотация издательства, 0.5–2.3 тыс. символов) и в выдаче
/// поиска `textSnippet` на пару строк, а ознакомительный фрагмент лежит только
/// за `acsTokenLink` — это Adobe DRM, без него не открыть. Викитека, на которую
/// рассчитывали для текста, держит общественное достояние, а на витрине — свежий
/// нон-фикшен. Поэтому читалка показывает аннотацию тома целиком: её Google хранит
/// с разметкой абзацев на `/volumes/{id}` (в поиске то же поле — одной строкой).
///
/// Аннотации нет вовсе (моковая витрина, сеть упала, том без описания) — текст
/// из макета читалки. Тот же приём, что у блока «продолжить чтение»: пустая
/// читалка выглядит сломанной, а отрывок макета честно моковый.
///
/// Один заход на книгу обслуживает оба экрана: экран книги показывает аннотацию
/// описанием, читалка — как текст. Повторный запрос из читалки закрывает `URLCache`.
@MainActor
@Observable
final class BookTextStore {
    /// Описание на экране книги — аннотация как есть. Пусто — описания нет: моковым
    /// книгам без своей подписи выдумывать его нельзя.
    private(set) var annotation: [String] = []
    /// Текст для читалки.
    private(set) var pages: [String] = []
    /// Автор из API — если экран, открывший читалку, его не знал.
    private(set) var author: String?
    /// Текст готов. До этого колонка пустая и проявляется целиком, а не набирается
    /// на глазах абзац за абзацем.
    private(set) var isReady = false

    /// Сколько раз читалка повторяет текст. Длиннее аннотации у API ничего нет,
    /// а в одну аннотацию прокручивать почти нечего — пользователь попросил
    /// повторить имеющийся текст трижды (2026-10-03).
    private static let readerRepeats = 3

    func load(bookID: String) async {
        guard !isReady else { return }
        var fromAPI: [String] = []
        if let volumeID = Self.volumeID(for: bookID),
           let volume = try? await BooksService.shared.volume(id: volumeID) {
            author = volume.volumeInfo.authors?.first
            fromAPI = Self.paragraphs(fromDescription: volume.volumeInfo.description ?? "")
                .map(Self.bindingShortWords)
        }
        guard !Task.isCancelled else { return }
        author = author ?? Self.mockAuthors[bookID]
        annotation = fromAPI.isEmpty
            ? Self.mockAnnotations[bookID].map { [Self.bindingShortWords($0)] } ?? []
            : fromAPI
        let text = fromAPI.isEmpty ? Self.mockParagraphs.map(Self.bindingShortWords) : fromAPI
        pages = Array(repeating: text, count: Self.readerRepeats).flatMap { $0 }
        isReady = true
    }

    /// Однобуквенные предлоги и союзы держатся за следующее слово неразрывным
    /// пробелом — как в макете, где «с» уходит на новую строку вместе с «наемной
    /// работы», а не висит в конце предыдущей. Правило русской вёрстки; применяется
    /// и к аннотациям из API, где о нём никто не позаботился.
    private static func bindingShortWords(_ text: String) -> String {
        let words = text.split(separator: " ", omittingEmptySubsequences: false)
        var result = ""
        for (index, word) in words.enumerated() {
            result += word
            guard index < words.count - 1 else { break }
            let core = word.drop { "«„\"(".contains($0) }
            let isShort = core.count == 1 && core.first?.isLetter == true
            result += isShort ? "\u{00A0}" : " "
        }
        return result
    }

    // MARK: - Разбор

    /// id витрины и поиска — `gb-<том>`, у блока «продолжить чтение» — `gb-r-<том>`.
    /// Остальное — моки: тома Google за ними нет.
    static func volumeID(for bookID: String) -> String? {
        for prefix in ["gb-r-", "gb-"] where bookID.hasPrefix(prefix) {
            return String(bookID.dropFirst(prefix.count))
        }
        return nil
    }

    /// Абзацы из HTML аннотации. Google размечает их `<p>` и `<br>`; прочая разметка
    /// (`<b>`, `<i>`, списки) читалке не нужна — она набрана одним стилем.
    static func paragraphs(fromDescription html: String) -> [String] {
        var text = html.replacingOccurrences(
            of: #"<\s*(br|/p|/li|/div)\s*/?\s*>"#,
            with: "\n",
            options: [.regularExpression, .caseInsensitive]
        )
        text = text.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        text = decodingEntities(text)

        let blocks = text
            .components(separatedBy: .newlines)
            .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression) }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Аннотация без разметки приходит одной строкой на полторы тысячи знаков —
        // в колонке это стена текста. Режем по границам предложений.
        return blocks.flatMap { block in
            block.count > longBlock ? block.paragraphs(targetLength: paragraphLength) : [block]
        }
    }

    /// Дальше этого блок без разметки режется на абзацы — примерно по семь-восемь строк
    /// колонки (≈ 45 знаков в строке на кегле 16).
    private static let longBlock = 600
    private static let paragraphLength = 350

    private static let namedEntities: [String: String] = [
        "amp": "&", "quot": "\"", "apos": "'", "lt": "<", "gt": ">",
        "nbsp": "\u{00A0}", "laquo": "«", "raquo": "»", "mdash": "—", "ndash": "–",
        "hellip": "…", "bdquo": "„", "ldquo": "“", "rdquo": "”", "lsquo": "‘", "rsquo": "’",
    ]

    /// Сущности HTML: именованные из тех, что встречаются в аннотациях, и числовые.
    private static func decodingEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = ""
        var rest = Substring(text)
        while let amp = rest.firstIndex(of: "&") {
            result += rest[..<amp]
            let tail = rest[amp...]
            guard let semicolon = tail.firstIndex(of: ";"),
                  tail.distance(from: amp, to: semicolon) <= 10
            else {
                result += "&"
                rest = rest[rest.index(after: amp)...]
                continue
            }
            let name = String(tail[tail.index(after: amp)..<semicolon])
            if let decoded = decodeEntity(name) {
                result += decoded
            } else {
                result += tail[amp...semicolon]
            }
            rest = rest[rest.index(after: semicolon)...]
        }
        return result + rest
    }

    private static func decodeEntity(_ name: String) -> String? {
        if let named = namedEntities[name] { return named }
        guard name.hasPrefix("#") else { return nil }
        let digits = name.dropFirst()
        let code = digits.lowercased().hasPrefix("x")
            ? UInt32(digits.dropFirst(), radix: 16)
            : UInt32(digits)
        guard let code, let scalar = Unicode.Scalar(code) else { return nil }
        return String(Character(scalar))
    }

    // MARK: - Моки

    /// Текст макета `2311:27488` — отрывок из «Технофеодализма»: в макете он стоит
    /// дважды подряд, чтобы колонку было что прокручивать, так же и здесь.
    private static let mockParagraph = """
        Пиль предполагал, что у рабочих не было другого выбора, кроме наемного труда. \
        Это предположение звучало здраво в Британии, где после огораживания — массовой \
        приватизации общинных земель, которая происходила с конца XVIII века, — крестьяне \
        больше не имели доступа к какой-либо земле. Безземельный работник, уволившись \
        с наемной работы в Манчестере, Ливерпуле или Глазго, просто умер бы от голода. \
        Однако в Западной Австралии обилие пустующих земель (даже с учетом присутствия \
        коренных жителей) предлагало им альтернативу: расторжение контракта и работу \
        на себя. Таким образом, незадачливый мистер Пиль остался с великолепными \
        средствами производства Made in England, большим количеством денег, но без \
        власти командовать своими рабочими.
        """

    private static let mockParagraphs = [mockParagraph, mockParagraph]

    /// Авторы моковых книг: на витрине `.personal` и в отладочном пресете бара.
    private static let mockAuthors = [
        "technofeudalism": "Янис Варуфакис",
        "bullshit-jobs": "Дэвид Гребер",
        "debug-book": "Янис Варуфакис",
    ]

    /// Описание моковой книги на её экране — та же подпись, что у неё на витрине
    /// (`ShowcaseFeed.personal`). У «Бредовой работы» подписи нет, и описания тоже.
    private static let mockAnnotations = [
        "technofeudalism": "Что пришло на смену капитализму и как это изменило мир? Новый взгляд на экономику",
        "debug-book": "Что пришло на смену капитализму и как это изменило мир? Новый взгляд на экономику",
    ]
}
