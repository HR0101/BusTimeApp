import MetricKit

/// Appleが端末内で収集したクラッシュ・ハング・性能情報を受け取ります。
/// 外部サービスへ送信せず、件数だけを統合ログへ残します。
final class AppDiagnostics: NSObject, MXMetricManagerSubscriber {
    static let shared = AppDiagnostics()

    private var isStarted = false

    private override init() {
        super.init()
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        AppLogger.performance.info("Received \(payloads.count) MetricKit performance payloads")
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        AppLogger.performance.error("Received \(payloads.count) MetricKit diagnostic payloads")
    }
}
