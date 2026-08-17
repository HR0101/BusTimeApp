import Foundation

/// 現在の天気を取得する役割です。テストで差し替えられるようにプロトコルにしています。
protocol WeatherFetching {
  func fetchCurrentWeather() async throws -> SkyWeather
}

/// Open-Meteo から海浜幕張駅付近の現在の天気を取得します。
///
/// APIキーが不要で、利用登録もいらないサービスです。
/// 位置は駅の座標に固定しているため、端末の位置情報は使いません。
struct OpenMeteoWeatherService: WeatherFetching {
  /// 海浜幕張駅の緯度です。
  private static let latitude = 35.6485608
  /// 海浜幕張駅の経度です。
  private static let longitude = 140.0416924
  /// 応答を待つ上限です。バスの表示を妨げないよう短めにします。
  private static let timeout: TimeInterval = 8

  private let session: URLSession

  init(session: URLSession = .shared) {
    self.session = session
  }

  func fetchCurrentWeather() async throws -> SkyWeather {
    guard let url = Self.makeURL() else {
      throw WeatherServiceError.invalidURL
    }

    var request = URLRequest(url: url)
    request.timeoutInterval = Self.timeout

    let data: Data
    let response: URLResponse

    do {
      (data, response) = try await session.data(for: request)
    } catch {
      AppLogger.weather.error(
        "Weather transport failed: \(error.localizedDescription, privacy: .public)"
      )
      throw WeatherServiceError.requestFailed
    }

    guard let httpResponse = response as? HTTPURLResponse else {
      AppLogger.weather.error("Weather response was not HTTP")
      throw WeatherServiceError.requestFailed
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
      AppLogger.weather.error("Weather HTTP status: \(httpResponse.statusCode)")
      throw WeatherServiceError.requestFailed
    }

    do {
      let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
      return WeatherCodeInterpreter.weather(
        code: decoded.current.weatherCode,
        precipitation: decoded.current.precipitation,
        cloudCover: decoded.current.cloudCover,
        windSpeed: decoded.current.windSpeed
      )
    } catch {
      AppLogger.weather.error("Weather response decoding failed")
      throw WeatherServiceError.invalidResponse
    }
  }

  private static func makeURL() -> URL? {
    var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
    components?.queryItems = [
      URLQueryItem(name: "latitude", value: String(latitude)),
      URLQueryItem(name: "longitude", value: String(longitude)),
      URLQueryItem(
        name: "current",
        value: "weather_code,precipitation,cloud_cover,wind_speed_10m"
      ),
      URLQueryItem(name: "timezone", value: "Asia/Tokyo")
    ]
    return components?.url
  }
}

#if DEBUG
/// 開発中に雨の見た目を確認するためのスタブです。
///
/// 起動引数 `-forceWeather` に値を渡すと、通信せずにその空模様を返します。
/// 指定できる値は `clear` `rain-light` `rain-moderate` `rain-heavy` です。
///
/// Xcodeで使う場合は Product → Scheme → Edit Scheme → Run → Arguments の
/// 「Arguments Passed On Launch」に `-forceWeather rain-heavy` を追加します。
/// シミュレータへ直接渡す場合は次のようにします。
///
///     xcrun simctl launch <device> com.hara.BusTimeApp -forceWeather rain-heavy
///
/// この指定はプロセス内でだけ有効で、端末には保存されません。
struct DebugWeatherService: WeatherFetching {
  let weather: SkyWeather

  func fetchCurrentWeather() async throws -> SkyWeather {
    weather
  }

  /// 起動引数の指定があればスタブを作ります。指定がなければnilを返します。
  static func makeFromLaunchArguments(
    defaults: UserDefaults = .standard
  ) -> DebugWeatherService? {
    guard let value = defaults.string(forKey: launchArgumentKey),
          let weather = weather(for: value) else {
      return nil
    }
    return DebugWeatherService(weather: weather)
  }

  /// 起動引数の名前です。先頭のハイフンを除いた形でUserDefaultsに入ります。
  private static let launchArgumentKey = "forceWeather"

  private static func weather(for value: String) -> SkyWeather? {
    switch value.lowercased() {
    case "clear":
      return .clear
    case "rain", "rain-moderate":
      return .rain(.moderate)
    case "rain-light":
      return .rain(.light)
    case "rain-heavy":
      return .rain(.heavy)
    default:
      return nil
    }
  }
}
#endif

/// Open-Meteo の応答のうち、必要な項目だけを取り出す入れ物です。
private struct OpenMeteoResponse: Decodable {
  let current: Current

  struct Current: Decodable {
    let weatherCode: Int
    let precipitation: Double
    /// 空を覆う雲の割合です。百分率で届きます。
    let cloudCover: Double
    /// 地上10メートルの風の強さです。
    let windSpeed: Double

    private enum CodingKeys: String, CodingKey {
      case weatherCode = "weather_code"
      case precipitation
      case cloudCover = "cloud_cover"
      case windSpeed = "wind_speed_10m"
    }
  }
}
