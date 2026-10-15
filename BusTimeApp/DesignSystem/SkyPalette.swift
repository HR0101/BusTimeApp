import SwiftUI
import Combine

/// 補間計算のために色をRGB成分で保持する内部表現です。
/// SwiftUIのColorは成分を取り出せないため、パレット内部ではこの型で色を扱います。
private struct RGBComponents: Equatable {
  let red: Double
  let green: Double
  let blue: Double

  /// 2色を比率で混ぜます。ratioが0なら自分自身、1ならotherになります。
  func mixed(with other: RGBComponents, ratio: Double) -> RGBComponents {
    let clamped = min(max(ratio, 0), 1)
    return RGBComponents(
      red: red + (other.red - red) * clamped,
      green: green + (other.green - green) * clamped,
      blue: blue + (other.blue - blue) * clamped
    )
  }

  /// 色を暗い方へ寄せます。
  func darkened(by amount: Double) -> RGBComponents {
    let factor = 1 - min(max(amount, 0), 1)
    return RGBComponents(red: red * factor, green: green * factor, blue: blue * factor)
  }

  func color(opacity: Double = 1) -> Color {
    Color(red: red, green: green, blue: blue, opacity: opacity)
  }

  private var relativeLuminance: Double {
    func linear(_ value: Double) -> Double {
      value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
  }

  func contrastRatio(with other: RGBComponents) -> Double {
    let lighter = max(relativeLuminance, other.relativeLuminance)
    let darker = min(relativeLuminance, other.relativeLuminance)
    return (lighter + 0.05) / (darker + 0.05)
  }
}

/// 季節です。空の色と昼の長さを季節ごとに寄せるために使います。
enum Season: CaseIterable {
  case spring
  case summer
  case autumn
  case winter

  /// その月の季節です。3〜5月を春、6〜8月を夏、9〜11月を秋、それ以外を冬とします。
  static func from(month: Int) -> Season {
    switch month {
    case 3...5:
      return .spring
    case 6...8:
      return .summer
    case 9...11:
      return .autumn
    default:
      return .winter
    }
  }

  /// 今日の季節です。
  ///
  /// 運行判定と同じく、アプリ内の現在時刻と日本時間の暦で判定します。
  /// 端末のタイムゾーンで判定すると、月末から月初の数時間だけ季節がずれるためです。
  /// Debugビルドで季節を固定する起動引数が渡されていれば、その季節を返します。
  static func current(date: Date = AppDate.now(), calendar: Calendar = AppCalendar.japan) -> Season {
    from(month: calendar.component(.month, from: SeasonalDate.resolve(date, calendar: calendar)))
  }

  /// 一年の中で季節が移っていく順番です。年の初めの冬から並べます。
  static let yearOrder: [Season] = [.winter, .spring, .summer, .autumn]

  /// 季節を代表する月日です。季節だけを差し替えて確かめるときに使います。
  ///
  /// 季節を構成する3か月のうち、真ん中の月の中ほどにします。
  var representativeMonthDay: (month: Int, day: Int) {
    switch self {
    case .spring:
      return (4, 15)
    case .summer:
      return (7, 16)
    case .autumn:
      return (10, 16)
    case .winter:
      return (1, 15)
    }
  }

  /// 起動引数に書かれた季節の名前から季節を作ります。知らない名前ならnilを返します。
  init?(launchArgument value: String) {
    switch value.lowercased() {
    case "spring":
      self = .spring
    case "summer":
      self = .summer
    case "autumn", "fall":
      self = .autumn
    case "winter":
      self = .winter
    default:
      return nil
    }
  }

  /// 海と砂浜の、季節ごとの色です。
  ///
  /// 空だけが季節で変わり、画面の下半分が一年中同じだと季節が伝わりにくいためです。
  /// - 春: やわらかく霞んだ青緑の海と、明るい砂浜です。
  /// - 夏: 日差しで明るく澄んだ青緑の海と、白く乾いた砂浜です。
  /// - 秋: 深い青の海と、少し色づいた茶色の砂浜です。
  /// - 冬: 深く暗い紺の海と、冷たく灰色がかった砂浜です。
  fileprivate var scenery: SeasonalScenery {
    switch self {
    case .spring:
      return SeasonalScenery(
        waterTint: RGBComponents(red: 0.10, green: 0.26, blue: 0.30),
        waterTintStrength: 0.24,
        waterDarkening: 0.20,
        shore: RGBComponents(red: 0.640, green: 0.580, blue: 0.480)
      )
    case .summer:
      return SeasonalScenery(
        waterTint: RGBComponents(red: 0.00, green: 0.52, blue: 0.46),
        waterTintStrength: 0.40,
        waterDarkening: 0.16,
        shore: RGBComponents(red: 0.720, green: 0.640, blue: 0.500)
      )
    case .autumn:
      return SeasonalScenery(
        waterTint: RGBComponents(red: 0.03, green: 0.17, blue: 0.28),
        waterTintStrength: 0.28,
        waterDarkening: 0.24,
        shore: RGBComponents(red: 0.600, green: 0.520, blue: 0.400)
      )
    case .winter:
      return SeasonalScenery(
        waterTint: RGBComponents(red: 0.02, green: 0.07, blue: 0.24),
        waterTintStrength: 0.34,
        waterDarkening: 0.30,
        shore: RGBComponents(red: 0.580, green: 0.560, blue: 0.520)
      )
    }
  }

  /// 街路樹の葉の、季節ごとの色です。
  ///
  /// 春は桜、夏は青葉、秋は紅葉にし、冬は葉を落として枝だけにします。
  fileprivate var foliage: SeasonalFoliage {
    switch self {
    case .spring:
      return SeasonalFoliage(
        color: RGBComponents(red: 0.96, green: 0.72, blue: 0.80),
        highlight: RGBComponents(red: 1.00, green: 0.88, blue: 0.92),
        density: 1
      )
    case .summer:
      return SeasonalFoliage(
        color: RGBComponents(red: 0.20, green: 0.45, blue: 0.24),
        highlight: RGBComponents(red: 0.34, green: 0.60, blue: 0.30),
        density: 1
      )
    case .autumn:
      return SeasonalFoliage(
        color: RGBComponents(red: 0.84, green: 0.34, blue: 0.15),
        highlight: RGBComponents(red: 0.96, green: 0.62, blue: 0.20),
        density: 1
      )
    case .winter:
      // 葉はありません。色は秋から移るあいだの補間にだけ使います。
      return SeasonalFoliage(
        color: RGBComponents(red: 0.55, green: 0.40, blue: 0.25),
        highlight: RGBComponents(red: 0.65, green: 0.50, blue: 0.32),
        density: 0
      )
    }
  }

  /// 夜空の澄み具合です。1で最も澄み、暗い星まで見えます。
  ///
  /// 夜は空に季節の色を混ぜると、黒に近い紺が灰色や茶色に濁ります。
  /// そこで空の色は変えず、星の見え方で季節の空気の違いを表します。
  /// 乾いた冬と秋は澄み、湿った夏と、かすみの出る春は暗い星が隠れます。
  var starClarity: Double {
    switch self {
    case .winter:
      return 1.0
    case .autumn:
      return 0.9
    case .summer:
      return 0.7
    case .spring:
      return 0.55
    }
  }
}

/// 背景の季節を決める、年内の日付です。
///
/// 日の出・日の入りは日付から求めるため、季節の代わりに年内の何日目かを持ちます。
struct SeasonalDay: Equatable {
  /// 1月1日を1とした、年内の通し日数です。
  let dayOfYear: Int
  /// その年の日数です。365か366です。
  let daysInYear: Int

