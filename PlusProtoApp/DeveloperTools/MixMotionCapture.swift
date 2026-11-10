import SwiftUI

/// Сценарии снимают настоящую карусель через те же обработчики, что и её кнопки.
/// В обычном запуске ничего не выполняется; параметры съёмки не сохраняются.
@MainActor enum MixMotionCapture {
    static var glowForegroundOpacity: Double {
        #if DEBUG
        if scenario == "glow" { return 0 }
        #endif
        return 0.1
    }

    #if DEBUG
    static func preparePreferences() {
        let defaults = UserDefaults.standard
        guard let domain = Bundle.main.bundleIdentifier else { return }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("mix-capture-preferences.plist")
        if ProcessInfo.processInfo.arguments.contains("-debugMixRestore") {
            if let data = try? Data(contentsOf: url),
               var saved = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] {
                saved["localHomeDev.hideRecently"] = true
                defaults.setPersistentDomain(saved, forName: domain)
                try? FileManager.default.removeItem(at: url)
            }
        } else if scenario != nil, !FileManager.default.fileExists(atPath: url.path) {
            if let data = try? PropertyListSerialization.data(fromPropertyList: defaults.persistentDomain(forName: domain) ?? [:],
                                                            format: .binary, options: 0) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    static var scenario: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-debugMixCapture"), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    static func waitForEntrance() async -> Bool {
        guard scenario == "entrance" else { return false }
        let go = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("mix-capture-go")
        for _ in 0..<1200 {
            guard !Task.isCancelled else { return false }
            if FileManager.default.fileExists(atPath: go.path) {
                try? await Task.sleep(for: .milliseconds(650))
                return !Task.isCancelled
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return false
    }

    static func run(locate: (String) -> Bool, perform: (String) async -> Void) async {
        guard let scenario else { return }
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let ready = directory.appendingPathComponent("mix-capture-ready")
        let go = directory.appendingPathComponent("mix-capture-go")
        try? FileManager.default.removeItem(at: ready)
        try? FileManager.default.removeItem(at: go)
        await perform("reset-playback")
        try? await Task.sleep(for: .seconds(2))
        let petal = scenario.hasPrefix("petal")
        for _ in 0..<40 {
            guard !Task.isCancelled else { return }
            let album = ["intro", "open", "like", "save"].contains(scenario)
            if locate(petal ? "petal" : (album ? "album" : "movie")) { break }
            try? await Task.sleep(for: .milliseconds(180))
        }
        try? await Task.sleep(for: .seconds(2))
        if scenario == "save" { await perform("prepare-save") }
        if scenario == "petal-breath" || scenario == "petal-pause" { await perform("play") }
        if scenario == "petal-breath" || scenario == "petal-pause" { try? await Task.sleep(for: .seconds(2)) }
        if scenario == "toast" {
            await perform("like")
            try? await Task.sleep(for: .seconds(1))
        }
        if ["intro", "like", "save"].contains(scenario) {
            await perform("intro-replay")
            try? await Task.sleep(for: .seconds(1))
        }
        try? Data(scenario.utf8).write(to: ready)
        for _ in 0..<1200 {
            guard !Task.isCancelled else { return }
            if FileManager.default.fileExists(atPath: go.path) { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        guard !Task.isCancelled else { return }
        MixCaptureTouches.shared.isRecording = true
        try? await Task.sleep(for: .milliseconds(650))
        switch scenario {
        case "swipe-flat", "swipe-depth", "glow", "captions":
            for _ in 0..<3 {
                await perform("next")
                try? await Task.sleep(for: .milliseconds(1250))
            }
        case "petal-wave", "petal-press": await perform("play")
        case "petal-pause": await perform("pause")
        case "like", "save", "dislike": await perform(scenario)
        case "neighbor": await perform("tap-neighbor")
        case "intro": await perform("intro-collapse")
        case "open": await perform("open")
        default: break
        }
    }
    #endif
}
