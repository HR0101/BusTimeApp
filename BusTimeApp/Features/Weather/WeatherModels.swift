import Foundation

/// 背景に描く空模様です。
///
/// 降っているもの・雲の量・霧・雷・風を別々に持ちます。
/// 「雨か晴れか」の2択では、曇りや雪や風を表せないためです。
struct SkyWeather: Codable, Equatable, Sendable {
  /// 降っているものです。
  enum Precipitation: Codable, Equatable, Sendable {
    case none
    case rain(RainIntensity)
    case snow(RainIntensity)
  }

  /// 降っているものです。
  var precipitation: Precipitation = .none
  /// 空を覆う雲の割合です。0が快晴、1が一面の曇りです。
  var cloudCover: Double = 0
  /// 霧が出ているかどうかです。
  var isFoggy: Bool = false
  /// 雷が鳴っているかどうかです。
  var hasThunder: Bool = false
  /// 風の強さです。毎秒何メートルかで持ちます。
  var windSpeed: Double = 0

  /// 何も起きていない空です。
  static let clear = SkyWeather()

  /// 雨だけの空を作ります。
  static func rain(_ intensity: RainIntensity) -> SkyWeather {
    SkyWeather(precipitation: .rain(intensity), cloudCover: 0.9)
  }

  /// 雪だけの空を作ります。
  static func snow(_ intensity: RainIntensity) -> SkyWeather {
    SkyWeather(precipitation: .snow(intensity), cloudCover: 0.9)
  }

  var isRaining: Bool {
    if case .rain = precipitation { return true }
    return false
  }

  var rainIntensity: RainIntensity? {
    if case let .rain(intensity) = precipitation { return intensity }
    return nil
  }

  var isSnowing: Bool {
    if case .snow = precipitation { return true }
    return false
  }

  var snowIntensity: RainIntensity? {
    if case let .snow(intensity) = precipitation { return intensity }
    return nil
  }
}

/// 雨の強さです。降水量から3段階に分けます。
enum RainIntensity: Codable, Equatable, Sendable {
  case light
  case moderate
  case heavy

  /// 1時間あたりの降水量から強さを決めます。
  /// - Parameter millimeters: 直近1時間の降水量です。
  static func from(millimetersPerHour millimeters: Double) -> RainIntensity {
    if millimeters >= heavyThreshold {
      return .heavy
    }
    if millimeters >= moderateThreshold {
      return .moderate
    }
    return .light
  }

  /// 強い雨とみなす1時間あたりの降水量です。
  private static let heavyThreshold: Double = 4.0
  /// 並の雨とみなす1時間あたりの降水量です。
  private static let moderateThreshold: Double = 1.0
}

/// WMOの天気コードを解釈します。
/// コードの定義は Open-Meteo のドキュメントに準拠しています。
enum WeatherCodeInterpreter {
  /// 霧雨を表すコードです。
  private static let drizzleCodes: Set<Int> = [51, 53, 55, 56, 57]
  /// 雨を表すコードです。
  private static let rainCodes: Set<Int> = [61, 63, 65, 66, 67]
  /// にわか雨を表すコードです。
  private static let showerCodes: Set<Int> = [80, 81, 82]
  /// 雷雨を表すコードです。
  private static let thunderstormCodes: Set<Int> = [95, 96, 99]
  /// 雪を表すコードです。
  private static let snowCodes: Set<Int> = [71, 73, 75, 77, 85, 86]
  /// 霧を表すコードです。
  private static let fogCodes: Set<Int> = [45, 48]

  /// 天気コードが雨を表すかどうかを返します。
  /// 雪やあられは対象外とし、雨のときだけ背景を変えます。
  static func isRaining(code: Int) -> Bool {
    drizzleCodes.contains(code)
      || rainCodes.contains(code)
      || showerCodes.contains(code)
      || thunderstormCodes.contains(code)
  }

  /// 天気コードが雪を表すかどうかを返します。
  static func isSnowing(code: Int) -> Bool {
    snowCodes.contains(code)
  }

  /// 天気コードと観測値から空模様を組み立てます。
  /// - Parameters:
  ///   - code: WMOの天気コードです。
  ///   - precipitation: 直近1時間の降水量です。
  ///   - cloudCover: 空を覆う雲の割合です。百分率で渡します。
  ///   - windSpeed: 風の強さです。毎秒何メートルかで渡します。
  static func weather(
    code: Int,
    precipitation: Double,
    cloudCover: Double = 0,
    windSpeed: Double = 0
  ) -> SkyWeather {
    var weather = SkyWeather()
    weather.cloudCover = min(max(cloudCover / 100, 0), 1)
    weather.windSpeed = max(windSpeed, 0)
    weather.isFoggy = fogCodes.contains(code)
    weather.hasThunder = thunderstormCodes.contains(code)

    if isSnowing(code: code) {
      weather.precipitation = .snow(RainIntensity.from(millimetersPerHour: precipitation))
    } else if isRaining(code: code) {
      // 雷雨は降水量が少なくても強い雨として扱います。
      let intensity = thunderstormCodes.contains(code)
        ? RainIntensity.heavy
        : RainIntensity.from(millimetersPerHour: precipitation)
      weather.precipitation = .rain(intensity)
    }

    return weather
  }
}

/// 天気の取得に失敗した理由です。
enum WeatherServiceError: LocalizedError, Equatable {
  case invalidURL
  case requestFailed
  case invalidResponse

  var errorDescription: String? {
    switch self {
    case .invalidURL:
      return L10n.Weather.invalidURL
    case .requestFailed:
      return L10n.Weather.requestFailed
    case .invalidResponse:
      return L10n.Weather.decodingFailed
    }
  }
}