  /// 平年の各月の1日が、年内の何日目にあたるかです。
  private static let monthStartDays = [1, 32, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335]

  init(dayOfYear: Int, daysInYear: Int = 365) {
    self.daysInYear = daysInYear == 366 ? 366 : 365
    self.dayOfYear = min(max(dayOfYear, 1), self.daysInYear)
  }

  /// その日時が属する日です。
  init(date: Date, calendar: Calendar) {
    let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
    let daysInYear = calendar.range(of: .day, in: .year, for: date)?.count ?? 365
    self.init(dayOfYear: dayOfYear, daysInYear: daysInYear)
  }

  /// その季節を代表する日です。平年の日付として扱います。
  init(season: Season) {
    let monthDay = season.representativeMonthDay
    self.init(dayOfYear: Self.monthStartDays[monthDay.month - 1] + monthDay.day - 1)
  }

  /// その日の月です。
  var month: Int {
    let leapShift = daysInYear == 366 && dayOfYear >= 60 ? 1 : 0
    let index = Self.monthStartDays.lastIndex { $0 <= dayOfYear - leapShift } ?? 0
    return index + 1
  }

  /// その日の季節です。月で区切った季節を返します。
  var season: Season {
    Season.from(month: month)
  }

  /// その日の季節の混ざり具合です。
  ///
  /// 各季節の代表日（4月15日、7月16日、10月16日、1月15日）でその季節の色が最も強く、
  /// 次の季節の代表日へ向けてなだらかに移ります。月で区切って切り替えると、
  /// 2月末から3月1日のような境目で、一晩のうちに空の色が変わってしまうためです。
  /// ちょうど中間（5月末、8月末、11月末、2月末）で、2つの季節が半分ずつになります。
  var seasonBlend: SeasonBlend {
    let length = Double(daysInYear)
    let day = Double(dayOfYear)
    let order = Season.yearOrder

    for (index, earlier) in order.enumerated() {
      let later = order[(index + 1) % order.count]
      let start = Double(SeasonalDay(season: earlier).dayOfYear)
      var end = Double(SeasonalDay(season: later).dayOfYear)
      // 秋から冬へは年をまたぐので、翌年の代表日として扱います。
      if end <= start {
        end += length
      }
      let position = day < start ? day + length : day
      guard position < end else { continue }

      let progress = (position - start) / (end - start)
      // 代表日の前後では色をあまり動かさず、季節の中間でいちばん速く移ります。
      let eased = progress * progress * (3 - 2 * progress)
      return SeasonBlend(earlier: earlier, later: later, ratio: eased)
    }
    // 上の区間で一年を覆っているので、ここへは来ません。
    return SeasonBlend(earlier: season, later: season, ratio: 0)
  }

  /// 海浜幕張でのその日の日の出と日の入りです。
  var daylight: DaylightSchedule {
    MakuhariSun.daylight(dayOfYear: dayOfYear, daysInYear: daysInYear)
  }
}

/// 隣り合う2つの季節の混ざり具合です。
struct SeasonBlend: Equatable {
  /// 前の季節です。
  let earlier: Season
  /// 後の季節です。
  let later: Season
  /// 後の季節の割合です。0なら前の季節だけ、1なら後の季節だけになります。
  let ratio: Double

  /// その季節がどれだけ混ざっているかです。0から1で表します。
  func weight(of season: Season) -> Double {
    var weight = 0.0
    if season == earlier {
      weight += 1 - ratio
    }
    if season == later {
      weight += ratio
    }
    return weight
  }
}

/// 海浜幕張での太陽の動きを、日付から求めます。
///
/// アメリカ海洋大気庁（NOAA）が公開している太陽位置の近似式を使います。
/// 国立天文台の暦と比べた日の出・日の入りのずれは数分以内で、背景を描くには十分な精度です。
/// https://gml.noaa.gov/grad/solcalc/solareqns.PDF
enum MakuhariSun {
  /// 海浜幕張駅付近の緯度です。
  static let latitude: Double = 35.648
  /// 海浜幕張駅付近の経度です。
  static let longitude: Double = 140.042
  /// 日本標準時の協定世界時からの差です。時間単位で持ちます。
  static let utcOffsetHours: Double = 9
  /// 日の出・日の入りとみなす太陽の天頂距離です。
  /// 大気による屈折と太陽の半径を見込み、地平線より0.833度下に中心が来た時点とします。
  private static let sunriseZenithDegrees: Double = 90.833

  /// その日の日の出と日の入りです。時刻は日本時間です。
  static func daylight(dayOfYear: Int, daysInYear: Int = 365) -> DaylightSchedule {
    // 1年を一周とした角度です。正午の値を使います。
    let fractionalYear = 2 * Double.pi / Double(daysInYear) * Double(dayOfYear - 1)
    let equationOfTimeMinutes = 229.18 * (
      0.000075
        + 0.001868 * cos(fractionalYear)
        - 0.032077 * sin(fractionalYear)
        - 0.014615 * cos(2 * fractionalYear)
        - 0.040849 * sin(2 * fractionalYear)
    )
    let declination = 0.006918
      - 0.399912 * cos(fractionalYear)
      + 0.070257 * sin(fractionalYear)
      - 0.006758 * cos(2 * fractionalYear)
      + 0.000907 * sin(2 * fractionalYear)
      - 0.002697 * cos(3 * fractionalYear)
      + 0.00148 * sin(3 * fractionalYear)

    let latitudeRadians = latitude * Double.pi / 180
    let zenithRadians = sunriseZenithDegrees * Double.pi / 180
    let cosineHourAngle = cos(zenithRadians) / (cos(latitudeRadians) * cos(declination))
      - tan(latitudeRadians) * tan(declination)
    // 海浜幕張の緯度では白夜も極夜も起きませんが、念のため範囲内に収めます。
    let hourAngleDegrees = acos(min(max(cosineHourAngle, -1), 1)) * 180 / Double.pi

    // 経度1度あたり4分で、南中時刻が日本標準時の正午からずれます。
    let solarNoonMinutes = 720 - 4 * longitude - equationOfTimeMinutes + utcOffsetHours * 60
    let halfDaylightMinutes = 4 * hourAngleDegrees
    return DaylightSchedule(
      sunrise: (solarNoonMinutes - halfDaylightMinutes) / 60,
      sunset: (solarNoonMinutes + halfDaylightMinutes) / 60
    )
  }
}

/// 日の出と日の入りの時刻です。
///
/// 空の色の移り変わりと太陽・月の軌道は、どちらもこの値を基準にします。
/// 別々の時刻を使うと、空は夕焼けなのに太陽がまだ高い、
/// 太陽が沈んだのに空がまだ明るい、といった食い違いが起きるためです。
struct DaylightSchedule: Equatable {
  /// 日の出の時刻です。0時からの経過時間を、24時間表記の小数で表します。
  let sunrise: Double
  /// 日の入りの時刻です。
  let sunset: Double

