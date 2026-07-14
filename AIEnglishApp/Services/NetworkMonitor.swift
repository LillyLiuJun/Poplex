import Foundation
import Network
import Observation

/// 全局网络可达性监控。用系统 NWPathMonitor 反映「设备是否真的有网络」，
/// 而不是「某一次服务器请求是否成功」——后者会把后端报错 / 超时误判成离线，
/// 即使用户网络完全正常。断网提示只应依赖这个真实状态。
@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    /// 乐观默认 true：避免 App 冷启动、monitor 尚未首次回调的那一瞬间误报离线。
    private(set) var isConnected = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.aienglishapp.networkmonitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor in
                self?.isConnected = connected
            }
        }
        monitor.start(queue: queue)
    }
}
