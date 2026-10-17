import SwiftUI

/// Средняя плитка музыки — квадрат на фото с подписью поверх (`card / music / my vibe station`
/// и `top statistic card` экрана «Для вас», `68:15807`). Одна плитка на три содержимого:
/// счётчик («184 раза», «17 минут») с подписью под плиткой, станция «Моя волна» и «Играет
/// сейчас» с аватаром исполнителя. Только вёрстка — нажатие у вызывающего.
struct MusicTileCard: View {
    enum Content {
        /// Число и единица — снизу слева; подпись (название) — под плиткой.
        case counter(value: Int, unit: String)
        /// «Моя волна» и название станции (Headline S).
        case station(label: String, title: String)
        /// «Играет сейчас» и исполнитель с аватаром 24.
        case nowPlaying(label: String, avatar: ArtworkSource?, name: String)
    }

    let image: ArtworkSource?
    let content: Content
    /// Подпись под плиткой (Text M) — у счётчиков.
    var caption: String? = nil
    /// Строк подписи: у «Героев месяца» имя исполнителя — до двух (правка пользователя
    /// 2026-10-17), у треков — одна.
    var captionLines = 1
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: MusicCardLayout.textGap) {
            tile
            if let caption {
                Text(caption)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillOne)
                    .lineLimit(captionLines)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: width, alignment: .leading)
            }
        }
        .frame(width: width, alignment: .leading)
        .contentShape(.rect)
    }

    /// Плитка целиком с подписью — для явной высоты карусели: подпись — по наибольшему
    /// числу строк, место держится заранее.
    static func height(width: CGFloat, captionLines: Int) -> CGFloat {
        width + (captionLines > 0 ? MusicCardLayout.textGap + CGFloat(captionLines) * PlusTextSize.textM.lineHeight : 0)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: MusicCardLayout.radius, style: .continuous)
    }

    private var tile: some View {
        PlusSkeleton.fill
            .frame(width: width, height: width)
            .overlay {
                if let image {
                    SkeletonArtwork(source: image)
                        .overlay { MusicTileShade(image: image) }
                }
            }
            .overlay(alignment: .bottomLeading) {
                label
                    .padding(.leading, MusicTileLayout.inset)
                    .padding(.bottom, bottomInset)
            }
            .clipShape(shape)
            .coverBorder(shape)
    }

    private var bottomInset: CGFloat {
        if case .nowPlaying = content { return MusicTileLayout.inset }
        return MusicTileLayout.bottomInset
    }

    @ViewBuilder
    private var label: some View {
        switch content {
        case .counter(let value, let unit):
            VStack(alignment: .leading, spacing: MusicTileLayout.counterGap) {
                Text("\(value)")
                    .plusHeadline(.l)
                    .foregroundStyle(Color.fillOne)
                Text(unit)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillSubtitle)
            }
        case .station(let label, let title):
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillSubtitle)
                // Длинное название переносится, как в макете («Сентиментальное»)
                Text(title)
                    .plusHeadline(.s)
                    .foregroundStyle(Color.fillOne)
                    .lineLimit(2)
            }
            .frame(width: width - 2 * MusicTileLayout.inset, alignment: .leading)
        case .nowPlaying(let label, let avatar, let name):
            VStack(alignment: .leading, spacing: MusicTileLayout.artistGap) {
                Text(label)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillSubtitle)
                HStack(spacing: MusicTileLayout.artistAvatarGap) {
                    PlusSkeleton.fill
                        .frame(width: MusicTileLayout.artistAvatar, height: MusicTileLayout.artistAvatar)
                        .overlay {
                            if let avatar {
                                SkeletonArtwork(source: avatar)
                            }
                        }
                        .clipShape(Circle())
                        .coverBorder(Circle())
                    Text(name)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillOne)
                        .lineLimit(1)
                }
            }
            .frame(width: width - 2 * MusicTileLayout.inset, alignment: .leading)
        }
    }
}

/// Числа плитки — `card / music / my vibe station` (`17366:36890`) и `top statistic card`
/// (`17608:15654`).
enum MusicTileLayout {
    /// Подпись поверх фото — 12 от левой кромки, 8 от нижней (у «Играет сейчас» — 12)
    static let inset: CGFloat = 12
    static let bottomInset: CGFloat = 8
    /// Число и единица счётчика наезжают на 6 (`mb-[-6px]`)
    static let counterGap: CGFloat = -6
    static let artistGap: CGFloat = 2
    static let artistAvatar: CGFloat = 24
    static let artistAvatarGap: CGFloat = 4
    /// Размытие у низа плитки — backdrop-blur 32 панели Figma, в коде вдвое меньше
    static let shadeBlur: CGFloat = 16
    /// Затемнение низа под подписью — чёрный 15 % → 0 к верху
    static let shadeOpacity: Double = 0.15
}

/// Низ плитки: фото размыто и чуть притемнено, к верху — резкое (`blured gradient overlay`
/// макета — фоновый блюр под градиентом). Фоном под плиткой лежит то же фото, поэтому блюр
/// здесь — размытая копия под маской, а не живой фоновый блюр: он пересчитывался бы
/// у каждой плитки на каждом кадре скролла.
private struct MusicTileShade: View {
    let image: ArtworkSource

    var body: some View {
        ZStack {
            SkeletonArtwork(source: image)
                .blur(radius: MusicTileLayout.shadeBlur, opaque: true)
                .mask(LinearGradient(colors: [.black, .clear], startPoint: .bottom, endPoint: .center))
            LinearGradient(
                colors: [.black.opacity(MusicTileLayout.shadeOpacity), .clear],
                startPoint: .bottom,
                endPoint: .top
            )
        }
        .allowsHitTesting(false)
    }
}