  /// 太陽がいちばん高くなる時刻です。
  var solarNoon: Double {
    (sunrise + sunset) / 2
  }

  /// 太陽が地平線より上にあるかどうかです。
  func isSunUp(at hour: Double) -> Bool {
    hour >= sunrise && hour <= sunset
  }

  /// 太陽・月の水平位置です。0が画面左端、1が画面右端に対応します。
  ///
  /// 昼は日の出から日の入りまでで太陽が、夜は日の入りから翌日の日の出までで月が、
  /// それぞれ左から右へ渡ります。
  func celestialProgress(at hour: Double) -> Double {
    if isSunUp(at: hour) {
      return (hour - sunrise) / (sunset - sunrise)
    }

    // 夜は日の入りから翌日の日の出までを一区間として扱います。
    let nightSpan = 24 - sunset + sunrise
    let elapsed = hour > sunset ? hour - sunset : hour + (24 - sunset)
    return elapsed / nightSpan
  }

  /// 太陽・月の高さです。区間の両端で地平線、中央で天頂になる弧を描きます。
  func celestialAltitude(at hour: Double) -> Double {
    sin(celestialProgress(at: hour) * Double.pi)
  }
}

/// 背景の季節を決めるための日付です。
///
/// 通常は渡された日付をそのまま使います。Debugビルドだけは起動引数で月日を差し替え、
/// 時刻はそのままに季節の見た目だけを確かめられるようにします。
/// `-UITestNow`で日付ごと固定すると、時刻表や運行日の判定まで変わってしまうためです。
///
/// - `-forceSeason spring|summer|autumn|winter`: その季節を代表する日に差し替えます。
/// - `-forceDayOfYear <1〜366>`: その年の何日目かを指定します。季節の境目を確かめるときに使います。
///
/// 両方を渡した場合は、細かく指定できる`-forceDayOfYear`を優先します。
enum SeasonalDate {
  /// 季節を固定する起動引数の名前です。先頭のハイフンを除いた形でUserDefaultsに入ります。
  static let forceSeasonKey = "forceSeason"
  /// 年内の日付を固定する起動引数の名前です。
  static let forceDayOfYearKey = "forceDayOfYear"

  /// 季節の判定に使う日付を返します。
  static func resolve(_ date: Date, calendar: Calendar, defaults: UserDefaults = .standard) -> Date {
#if DEBUG
    if let forced = forcedDate(for: date, calendar: calendar, defaults: defaults) {
      return forced
    }
#endif
    return date
  }

  /// 起動引数で指定された月日へ差し替えた日付です。指定がなければnilを返します。
  ///
  /// 年と時刻は元の日付のものを残し、月日だけを入れ替えます。
  static func forcedDate(for date: Date, calendar: Calendar, defaults: UserDefaults) -> Date? {
    let time = calendar.dateComponents([.year, .hour, .minute, .second, .nanosecond], from: date)
    guard let year = time.year else { return nil }

    let monthDay: (month: Int, day: Int)
    if let dayOfYear = forcedDayOfYear(defaults: defaults) {
      guard let resolved = monthAndDay(ofDayOfYear: dayOfYear, year: year, calendar: calendar) else {
        return nil
      }
      monthDay = resolved
    } else if let value = defaults.string(forKey: forceSeasonKey),
              let season = Season(launchArgument: value) {
      monthDay = season.representativeMonthDay
    } else {
      return nil
    }

    var components = time
    components.month = monthDay.month
    components.day = monthDay.day
    return calendar.date(from: components)
  }

  /// 起動引数で指定された年内の日数です。
  ///
  /// 起動引数は文字列で、テストなどから直接入れた値は数値で届くため、両方を受け付けます。
  private static func forcedDayOfYear(defaults: UserDefaults) -> Int? {
    switch defaults.object(forKey: forceDayOfYearKey) {
    case let number as NSNumber:
      return number.intValue
    case let string as String:
      return Int(string)
    default:
      return nil
    }
  }

  /// その年の何日目にあたる月日かを返します。年の日数を超える値は大晦日に丸めます。
  private static func monthAndDay(
    ofDayOfYear dayOfYear: Int,
    year: Int,
    calendar: Calendar
  ) -> (month: Int, day: Int)? {
    guard dayOfYear >= 1,
          let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
          let daysInYear = calendar.range(of: .day, in: .year, for: startOfYear)?.count,
          let day = calendar.date(
            byAdding: .day,
            value: min(dayOfYear, daysInYear) - 1,
            to: startOfYear
          ) else {
      return nil
    }
    let components = calendar.dateComponents([.month, .day], from: day)
    guard let month = components.month, let dayOfMonth = components.day else { return nil }
    return (month, dayOfMonth)
  }
}

/// キーフレームの時刻の基準にする、太陽の動きの節目です。
private enum SolarEvent {
  /// 南中の12時間前です。その日の夜の始まりとして扱います。
  case previousMidnight
  case sunrise
  case solarNoon
  case sunset
  /// 南中の12時間後です。
  case nextMidnight

  /// その日のこの節目の時刻です。0時より前や24時より後になることがあります。
  func hour(in daylight: DaylightSchedule) -> Double {
    switch self {
    case .previousMidnight:
      return daylight.solarNoon - 12
    case .sunrise:
      return daylight.sunrise
    case .solarNoon:
      return daylight.solarNoon
    case .sunset:
      return daylight.sunset
    case .nextMidnight:
      return daylight.solarNoon + 12
    }
  }
}

/// 1日の中の特定の時刻における空の色を定義します。
///
/// 時刻は固定の時計の時刻ではなく、日の出・南中・日の入りからの前後で持ちます。
/// 日の出が4時台の夏も6時台の冬も、日の出の空は同じ色になり、
/// 昼の長さの違いがそのまま空の移り変わりに表れます。
private struct SkyKeyframe {
  /// 時刻の基準にする太陽の動きの節目です。
  let event: SolarEvent
  /// 節目からの前後です。時間単位で、負の値は節目より前を表します。
  let offset: Double
  /// 季節ごとの色を持たないときの、空の上端の色です。
  let skyTop: RGBComponents
  /// 季節ごとの色を持たないときの、空の下端の色です。
  let skyBottom: RGBComponents
  /// 空の暗さです。0が完全な昼、1が完全な夜を表し、文字色やカード色の決定に使います。
  let nightness: Double
  /// 季節ごとに描き分ける空の色です。ここにない季節は`skyTop`と`skyBottom`を使います。
  var seasonal: [Season: SkyColors] = [:]

  /// その日のこのキーフレームの時刻です。
  func hour(in daylight: DaylightSchedule) -> Double {
    event.hour(in: daylight) + offset
  }

  /// その季節の空の色です。
  func colors(for season: Season) -> SkyColors {
    seasonal[season] ?? SkyColors(top: skyTop, bottom: skyBottom)
  }

}

/// 海と砂浜の、季節ごとの色です。
private struct SeasonalScenery: Equatable {
  /// 水そのものの色です。海面の色をこの色へ寄せます。
  let waterTint: RGBComponents
  /// 海面に水の色を混ぜる強さです。
  let waterTintStrength: Double
  /// 海面を空より沈ませる度合いです。
  let waterDarkening: Double
  /// 昼の砂浜の色です。
  let shore: RGBComponents

