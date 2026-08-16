import Foundation

/// 背景に描く空模様です。
enum SkyWeather: Equatable {
  /// 雨が降っていない状態です。
  case clear
  /// 雨が降っている状態です。
  case rain(RainIntensity)

  var isRaining: Bool {
    if case .rain = self {
      return true
    }
    return false
  }

  var rainIntensity: RainIntensity? {
    if case let .rain(intensity) = self {
      return intensity
    }
    return nil
  }
}

/// 雨の強さです。降水量から3段階に分けます。
enum RainIntensity: Equatable {
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

  /// 天気コードが雨を表すかどうかを返します。
  /// 雪やあられは対象外とし、雨のときだけ背景を変えます。
  static func isRaining(code: Int) -> Bool {
    drizzleCodes.contains(code)
      || rainCodes.contains(code)
      || showerCodes.contains(code)
      || thunderstormCodes.contains(code)
  }

  /// 天気コードと降水量から空模様を組み立てます。
  static func weather(code: Int, precipitation: Double) -> SkyWeather {
    guard isRaining(code: code) else { return .clear }

    // 雷雨は降水量が少なくても強い雨として扱います。
    if thunderstormCodes.contains(code) {
      return .rain(.heavy)
    }
    return .rain(RainIntensity.from(millimetersPerHour: precipitation))
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
