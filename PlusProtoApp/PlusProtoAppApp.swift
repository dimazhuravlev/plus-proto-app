import SwiftUI
import UIKit

@main
struct PlusProtoAppApp: App {
    init() {
        FontManager.registerFonts()
        UIWindow.appearance().backgroundColor = .black
        #if DEBUG
        Self.parseDebugLaunchArguments()
        #endif
    }

    #if DEBUG
    /// Аргументы simctl launch → UserDefaults для скриншотной верификации без тапов.
    /// Ключи сбрасываются, если аргумент в **этом** запуске не передан — иначе после
    /// simctl обычный Run из Xcode остаётся в debug-режиме (чёрный экран / скрытый каталог).
    ///   xcrun simctl launch booted com.dima.PlusProtoApp -debugTab plus -debugActionBar music
    private static func parseDebugLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments

        if !args.contains("-debugTab") {
            UserDefaults.standard.removeObject(forKey: "debugTab")
        }
        if !args.contains("-debugActionBar") {
            UserDefaults.standard.removeObject(forKey: "debugActionBar")
        }
        if !args.contains("-debugSearchFocus") {
            UserDefaults.standard.removeObject(forKey: "debugSearchFocus")
        }
        if !args.contains("-debugMorphCycle") {
            UserDefaults.standard.removeObject(forKey: "debugMorphCycle")
        }
        if !args.contains("-debugScrollTo") {
            UserDefaults.standard.removeObject(forKey: "debugScrollTo")
        }
        if !args.contains("-debugTapBlock") {
            UserDefaults.standard.removeObject(forKey: "debugTapBlock")
        }
        if !args.contains("-debugMockFeed") {
            UserDefaults.standard.removeObject(forKey: "debugMockFeed")
        }
        if !args.contains("-debugFreshFeed") {
            UserDefaults.standard.removeObject(forKey: "debugFreshFeed")
        }
        if !args.contains("-debugPlayCycle") {
            UserDefaults.standard.removeObject(forKey: "debugPlayCycle")
        }

        var index = 0
        while index < args.count {
            switch args[index] {
            case "-debugTab" where index + 1 < args.count:
                UserDefaults.standard.set(args[index + 1], forKey: "debugTab")
                index += 2
            case "-debugActionBar" where index + 1 < args.count:
                UserDefaults.standard.set(args[index + 1], forKey: "debugActionBar")
                index += 2
            case "-debugSearchFocus":
                UserDefaults.standard.set(true, forKey: "debugSearchFocus")
                index += 1
            case "-debugMorphCycle":
                UserDefaults.standard.set(true, forKey: "debugMorphCycle")
                index += 1
            case "-debugMockFeed":
                UserDefaults.standard.set(true, forKey: "debugMockFeed")
                index += 1
            case "-debugFreshFeed":
                UserDefaults.standard.set(true, forKey: "debugFreshFeed")
                index += 1
            case "-debugPlayCycle":
                UserDefaults.standard.set(true, forKey: "debugPlayCycle")
                index += 1
            case "-debugScrollTo" where index + 1 < args.count:
                UserDefaults.standard.set(Double(args[index + 1]) ?? 0, forKey: "debugScrollTo")
                index += 2
            case "-debugTapBlock" where index + 1 < args.count:
                UserDefaults.standard.set(Int(args[index + 1]) ?? 0, forKey: "debugTapBlock")
                index += 2
            default:
                index += 1
            }
        }
    }
    #endif

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .preferredColorScheme(.dark)
        }
    }
}