  /// 隣り合う季節のあいだの色です。
  init(blend: SeasonBlend) {
    let earlier = blend.earlier.scenery
    let later = blend.later.scenery
    let ratio = blend.ratio
    self.init(
      waterTint: earlier.waterTint.mixed(with: later.waterTint, ratio: ratio),
      waterTintStrength: earlier.waterTintStrength
        + (later.waterTintStrength - earlier.waterTintStrength) * ratio,
      waterDarkening: earlier.waterDarkening + (later.waterDarkening - earlier.waterDarkening) * ratio,
      shore: earlier.shore.mixed(with: later.shore, ratio: ratio)
    )
  }

  init(waterTint: RGBComponents, waterTintStrength: Double, waterDarkening: Double, shore: RGBComponents) {
    self.waterTint = waterTint
    self.waterTintStrength = waterTintStrength
    self.waterDarkening = waterDarkening
    self.shore = shore
  }
}

/// 街路樹の葉の色と茂り具合です。
private struct SeasonalFoliage {
  let color: RGBComponents
  let highlight: RGBComponents
  /// 葉の茂り具合です。1で茂り、0で葉を落とした枝だけになります。
  let density: Double

  init(color: RGBComponents, highlight: RGBComponents, density: Double) {
    self.color = color
    self.highlight = highlight
    self.density = density
  }

  /// 隣り合う季節のあいだの葉です。
  ///
  /// 色は茂っている側に寄せて混ぜます。紅葉から冬へ移るときに、
  /// 葉の色が冬の仮の色へ近づかず、紅葉のまま散っていくようにするためです。
  init(blend: SeasonBlend) {
    let earlier = blend.earlier.foliage
    let later = blend.later.foliage
    let earlierWeight = earlier.density * (1 - blend.ratio)
    let laterWeight = later.density * blend.ratio
    let total = earlierWeight + laterWeight
    let colorRatio = total > 0 ? laterWeight / total : blend.ratio
    self.init(
      color: earlier.color.mixed(with: later.color, ratio: colorRatio),
      highlight: earlier.highlight.mixed(with: later.highlight, ratio: colorRatio),
      density: total
    )
  }
}

/// 空の上端と下端の色の組です。
private struct SkyColors {
  let top: RGBComponents
  let bottom: RGBComponents
}

/// 時刻に応じて連続的に変化するアプリ全体の配色です。
///
/// 背景の空の色を時刻から補間し、文字色・カード色・境界線は
/// その空の暗さ（nightness）から自動的に導出します。
/// これにより、どの時刻でも文字と背景のコントラストが保たれます。
struct SkyPalette: Equatable {
  /// 背景グラデーションの上端の色です。
  let skyTop: Color
  /// 背景グラデーションの下端の色です。
  let skyBottom: Color
  /// 空を段階的に塗り分けるための、上端の色の成分です。
  fileprivate let skyTopComponents: RGBComponents
  /// 空を段階的に塗り分けるための、下端の色の成分です。
  fileprivate let skyBottomComponents: RGBComponents
  /// この日の海と砂浜の色です。
  fileprivate let scenery: SeasonalScenery
  /// 見出しや時刻など、主要な文字の色です。
  let ink: Color
  /// 補足説明など、副次的な文字の色です。
  let inkSecondary: Color
  /// 区切り線や無効状態など、最も控えめな要素の色です。
  let inkFaint: Color
  /// カードやパネルの地の色です。背景がうっすら透ける半透明です。
  let surface: Color
  /// 背景を完全に隠すときの地の色です。
  /// 白を重ねる方式では文字の色に近づいてしまうため、空の色から作った不透明色を使います。
  let surfaceOpaque: Color
  /// カードの輪郭線の色です。
  let surfaceBorder: Color
  /// 選択状態や強調に使う色です。上に置く文字色は`accentInk`を使います。
  let accent: Color
  /// 強調色の上に置く文字色です。明るい夜の青では濃色を使ってコントラストを保ちます。
  let accentInk: Color
  /// カード上でアクセント相当の役割を担う、高コントラストの文字色です。
  let accentReadable: Color
  /// 強調色の淡い背景です。バッジやチップの地に使います。
  let accentSoft: Color
  /// 注意を促すメッセージの色です。
  let warning: Color
  /// 運行中であることを示す色です。
  let positive: Color
  /// 太陽または月の色です。
  let celestialTint: Color
  /// 海と道路のあいだの岸辺の色です。
  let shore: Color
  /// 道路の色です。
  let road: Color
  /// 道路に引かれた白線の色です。
  let roadLine: Color
  /// バス停の標識の色です。
  let signboard: Color
  /// バス停の標識の縁と、板に引く線の色です。
  let signboardInk: Color
  /// 街路樹の葉の色です。
  let foliage: Color
  /// 街路樹の葉の、光の当たる部分の色です。
  let foliageHighlight: Color
  /// 街路樹の葉の茂り具合です。1で茂り、0で葉を落とした枝だけになります。
  let foliageDensity: Double
  /// 街路樹の幹と枝の色です。
  let treeTrunk: Color
  /// この配色が表す時刻です。0以上24未満で持ちます。
  let hour: Double
  /// 太陽・月の水平位置です。0が画面左端、1が画面右端に対応します。
  let celestialProgress: Double
  /// 太陽・月の軌道の高さです。0が地平線、1が天頂に対応します。
  let celestialAltitude: Double
  /// 空の暗さです。0が完全な昼、1が完全な夜を表します。
  let nightness: Double
  /// 空が夜であるかどうかです。ステータスバーの明暗切り替えに使います。
  let isNight: Bool
  /// この配色を作った日です。
  /// 設定画面のプレビューなど、別の時刻の配色を作るときに同じ日を引き継ぎます。
  let day: SeasonalDay
  /// この配色の日の出と日の入りです。空の色と太陽・月の軌道が共有します。
  let daylight: DaylightSchedule

  /// この配色を作った季節です。
  var season: Season {
    day.season
  }

  /// 夜空の澄み具合です。隣り合う季節のあいだでは、日付に応じて移ります。
  var starClarity: Double {
    let blend = day.seasonBlend
    return blend.earlier.starClarity
      + (blend.later.starClarity - blend.earlier.starClarity) * blend.ratio
  }

  /// 太陽が地平線より上にあるかどうかです。太陽と月のどちらを描くかを決めます。
  var isSunUp: Bool {
    daylight.isSunUp(at: hour)
  }

  /// 街灯が点いているかどうかです。
  ///
  /// 日の入りが近づいて空が暗くなると点け、夜明けの30分前に消します。
  /// 夜明け前から朝まで点いていると、「これから明るくなる」時間帯の印象と合わないためです。
  /// 日の出・日の入りに合わせるので、日の短い冬は早く点いて遅く消えます。
  var isStreetLightOn: Bool {
    guard nightness > Self.streetLightNightness else { return false }
    let isEvening = hour >= daylight.solarNoon
    return isEvening || hour < daylight.sunrise - Self.streetLightDawnLead
  }

  // MARK: - 時刻から配色を生成する

