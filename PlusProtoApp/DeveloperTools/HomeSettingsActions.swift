import SwiftUI

extension HomePresentationSettings {
    func setMinimumWidth(_ width: Double, for kind: HomePromoKind) {
        promoMinimumWidths[kind.rawValue] = min(Double(widths(for: kind).maximum), max(160, width.rounded()))
    }

    func setMaximumWidth(_ width: Double, for kind: HomePromoKind) {
        promoMaximumWidths[kind.rawValue] = max(Double(widths(for: kind).minimum), min(400, width.rounded()))
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
