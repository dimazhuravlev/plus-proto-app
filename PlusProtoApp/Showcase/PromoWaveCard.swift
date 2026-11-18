import SwiftUI

/// Figma NS7mKDEaIwxlgTdds2h5s6, 694:29666 / 694:29741.
/// Feedback remains outside the card button in ShowcasePromo.
struct PromoWaveCard: View {
    let station: VibePromoStation
    var breathing = false
    var artDepth: CGFloat = 0
    var showsCaption = true

    var body: some View {
        let geometry = ShowcasePromoLayout.geometry.wave
        let size = geometry.frame
        let scale = geometry.artSize / 160
        let captionTop = geometry.captionTop
        Color.clear
            .frame(width: size.width, height: size.height)
            .background(alignment: .top) {
                PromoWaveTextShadow(artist: station.artist != nil)
                    .offset(y: captionTop + PromoWaveShadowGeometry.captionOffset)
                    .opacity(showsCaption ? 1 : 0)
                    .showcaseSwappable()
            }
            .overlay(alignment: .top) {
                artwork
                    .frame(width: 160, height: 160)
                    .scaleEffect(scale)
                    .frame(width: 160 * scale, height: 160 * scale)
                    .modifier(PromoPetalBreathing(active: breathing, anchor: .center))
                    .showcaseSwappable()
                    .offset(y: geometry.artOrigin.y)
                    .promoLayer(enabled: artDepth != 0, depth: artDepth, alignment: .top)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .top) {
                VStack(spacing: 2) {
                    if station.artist != nil {
                        stationSubtitle
                    }
                    Text(station.name)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillOne)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if station.artist == nil {
                        stationSubtitle
                    }
                }
                .multilineTextAlignment(.center)
                .frame(width: geometry.captionWidth)
                .modifier(PromoReveal(isShown: showsCaption,
                                      hiddenScale: ShowcasePromoMotion.pairHiddenScale, anchor: .center))
                .offset(y: captionTop)
                .showcaseSwappable()
            }
            .contentShape(.rect)
    }

    private var stationSubtitle: some View {
        Text(station.artist == nil ? "Моя волна" : "Моя волна в стиле")
            .plusText(.textM, .medium)
            .foregroundStyle(Color.white.opacity(0.5))
            .lineLimit(1)
    }

    @ViewBuilder private var artwork: some View {
        switch station.kind {
        case .genre(let asset):
            Image(asset).resizable().scaledToFit()
                .frame(width: 174.359, height: 174.359)
        case .artist(let artist):
            PromoArtistWaveArtwork(artist: artist, paletteIndex: station.paletteIndex ?? 0)
        }
    }
}


/// Figma 19537:58816 / 19537:59000 / 19537:59025: ellipse, not a blurred bitmap.
private struct PromoWaveTextShadow: View {
    let artist: Bool

    var body: some View {
        let shadow = PromoWaveShadowGeometry.self
        let alphas = shadow.alphas(artist: artist, viewportWidth: PlusMetrics.screenWidth)
        Circle()
            .fill(RadialGradient(stops: alphas.enumerated().map { index, alpha in
                .init(color: .black.opacity(alpha), location: CGFloat(index) / 15)
            }, center: .center, startRadius: 0, endRadius: shadow.height / 2))
            .frame(width: shadow.height, height: shadow.height)
            .scaleEffect(x: shadow.width / shadow.height, y: 1)
            .frame(width: shadow.width, height: shadow.height)
            .opacity(shadow.opacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