  /// 昼の空の、季節ごとの色を作ります。
  ///
  /// 季節の色を一律に混ぜるだけでは、昼の空がどの季節もほぼ同じ色になります。
  /// そこで昼のあいだは、季節ごとに空そのものの彩度・明度・地平線のかすみを変えます。
  /// - 春: かすみがかった淡い空です。地平線は桃色を帯びた白にかすみます。
  /// - 夏: 濃く高い青です。最も鮮やかで、地平線まで青が残ります。
  /// - 秋: 澄んだ青です。夏より紫に寄った深い青で、地平線はすっきり晴れます。
  /// - 冬: 低く白っぽい空です。最も淡く、地平線は冷たい白になります。
  private static func daytimeColors(
    spring: (top: (Double, Double, Double), bottom: (Double, Double, Double)),
    summer: (top: (Double, Double, Double), bottom: (Double, Double, Double)),
    autumn: (top: (Double, Double, Double), bottom: (Double, Double, Double)),
    winter: (top: (Double, Double, Double), bottom: (Double, Double, Double))
  ) -> [Season: SkyColors] {
    [
      .spring: colors(top: spring.top, bottom: spring.bottom),
      .summer: colors(top: summer.top, bottom: summer.bottom),
      .autumn: colors(top: autumn.top, bottom: autumn.bottom),
      .winter: colors(top: winter.top, bottom: winter.bottom)
    ]
  }

  /// 0〜1の赤・緑・青の組から、空の上端と下端の色を作ります。
  private static func colors(
    top: (Double, Double, Double),
    bottom: (Double, Double, Double)
  ) -> SkyColors {
    SkyColors(
      top: RGBComponents(red: top.0, green: top.1, blue: top.2),
      bottom: RGBComponents(red: bottom.0, green: bottom.1, blue: bottom.2)
    )
  }

  /// 1日の空の色を定義するキーフレームです。時刻順に並べる必要があります。
  ///
  /// 日の出の前後は、空が白み始める薄明（約1時間15分前）から、
  /// 朝の青空になる1時間30分後までを描き分けます。日の入りの前後も同じく、
  /// 45分前の夕焼けから1時間30分後の夜空までを描き分けます。
  /// 薄明の長さは季節であまり変わらないので、昼の長さだけが季節で伸び縮みします。
  private static let keyframes: [SkyKeyframe] = [
    SkyKeyframe(
      event: .previousMidnight,
      offset: 0,
      skyTop: RGBComponents(red: 0.016, green: 0.024, blue: 0.086),
      skyBottom: RGBComponents(red: 0.161, green: 0.196, blue: 0.384),
      nightness: 1.0
    ),
    SkyKeyframe(
      event: .sunrise,
      offset: -1.25,
      skyTop: RGBComponents(red: 0.043, green: 0.063, blue: 0.180),
      skyBottom: RGBComponents(red: 0.353, green: 0.286, blue: 0.478),
      nightness: 0.94
    ),
    SkyKeyframe(
      event: .sunrise,
      offset: 0,
      skyTop: RGBComponents(red: 0.243, green: 0.243, blue: 0.541),
      skyBottom: RGBComponents(red: 0.988, green: 0.667, blue: 0.396),
      nightness: 0.30,
      seasonal: [
        // 春の夜明けは、かすみで淡い藤色と桃色ににじみます。
        .spring: colors(top: (0.40, 0.36, 0.60), bottom: (0.98, 0.80, 0.70)),
        // 秋の夜明けは澄んでいて、深い藍の空に鮮やかな橙が差します。
        .autumn: colors(top: (0.16, 0.20, 0.50), bottom: (0.99, 0.62, 0.32))
      ]
    ),
    SkyKeyframe(
      event: .sunrise,
      offset: 1.5,
      skyTop: RGBComponents(red: 0.318, green: 0.596, blue: 0.910),
      skyBottom: RGBComponents(red: 0.878, green: 0.941, blue: 0.988),
      nightness: 0.0,
      seasonal: daytimeColors(
        spring: (top: (0.47, 0.66, 0.90), bottom: (0.95, 0.90, 0.93)),
        summer: (top: (0.16, 0.56, 0.96), bottom: (0.74, 0.91, 0.99)),
        autumn: (top: (0.31, 0.47, 0.87), bottom: (0.84, 0.89, 0.97)),
        winter: (top: (0.60, 0.72, 0.84), bottom: (0.88, 0.92, 0.95))
      )
    ),
    SkyKeyframe(
      event: .solarNoon,
      offset: -1,
      skyTop: RGBComponents(red: 0.400, green: 0.671, blue: 0.941),
      skyBottom: RGBComponents(red: 0.851, green: 0.937, blue: 0.996),
      nightness: 0.0,
      seasonal: daytimeColors(
        spring: (top: (0.53, 0.70, 0.93), bottom: (0.95, 0.91, 0.94)),
        summer: (top: (0.16, 0.60, 0.98), bottom: (0.70, 0.90, 1.00)),
        autumn: (top: (0.33, 0.50, 0.90), bottom: (0.80, 0.88, 0.98)),
        winter: (top: (0.64, 0.76, 0.86), bottom: (0.89, 0.93, 0.96))
      )
    ),
    SkyKeyframe(
      event: .solarNoon,
      offset: 3,
      skyTop: RGBComponents(red: 0.353, green: 0.635, blue: 0.914),
      skyBottom: RGBComponents(red: 0.980, green: 0.929, blue: 0.831),
      nightness: 0.0,
      seasonal: daytimeColors(
        spring: (top: (0.50, 0.68, 0.91), bottom: (0.98, 0.90, 0.86)),
        summer: (top: (0.17, 0.57, 0.96), bottom: (0.88, 0.94, 0.90)),
        autumn: (top: (0.32, 0.48, 0.87), bottom: (0.98, 0.88, 0.74)),
        winter: (top: (0.62, 0.73, 0.84), bottom: (0.95, 0.92, 0.87))
      )
    ),
    SkyKeyframe(
      event: .sunset,
      offset: -0.75,
      skyTop: RGBComponents(red: 0.882, green: 0.482, blue: 0.310),
      skyBottom: RGBComponents(red: 0.996, green: 0.855, blue: 0.612),
      nightness: 0.10,
      seasonal: [
        // 春の夕焼けは、かすみで淡い桃色ににじみ、地平線は乳白色にぼやけます。
        .spring: colors(top: (0.88, 0.64, 0.58), bottom: (0.99, 0.90, 0.78)),
        // 夏の夕焼けは、ほかの季節より濃い橙から赤へ焼けます。
        .summer: colors(top: (0.93, 0.40, 0.20), bottom: (1.00, 0.78, 0.45)),
        // 秋の夕焼けは、澄んだ空気で紅色が冴え、地平線は琥珀色に焼けます。
        .autumn: colors(top: (0.76, 0.30, 0.30), bottom: (0.99, 0.70, 0.40))
      ]
    ),
    SkyKeyframe(
      event: .sunset,
      offset: 0.5,
      skyTop: RGBComponents(red: 0.278, green: 0.157, blue: 0.353),
      skyBottom: RGBComponents(red: 0.867, green: 0.416, blue: 0.365),
      nightness: 0.74,
      seasonal: [
        // 春の夕暮れは、くすんだ藤色と薄紅にかすみます。
        // 地平線を明るくしすぎると、夜の配色へ切り替わった直後にカードの文字が読みにくくなるため、
        // 明るさは共通の夕暮れと同じくらいに抑えます。
        .spring: colors(top: (0.36, 0.27, 0.42), bottom: (0.78, 0.47, 0.50)),
        // 夏の残照は、地平線の赤が濃く残ります。
        .summer: colors(top: (0.31, 0.13, 0.30), bottom: (0.92, 0.36, 0.24)),
        // 秋の夕暮れは澄んでいて、深い藍の空の下に紅の帯がくっきり残ります。
        .autumn: colors(top: (0.16, 0.12, 0.34), bottom: (0.82, 0.30, 0.25))
      ]
    ),
    SkyKeyframe(
      event: .sunset,
      offset: 1.5,
      skyTop: RGBComponents(red: 0.055, green: 0.071, blue: 0.204),
      skyBottom: RGBComponents(red: 0.231, green: 0.251, blue: 0.443),
      nightness: 1.0
    ),
    SkyKeyframe(
      event: .nextMidnight,
      offset: 0,
      skyTop: RGBComponents(red: 0.016, green: 0.024, blue: 0.086),
      skyBottom: RGBComponents(red: 0.161, green: 0.196, blue: 0.384),
      nightness: 1.0
    )
  ]

