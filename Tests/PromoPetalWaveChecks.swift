import Foundation
import CoreGraphics

@main enum PromoPetalWaveChecks {
    static func main() {
        var wave = PromoPetalWave<String>(duration: 1.3)
        let center = CGPoint(x: 100, y: 120)
        let finger = CGPoint(x: 37, y: 81)
        wave.recordTouch(finger, at: "a", time: 10)
        wave.launch(at: "a", fallbackOrigin: center, time: 10.1)
        precondition(wave.pulses["a"]?.origin == finger)
        precondition(wave.pulses["a"]?.trigger == 1)

        // Быстрый повтор не двигает источник уже идущей волны и не меняет счётчик.
        wave.recordTouch(.zero, at: "a", time: 10.2)
        wave.launch(at: "a", fallbackOrigin: center, time: 10.3)
        precondition(wave.pulses["a"]?.origin == finger)
        precondition(wave.pulses["a"]?.trigger == 1)
        wave.launch(at: "b", fallbackOrigin: center, time: 10.4)
        precondition(wave.pulses["b"] == nil)

        // Точка другой карточки и устаревшее касание не заменяют центр VoiceOver.
        wave.recordTouch(finger, at: "a", time: 12)
        wave.launch(at: "b", fallbackOrigin: center, time: 12.1)
        precondition(wave.pulses["b"]?.origin == center)
        precondition(wave.pulses["b"]?.trigger == 1)
        wave.recordTouch(finger, at: "a", time: 14)
        wave.launch(at: "a", fallbackOrigin: center, time: 14.6)
        precondition(wave.pulses["a"]?.origin == center)
        precondition(wave.pulses["a"]?.trigger == 2)

        // Потреблённая координата не переиспользуется при программном запуске.
        wave.recordTouch(finger, at: "a", time: 16)
        wave.launch(at: "a", fallbackOrigin: center, time: 16.1)
        wave.launch(at: "a", fallbackOrigin: center, time: 18)
        precondition(wave.pulses["a"]?.origin == center)
        precondition(wave.pulses["a"]?.trigger == 4)

        wave.recordTouch(finger, at: "b", time: 20)
        wave.retain(["a"])
        precondition(Set(wave.pulses.keys) == ["a"])
        wave.launch(at: "b", fallbackOrigin: center, time: 20.1)
        precondition(wave.pulses["b"]?.origin == center)
        precondition(wave.pulses["b"]?.trigger == 1)
        wave.reset()
        precondition(wave.pulses.isEmpty)
        wave.launch(at: "a", fallbackOrigin: center, time: 20.2)
        precondition(wave.pulses["a"]?.trigger == 1)
        precondition(wave.pulses["a"]?.origin == center)
        print("PASS: wave touch isolation, stable origin, throttle, per-slot counters and bounded state")
    }
}
