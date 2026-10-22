import SwiftUI
import UIKit

@MainActor private enum PromoSynopsisCache {
    static var lines: [String: [String]] = [:]
}

enum PromoEditorialContent {
    static var replacementMovie: MovieBlock {
        MovieBlock(id: "local-promo-maid", title: "Горничная",
                   poster: .asset("shelfMovieMaid"), still: .asset("shelfMovieMaid"),
                   caption: "Молодая женщина становится горничной в роскошном доме. За безупречной жизнью хозяев скрываются опасные тайны, и новая работа постепенно превращается в ловушку.",
                   captionTint: .clear)
    }
}

/// Фиксированный текстовый слот. TextKit переносит полную аннотацию без ellipsis;
/// максимум две строки по центру, только обрезанная вторая затухает справа.
struct PromoSynopsis: View {
    let text: String
    private var width: CGFloat { PlusMetrics.screenWidth - 48 }
    private let lineHeight: CGFloat = 20

    @MainActor private var lines: [String] {
        let key = "\(width)|\(text)"
        if let cached = PromoSynopsisCache.lines[key] { return cached }
        let plain = text.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let font = UIFont(name: PlusFont.textMedium, size: 15) ?? .systemFont(ofSize: 15, weight: .medium)
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
        let storage = NSTextStorage(string: plain, attributes: [.font: font, .paragraphStyle: paragraph])
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: width, height: lineHeight * 3))
        container.lineFragmentPadding = 0
        container.maximumNumberOfLines = 3
        container.lineBreakMode = .byWordWrapping
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)
        layout.ensureLayout(for: container)
        var result: [String] = []
        layout.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: layout.numberOfGlyphs)) { _, _, _, range, stop in
            let characters = layout.characterRange(forGlyphRange: range, actualGlyphRange: nil)
            result.append((plain as NSString).substring(with: characters).trimmingCharacters(in: .whitespacesAndNewlines))
            if result.count == 3 { stop.pointee = true }
        }
        PromoSynopsisCache.lines[key] = result
        return result
    }

    var body: some View {
        let lines = lines
        VStack(alignment: .center, spacing: 0) {
            ForEach(Array(lines.prefix(2).enumerated()), id: \.offset) { index, line in
                Text(line).plusText(.textM, .medium).foregroundStyle(Color.fillOne)
                    .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                    .frame(width: width, height: lineHeight, alignment: .center).clipped()
                    .mask {
                        if index == 1 && lines.count > 2 {
                            let font = UIFont(name: PlusFont.textMedium, size: 15) ?? .systemFont(ofSize: 15, weight: .medium)
                            let end = min(width, max(1, (line as NSString).size(withAttributes: [.font: font]).width))
                            let leading = (width - end) / 2
                            LinearGradient(stops: [.init(color: .white, location: 0),
                                                   .init(color: .white, location: max(0, leading + end - 24) / width),
                                                   .init(color: .clear, location: (leading + end) / width),
                                                   .init(color: .clear, location: 1)], startPoint: .leading, endPoint: .trailing)
                        } else { Color.white }
                    }
            }
        }
        .frame(width: width, height: 40, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

extension ShowcaseBlock {
    var promoSynopsis: String? {
        switch self {
        case .movie(let movie): movie.synopsis ?? movie.caption
        case .book(let book): book.synopsis ?? book.caption
        default: nil
        }
    }
}