  /// 昼の文字色です。明るい空の上に置きます。
  private static let dayInk = RGBComponents(red: 0.086, green: 0.129, blue: 0.208)
  /// 夜の文字色です。暗い空の上に置きます。
  private static let nightInk = RGBComponents(red: 0.949, green: 0.965, blue: 0.988)
  /// 昼の強調色です。
  private static let dayAccent = RGBComponents(red: 0.098, green: 0.361, blue: 0.761)
  /// 夜の強調色です。暗い背景でも沈まないよう、昼より明度を上げます。
  /// 夜の強調色です。
  ///
  /// 明るくしすぎると、上に置く白文字とのコントラストが落ちます。
  /// 昼と夜のちょうど中間で白と黒のどちらを置いても足りなくなるため、
  /// どの時刻でも白文字が十分に読める明るさに抑えています。
  private static let nightAccent = RGBComponents(red: 0.216, green: 0.400, blue: 0.780)
  private static let lightAccentInk = RGBComponents(red: 1, green: 1, blue: 1)
  private static let darkAccentInk = RGBComponents(red: 0, green: 0, blue: 0)
  /// 昼の注意色です。
  private static let dayWarning = RGBComponents(red: 0.580, green: 0.230, blue: 0.030)
  /// 夜の注意色です。
  private static let nightWarning = RGBComponents(red: 1.000, green: 0.820, blue: 0.580)
  /// 昼の運行中表示の色です。
  private static let dayPositive = RGBComponents(red: 0.122, green: 0.478, blue: 0.361)
  /// 夜の運行中表示の色です。
  private static let nightPositive = RGBComponents(red: 0.580, green: 0.950, blue: 0.780)
  /// 太陽の色です。
  private static let sunTint = RGBComponents(red: 1.0, green: 0.973, blue: 0.867)
  /// 月の色です。海面に落ちる光を温かく見せるため、わずかに黄みを含ませます。
  private static let moonTint = RGBComponents(red: 0.988, green: 0.961, blue: 0.867)
  /// 街路樹の幹と枝の色です。
  private static let treeTrunk = RGBComponents(red: 0.34, green: 0.26, blue: 0.20)
  /// 昼の道路の色です。
  private static let dayRoad = RGBComponents(red: 0.353, green: 0.361, blue: 0.376)
  /// 昼の道路の白線の色です。色あせを見込んで、白より灰色に寄せます。
  private static let dayRoadLine = RGBComponents(red: 0.804, green: 0.796, blue: 0.749)
  /// 昼のバス停の標識の色です。空と海に馴染む水色にします。
  /// 背にする海より明るく保つことで、青のなかでも板として見分けられます。
  private static let daySignboard = RGBComponents(red: 0.612, green: 0.745, blue: 0.855)
  /// 昼のバス停の標識の縁と線の色です。深い海の青にそろえます。
  private static let daySignboardInk = RGBComponents(red: 0.145, green: 0.290, blue: 0.435)
  /// 夜に地上が沈む度合いです。街灯のない暗さまでは落とさず、月明かりが残る程度にします。
  private static let groundNightDarkening: Double = 0.52
  /// 地上が周囲の光を受ける度合いです。空の色を混ぜて、風景から浮かないようにします。
  private static let groundAmbientBlend: Double = 0.30

  /// 昼のカード地の不透明度です。明るい空の上では白を濃いめに乗せます。
  private static let daySurfaceOpacity: Double = 0.70
  /// 夜のカード地の不透明度です。背後の星がうっすら透ける濃さに保ちます。
  private static let nightSurfaceOpacity: Double = 0.14
  /// 背景を隠す地を作るとき、昼に空の色へ混ぜる白の割合です。
  private static let dayOpaqueWhiteMix: Double = 0.62
  /// 背景を隠す地を作るとき、夜に空の色を沈ませる度合いです。
  /// 白い文字とのコントラストを確保するため、しっかり暗くします。
  private static let nightOpaqueDarkening: Double = 0.42
  /// 昼のカード輪郭の不透明度です。
  private static let daySurfaceBorderOpacity: Double = 0.85
  /// 夜のカード輪郭の不透明度です。
  private static let nightSurfaceBorderOpacity: Double = 0.16
  /// 副次的な文字の不透明度です。
  ///
  /// 薄くすると、カードごしに透ける風景と重なったときにコントラストが落ちます。
  /// 主な文字とは大きさと太さで差を付けているので、色の濃さは同じにします。
  private static let secondaryInkOpacity: Double = 1.0
  /// 最も控えめな要素の不透明度です。
  private static let faintInkOpacity: Double = 0.22
  /// 昼の強調色の淡い背景の不透明度です。
  private static let dayAccentSoftOpacity: Double = 0.14
  /// 夜の強調色の淡い背景の不透明度です。
  private static let nightAccentSoftOpacity: Double = 0.30

  /// 街灯を点ける空の暗さの下限です。星が見え始める暗さに揃えます。
  private static let streetLightNightness: Double = 0.22
  /// 街灯を消す時刻を、日の出の何時間前にするかです。
  private static let streetLightDawnLead: Double = 0.5
  /// 昼の配色から夜の配色へ切り替える境界です。
  ///
  /// カードの地と文字色は、この一点で同時に入れ替えます。
  /// 空の暗さに合わせて少しずつ混ぜていくと、夕方に地も文字も中間の明るさになり、
  /// 互いに近づいて読めなくなるためです。
  ///
  /// 夜の地は空を暗くして作るので、境界の直後（夕暮れから夜へ移る途中）が最も読みにくくなります。
  /// 境界を0.82に置くと、空の暗さがどの値でも、標準の濃さでコントラスト比4.9以上を保てます。
  /// 日の出・日の入りは日付で毎日少しずつ動くため、15分おきの時刻だけでなく、
  /// 境界のすぐ手前とすぐ後の暗さになる時刻がいずれかの日に必ず訪れます。
  private static let nightThreshold: Double = 0.82

  /// 指定した時刻の配色を作ります。
  /// - Parameters:
  ///   - hour: 0以上24未満の時刻です。範囲外の値は24時間周期に丸めます。
  ///   - season: 季節です。省略すると今日の季節を使います。季節を代表する日の配色になります。
  static func at(
    hour: Double, season: Season = Season.current(), colorScheme: ColorScheme? = nil
  ) -> SkyPalette {
    at(hour: hour, day: SeasonalDay(season: season), colorScheme: colorScheme)
  }

