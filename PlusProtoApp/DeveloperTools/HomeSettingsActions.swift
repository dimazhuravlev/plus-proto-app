import SwiftUI

extension HomePresentationSettings {
    func setWidth(_ width: Double, for kind: HomePromoKind) {
        let value = (min(max(width, 160), 400) / 4).rounded() * 4
        if kind == .artist {
            promoArtistWidth = value
        } else if kind == .movie {
            promoMovieWidth = value
        } else if kind == .book {
            promoBookWidth = value
        } else {
            widths[kind.rawValue] = value
        }
    }

    func resetWaveShader() {
        waveShaderScale = 1
        waveShaderGlow = 0.14
        waveShaderHue = 0
        waveShaderSaturation = 1
        waveShaderContrast = 1
        waveShaderWarp = 0.035
        waveShaderSpeed = 1
        waveShaderCoreSpeed = 0.5
        waveShaderMiddleSpeed = 1
        waveShaderRimSpeed = 0.7
    }

    func restoreWaveColors(boosted: Bool) {
        recentlyWaveOpacity = boosted ? 1 : 0.9
        recentlyWaveSaturation = boosted ? 1.25 : 1
        recentlyWaveContrast = boosted ? 1.15 : 1
    }

}
