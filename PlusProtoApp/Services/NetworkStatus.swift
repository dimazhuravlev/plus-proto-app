import Foundation
import Network

/// Есть ли сеть — для стандартной ошибки «Что-то с интернетом» в поиске (PRD общего
/// поиска, макеты `17064:124242`). Системный монитор пути: без сети он узнаёт о ней
/// сразу, а не по таймауту запросов.
///
/// Монитор запускается с первым обращением — первым вводом в поиск: до конца дебаунса
/// он успевает узнать путь. Если не успел, отсутствие сети узнается по ошибкам самих
/// запросов (`SearchState.isConnectivity`).
@MainActor
@Observable
final class NetworkStatus {
    static let shared = NetworkStatus()

    /// Пути в сеть нет.
    private(set) var isOffline = false

    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { path in
            let isOffline = path.status != .satisfied
            Task { @MainActor in
                NetworkStatus.shared.isOffline = isOffline
            }
        }
        monitor.start(queue: DispatchQueue(label: "plusproto.network-status"))
    }
}
