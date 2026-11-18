import SwiftUI

/// Figma 702:99842: live portrait → color with shadow → Screen highlights →
/// two opposing progressive blurs. Layer opacity is baked into the exported assets.
struct PromoArtistWaveArtwork: View {
    let artist: ArtistBlock
    let paletteIndex: Int

    var body: some View {
        Color.clear.frame(width: 140, height: 140)
            .overlay { ArtworkImage(source: artist.picture).scaledToFill() }
            .overlay {
                Image("promoArtistWaveColor\(paletteIndex)").resizable()
            }
            .overlay {
                Image("promoArtistWaveTexture").resizable().blendMode(.screen)
            }
            .clipShape(Circle())
            // The blur extends beyond the photo; clipping after it loses the halo.
            .frame(width: 170, height: 170)
            .drawingGroup()
            .layerEffect(ShaderLibrary.promoArtistProgressiveBlur(.float2(170, 170), .float2(1, 0)),
                         maxSampleOffset: CGSize(width: 25, height: 0))
            .layerEffect(ShaderLibrary.promoArtistProgressiveBlur(.float2(170, 170), .float2(0, 1)),
                         maxSampleOffset: CGSize(width: 0, height: 25))
            .frame(width: 156, height: 156)
            .scaleEffect(160.0 / 156)
            .frame(width: 160, height: 160)
    }
}