  /// 指定した日の、指定した時刻の配色を作ります。
  /// - Parameters:
  ///   - hour: 0以上24未満の時刻です。範囲外の値は24時間周期に丸めます。
  ///   - day: 日の出・日の入りと季節を決める日です。
  static func at(
    hour: Double, day: SeasonalDay, colorScheme: ColorScheme? = nil
  ) -> SkyPalette {
    let normalizedHour = normalize(hour: hour)
    // 空の色と太陽・月の軌道は、その日の日の出・日の入りを共有します。
    // 冬は同じ17時でも暗く、夏は明るく見えます。
    let daylight = day.daylight
    let (previous, next, ratio) = surroundingKeyframes(for: normalizedHour, in: daylight)

    // 隣り合う2つの季節の空をそれぞれ作り、日付に応じて混ぜ合わせます。
    let blend = day.seasonBlend
    // 海と砂浜も、空と同じ割合で隣の季節へ移ります。
    let scenery = SeasonalScenery(blend: blend)
    let foliage = SeasonalFoliage(blend: blend)
    let earlierSky = skyColors(between: previous, and: next, ratio: ratio, season: blend.earlier)
    let laterSky = skyColors(between: previous, and: next, ratio: ratio, season: blend.later)
    let skyTop = earlierSky.top.mixed(with: laterSky.top, ratio: blend.ratio)
    let skyBottom = earlierSky.bottom.mixed(with: laterSky.bottom, ratio: blend.ratio)
    let nightness = previous.nightness + (next.nightness - previous.nightness) * ratio

    // 外観指定はカードと操作部品に適用し、時刻による風景は維持します。
    let darkSurfaces = colorScheme.map { $0 == .dark } ?? (nightness > nightThreshold)
    let interfaceNightness = colorScheme == nil ? nightness : (darkSurfaces ? 1.0 : 0.0)
    let surfaceBase: RGBComponents = colorScheme == nil ? skyBottom : (
      darkSurfaces ? keyframes[0].skyBottom : RGBComponents(red: 0.94, green: 0.96, blue: 0.98)
    )
    let accent = dayAccent.mixed(with: nightAccent, ratio: interfaceNightness)
    let accentInk = accent.contrastRatio(with: lightAccentInk)
      >= accent.contrastRatio(with: darkAccentInk)
      ? lightAccentInk
      : darkAccentInk
    let isNight = nightness > nightThreshold
    // 文字とカードの地は中間の値を持たせず、この境界で一度に入れ替えます。
    let ink = darkSurfaces ? nightInk : dayInk
    let surfaceTone: Double = darkSurfaces ? 1 : 0

    return SkyPalette(
      skyTop: skyTop.color(),
      skyBottom: skyBottom.color(),
      skyTopComponents: skyTop,
      skyBottomComponents: skyBottom,
      scenery: scenery,
      ink: ink.color(),
      inkSecondary: ink.color(opacity: secondaryInkOpacity),
      inkFaint: ink.color(opacity: faintInkOpacity),
      surface: colorScheme == nil ? Color.white.opacity(
        interpolate(from: daySurfaceOpacity, to: nightSurfaceOpacity, ratio: surfaceTone)
      ) : surfaceBase.color(opacity: 0.95),
      surfaceOpaque: surfaceBase
        .mixed(with: RGBComponents(red: 1, green: 1, blue: 1), ratio: dayOpaqueWhiteMix)
        .mixed(
          with: surfaceBase.darkened(by: nightOpaqueDarkening),
          ratio: surfaceTone
        )
        .color(),
      surfaceBorder: Color.white.opacity(
        interpolate(from: daySurfaceBorderOpacity, to: nightSurfaceBorderOpacity, ratio: surfaceTone)
      ),
      accent: accent.color(),
      accentInk: accentInk.color(),
      accentReadable: ink.color(),
      accentSoft: accent.color(
        opacity: interpolate(from: dayAccentSoftOpacity, to: nightAccentSoftOpacity, ratio: interfaceNightness)
      ),
      // 状態色もカード地と同じ境界で切り替えます。補間すると夕方に
      // カードと同程度の明るさを通過し、アイコンの輪郭が見えなくなるためです。
      warning: (darkSurfaces ? nightWarning : dayWarning).color(),
      positive: (darkSurfaces ? nightPositive : dayPositive).color(),
      celestialTint: sunTint.mixed(with: moonTint, ratio: nightness).color(),
      shore: scenery.shore
        .darkened(by: nightness * groundNightDarkening)
        .mixed(with: skyBottom, ratio: groundAmbientBlend)
        .color(),
      road: dayRoad
        .darkened(by: nightness * groundNightDarkening)
        .mixed(with: skyBottom, ratio: groundAmbientBlend)
        .color(),
      roadLine: dayRoadLine
        .darkened(by: nightness * groundNightDarkening)
        .mixed(with: skyBottom, ratio: groundAmbientBlend)
        .color(),
      signboard: daySignboard
        .darkened(by: nightness * groundNightDarkening * 0.55)
        .mixed(with: skyBottom, ratio: groundAmbientBlend * 0.4)
        .color(),
      signboardInk: daySignboardInk
        .darkened(by: nightness * groundNightDarkening * 0.4)
        .mixed(with: skyBottom, ratio: groundAmbientBlend * 0.3)
        .color(),
      // 街路樹も地上のものと同じく、夜は沈ませ、空の色を少し受けます。
      foliage: foliage.color
        .darkened(by: nightness * groundNightDarkening)
        .mixed(with: skyBottom, ratio: groundAmbientBlend * 0.5)
        .color(),
      foliageHighlight: foliage.highlight
        .darkened(by: nightness * groundNightDarkening)
        .mixed(with: skyBottom, ratio: groundAmbientBlend * 0.5)
        .color(),
      foliageDensity: foliage.density,
      treeTrunk: treeTrunk
        .darkened(by: nightness * groundNightDarkening)
        .mixed(with: skyBottom, ratio: groundAmbientBlend * 0.5)
        .color(),
      hour: normalizedHour,
      celestialProgress: daylight.celestialProgress(at: normalizedHour),
      celestialAltitude: daylight.celestialAltitude(at: normalizedHour),
      nightness: nightness,
      isNight: isNight,
      day: day,
      daylight: daylight
    )
  }

  /// 指定した日時の配色を作ります。
  ///
  /// 時刻と季節は日本時間の暦で求めます。背景は海浜幕張の空を描いているので、
  /// 端末のタイムゾーンが違っても、運行判定や天気と同じ現地の時刻に合わせます。
  static func at(date: Date, calendar: Calendar = AppCalendar.japan) -> SkyPalette {
    let components = calendar.dateComponents([.hour, .minute], from: date)
    let hour = Double(components.hour ?? 0)
    let minute = Double(components.minute ?? 0)
    // Debugビルドで季節を固定する起動引数が渡されていれば、その日に差し替えます。
    let seasonalDate = SeasonalDate.resolve(date, calendar: calendar)
    return at(
      hour: hour + minute / 60,
      day: SeasonalDay(date: seasonalDate, calendar: calendar)
    )
  }

