import Foundation
import Combine

/// 背景に反映する天気を保持し、一定間隔で更新します。
///
/// 天気の取得に失敗しても画面は通常どおり動きます。
/// 直前に取得できた空模様をそのまま保ち、次の更新を待ちます。
@MainActor
final class WeatherViewModel: ObservableObject {
  /// 背景に描く空模様です。取得できていないあいだは晴れとして扱います。
  @Published private(set) var weather: SkyWeather = .clear
  /// 直近の取得に失敗したかどうかです。設定画面での案内に使います。
  @Published private(set) var hasFailedRecently = false
  /// 最後に取得に成功した時刻です。キャッシュを表示している場合にも保持します。
  @Published private(set) var lastSuccessfulUpdate: Date?

  /// 天気を取り直す間隔です。短時間に何度も問い合わせないようにします。
  private static let refreshInterval: TimeInterval = 15 * 60
  /// 取り直しが必要かを見に行く間隔です。
  /// 画面を開いたままでも天気が古くならないよう、この間隔で確認します。
  private static let checkInterval: TimeInterval = 60

  private let service: WeatherFetching
  private let nowProvider: () -> Date
  private let defaults: UserDefaults
  private let usesPersistentCache: Bool
  private var lastUpdatedAt: Date?
  private var lastAttemptAt: Date?
  private var consecutiveFailureCount = 0
  private var isRefreshing = false
  private var timer: AnyCancellable?

  private static let cacheKey = "weatherCache.v1"
  private static let maximumRetryInterval: TimeInterval = 15 * 60

  private struct Cache: Codable {
    let version: Int
    let weather: SkyWeather
    let updatedAt: Date
  }

  init(
    service: WeatherFetching? = nil,
    nowProvider: @escaping () -> Date = AppDate.now,
    defaults: UserDefaults = .standard,
    startsAutomaticRefresh: Bool = true
  ) {
    let resolvedService = service ?? Self.defaultService()
    self.service = resolvedService
    self.nowProvider = nowProvider
    self.defaults = defaults
#if DEBUG
    usesPersistentCache = !(resolvedService is DebugWeatherService)
    if let debugService = resolvedService as? DebugWeatherService {
      weather = debugService.weather
      let updatedAt = nowProvider()
      lastUpdatedAt = updatedAt
      lastSuccessfulUpdate = updatedAt
    } else {
      restoreCache()
    }
#else
    usesPersistentCache = true
    restoreCache()
#endif

    if startsAutomaticRefresh {
      startTimer()
    }
  }

  /// 画面を開いたままでも取り直しが止まらないよう、一定間隔で確認を続けます。
  /// 実際に通信するのは前回の取得から`refreshInterval`が過ぎたときだけです。
  private func startTimer() {
    guard timer == nil else { return }
    timer = Timer.publish(every: Self.checkInterval, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        Task { @MainActor [weak self] in
          await self?.refreshIfNeeded()
        }
      }
  }

  /// 画面が非アクティブな間は定期確認を止め、復帰時に必要なら更新します。
  func setAutomaticRefreshActive(_ isActive: Bool) {
    if isActive {
      startTimer()
    } else {
      timer?.cancel()
      timer = nil
    }
  }

  /// 通常はOpen-Meteoから取得しますが、
  /// 開発ビルドで起動引数の指定があればそちらを優先します。
  private static func defaultService() -> WeatherFetching {
#if DEBUG
    if let debugService = DebugWeatherService.makeFromLaunchArguments() {
      return debugService
    }
#endif
    return OpenMeteoWeatherService()
  }

  /// 前回の取得から十分に時間が経っていれば、天気を取り直します。
  func refreshIfNeeded() async {
    guard shouldRefresh else { return }
    await refresh()
  }

  /// 間隔を無視して天気を取り直します。
  func refresh() async {
    guard !isRefreshing else { return }
    isRefreshing = true
    lastAttemptAt = nowProvider()
    defer { isRefreshing = false }

    do {
      weather = try await service.fetchCurrentWeather()
      hasFailedRecently = false
      consecutiveFailureCount = 0
      let updatedAt = nowProvider()
      lastUpdatedAt = updatedAt
      lastSuccessfulUpdate = updatedAt
      persistCache(updatedAt: updatedAt)
      AppLogger.weather.info("Weather refreshed successfully")
    } catch {
      // 取得できなかった場合は直前の空模様を保ち、次の機会に再試行します。
      hasFailedRecently = true
      consecutiveFailureCount += 1
      AppLogger.weather.error("Weather refresh failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  private var shouldRefresh: Bool {
    let now = nowProvider()
    if let lastUpdatedAt,
       now.timeIntervalSince(lastUpdatedAt) < Self.refreshInterval {
      return false
    }

    guard hasFailedRecently, let lastAttemptAt else { return true }
    let exponent = min(max(consecutiveFailureCount - 1, 0), 4)
    let retryInterval = min(60 * pow(2, Double(exponent)), Self.maximumRetryInterval)
    return now.timeIntervalSince(lastAttemptAt) >= retryInterval
  }

  private func restoreCache() {
    guard let data = defaults.data(forKey: Self.cacheKey) else { return }
    do {
      let cache = try JSONDecoder().decode(Cache.self, from: data)
      guard cache.version == 1 else {
        AppLogger.persistence.error("Unsupported weather cache version: \(cache.version)")
        return
      }
      // 端末時計の変更や破損で未来の時刻が入ると更新が永久に止まるため、
      // 小さな時計ずれを超える未来値は採用しません。
      guard cache.updatedAt <= nowProvider().addingTimeInterval(5 * 60) else {
        AppLogger.persistence.error("Weather cache has an invalid future timestamp")
        return
      }
      weather = cache.weather
      lastUpdatedAt = cache.updatedAt
      lastSuccessfulUpdate = cache.updatedAt
    } catch {
      AppLogger.persistence.error("Weather cache could not be decoded")
    }
  }

  private func persistCache(updatedAt: Date) {
    guard usesPersistentCache else { return }
    do {
      let cache = Cache(version: 1, weather: weather, updatedAt: updatedAt)
      defaults.set(try JSONEncoder().encode(cache), forKey: Self.cacheKey)
    } catch {
      AppLogger.persistence.error("Weather cache could not be encoded")
    }
  }
}
