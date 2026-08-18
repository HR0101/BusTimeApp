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
  static func current(date: Date = Date(), calendar: Calendar = .current) -> Season {
    from(month: calendar.component(.month, from: date))
  }

  /// 昼の長さの伸び縮みです。
  ///
  /// 1より大きいほど、正午から離れた時刻が「より進んだ時刻」として扱われ、
  /// 早く暗くなります。冬は昼が短く、夏は長くなります。
  var daylightScale: Double {
    switch self {
    case .winter:
      return 1.13
    case .spring, .autumn:
      return 1.0
    case .summer:
      return 0.90
    }
  }

  /// 空に混ぜる季節の色です。
  fileprivate var tint: RGBComponents {
    switch self {
    case .spring:
      // 霞んだ淡い桃色です。
      return RGBComponents(red: 0.98, green: 0.90, blue: 0.92)
    case .summer:
      // 濃く澄んだ青です。
      return RGBComponents(red: 0.30, green: 0.55, blue: 0.95)
    case .autumn:
      // 夕暮れに寄せた橙です。
      return RGBComponents(red: 0.95, green: 0.72, blue: 0.48)
    case .winter:
      // 冷たく白い青です。
      return RGBComponents(red: 0.82, green: 0.88, blue: 0.97)
    }
  }

  /// 季節の色をどれだけ混ぜるかです。強すぎると時刻ごとの変化が消えます。
  var tintStrength: Double {
    switch self {
    case .spring, .autumn:
      return 0.10
    case .summer, .winter:
      return 0.13
    }
  }
}

/// 1日の中の特定の時刻における空の色を定義します。
private struct SkyKeyframe {
  /// 0時からの経過時間です。24時間表記の小数（例: 6.5は6時30分）で指定します。
  let hour: Double
  let skyTop: RGBComponents
  let skyBottom: RGBComponents
  /// 空の暗さです。0が完全な昼、1が完全な夜を表し、文字色やカード色の決定に使います。
  let nightness: Double
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

  // MARK: - 時刻から配色を生成する