  /// 画面の縦位置に対応する空の色を返します。
  /// - Parameter verticalRatio: 0が画面上端、1が画面下端です。
  func skyColor(at verticalRatio: Double, weather: SkyWeather = .clear) -> Color {
    skyComponents(at: verticalRatio, weather: weather).color()
  }

  private func skyComponents(at ratio: Double, weather: SkyWeather) -> RGBComponents {
    let clear = skyTopComponents.mixed(with: skyBottomComponents, ratio: ratio)
    let overcast = RGBComponents(red: 0.36, green: 0.42, blue: 0.48)
      .darkened(by: nightness * 0.85)
    return clear.mixed(with: overcast, ratio: weather.skyObscuration * 0.95)
  }

  /// 空の色を指定した段階数に量子化して返します。
  /// ドット絵は色数を絞ることで成立するため、背景はこの限られた色だけで塗ります。
  /// - Parameter steps: 作る色の数です。上端の色から下端の色までを等間隔で刻みます。
  func quantizedSkyColors(steps: Int, weather: SkyWeather = .clear) -> [Color] {
    guard steps > 1 else { return [skyColor(at: 0, weather: weather)] }

    return (0..<steps).map { index in
      let ratio = Double(index) / Double(steps - 1)
      return skyColor(at: ratio, weather: weather)
    }
  }

  /// 海面に使う色を返します。
  /// 空を映しつつ、水そのものの深さを表すために暗く沈ませ、青へ寄せます。
  /// これにより、空と水面の色が近い昼や夕方でも水際が見分けられます。
  func quantizedWaterColors(steps: Int, weather: SkyWeather = .clear) -> [Color] {
    guard steps > 1 else { return [skyTop] }

    return (0..<steps).map { index in
      let ratio = Double(index) / Double(steps - 1)
      let reflected = skyComponents(at: ratio, weather: weather)
      // 水の色も夜は沈ませます。夏の明るい青緑のまま混ぜると、夜の海だけが明るく浮くためです。
      let waterTint = scenery.waterTint.darkened(by: nightness * Self.groundNightDarkening)
      return reflected
        .darkened(by: scenery.waterDarkening)
        .mixed(with: waterTint, ratio: scenery.waterTintStrength)
        .color()
    }
  }

  // MARK: - 補間の内部処理

  /// 時刻を0以上24未満に丸めます。
  private static func normalize(hour: Double) -> Double {
    let remainder = hour.truncatingRemainder(dividingBy: 24)
    return remainder < 0 ? remainder + 24 : remainder
  }

  /// 指定時刻を挟む2つのキーフレームと、その間の位置（0〜1）を返します。
  private static func surroundingKeyframes(
    for hour: Double,
    in daylight: DaylightSchedule
  ) -> (previous: SkyKeyframe, next: SkyKeyframe, ratio: Double) {
    // キーフレームは南中の12時間前から12時間後までの24時間に並んでいます。
    // 南中は正午より少し早いので、0時の直前などはこの範囲へ移してから探します。
    let start = SolarEvent.previousMidnight.hour(in: daylight)
    var shiftedHour = hour
    if shiftedHour < start {
      shiftedHour += 24
    } else if shiftedHour >= start + 24 {
      shiftedHour -= 24
    }

    // キーフレームは時刻順に並んでおり、両端が南中の12時間前後なので必ず区間が見つかります。
    for index in 0..<(keyframes.count - 1) {
      let previous = keyframes[index]
      let next = keyframes[index + 1]
      let previousHour = previous.hour(in: daylight)
      let nextHour = next.hour(in: daylight)
      guard shiftedHour >= previousHour, shiftedHour <= nextHour else { continue }

      let span = nextHour - previousHour
      let ratio = span > 0 ? (shiftedHour - previousHour) / span : 0
      return (previous, next, ratio)
    }
    // 丸め誤差などで区間から外れた場合は、最後のキーフレームを使います。
    let last = keyframes[keyframes.count - 1]
    return (last, last, 0)
  }

  /// ある季節の、2つのキーフレームのあいだの空の色です。
  ///
  /// 季節の色を時間帯に関係なく一律に混ぜると、暗い夜空や彩度の高い夕焼けほど濁ります。
  /// そのため季節の違いは、キーフレームごとに持たせた季節の空の色だけで表します。
  /// 季節ごとの色を持たない時間帯は、どの季節も同じ空になります。
  private static func skyColors(
    between previous: SkyKeyframe,
    and next: SkyKeyframe,
    ratio: Double,
    season: Season
  ) -> SkyColors {
    let from = previous.colors(for: season)
    let to = next.colors(for: season)
    return SkyColors(
      top: from.top.mixed(with: to.top, ratio: ratio),
      bottom: from.bottom.mixed(with: to.bottom, ratio: ratio)
    )
  }

  /// 数値を比率で補間します。
  private static func interpolate(from start: Double, to end: Double, ratio: Double) -> Double {
    let clamped = min(max(ratio, 0), 1)
    return start + (end - start) * clamped
  }

  /// その季節を代表する日の、日の出と日の入りです。
  static func daylight(for season: Season) -> DaylightSchedule {
    SeasonalDay(season: season).daylight
  }
}

// MARK: - 時刻の供給

/// 現在時刻に対応する配色を一定間隔で更新して配信します。
@MainActor
final class SkyClock: ObservableObject {
  /// 現在時刻に対応する配色です。
  @Published private(set) var palette: SkyPalette

  /// 配色を更新する間隔です。1分ごとの更新でも色の変化は滑らかに見えます。
  private static let updateInterval: TimeInterval = 60

  private let nowProvider: () -> Date
  private var timer: AnyCancellable?

  init(nowProvider: @escaping () -> Date = AppDate.now) {
    self.nowProvider = nowProvider
    self.palette = SkyPalette.at(date: nowProvider())
    startTimer()
  }

  /// アプリ復帰時など、任意のタイミングで配色を現在時刻へ合わせます。
  func refresh() {
    let updated = SkyPalette.at(date: nowProvider())
    guard updated != palette else { return }
    palette = updated
  }

  private func startTimer() {
    guard timer == nil else { return }
    timer = Timer.publish(every: Self.updateInterval, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        self?.refresh()
      }
  }

  func setAutomaticUpdatesActive(_ isActive: Bool) {
    if isActive {
      refresh()
      startTimer()
    } else {
      timer?.cancel()
      timer = nil
    }
  }
}

// MARK: - 環境値

private struct SkyPaletteKey: EnvironmentKey {
  /// プレビューなどで時刻が供給されない場合は、昼の配色を使います。
  static let defaultValue = SkyPalette.at(hour: 11)
}

private struct SkyWeatherKey: EnvironmentKey {
  /// 天気を取得できていないあいだは、雨のない状態として扱います。
  static let defaultValue: SkyWeather = .clear
}

extension EnvironmentValues {
  /// 画面全体で共有される時刻連動の配色です。
  var sky: SkyPalette {
    get { self[SkyPaletteKey.self] }
    set { self[SkyPaletteKey.self] = newValue }
  }

  /// 背景に反映する空模様です。
  var skyWeather: SkyWeather {
    get { self[SkyWeatherKey.self] }
    set { self[SkyWeatherKey.self] = newValue }
  }
}
