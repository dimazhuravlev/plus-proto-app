import Foundation

@main enum HomeRecentlyModeChecks {
    static func main() {
        precondition(HomeRecentlyMode.restored(rawValue: nil, wasHidden: false, wasExperimental: false) == .standard)
        precondition(HomeRecentlyMode.restored(rawValue: nil, wasHidden: true, wasExperimental: true) == .hidden)
        precondition(HomeRecentlyMode.restored(rawValue: nil, wasHidden: false, wasExperimental: true) == .experiment)
        precondition(HomeRecentlyMode.restored(rawValue: "obsolete", wasHidden: false, wasExperimental: false) == .standard)
        for mode in HomeRecentlyMode.allCases {
            for hidden in [true, false] {
                for experiment in [true, false] {
                    precondition(HomeRecentlyMode.restored(rawValue: mode.rawValue,
                        wasHidden: hidden, wasExperimental: experiment) == mode,
                        "Explicit selection overrides legacy settings after relaunch")
                }
            }
        }
        print("PASS: Recently selection, migration, invalid values, persisted selection priority")
    }
}