  /// 1日の空の色を定義するキーフレームです。時刻順に並べる必要があります。
  private static let keyframes: [SkyKeyframe] = [
    SkyKeyframe(
      hour: 0,
      skyTop: RGBComponents(red: 0.016, green: 0.024, blue: 0.086),
      skyBottom: RGBComponents(red: 0.161, green: 0.196, blue: 0.384),
      nightness: 1.0
    ),
    SkyKeyframe(
      hour: 4.5,
      skyTop: RGBComponents(red: 0.043, green: 0.063, blue: 0.180),
      skyBottom: RGBComponents(red: 0.353, green: 0.286, blue: 0.478),
      nightness: 0.94
    ),
    SkyKeyframe(
      hour: 6.0,
      skyTop: RGBComponents(red: 0.243, green: 0.243, blue: 0.541),
      skyBottom: RGBComponents(red: 0.988, green: 0.667, blue: 0.396),
      nightness: 0.30
    ),
    SkyKeyframe(
      hour: 7.5,
      skyTop: RGBComponents(red: 0.318, green: 0.596, blue: 0.910),
      skyBottom: RGBComponents(red: 0.878, green: 0.941, blue: 0.988),
      nightness: 0.0
    ),
    SkyKeyframe(
      hour: 11.0,
      skyTop: RGBComponents(red: 0.400, green: 0.671, blue: 0.941),
      skyBottom: RGBComponents(red: 0.851, green: 0.937, blue: 0.996),
      nightness: 0.0
    ),
    SkyKeyframe(
      hour: 15.0,
      skyTop: RGBComponents(red: 0.353, green: 0.635, blue: 0.914),
      skyBottom: RGBComponents(red: 0.980, green: 0.929, blue: 0.831),
      nightness: 0.0
    ),
    SkyKeyframe(
      hour: 17.0,
      skyTop: RGBComponents(red: 0.882, green: 0.482, blue: 0.310),
      skyBottom: RGBComponents(red: 0.996, green: 0.855, blue: 0.612),
      nightness: 0.10
    ),
    SkyKeyframe(
      hour: 18.5,
      skyTop: RGBComponents(red: 0.278, green: 0.157, blue: 0.353),
      skyBottom: RGBComponents(red: 0.867, green: 0.416, blue: 0.365),
      nightness: 0.74
    ),
    SkyKeyframe(
      hour: 20.0,
      skyTop: RGBComponents(red: 0.055, green: 0.071, blue: 0.204),
      skyBottom: RGBComponents(red: 0.231, green: 0.251, blue: 0.443),
      nightness: 1.0
    ),
    SkyKeyframe(
      hour: 24.0,
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
  /// 水そのものの色です。海面の色をこの色へ少し寄せます。
  /// 湖より緑を含ませ、外洋の深い青緑に近づけます。
  private static let waterTint = RGBComponents(red: 0.039, green: 0.169, blue: 0.204)
  /// 昼の岸辺の色です。
  private static let dayShore = RGBComponents(red: 0.616, green: 0.561, blue: 0.463)
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
  /// 海面を空より沈ませる度合いです。
  private static let waterDarkening: Double = 0.22
  /// 海面に水の色を混ぜる強さです。
  private static let waterTintStrength: Double = 0.24

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

  /// 日の出の時刻です。太陽の軌道の起点になります。
  private static let sunriseHour: Double = 5.5
  /// 日の入りの時刻です。太陽の軌道の終点になります。
  private static let sunsetHour: Double = 18.5
  /// 昼の配色から夜の配色へ切り替える境界です。
  ///
  /// カードの地と文字色は、この一点で同時に入れ替えます。
  /// 空の暗さに合わせて少しずつ混ぜていくと、夕方に地も文字も中間の明るさになり、
  /// 互いに近づいて読めなくなるためです。境界を0.78に置くと、
  /// 標準の濃さで最も条件の悪い時刻でもコントラスト比4.9を保てます。
  private static let nightThreshold: Double = 0.78

  /// 指定した時刻の配色を作ります。
  /// - Parameters:
  ///   - hour: 0以上24未満の時刻です。範囲外の値は24時間周期に丸めます。
  ///   - season: 季節です。省略すると今日の季節を使います。
  static func at(hour: Double, season: Season = Season.current()) -> SkyPalette {
    let normalizedHour = normalize(hour: hour)
    // 昼の長さを季節で伸び縮みさせます。
    // 冬は同じ17時でも暗く、夏は明るく見えるようにするためです。
    let daylightHour = normalize(hour: 12 + (normalizedHour - 12) * season.daylightScale)
    let (previous, next, ratio) = surroundingKeyframes(for: daylightHour)

    let baseSkyTop = previous.skyTop.mixed(with: next.skyTop, ratio: ratio)
    let baseSkyBottom = previous.skyBottom.mixed(with: next.skyBottom, ratio: ratio)
    // 季節の色をうっすら混ぜます。夏は青く、秋は暖かく、冬は白っぽくなります。
    let skyTop = baseSkyTop.mixed(with: season.tint, ratio: season.tintStrength)
    let skyBottom = baseSkyBottom.mixed(with: season.tint, ratio: season.tintStrength * 0.6)
    let nightness = previous.nightness + (next.nightness - previous.nightness) * ratio

    let accent = dayAccent.mixed(with: nightAccent, ratio: nightness)
    let accentInk = accent.contrastRatio(with: lightAccentInk)
      >= accent.contrastRatio(with: darkAccentInk)
      ? lightAccentInk
      : darkAccentInk
    let isNight = nightness > nightThreshold
    // 文字とカードの地は中間の値を持たせず、この境界で一度に入れ替えます。
    let ink = isNight ? nightInk : dayInk
    let surfaceTone: Double = isNight ? 1 : 0

    return SkyPalette(
      skyTop: skyTop.color(),
      skyBottom: skyBottom.color(),
      skyTopComponents: skyTop,
      skyBottomComponents: skyBottom,
      ink: ink.color(),
      inkSecondary: ink.color(opacity: secondaryInkOpacity),
      inkFaint: ink.color(opacity: faintInkOpacity),
      surface: Color.white.opacity(
        interpolate(from: daySurfaceOpacity, to: nightSurfaceOpacity, ratio: surfaceTone)
      ),
      surfaceOpaque: skyBottom
        .mixed(with: RGBComponents(red: 1, green: 1, blue: 1), ratio: dayOpaqueWhiteMix)
        .mixed(
          with: skyBottom.darkened(by: nightOpaqueDarkening),
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
        opacity: interpolate(from: dayAccentSoftOpacity, to: nightAccentSoftOpacity, ratio: nightness)
      ),
      // 状態色もカード地と同じ境界で切り替えます。補間すると夕方に
      // カードと同程度の明るさを通過し、アイコンの輪郭が見えなくなるためです。
      warning: (isNight ? nightWarning : dayWarning).color(),
      positive: (isNight ? nightPositive : dayPositive).color(),
      celestialTint: sunTint.mixed(with: moonTint, ratio: nightness).color(),
      shore: dayShore
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
      hour: normalizedHour,
      celestialProgress: celestialProgress(at: normalizedHour),
      celestialAltitude: celestialAltitude(at: normalizedHour),
      nightness: nightness,
      isNight: isNight
    )
  }

  /// 指定した日時の配色を作ります。
  static func at(date: Date, calendar: Calendar = .current) -> SkyPalette {
    let components = calendar.dateComponents([.hour, .minute], from: date)
    let hour = Double(components.hour ?? 0)
    let minute = Double(components.minute ?? 0)
    return at(
      hour: hour + minute / 60,
      season: Season.current(date: date, calendar: calendar)
    )
  }

  /// 画面の縦位置に対応する空の色を返します。
  /// - Parameter verticalRatio: 0が画面上端、1が画面下端です。
  func skyColor(at verticalRatio: Double) -> Color {
    skyTopComponents.mixed(with: skyBottomComponents, ratio: verticalRatio).color()
  }

  /// 空の色を指定した段階数に量子化して返します。
  /// ドット絵は色数を絞ることで成立するため、背景はこの限られた色だけで塗ります。
  /// - Parameter steps: 作る色の数です。上端の色から下端の色までを等間隔で刻みます。
  func quantizedSkyColors(steps: Int) -> [Color] {
    guard steps > 1 else { return [skyTop] }

    return (0..<steps).map { index in
      let ratio = Double(index) / Double(steps - 1)
      return skyTopComponents.mixed(with: skyBottomComponents, ratio: ratio).color()
    }
  }

  /// 海面に使う色を返します。
  /// 空を映しつつ、水そのものの深さを表すために暗く沈ませ、青へ寄せます。
  /// これにより、空と水面の色が近い昼や夕方でも水際が見分けられます。
  func quantizedWaterColors(steps: Int) -> [Color] {
    guard steps > 1 else { return [skyTop] }

    return (0..<steps).map { index in
      let ratio = Double(index) / Double(steps - 1)
      let reflected = skyTopComponents.mixed(with: skyBottomComponents, ratio: ratio)
      return reflected
        .darkened(by: Self.waterDarkening)
        .mixed(with: Self.waterTint, ratio: Self.waterTintStrength)
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
    for hour: Double
  ) -> (previous: SkyKeyframe, next: SkyKeyframe, ratio: Double) {
    // キーフレームは時刻順に並んでおり、末尾が24時なので必ず区間が見つかります。
    for index in 0..<(keyframes.count - 1) {
      let previous = keyframes[index]
      let next = keyframes[index + 1]
      guard hour >= previous.hour, hour <= next.hour else { continue }

      let span = next.hour - previous.hour
      let ratio = span > 0 ? (hour - previous.hour) / span : 0
      return (previous, next, ratio)
    }
    // 丸め誤差などで区間から外れた場合は、最後のキーフレームを使います。
    let last = keyframes[keyframes.count - 1]
    return (last, last, 0)
  }

  /// 数値を比率で補間します。
  private static func interpolate(from start: Double, to end: Double, ratio: Double) -> Double {
    let clamped = min(max(ratio, 0), 1)
    return start + (end - start) * clamped
  }

  /// 太陽・月の水平位置を求めます。昼と夜でそれぞれ左から右へ一周します。
  private static func celestialProgress(at hour: Double) -> Double {
    if hour >= sunriseHour, hour <= sunsetHour {
      return (hour - sunriseHour) / (sunsetHour - sunriseHour)
    }

    // 夜は日の入りから翌日の日の出までを一区間として扱います。
    let nightSpan = 24 - sunsetHour + sunriseHour
    let elapsed = hour > sunsetHour ? hour - sunsetHour : hour + (24 - sunsetHour)
    return elapsed / nightSpan
  }

  /// 太陽・月の高さを求めます。区間の中央で最も高くなる弧を描きます。
  private static func celestialAltitude(at hour: Double) -> Double {
    let progress = celestialProgress(at: hour)
    // sinカーブで、区間の両端が地平線、中央が天頂になります。
    return sin(progress * Double.pi)
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
