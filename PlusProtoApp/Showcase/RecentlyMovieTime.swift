import Foundation

enum RecentlyMovieTime {
    static func label(_ seconds: TimeInterval) -> String {
        let minutes = Int(ceil(max(0, seconds) / 60))
        let hours = minutes / 60
        return hours > 0 ? "\(hours) ч \(minutes % 60) мин" : "\(minutes) мин"
    }
}


extension MovieInProgress {
    var remainingTime: TimeInterval? {
        guard let runtime, runtime.isFinite, runtime > 0 else { return nil }
        return max(0, runtime - max(0, position ?? 0))
    }
}
