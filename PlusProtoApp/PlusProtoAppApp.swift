import SwiftUI
import UIKit

@main
struct PlusProtoAppApp: App {
    init() {
        FontManager.registerFonts()
        UIWindow.appearance().backgroundColor = .black
        // Молча уехать на моки — значит оставить нового участника гадать, почему
        // витрина не меняется от запуска к запуску. Одна строка в консоль на старте.
        if !APIKeysCheck.isKinopoiskConfigured {
            print("⚠️ APIKeys.kinopoisk пуст — витрина идёт на моках, сеть не трогаем. Ключ: README, раздел «Ключи»")
        }
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
        if !args.contains("-debugSearchCycle") {
            UserDefaults.standard.removeObject(forKey: "debugSearchCycle")
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
        if !args.contains("-debugFrozenFeed") {
            UserDefaults.standard.removeObject(forKey: "debugFrozenFeed")
        }
        if !args.contains("-debugResetMoviePool") {
            UserDefaults.standard.removeObject(forKey: "debugResetMoviePool")
        }
        if !args.contains("-debugPlayCycle") {
            UserDefaults.standard.removeObject(forKey: "debugPlayCycle")
        }
        if !args.contains("-debugOpenEntity") {
            UserDefaults.standard.removeObject(forKey: "debugOpenEntity")
        }
        if !args.contains("-debugCloseEntity") {
            UserDefaults.standard.removeObject(forKey: "debugCloseEntity")
        }
        if !args.contains("-debugHitProbe") {
            UserDefaults.standard.removeObject(forKey: "debugHitProbe")
        }
        if !args.contains("-debugLayerProbe") {
            UserDefaults.standard.removeObject(forKey: "debugLayerProbe")
        }
        if !args.contains("-debugFullPlayer") {
            UserDefaults.standard.removeObject(forKey: "debugFullPlayer")
        }
        if !args.contains("-debugFullPlayerNow") {
            UserDefaults.standard.removeObject(forKey: "debugFullPlayerNow")
        }
        if !args.contains("-debugTapCover") {
            UserDefaults.standard.removeObject(forKey: "debugTapCover")
        }
        if !args.contains("-debugTapCard") {
            UserDefaults.standard.removeObject(forKey: "debugTapCard")
        }
        if !args.contains("-debugAlbumId") {
            UserDefaults.standard.removeObject(forKey: "debugAlbumId")
        }
        if !args.contains("-debugNoSplash") {
            UserDefaults.standard.removeObject(forKey: "debugNoSplash")
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
            // Заставка держит запуск до готовности витрины — отладочным прогонам,
            // которые снимают кадры по таймеру, она сдвигает всю раскадровку.
            case "-debugNoSplash":
                UserDefaults.standard.set(true, forKey: "debugNoSplash")
                index += 1
            case "-debugSearchCycle":
                UserDefaults.standard.set(true, forKey: "debugSearchCycle")
                index += 1
            case "-debugMorphCycle":
                UserDefaults.standard.set(true, forKey: "debugMorphCycle")
                index += 1
            case "-debugMockFeed":
                UserDefaults.standard.set(true, forKey: "debugMockFeed")
                index += 1
            // Витрина выбирается случайно на каждый запуск — для скриншотной сверки
            // зерно надо уметь зафиксировать.
            case "-debugFrozenFeed":
                UserDefaults.standard.set(true, forKey: "debugFrozenFeed")
                index += 1
            // Опустошить запас фильмов: иначе первый запуск после установки
            // не проверить, не переустанавливая приложение.
            case "-debugResetMoviePool":
                UserDefaults.standard.set(true, forKey: "debugResetMoviePool")
                index += 1
            case "-debugPlayCycle":
                UserDefaults.standard.set(true, forKey: "debugPlayCycle")
                index += 1
            case "-debugOpenEntity":
                UserDefaults.standard.set(true, forKey: "debugOpenEntity")
                index += 1
            case "-debugCloseEntity":
                UserDefaults.standard.set(true, forKey: "debugCloseEntity")
                index += 1
            case "-debugHitProbe":
                UserDefaults.standard.set(true, forKey: "debugHitProbe")
                index += 1
            case "-debugLayerProbe":
                UserDefaults.standard.set(true, forKey: "debugLayerProbe")
                index += 1
            case "-debugFullPlayer":
                UserDefaults.standard.set(true, forKey: "debugFullPlayer")
                index += 1
            case "-debugTapCover":
                UserDefaults.standard.set(true, forKey: "debugTapCover")
                index += 1
            case "-debugTapCard":
                UserDefaults.standard.set(true, forKey: "debugTapCard")
                index += 1
            case "-debugFullPlayerNow":
                UserDefaults.standard.set(true, forKey: "debugFullPlayerNow")
                index += 1
            case "-debugScrollTo" where index + 1 < args.count:
                UserDefaults.standard.set(Double(args[index + 1]) ?? 0, forKey: "debugScrollTo")
                index += 2
            case "-debugTapBlock" where index + 1 < args.count:
                UserDefaults.standard.set(Int(args[index + 1]) ?? 0, forKey: "debugTapBlock")
                index += 2
            case "-debugAlbumId" where index + 1 < args.count:
                UserDefaults.standard.set(Int(args[index + 1]) ?? 0, forKey: "debugAlbumId")
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
                #if DEBUG
                .debugHitAreaProbe()
                #endif
        }
    }
}
