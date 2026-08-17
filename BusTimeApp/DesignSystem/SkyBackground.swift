import SwiftUI

/// 月の満ち欠けを、実際の日付から求めます。
///
/// 新月から次の新月までの平均日数（朔望月）を使った近似です。
/// 実際の新月・満月と比べたずれは0.4日ほどで、絵として描くには十分な精度です。
enum MoonPhase {
  /// 基準にする新月です。2000年1月6日18時14分（協定世界時）が新月でした。
  private static let referenceNewMoon = Date(timeIntervalSince1970: 947_182_440)
  /// 朔望月の長さです。新月から次の新月までの平均日数です。
  static let synodicMonth: Double = 29.530588853

  /// その日時の月齢です。0が新月、およそ14.8が満月です。
  static func age(at date: Date) -> Double {
    let days = date.timeIntervalSince(referenceNewMoon) / 86_400
    let age = days.truncatingRemainder(dividingBy: synodicMonth)
    return age < 0 ? age + synodicMonth : age
  }

  /// その日時の位相です。0が新月、0.5が満月、1でまた新月に戻ります。
  static func phase(at date: Date) -> Double {
    age(at: date) / synodicMonth
  }
}

/// アプリ全体の背景です。画面いっぱいにドット絵の空を敷きます。
struct SkyBackground: View {
  var body: some View {
    SkyCanvas()
      .ignoresSafeArea()
      .accessibilityHidden(true)
  }
}

/// ドット絵の空そのものです。
///
/// すべての要素を正方形のセル単位に量子化し、グラデーションは横帯と
/// 市松模様のディザで表現します。夜は星空、昼は雲が現れ、太陽と月は
/// セルで組んだ円として時刻に応じて移動します。
///
/// 背景として使う場合は `SkyBackground` を、見本として小さく並べる場合は
/// この型を直接埋め込みます。
struct SkyCanvas: View {
  @Environment(\.sky) private var sky
  @Environment(\.skyWeather) private var weather
  /// iPhoneの「視差効果を減らす」設定です。
  /// オンのときは背景を動かさず、静止した一枚として描きます。
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// 背景を静止させるかどうかです。
  ///
  /// 「視差効果を減らす」設定に加えて、UIテストからの指定でも静止させます。
  /// 動き続ける層があるとアプリが静止状態にならず、
  /// UIテストの画面問い合わせが応答を待ち続けて失敗するためです。
  private var isStill: Bool {
    reduceMotion || Self.isStillBackgroundRequested
  }

  /// UIテストから背景の静止を指定されているかどうかです。
  private static let isStillBackgroundRequested = ProcessInfo.processInfo
    .arguments.contains(stillBackgroundArgument)

  /// 背景を静止させるために、UIテストが起動時に渡す引数です。
  static let stillBackgroundArgument = "-SkyBackgroundStill"

  // MARK: - 描画の基準値

  /// 1ドットとして扱う正方形の一辺です。この値がドット絵の粗さを決めます。
  private static let cellSize: CGFloat = 4
  /// 空に使う色の数です。少ないほどドット絵らしい階調になります。
  private static let skyColorSteps = 6
  /// 4×4のベイヤーマトリクスです。中間の階調を市松模様の濃淡で表すために使います。
  private static let ditherMatrix: [[Int]] = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5]
  ]
  /// 動く層を描き直す間隔です。滑らかに動かすより、ドット絵らしいコマ送りにします。
  private static let animationInterval: TimeInterval = 0.4
  /// 動きを止めるときに使う、時間の代わりの値です。
  /// どの値でも絵は成り立ちますが、毎回同じ見た目になるよう固定します。
  private static let stillTick = 0
  /// 動く層の基準時刻です。画面の再描画で周期がずれないよう、固定の起点を使います。
  private static let animationEpoch = Date(timeIntervalSinceReferenceDate: 0)
  /// 星の瞬きが変わる周期です。描き直し何回ぶんかで指定します。
  private static let twinkleTicks = 4
  /// 海面の光の粒のうち、位置が変わらない割合です。
  /// 残りが入れ替わることで、水面全体ではなく一部だけがゆらめきます。
  private static let reflectionStableRatio: Double = 0.62

  /// 雨粒を描き直す間隔です。落下が速いので海面より短くします。
  private static let rainInterval: TimeInterval = 0.05
  /// 雨粒が1秒間に落ちるマス数です。
  /// 描き直しの間隔を変えても見た目の速さが変わらないよう、秒あたりで持ちます。
  private static let rainSpeedPerSecond: Double = 110
  /// 雨粒1つの長さです。マス数で指定します。長すぎると紐のように見えます。
  private static let rainDropLength = 2
  /// 雨粒の色です。
  private static let rainColor = Color(red: 0.847, green: 0.906, blue: 0.976)
  /// 雨粒の濃さです。
  private static let rainOpacity: Double = 0.34
  /// 星を描く空の暗さの下限です。これより明るいと星は見えません。
  /// 夕焼けの残る空に星が出ないよう、暗さがある程度進んでから現れるようにします。
  private static let starVisibilityThreshold: Double = 0.22
  /// 画面に散らす星の数です。1粒が小さいぶん、数を多めにします。
  private static let starCount = 230
  /// 星を散らす範囲の下限です。画面の上からこの割合までに収め、空を見上げた構図にします。
  private static let starFieldRatio: Double = 0.45
  /// 星を散らす範囲の上限です。ステータスバーの真上に星が固まらないよう余白を空けます。
  private static let starFieldTopInset: Double = 0.03

  /// 流れ星が現れる周期です。この間隔ごとに一度だけ流れます。
  private static let shootingStarPeriod: Double = 52
  /// 流れ星が流れきるまでの時間です。
  private static let shootingStarDuration: Double = 1.3
  /// 流れ星を描き直す間隔です。動きが速いので短めにします。
  private static let shootingStarInterval: TimeInterval = 0.08
  /// 流れ星の尾の長さです。マス数で指定します。
  private static let shootingStarTail = 16
  /// 流れ星が横切る距離です。画面幅に対する割合で指定します。
  private static let shootingStarTravel: Double = 0.42
  /// 流れ星の色です。
  private static let shootingStarColor = Color(red: 1.0, green: 0.984, blue: 0.925)
  /// 流れ星の先端の濃さです。
  private static let shootingStarHeadOpacity: Double = 0.92
  /// 流れ星の尾の濃さです。
  private static let shootingStarTailOpacity: Double = 0.34

  /// 昼の太陽の半径です。セル数で指定します。
  private static let sunRadiusCells = 12
  /// 夜の月の半径です。セル数で指定します。
  private static let moonRadiusCells = 6

  /// 太陽・月が天頂にあるときの、画面高さに対する縦位置です。
  /// ステータスバーやDynamic Islandに重ならない高さで止めます。
  private static let zenithRatio: Double = 0.13

  /// 最も数の多い、ごく暗い星の色です。
  private static let faintStarColor = Color(red: 1.0, green: 0.965, blue: 0.855)
  /// 明るい星の色です。
  private static let brightStarColor = Color(red: 1.0, green: 0.937, blue: 0.780)
  /// 少数だけ混ぜる青い星の色です。黄みの中に置くことで色の幅が出ます。
  private static let blueStarColor = Color(red: 0.78, green: 0.87, blue: 1.0)
  /// 最も明るい、十字に描く星の色です。
  private static let warmStarColor = Color(red: 1.0, green: 0.847, blue: 0.494)

  /// 水平線の位置です。これより下は海面で、太陽・月もこの高さに沈みます。
  private static let horizonRatio: Double = 0.55
  /// 海面の横波の細かさです。値が小さいほど大きなうねりになります。
  private static let waveFrequency: Double = 0.19
  /// 波の山と谷で色を何段ずらすかです。映り込みの位置だけでは分かりにくい明暗を補います。
  private static let waveBrightness: Double = 1.45
  /// 海面の横波の振幅です。空を映す位置をこの分だけ揺らします。
  private static let waveAmplitude: Double = 0.016
  /// 水平線の直下を暗くする範囲です。画面高さに対する割合で指定します。
  private static let horizonShadeBand: Double = 0.05
  /// 水平線の直下を暗くする強さです。色を何段ずらすかで指定します。
  private static let horizonShadeDepth: Double = 1.6
  /// 波が進む速さです。描き直し1回あたりに位相がどれだけ進むかを表します。
  private static let waveSpeed: Double = 0.22
  /// 海面に落ちる光の道の濃さです。文字の読みやすさを保つため控えめにします。
  private static let reflectionOpacity: Double = 0.26
  /// 光の道が水平線から手前に向かって広がる倍率です。
  private static let reflectionSpread: Double = 1.8
  /// 水際での光の粒の密度です。手前に向かって減っていきます。
  private static let reflectionDensity: Double = 0.5
  /// 波が沖から岸へ進む速さです。描き直し1回あたりに位相がどれだけ進むかを表します。
  private static let swellSpeed: Double = 0.045
  /// 画面内に並ぶ波の数です。
  private static let swellFrequency: Double = 7.0
  /// 波の筋を描く高さのしきい値です。値が大きいほど筋が細くなります。
  private static let swellThreshold: Double = 0.55
  /// 白波が立つ高さのしきい値です。波の頂点付近だけが白くなります。
  private static let whitecapThreshold: Double = 0.88
  /// 波の筋にマスが現れる割合です。
  private static let swellChance: Double = 0.55
  /// 波の筋が横方向にうねる細かさです。
  private static let swellWaviness: Double = 0.06
  /// 波の筋が横方向にうねる深さです。位相のずれ量で指定します。
  private static let swellWaveDepth: Double = 0.10
  /// 波の筋の濃さです。
  private static let rippleOpacity: Double = 0.045
  /// 白波の濃さです。
  private static let whitecapOpacity: Double = 0.15

  /// 波打ち際の泡が伸びる高さです。マス数で指定します。
  private static let surfHeight = 4
  /// 波が寄せて返す周期です。描き直し何回ぶんで一往復するかを表します。
  private static let surfPeriod: Double = 26
  /// 波打ち際の泡の濃さです。
  private static let surfOpacity: Double = 0.42

  /// 岸辺が始まる位置です。ここで海が終わります。
  private static let shoreRatio: Double = 0.76
  /// 面の境目を市松で馴染ませる行数です。
  private static let groundEdgeRows = 5
  /// 道路にひび割れが現れる割合です。
  private static let roadCrackChance: Double = 0.055
  /// 道路に色あせが現れる割合です。
  private static let roadFadeChance: Double = 0.045
  /// センターラインが剥がれている割合です。
  private static let roadLineWearChance: Double = 0.34
  /// バス停の支柱が錆びて欠けている割合です。
  private static let poleWearChance: Double = 0.16
  /// 道路が始まる位置です。
  private static let roadRatio: Double = 0.80
  /// 道路のセンターラインを引く位置です。
  private static let roadLineRatio: Double = 0.90
  /// センターラインの一本の長さです。セル数で指定します。
  private static let roadDashLength = 7
  /// センターラインの間隔です。セル数で指定します。
  private static let roadDashGap = 6

  /// バス停を立てる横位置です。
  private static let busStopRatio: Double = 0.13
  /// 対岸の陸地の、いちばん低いところの高さです。セルの数で数えます。
  private static let distantShoreBaseHeight = 1
  /// 対岸に建つものの、最も高いところの高さです。
  /// 遠くにあるものなので、低く抑えるほうが距離が出ます。
  private static let distantShoreMaxHeight = 4
  /// 建物が現れる割合です。これを超えた列だけ高くなります。
  private static let distantBuildingChance: Double = 0.80
  /// 対岸の色を、空の色からどれだけ暗くするかです。
  private static let distantShoreDarkening: Double = 0.55
  /// 対岸に灯りがともる割合です。夜だけ現れます。
  private static let distantLightChance: Double = 0.86
  /// 対岸の灯りの色です。
  private static let distantLightColor = Color(red: 1.0, green: 0.898, blue: 0.647)
  /// 街灯を吊る電柱です。`utilityPoleRatios` の何本目かで指定します。
  ///
  /// 傘は支柱の左へ伸びるので、照らしたいものより右の電柱を選びます。
  /// 1本目はバス停を照らし、2本目は道路の先を照らします。
  private static let lightedPoleIndices: Set<Int> = [0, 1]
  /// 電柱のどの高さに街灯を吊るかです。路面からのセル数で指定します。
  /// バス停は支柱14セルに標識11セルで約25セルあるため、
  /// 街灯はそれよりはっきり高くして、道路の照明らしく見せます。
  private static let streetLightHeight = 42
  /// 街灯の傘の幅です。セル数で指定します。
  private static let streetLightHeadWidth = 7
  /// 街灯の光だまりが路面に広がる幅です。セル数で指定します。
  private static let streetLightGlowWidth = 32
  /// 光だまりが手前へ伸びる深さです。セル数で指定します。
  private static let streetLightGlowDepth = 9
  /// 街灯が点く時刻です。これ以降は夕方から夜として扱います。
  /// 風が最も強いとみなす速さです。これ以上は同じ扱いにします。
  private static let strongWindSpeed: Double = 15
  /// 風が最も強いときに、雨や雪が横へ流れる量です。落ちた距離に対する割合です。
  private static let precipitationSlant: Double = 0.7
  /// 風が最も強いときに、白波が立ちやすくなる度合いです。
  private static let windWhitecapBoost: Double = 0.18
  /// 雲を空の色で染める強さです。
  private static let cloudTintStrength: Double = 0.42
  /// 波紋の粒の細かさです。風景の何分の1の大きさで描くかを指定します。
  /// 風景と同じ粗さでは輪が点に潰れてしまうため、ここだけ細かくして
  /// 広がっていく輪として見えるようにします。
  private static let rippleSubdivision = 2
  /// 波紋の輪が広がりきる半径です。細かい粒の数で指定します。
  private static let rippleMaxRadius = 4
  /// 手前の海面での、輪の縦の潰れ具合です。横の半径に対する割合で指定します。
  /// 水面を斜めから見ているので、輪は真円ではなく横長の楕円に見えます。
  private static let rippleFlattenNear: Double = 0.55
  /// 水平線近くでの、輪の縦の潰れ具合です。遠いほど水面を浅い角度で見るため、より潰れます。
  private static let rippleFlattenFar: Double = 0.22
  /// 同時に見えている波紋の数です。雨の強さに応じて増えます。
  private static let rippleCountPerIntensity = 90
  /// 波紋が現れてから消えるまでのコマ数です。
  private static let rippleLifeTicks = 3
  /// 波紋の濃さです。
  private static let rippleOpacityValue: Double = 0.30
  /// 星座の星の色です。まわりの星より明るく置きます。
  private static let constellationStarColor = Color(red: 1.0, green: 0.98, blue: 0.92)
  /// 星座を結ぶ線の濃さです。
  private static let constellationLineOpacity: Double = 0.12
  /// 星座の星の濃さです。
  private static let constellationStarOpacity: Double = 0.85
  /// 風が最も強いときに、鳥の飛ぶ速さが何倍になるかです。
  private static let birdWindSpeedBoost: Double = 1.8
  /// ガードレールを立てる高さです。道路の海側の縁に置きます。
  private static let guardrailRatio: Double = 0.795
  /// ガードレールの支柱の間隔です。セル数で指定します。
  private static let guardrailPostSpacing = 14
  /// ガードレールの支柱の高さです。セル数で指定します。
  private static let guardrailPostHeight = 5
  /// 電柱を立てる横位置です。等間隔に並べます。
  /// 電線のたるみは、この間隔がそのまま画面の外へ続くものとして描きます。
  private static let utilityPoleRatios: [Double] = [0.26, 0.96]
  /// 電柱の高さです。セル数で指定します。街灯より高くします。
  private static let utilityPoleHeight = 72
  /// 電柱の腕木の幅です。セル数で指定します。
  private static let utilityPoleArmWidth = 9
  /// 電柱の太さです。マス数で指定します。
  private static let utilityPoleWidth = 2
  /// 電線が垂れ下がる深さです。セル数で指定します。
  private static let powerLineSag = 4
  /// 電線の本数です。
  private static let powerLineCount = 3
  /// 電線どうしの間隔です。マス数で指定します。
  private static let powerLineSpacing = 3
  /// 電柱の濃さです。空に対して影になる程度にします。
  private static let utilityPoleInkOpacity: Double = 0.55
  /// 電線の濃さです。電柱より細い線なので、薄めにして柵に見えないようにします。
  private static let powerLineInkOpacity: Double = 0.42
  /// 飛行機が現れる周期です。
  private static let airplanePeriod: Double = 240
  /// 飛行機が渡りきるまでの時間です。
  private static let airplaneDuration: Double = 46
  /// 飛行機の灯りが点滅する周期です。描き直し何回ぶんかで指定します。
  private static let airplaneBlinkTicks = 4
  /// 積もった雪の濃さです。降り続けても路面が完全には埋まらない濃さにします。
  private static let snowCoverOpacity: Double = 0.44
  /// 積雪をひとかたまりとして扱う大きさです。マス数で指定します。
  private static let snowPatchCells = 3
  /// 手前の路面で雪がどれだけ減るかです。踏み固められて消えていく分です。
  private static let snowClearedRatio: Double = 0.45
  /// 濡れた路面で、街灯の光がどれだけ強く映るかです。
  private static let wetRoadGlowBoost: Double = 1.9
  private static let streetLightOnHour: Double = 16
  /// 街灯が消える時刻です。これ以降は朝として扱います。
  private static let streetLightOffHour: Double = 4.5
  /// 点灯している街灯の、灯りの濃さの下限です。薄暮でも点いていると分かる強さにします。
  private static let streetLightBulbFloor: Double = 0.55
  /// 光だまりを道路の手前端からどれだけ奥へずらすかです。セル数で指定します。
  /// 道路の縁に貼りつくと手前に寄って見えるため、少し奥に落とします。
  private static let streetLightGlowLift = 5
  /// 光だまりの最も明るいところの濃さです。
  private static let streetLightGlowOpacity: Double = 0.16
  /// 光の筋の最も明るいところの濃さです。
  /// 空気に散った光なので、路面の光だまりより淡くします。
  private static let streetLightBeamOpacity: Double = 0.09
  /// 光だまりの粒を、風景の何分の1の大きさで描くかです。
  /// 細かいほど減衰が滑らかになります。
  private static let streetLightGlowSubdivision = 2
  /// 街灯の光の色です。
  private static let streetLightColor = Color(red: 1.0, green: 0.925, blue: 0.741)
  /// 雲が最も多いときに増やす数です。雲量に応じてこの数まで増えます。
  private static let extraCloudCount = 5
  /// 風速1メートルあたり、雲が1秒でどれだけ流れるかです。画面幅に対する割合です。
  private static let cloudDriftPerWind: Double = 0.0016
  /// 雪が1秒間に落ちるマス数です。雨よりゆっくり舞います。
  private static let snowSpeedPerSecond: Double = 26
  /// 雪が横に揺れる幅です。マス数で指定します。
  private static let snowSwayCells: Double = 3
  /// 雪の色です。
  private static let snowColor = Color(red: 0.97, green: 0.98, blue: 1.0)
  /// 霧の濃さです。
  private static let fogOpacity: Double = 0.30
  /// 霧がかかる高さの範囲です。水平線を中心に上下へ広がります。
  private static let fogBand: Double = 0.22
  /// 雷が光る周期です。この間隔ごとに一度光ります。
  private static let lightningPeriod: Double = 11
  /// 雷の光っている時間です。
  private static let lightningDuration: Double = 0.22
  /// 潮の満ち引きで波打ち際が動く幅です。セル数で指定します。
  /// 砂浜の高さは約9セルしかないため、大きく振ると満潮時に砂浜が消えます。
  private static let tideRangeCells = 2
  /// 潮が一巡する時間です。実際の潮汐に合わせて約12.4時間にします。
  private static let tidePeriodHours: Double = 12.4
  /// 鳥が現れる空の暗さの範囲です。朝夕の薄明のときだけ飛びます。
  private static let birdNightnessRange: ClosedRange<Double> = 0.18...0.72
  /// 鳥の群れの数です。
  private static let birdCount = 5
  /// 鳥が画面を横切るのにかかる時間です。
  private static let birdTravelSeconds: Double = 26
  /// 鳥が羽ばたく周期です。描き直し何回ぶんで一往復するかを表します。
  private static let birdFlapTicks = 3
  /// 船が現れる周期です。この間隔ごとに一度だけ通ります。
  private static let shipPeriod: Double = 190
  /// 船が水平線を渡りきるまでの時間です。
  private static let shipDuration: Double = 70
  /// バス停の標識の一辺です。セル数で指定します。
  private static let signSize = 11
  /// バス停の支柱の高さです。セル数で指定します。
  private static let poleHeight = 14
  /// バス停の支柱の太さです。セル数で指定します。
  private static let poleWidth = 2

  /// ドット絵の雲の形です。各行の(左端のセル位置, 幅のセル数)を上から順に並べます。
  private static let cloudRows: [(offsetX: Int, width: Int)] = [
    (2, 3),
    (1, 6),
    (0, 9)
  ]

  /// 星座の定義です。星の位置は星座ごとの正方形の中の割合で持ちます。
  struct Constellation {
    /// この星座が見える季節です。
    let season: Season
    /// 画面上のどこに置くかです。左上を基準にした割合です。
    let origin: CGPoint
    /// 画面に対する大きさです。
    let scale: Double
    /// 星の位置です。
    let stars: [CGPoint]
    /// 結ぶ星の組です。
    let links: [(Int, Int)]
  }

  /// 季節ごとの代表的な星座です。
  static let constellations: [Constellation] = [
    // 冬のオリオン座です。三つ星と四辺の star が特徴です。
    Constellation(
      season: .winter,
      origin: CGPoint(x: 0.60, y: 0.08),
      scale: 0.26,
      stars: [
        CGPoint(x: 0.00, y: 0.00),
        CGPoint(x: 0.62, y: 0.06),
        CGPoint(x: 0.26, y: 0.44),
        CGPoint(x: 0.38, y: 0.50),
        CGPoint(x: 0.50, y: 0.56),
        CGPoint(x: 0.10, y: 0.96),
        CGPoint(x: 0.70, y: 0.98)
      ],
      links: [(0, 2), (1, 4), (2, 3), (3, 4), (2, 5), (4, 6)]
    ),
    // 春の北斗七星です。ひしゃくの形に結びます。
    Constellation(
      season: .spring,
      origin: CGPoint(x: 0.12, y: 0.07),
      scale: 0.34,
      stars: [
        CGPoint(x: 0.00, y: 0.30),
        CGPoint(x: 0.18, y: 0.10),
        CGPoint(x: 0.40, y: 0.06),
        CGPoint(x: 0.58, y: 0.20),
        CGPoint(x: 0.72, y: 0.40),
        CGPoint(x: 0.90, y: 0.50),
        CGPoint(x: 1.00, y: 0.30)
      ],
      links: [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6)]
    ),
    // 夏の大三角です。3つの明るい星だけを結びます。
    Constellation(
      season: .summer,
      origin: CGPoint(x: 0.30, y: 0.06),
      scale: 0.34,
      stars: [
        CGPoint(x: 0.00, y: 0.00),
        CGPoint(x: 0.86, y: 0.26),
        CGPoint(x: 0.30, y: 0.92)
      ],
      links: [(0, 1), (1, 2), (2, 0)]
    ),
    // 秋のカシオペヤ座です。Wの形に結びます。
    Constellation(
      season: .autumn,
      origin: CGPoint(x: 0.18, y: 0.09),
      scale: 0.30,
      stars: [
        CGPoint(x: 0.00, y: 0.00),
        CGPoint(x: 0.22, y: 0.42),
        CGPoint(x: 0.48, y: 0.10),
        CGPoint(x: 0.74, y: 0.46),
        CGPoint(x: 1.00, y: 0.06)
      ],
      links: [(0, 1), (1, 2), (2, 3), (3, 4)]
    )
  ]

  /// 雲を置く位置と大きさです。位置は画面に対する比率、大きさはセルの倍率です。
  private static let cloudLayout: [(x: Double, y: Double, scale: Int)] = [
    (0.06, 0.09, 4),
    (0.63, 0.05, 6),
    (0.36, 0.21, 4)
  ]

  /// 雲量が多いときに足す雲です。空が埋まるように配置します。
  private static let extraCloudLayout: [(x: Double, y: Double, scale: Int)] = [
    (0.82, 0.16, 5),
    (0.20, 0.30, 5),
    (0.50, 0.34, 4),
    (0.00, 0.19, 6),
    (0.70, 0.27, 4)
  ]

  var body: some View {
    ZStack {
      staticLayer
      animatedLayer
      shootingStarLayer
      rainLayer
    }
  }

  /// 時刻が変わるまで描き直す必要のない層です。
  /// 走査量の多い空と路面はここに置き、動く層では触りません。
  private var staticLayer: some View {
    Canvas { context, size in
      drawSkyBase(in: &context, size: size)
      drawCelestialBody(in: &context, size: size)
      // 対岸は太陽や月より手前です。水平線に沈む様子を隠して奥行きを作ります。
      drawDistantShore(in: &context, size: size)
      drawGround(in: &context, size: size)
    }
  }

  /// 一定間隔で描き直す層です。
  /// 海面と、その上に重なる岸辺の水打ち際・バス停までをまとめて描きます。
  ///
  /// 「視差効果を減らす」設定がオンのときは描き直しをやめ、静止した一枚にします。
  /// 風景そのものは残したまま、絶え間なく動くことによる負担だけを取り除きます。
  @ViewBuilder
  private var animatedLayer: some View {
    if isStill {
      Canvas { context, size in
        drawSeaScene(in: &context, size: size, tick: Self.stillTick)
      }
    } else {
      TimelineView(.periodic(from: Self.animationEpoch, by: Self.animationInterval)) { timeline in
        let tick = Int(timeline.date.timeIntervalSinceReferenceDate / Self.animationInterval)

        Canvas { context, size in
          drawSeaScene(in: &context, size: size, tick: tick)
        }
      }
    }
  }

  /// 海と岸辺の一場面を描きます。動かす場合も止める場合も、同じ絵を使います。
  private func drawSeaScene(in context: inout GraphicsContext, size: CGSize, tick: Int) {
    // 雲は風で流れるので、静止した層ではなくここで描きます。
    drawClouds(in: &context, size: size, tick: tick)
    drawWater(in: &context, size: size, tick: tick)
    drawSwell(in: &context, size: size, tick: tick)
    drawReflectionPath(in: &context, size: size, tick: tick)
    drawStars(in: &context, size: size, tick: tick / Self.twinkleTicks)
    drawConstellations(in: &context, size: size)
    drawShoreEdge(in: &context, size: size)
    drawSurf(in: &context, size: size, tick: tick)
    drawShip(in: &context, size: size, elapsed: Double(tick) * Self.animationInterval)
    drawBirds(in: &context, size: size, tick: tick)
    // 街灯とバス停は海より手前です。静止した層に描くと、
    // 支柱の上半分が海に覆われて見えなくなります。
    drawGuardrail(in: &context, size: size)
    drawUtilityPoles(in: &context, size: size)
    drawStreetLights(in: &context, size: size)
    drawBusStop(in: &context, size: size)
    drawAirplane(in: &context, size: size, elapsed: Double(tick) * Self.animationInterval)
    // 雨が海面を叩く跳ねです。海の描画のあとに重ねます。
    drawRainRipples(in: &context, size: size, tick: tick)
    // 積もった雪は地面の上、霧の下に重ねます。
    drawSnowCover(in: &context, size: size)
    // 霧はいちばん最後に重ね、遠くのものほど霞ませます。
    drawFog(in: &context, size: size)
  }

  /// 潮の満ち引きを含めた、海と砂浜の境目の行です。
  /// 海・砂浜・泡・光の道のすべてがこの行を基準にします。
  /// 一部だけ潮位を反映すると、泡だけが砂浜の上へ取り残されます。
  private func tidalShoreRow(rowCount: Int) -> Int {
    min(max(Int(Self.shoreRatio * Double(rowCount)) + tideOffsetCells, 0), rowCount)
  }

  /// 潮の満ち引きを含めた、海と砂浜の境目の縦位置です。
  private func tidalShoreY(size: CGSize) -> CGFloat {
    snapped(CGFloat(Self.shoreRatio) * size.height)
      + CGFloat(tideOffsetCells) * Self.cellSize
  }

  /// 潮の満ち引きによる、波打ち際のずれです。
  ///
  /// 満潮のときは波が陸へ寄り、干潮のときは沖へ引きます。
  /// 約12.4時間で一巡するので、朝と夕で海際の位置が変わります。
  private var tideOffsetCells: Int {
    let phase = sin(sky.hour / Self.tidePeriodHours * 2 * .pi)
    return Int(phase * Double(Self.tideRangeCells))
  }

  /// 朝夕に横切る鳥の群れです。
  ///
  /// 空が明るいときも暗いときも出さず、薄明のあいだだけ飛ばします。
  /// 一日のうち短い時間にしか会えないほうが、見かけたときの印象が残ります。
  private func drawBirds(in context: inout GraphicsContext, size: CGSize, tick: Int) {
    guard Self.birdNightnessRange.contains(sky.nightness) else { return }

    let cell = Self.cellSize
    let elapsed = Double(tick) * Self.animationInterval
    // 風が強い日ほど速く飛びます。
    let speed = 1 + windStrength * (Self.birdWindSpeedBoost - 1)
    let travelSeconds = Self.birdTravelSeconds / speed
    let rawProgress = (elapsed / travelSeconds).truncatingRemainder(dividingBy: 1)
    // 風下へ向かって飛びます。風がないときは左から右へ渡ります。
    let isTailwind = weather.windSpeed >= 0
    let progress = isTailwind ? rawProgress : 1 - rawProgress
    // 羽ばたきは上下2つの形を交互に出します。
    let isFlapUp = (tick / Self.birdFlapTicks) % 2 == 0

    var path = Path()
    for index in 0..<Self.birdCount {
      // 群れは少しずつ位置と高さをずらし、隊列に見えるようにします。
      let lag = Double(index) * 0.035
      let x = (progress - lag) * 1.2 - 0.1
      guard x > -0.05, x < 1.05 else { continue }

      let y = 0.18 + pseudoRandom(index * 19 + 7) * 0.12 + Double(index % 2) * 0.02
      let column = Int(x * size.width / cell)
      let row = Int(y * size.height / cell)

      // 翼を「へ」の字で表します。
      let wing = isFlapUp ? 1 : 0
      for side in [-1, 1] {
        path.addRect(
          CGRect(
            x: CGFloat(column + side) * cell,
            y: CGFloat(row - wing) * cell,
            width: cell,
            height: cell
          )
        )
      }
      path.addRect(
        CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
      )
    }

    context.fill(path, with: .color(sky.ink.opacity(0.45)))
  }

  /// 水平線を渡る船です。まれにしか通りません。
  private func drawShip(in context: inout GraphicsContext, size: CGSize, elapsed: Double) {
    let phase = elapsed.truncatingRemainder(dividingBy: Self.shipPeriod)
    guard phase < Self.shipDuration else { return }

    let cell = Self.cellSize
    let rowCount = max(Int(ceil(size.height / cell)), 1)
    let horizonRow = Int(Self.horizonRatio * Double(rowCount))
    let progress = phase / Self.shipDuration
    let column = Int((1 - progress) * size.width / cell)

    var path = Path()
    // 船体です。水平線のすぐ上に置きます。
    for offset in 0..<5 {
      path.addRect(
        CGRect(
          x: CGFloat(column + offset) * cell,
          y: CGFloat(horizonRow - 1) * cell,
          width: cell,
          height: cell
        )
      )
    }
    // 船橋です。
    path.addRect(
      CGRect(
        x: CGFloat(column + 2) * cell,
        y: CGFloat(horizonRow - 2) * cell,
        width: cell,
        height: cell
      )
    )

    context.fill(path, with: .color(sky.skyBottom))
    context.fill(path, with: .color(Color.black.opacity(Self.distantShoreDarkening)))
  }

  /// 濡れた路面で光がどれだけ強く映るかです。
  /// 雨の夜は路面が鏡のようになり、街灯の光が伸びて明るく映ります。
  private var wetRoadFactor: Double {
    weather.isRaining ? Self.wetRoadGlowBoost : 1
  }

  /// 風の強さを0から1で表した値です。各要素の揺れ方をここに合わせます。
  private var windStrength: Double {
    min(weather.windSpeed / Self.strongWindSpeed, 1)
  }

  /// 街灯が点いているかどうかです。
  ///
  /// 実際の街灯は暗ければ点きますが、夜明け前から朝にかけて点いていると
  /// 「これから明るくなる」時間帯の印象と合いません。
  /// 夕方から夜のあいだだけ点け、朝と昼は消します。
  private var isStreetLightOn: Bool {
    let isEveningOrNight = sky.hour >= Self.streetLightOnHour
      || sky.hour < Self.streetLightOffHour
    return isEveningOrNight && sky.nightness > Self.starVisibilityThreshold
  }

  /// 点灯している街灯の、灯り部分の濃さです。
  private var streetLightBulbOpacity: Double {
    Self.streetLightBulbFloor + (1 - Self.streetLightBulbFloor) * sky.nightness
  }

  /// 街灯から路面へ広がる光の筋です。
  ///
  /// 灯りと路面の光だまりだけでは、光が届いている空間が見えません。
  /// 灯りを頂点に、路面へ向かって末広がりの筋を薄く敷きます。
  /// 空気に散った光なので、路面の光だまりよりさらに淡くします。
  private func drawStreetLightBeam(
    in context: inout GraphicsContext,
    size: CGSize,
    headRow: Int,
    roadRow: Int,
    centerColumn: Int
  ) {
    guard roadRow > headRow else { return }

    let cell = Self.cellSize
    let subdivision = Self.streetLightGlowSubdivision
    let beamCell = cell / CGFloat(subdivision)
    let centerX = CGFloat(centerColumn) * cell
    let topY = CGFloat(headRow + 1) * cell
    // 筋の着地点も光だまりに合わせて奥へずらします。
    let rowSteps = (roadRow - Self.streetLightGlowLift - headRow - 1) * subdivision
    guard rowSteps > 0 else { return }

    // 路面に着くときの広がりは、光だまりの幅に合わせます。
    let bottomHalfWidth = Double(Self.streetLightGlowWidth / 2 * subdivision)

    for step in 0..<rowSteps {
      let progress = Double(step) / Double(rowSteps)
      let y = topY + CGFloat(step) * beamCell
      guard y < size.height else { continue }

      // 灯りの真下ほど細く、路面に近づくほど広がります。
      let halfWidth = max(bottomHalfWidth * progress, 1)
      // 遠ざかるほど弱まります。
      let verticalFade = 1 - progress

      var rowPath = Path()
      for offset in -Int(halfWidth)...Int(halfWidth) {
        let horizontal = Double(abs(offset)) / halfWidth
        let intensity = max((1 - horizontal * horizontal) * verticalFade, 0)
        guard intensity > 0.03 else { continue }
        guard pseudoRandom(offset &* 29 &+ step &* 181 &+ centerColumn &* 11 &+ 7) < intensity else { continue }

        rowPath.addRect(
          CGRect(
            x: centerX + CGFloat(offset) * beamCell,
            y: y,
            width: beamCell,
            height: beamCell
          )
        )
      }

      context.fill(
        rowPath,
        with: .color(
          Self.streetLightColor.opacity(sky.nightness * Self.streetLightBeamOpacity * verticalFade)
        )
      )
    }
  }

  /// その季節に見える星座です。
  ///
  /// 星は完全に散らばっているだけで、見上げても「知っている形」がありません。
  /// 実在の星座をいくつか置くと、同じ空でも見覚えのある空になります。
  /// 季節ごとに代表的なものを選び、その時期にだけ現れるようにします。
  private func drawConstellations(in context: inout GraphicsContext, size: CGSize) {
    guard sky.nightness > Self.starVisibilityThreshold else { return }

    let cell = Self.cellSize
    let strength = sky.nightness

    for constellation in Self.constellations where constellation.season == sky.season {
      var starPath = Path()
      var linePath = Path()

      // 星の位置です。縦横とも同じ長さを基準にし、星座の形が縦に伸びないようにします。
      // 横長の画面では幅を基準にすると大きくなりすぎるので、短いほうの辺に合わせます。
      let unit = min(size.width, size.height) * constellation.scale
      func point(_ index: Int) -> CGPoint {
        let star = constellation.stars[index]
        return CGPoint(
          x: constellation.origin.x * size.width + star.x * unit,
          y: constellation.origin.y * size.height + star.y * unit
        )
      }

      for index in constellation.stars.indices {
        let position = point(index)
        // まわりの明るい星と同じ十字形にして、星座だけ浮かないようにします。
        appendCross(to: &starPath, x: snapped(position.x), y: snapped(position.y))
      }

      // 星どうしを結ぶ線です。細いドットの列で引きます。
      for link in constellation.links {
        let from = point(link.0)
        let to = point(link.1)
        let steps = Int(max(abs(to.x - from.x), abs(to.y - from.y)) / cell)
        guard steps > 0 else { continue }

        for step in 0...steps {
          let ratio = Double(step) / Double(steps)
          let x = from.x + (to.x - from.x) * ratio
          let y = from.y + (to.y - from.y) * ratio
          linePath.addRect(
            CGRect(x: snapped(x), y: snapped(y), width: cell, height: cell)
          )
        }
      }

      context.fill(
        linePath,
        with: .color(Self.constellationStarColor.opacity(Self.constellationLineOpacity * strength))
      )
      context.fill(
        starPath,
        with: .color(Self.constellationStarColor.opacity(Self.constellationStarOpacity * strength))
      )
    }
  }

  /// 道路の海側に立つガードレールです。
  ///
  /// 道路と砂浜が地続きに見えていたので、境目に一本入れて region を分けます。
  private func drawGuardrail(in context: inout GraphicsContext, size: CGSize) {
    let cell = Self.cellSize
    let columnCount = max(Int(ceil(size.width / cell)), 1)
    let rowCount = max(Int(ceil(size.height / cell)), 1)
    let railRow = Int(Self.guardrailRatio * Double(rowCount))
    guard railRow > 0, railRow < rowCount else { return }

    var path = Path()
    // 横に伸びる帯を2本引きます。
    for offset in [0, 2] {
      path.addRect(
        CGRect(
          x: 0,
          y: CGFloat(railRow + offset) * cell,
          width: size.width,
          height: cell
        )
      )
    }

    // 一定の間隔で支柱を立てます。
    for column in stride(from: 0, to: columnCount, by: Self.guardrailPostSpacing) {
      for offset in 0..<Self.guardrailPostHeight {
        path.addRect(
          CGRect(
            x: CGFloat(column) * cell,
            y: CGFloat(railRow + offset) * cell,
            width: cell,
            height: cell
          )
        )
      }
    }

    context.fill(path, with: .color(sky.road))
    context.fill(path, with: .color(Color.white.opacity(0.18)))
  }

  /// 道路沿いの電柱と電線です。
  ///
  /// 画面を横切る線が入ると構図が締まり、空と地面が結びつきます。
  private func drawUtilityPoles(in context: inout GraphicsContext, size: CGSize) {
    let cell = Self.cellSize
    let rowCount = max(Int(ceil(size.height / cell)), 1)
    let baseRow = Int(Self.roadRatio * Double(rowCount))
    let color = sky.skyBottom

    var path = Path()
    var wirePath = Path()
    var columns: [Int] = []

    for ratio in Self.utilityPoleRatios {
      let column = Int(ratio * size.width / cell)
      columns.append(column)

      // 支柱です。1マスだと空に溶けてしまうので、2マスの幅で立てます。
      for row in (baseRow - Self.utilityPoleHeight)..<baseRow where row >= 0 {
        path.addRect(
          CGRect(
            x: CGFloat(column) * cell,
            y: CGFloat(row) * cell,
            width: cell * CGFloat(Self.utilityPoleWidth),
            height: cell
          )
        )
      }

      // 腕木です。上下に2本渡します。
      for armOffset in [0, 4] {
        let armRow = baseRow - Self.utilityPoleHeight + armOffset
        guard armRow >= 0 else { continue }
        for offset in -(Self.utilityPoleArmWidth / 2)...(Self.utilityPoleArmWidth / 2) {
          path.addRect(
            CGRect(
              x: CGFloat(column + offset) * cell,
              y: CGFloat(armRow) * cell,
              width: cell,
              height: cell
            )
          )
        }
      }
    }

    // 電線です。電柱のあいだを、たるませながら渡します。
    let topRow = baseRow - Self.utilityPoleHeight
    columns.sort()
    for lineIndex in 0..<Self.powerLineCount {
      let lineRow = topRow + lineIndex * Self.powerLineSpacing
      guard lineRow >= 0 else { continue }

      var previousRow: Int?
      for column in 0..<max(Int(ceil(size.width / cell)), 1) {
        // 最も近い2本の電柱のあいだで、たるみを放物線で作ります。
        let row = lineRow + powerLineSag(atColumn: column, poles: columns)
        guard row >= 0, row < rowCount else { continue }

        // 隣の列と高さが変わるときは、そのあいだも埋めます。
        // 1マスずつ置くだけでは、たるみが階段状に途切れて見えます。
        let from = min(previousRow ?? row, row)
        let to = max(previousRow ?? row, row)
        for filled in from...to where filled >= 0 && filled < rowCount {
          wirePath.addRect(
            CGRect(x: CGFloat(column) * cell, y: CGFloat(filled) * cell, width: cell, height: cell)
          )
        }
        previousRow = row
      }
    }

    // 電線は電柱より細いので、同じ濃さで塗ると柵のように見えます。薄く落とします。
    context.fill(wirePath, with: .color(color))
    context.fill(wirePath, with: .color(Color.black.opacity(Self.powerLineInkOpacity)))
    context.fill(path, with: .color(color))
    context.fill(path, with: .color(Color.black.opacity(Self.utilityPoleInkOpacity)))
  }

  /// その列で電線がどれだけ垂れ下がるかです。
  ///
  /// 電線は電柱の腕木に留まっているので、電柱の位置では垂れ下がりが0になり、
  /// 電柱と電柱のちょうど中間で最も垂れます。画面の外にも電柱が続いているものとして、
  /// 両端の外側にも同じ間隔で仮の電柱を置き、端まで同じ形で垂らします。
  private func powerLineSag(atColumn column: Int, poles: [Int]) -> Int {
    guard let first = poles.first, poles.count >= 2 else { return 0 }

    // 電柱は等間隔に並んでいるので、隣り合う2本の間隔をそのまま周期に使います。
    let span = Double(poles[1] - first)
    guard span > 0 else { return 0 }
    // 最も近い電柱からの距離を、電柱の間隔に対する割合で求めます。
    let distance = (Double(column) - Double(first)) / span
    let local = distance - distance.rounded(.down)
    // 0と1で0、0.5で1になる山なりの曲線です。
    let position = 1 - abs(local - 0.5) * 2

    return Int(position * Double(Self.powerLineSag))
  }

  /// 夜空をゆっくり横切る飛行機です。
  ///
  /// 機体は見えず、点滅する灯りだけが動きます。
  private func drawAirplane(in context: inout GraphicsContext, size: CGSize, elapsed: Double) {
    guard sky.nightness > Self.starVisibilityThreshold else { return }

    let phase = elapsed.truncatingRemainder(dividingBy: Self.airplanePeriod)
    guard phase < Self.airplaneDuration else { return }

    let cell = Self.cellSize
    let progress = phase / Self.airplaneDuration
    let column = Int(progress * size.width / cell)
    let row = Int(0.10 * size.height / cell)

    // 点滅しているあいだだけ灯ります。
    let isBlinkOn = (Int(elapsed / Self.animationInterval) / Self.airplaneBlinkTicks) % 2 == 0
    guard isBlinkOn else { return }

    context.fill(
      Path(CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)),
      with: .color(Color(red: 1.0, green: 0.55, blue: 0.5).opacity(0.9))
    )
  }

  /// 雨が海面に落ちた跳ねです。
  ///
  /// 実際の波紋は同心円ですが、この粗さでは輪を描いても点にしかなりません。
  /// そこで粒をあえて大きくし、短い横棒として水面のきらめきだけを表します。
  private func drawRainRipples(in context: inout GraphicsContext, size: CGSize, tick: Int) {
    guard let intensity = weather.rainIntensity else { return }

    let cell = Self.cellSize / CGFloat(Self.rippleSubdivision)
    let columnCount = max(Int(size.width / cell), 1)
    let allRowCount = max(Int(ceil(size.height / Self.cellSize)), 1)
    let horizonRow = Int(Self.horizonRatio * Double(allRowCount))
    let waterEndRow = tidalShoreRow(rowCount: allRowCount)
    guard waterEndRow > horizonRow else { return }

    let topY = CGFloat(horizonRow) * Self.cellSize
    let bandHeight = CGFloat(waterEndRow - horizonRow) * Self.cellSize
    let rowCount = max(Int(bandHeight / cell), 1)
    let count = Int(Double(Self.rippleCountPerIntensity) * Self.snowDensity(for: intensity))

    var path = Path()
    for index in 0..<count {
      // 波紋ごとに現れる時期をずらし、ばらばらに跳ねているように見せます。
      let phase = (tick + Int(pseudoRandom(index &* 31 &+ 5) * 40)) % 40
      guard phase < Self.rippleLifeTicks else { continue }

      // 現れるたびに位置を変えます。
      let seed = index &* 97 &+ (tick / 40) &* 13
      let column = Int(pseudoRandom(seed &+ 1) * Double(columnCount))
      let row = Int(pseudoRandom(seed &+ 2) * Double(rowCount))
      // 輪は落ちた瞬間が最も小さく、消えるまでに広がります。
      let radiusX = 1 + phase * (Self.rippleMaxRadius - 1) / max(Self.rippleLifeTicks - 1, 1)

      // 水平線に近いほど水面を浅い角度で見るため、縦により潰れます。
      let depth = Double(row) / Double(max(rowCount - 1, 1))
      let flatten = Self.rippleFlattenFar
        + (Self.rippleFlattenNear - Self.rippleFlattenFar) * depth
      let radiusY = max(Int((Double(radiusX) * flatten).rounded()), 1)

      for dy in -radiusY...radiusY {
        for dx in -radiusX...radiusX {
          // 楕円の縁に乗る粒だけを置きます。
          let normalizedX = Double(dx) / Double(radiusX)
          let normalizedY = Double(dy) / Double(radiusY)
          let distance = (normalizedX * normalizedX + normalizedY * normalizedY).squareRoot()
          guard abs(distance - 1) < 0.34 else { continue }

          path.addRect(
            CGRect(
              x: CGFloat(column + dx) * cell,
              y: topY + CGFloat(row + dy) * cell,
              width: cell,
              height: cell
            )
          )
        }
      }
    }

    context.fill(path, with: .color(Self.rainColor.opacity(Self.rippleOpacityValue)))
  }

  /// 砂浜と道路に積もった雪です。
  ///
  /// 降っているだけでは地面が変わらず、雪の日らしくなりません。
  /// 一面を白く塗ると平坦になるので、まだらに置いて路面を透けさせます。
  private func drawSnowCover(in context: inout GraphicsContext, size: CGSize) {
    guard let intensity = weather.snowIntensity else { return }

    let cell = Self.cellSize
    let columnCount = max(Int(ceil(size.width / cell)), 1)
    let rowCount = max(Int(ceil(size.height / cell)), 1)
    let startRow = tidalShoreRow(rowCount: rowCount)
    guard startRow < rowCount else { return }

    // 強い雪ほど濃く積もります。
    let baseCoverage = Self.snowDensity(for: intensity) / 1.4
    let patch = Self.snowPatchCells

    var path = Path()
    for row in startRow..<rowCount {
      // 手前ほど踏まれて雪が減ります。奥は面が詰まって見えるぶん白く残ります。
      let depth = Double(row - startRow) / Double(max(rowCount - startRow, 1))
      let coverage = baseCoverage * (1 - depth * Self.snowClearedRatio)

      for column in 0..<columnCount {
        // 1マスごとに散らすと砂嵐に見えるので、数マスをひとかたまりにして斑に積もらせます。
        let block = (row / patch) &* 4_099 &+ (column / patch) &* 17 &+ 53
        guard pseudoRandom(block) < coverage else { continue }
        path.addRect(
          CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
        )
      }
    }

    context.fill(path, with: .color(Self.snowColor.opacity(Self.snowCoverOpacity)))
  }

  /// 水平線のあたりにかかる霧です。遠くの景色を白く霞ませます。
  private func drawFog(in context: inout GraphicsContext, size: CGSize) {
    guard weather.isFoggy else { return }

    let cell = Self.cellSize
    let rowCount = max(Int(ceil(size.height / cell)), 1)
    let centerRow = Int(Self.horizonRatio * Double(rowCount))
    let band = Int(Self.fogBand * Double(rowCount))

    for offset in -band...band {
      let row = centerRow + offset
      guard row >= 0, row < rowCount else { continue }

      // 水平線から離れるほど薄くします。
      let distance = Double(abs(offset)) / Double(band)
      let opacity = Self.fogOpacity * (1 - distance)
      guard opacity > 0.01 else { continue }

      context.fill(
        Path(CGRect(x: 0, y: CGFloat(row) * cell, width: size.width, height: cell)),
        with: .color(Color.white.opacity(opacity))
      )
    }
  }

  /// 流れ星だけを描く層です。星が見える時間帯にだけ動かします。
  ///
  /// 流れ星は動きそのものが中身なので、
  /// 「視差効果を減らす」設定がオンのときは出しません。
  @ViewBuilder
  private var shootingStarLayer: some View {
    if !isStill, sky.nightness > Self.starVisibilityThreshold {
      TimelineView(.periodic(from: Self.animationEpoch, by: Self.shootingStarInterval)) { timeline in
        let elapsed = timeline.date.timeIntervalSinceReferenceDate

        Canvas { context, size in
          drawShootingStar(in: &context, size: size, elapsed: elapsed)
        }
      }
    }
  }

  // MARK: - 流れ星

  /// 一定の周期で流れ星を1つ走らせます。
  /// 周期のうちごく短いあいだだけ現れ、残りの時間は何も描きません。
  private func drawShootingStar(
    in context: inout GraphicsContext,
    size: CGSize,
    elapsed: TimeInterval
  ) {
    let cycle = (elapsed / Self.shootingStarPeriod).rounded(.down)
    let timeInCycle = elapsed - cycle * Self.shootingStarPeriod

    guard timeInCycle < Self.shootingStarDuration else { return }

    let progress = timeInCycle / Self.shootingStarDuration
    let seed = Int(cycle)

    // 出現位置と向きは周期ごとに変わります。
    let startX = 0.08 + pseudoRandom(seed &* 13 &+ 1) * 0.84
    let startY = 0.04 + pseudoRandom(seed &* 13 &+ 2) * 0.22
    // 左下へ流れるか右下へ流れるかを決めます。
    let direction: Double = pseudoRandom(seed &* 13 &+ 3) < 0.5 ? -1 : 1
    // 斜めの傾きです。水平に近すぎない範囲で変えます。
    let slope = 0.45 + pseudoRandom(seed &* 13 &+ 4) * 0.35

    let travel = progress * Self.shootingStarTravel * Double(size.width)
    let headX = Double(size.width) * startX + travel * direction
    let headY = Double(size.height) * startY + travel * slope

    // 現れる瞬間と消える間際は淡くします。
    let fade = min(progress / 0.2, min((1 - progress) / 0.35, 1))

    var headPath = Path()
    var tailPath = Path()

    for segment in 0..<Self.shootingStarTail {
      let distance = Double(segment) * Double(Self.cellSize)
      let x = snapped(CGFloat(headX - distance * direction))
      let y = snapped(CGFloat(headY - distance * slope))

      let rect = CGRect(x: x, y: y, width: Self.cellSize, height: Self.cellSize)

      // 先端の数マスだけを明るく、残りを尾として薄く描きます。
      if segment < 3 {
        headPath.addRect(rect)
      } else {
        tailPath.addRect(rect)
      }
    }

    context.fill(
      tailPath,
      with: .color(Self.shootingStarColor.opacity(Self.shootingStarTailOpacity * fade))
    )
    context.fill(
      headPath,
      with: .color(Self.shootingStarColor.opacity(Self.shootingStarHeadOpacity * fade))
    )
  }

  /// 雨粒だけを描く層です。落下は速いので、海面より短い間隔で描き直します。
  ///
  /// 「視差効果を減らす」設定がオンでも雨は消しません。
  /// 雨が降っていること自体が伝えたい情報なので、落とさずに静止させます。
  @ViewBuilder
  private var rainLayer: some View {
    if weather.isRaining || weather.isSnowing || weather.hasThunder {
      if isStill {
        Canvas { context, size in
          drawPrecipitation(in: &context, size: size, frame: Self.stillTick, elapsed: 0)
        }
      } else {
        TimelineView(.periodic(from: Self.animationEpoch, by: Self.rainInterval)) { timeline in
          let elapsed = timeline.date.timeIntervalSinceReferenceDate
          let frame = Int(elapsed / Self.rainInterval)

          Canvas { context, size in
            drawPrecipitation(in: &context, size: size, frame: frame, elapsed: elapsed)
          }
        }
      }
    }
  }

  // MARK: - 雨

  /// 降っているものと雷をまとめて描きます。
  private func drawPrecipitation(
    in context: inout GraphicsContext,
    size: CGSize,
    frame: Int,
    elapsed: Double
  ) {
    drawLightning(in: &context, size: size, elapsed: elapsed)
    if weather.isSnowing {
      drawSnow(in: &context, size: size, frame: frame)
    } else {
      drawRain(in: &context, size: size, frame: frame)
    }
  }

  /// 雷の光です。ときどき空全体が一瞬白みます。
  private func drawLightning(in context: inout GraphicsContext, size: CGSize, elapsed: Double) {
    guard weather.hasThunder, elapsed > 0 else { return }

    let phase = elapsed.truncatingRemainder(dividingBy: Self.lightningPeriod)
    guard phase < Self.lightningDuration else { return }

    // 光り始めが最も明るく、すぐに引きます。
    let strength = 1 - phase / Self.lightningDuration
    context.fill(
      Path(CGRect(origin: .zero, size: size)),
      with: .color(Color.white.opacity(strength * 0.5))
    )
  }

  /// 雪の量です。強さごとに、画面の列数に対する割合で決めます。
  private static func snowDensity(for intensity: RainIntensity) -> Double {
    switch intensity {
    case .light:
      return 0.5
    case .moderate:
      return 0.9
    case .heavy:
      return 1.4
    }
  }

  /// 雪を降らせます。雨より遅く、横に揺れながら落ちます。
  private func drawSnow(in context: inout GraphicsContext, size: CGSize, frame: Int) {
    guard let intensity = weather.snowIntensity else { return }

    let cell = Self.cellSize
    let columnCount = max(Int(ceil(size.width / cell)), 1)
    let rowCount = max(Int(ceil(size.height / cell)), 1)
    let dropCount = Int(Double(columnCount) * Self.snowDensity(for: intensity))
    let elapsed = Double(frame) * Self.rainInterval

    var path = Path()
    for index in 0..<dropCount {
      let column = Int(pseudoRandom(index * 3 + 1) * Double(columnCount))
      let speed = 0.6 + pseudoRandom(index * 5 + 2) * 0.8
      let travel = elapsed * Self.snowSpeedPerSecond * speed
      let row = Int(travel + pseudoRandom(index * 7 + 3) * Double(rowCount)) % rowCount
      // 風に流されて斜めに降ります。落ちた距離に比例して横へずれます。
      let slant = Double(row) * windStrength * Self.precipitationSlant
      // 横揺れは粒ごとに位相をずらし、同じ動きに見えないようにします。
      let sway = sin(elapsed * 1.6 + pseudoRandom(index * 11 + 5) * 6.28) * Self.snowSwayCells
      let x = (Double(column) + sway + slant)
        .truncatingRemainder(dividingBy: Double(columnCount))

      path.addRect(
        CGRect(x: CGFloat(x) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
      )
    }

    context.fill(path, with: .color(Self.snowColor.opacity(0.82)))
  }

  /// 雨粒を真下へ降らせます。粒はそれぞれ決まった速さで落ち、画面の下端まで来ると上へ戻ります。
  private func drawRain(in context: inout GraphicsContext, size: CGSize, frame: Int) {
    guard let intensity = weather.rainIntensity else { return }

    let columnCount = max(Int(ceil(size.width / Self.cellSize)), 1)
    let rowCount = max(Int(ceil(size.height / Self.cellSize)), 1)
    let cycleRows = rowCount + Self.rainDropLength
    let dropCount = Self.dropCount(for: intensity)

    var path = Path()

    for index in 0..<dropCount {
      // 粒ごとに速さを変え、同じ間隔で落ちているように見えないようにします。
      let speed = Self.rainSpeedPerSecond
        * Self.rainInterval
        * (0.75 + pseudoRandom(index &* 7 &+ 2) * 0.5)
      let phase = pseudoRandom(index &* 7 &+ 3) * Double(cycleRows)
      let travelled = (Double(frame) * speed + phase)
        .truncatingRemainder(dividingBy: Double(cycleRows))
      let headRow = Int(travelled) - Self.rainDropLength
      let baseColumn = Int(pseudoRandom(index &* 7 &+ 1) * Double(columnCount))

      for segment in 0..<Self.rainDropLength {
        let row = headRow + segment
        guard row >= 0, row < rowCount else { continue }

        // 風に流されて斜めに降ります。落ちた距離に比例して横へずれます。
        let slant = Double(row) * windStrength * Self.precipitationSlant
        path.addRect(
          CGRect(
            x: CGFloat(Double(baseColumn) + slant) * Self.cellSize,
            y: CGFloat(row) * Self.cellSize,
            width: Self.cellSize,
            height: Self.cellSize
          )
        )
      }
    }

    context.fill(path, with: .color(Self.rainColor.opacity(Self.rainOpacity)))
  }

  /// 雨の強さごとの粒の数です。
  private static func dropCount(for intensity: RainIntensity) -> Int {
    switch intensity {
    case .light:
      return 45
    case .moderate:
      return 90
    case .heavy:
      return 150
    }
  }

  // MARK: - 空

  /// 空を数色だけで塗ります。
  /// 色の境目はベイヤーディザの市松模様でつなぎ、限られた色数のまま階調を表現します。
  /// 画面全体を空の色で埋め、海面は動く層があとから重ねます。
  private func drawSkyBase(in context: inout GraphicsContext, size: CGSize) {
    let colors = sky.quantizedSkyColors(steps: Self.skyColorSteps)
    let columnCount = max(Int(ceil(size.width / Self.cellSize)), 1)
    let rowCount = max(Int(ceil(size.height / Self.cellSize)), 1)

    // 同じ色が横に続く範囲を1つの矩形にまとめ、塗りの回数を色数だけに抑えます。
    var paths = [Path](repeating: Path(), count: colors.count)

    for row in 0..<rowCount {
      let verticalRatio = Double(row) / Double(max(rowCount - 1, 1))
      var runStartColumn = 0
      var runColorIndex = quantizedIndex(ratio: verticalRatio, row: row, column: 0)

      for column in 1...columnCount {
        // 行末では必ず区切るため、範囲外には色番号として-1を割り当てます。
        let colorIndex = column < columnCount
          ? quantizedIndex(ratio: verticalRatio, row: row, column: column)
          : -1

        guard colorIndex != runColorIndex else { continue }

        paths[runColorIndex].addRect(
          CGRect(
            x: CGFloat(runStartColumn) * Self.cellSize,
            y: CGFloat(row) * Self.cellSize,
            width: CGFloat(column - runStartColumn) * Self.cellSize,
            height: Self.cellSize
          )
        )
        runStartColumn = column
        runColorIndex = colorIndex
      }
    }

    for (index, color) in colors.enumerated() {
      context.fill(paths[index], with: .color(color))
    }
  }

  /// 海面を描きます。水平線を鏡として空を映し、映る位置は時間とともに波打ちます。
  private func drawWater(in context: inout GraphicsContext, size: CGSize, tick: Int) {
    let colors = sky.quantizedWaterColors(steps: Self.skyColorSteps)
    let columnCount = max(Int(ceil(size.width / Self.cellSize)), 1)
    let rowCount = max(Int(ceil(size.height / Self.cellSize)), 1)
    let startRow = max(Int(Self.horizonRatio * Double(rowCount)), 0)
    let endRow = tidalShoreRow(rowCount: rowCount)

    guard startRow < endRow else { return }

    // 波の位相です。時間とともに進み、映り込み全体が上下に揺れます。
    let phase = Double(tick) * Self.waveSpeed
    // 水平線の直下を暗くする範囲の行数です。
    let shadeRows = max(Int(Self.horizonShadeBand * Double(rowCount)), 1)
    var paths = [Path](repeating: Path(), count: colors.count)

    for row in startRow..<endRow {
      let rawRatio = Double(row) / Double(max(rowCount - 1, 1))
      let depth = rawRatio - Self.horizonRatio
      let waveOffset = sin(Double(row) * Self.waveFrequency + phase)
      let mirroredRatio = max(Self.horizonRatio - depth + waveOffset * Self.waveAmplitude, 0)

      // 水平線に近いほど沈ませ、遠くの海が暗く見えるようにします。
      let horizonDistance = Double(row - startRow) / Double(shadeRows)
      let shade = horizonDistance < 1 ? 1 - horizonDistance : 0

      // 波の山では明るく、谷では暗く見えるよう、選ぶ色をずらします。
      let brightnessShift = Int((waveOffset * Self.waveBrightness).rounded())
        - Int((shade * Self.horizonShadeDepth).rounded())

      var runStartColumn = 0
      var runColorIndex = waterColorIndex(
        row: row,
        column: 0,
        mirroredRatio: mirroredRatio,
        brightnessShift: brightnessShift
      )

      for column in 1...columnCount {
        // 行末では必ず区切るため、範囲外には使わない番号を割り当てます。
        let colorIndex = column < columnCount
          ? waterColorIndex(
              row: row,
              column: column,
              mirroredRatio: mirroredRatio,
              brightnessShift: brightnessShift
            )
          : -1

        guard colorIndex != runColorIndex else { continue }

        paths[runColorIndex].addRect(
          CGRect(
            x: CGFloat(runStartColumn) * Self.cellSize,
            y: CGFloat(row) * Self.cellSize,
            width: CGFloat(column - runStartColumn) * Self.cellSize,
            height: Self.cellSize
          )
        )

        runStartColumn = column
        runColorIndex = colorIndex
      }
    }

    for (index, color) in colors.enumerated() {
      context.fill(paths[index], with: .color(color))
    }
  }

  /// 岸辺の水打ち際です。海面の上に重ねる必要があるため、動く層で描きます。
  private func drawShoreEdge(in context: inout GraphicsContext, size: CGSize) {
    let shoreTop = tidalShoreY(size: size)
    drawDitheredEdge(in: &context, size: size, top: shoreTop, color: sky.shore)
  }

  /// そのマスに塗る海面の色番号を返します。
  private func waterColorIndex(
    row: Int,
    column: Int,
    mirroredRatio: Double,
    brightnessShift: Int
  ) -> Int {
    let baseIndex = quantizedIndex(ratio: mirroredRatio, row: row, column: column)
    return min(max(baseIndex + brightnessShift, 0), Self.skyColorSteps - 1)
  }

  /// 縦位置に対応する色を、量子化した何番目の色にするかを決めます。
  /// 隣り合う2色のどちらを塗るかは、ディザマトリクスのしきい値で分けます。
  private func quantizedIndex(ratio: Double, row: Int, column: Int) -> Int {
    let scaled = ratio * Double(Self.skyColorSteps - 1)
    let lowerIndex = min(Int(scaled), Self.skyColorSteps - 1)
    let fraction = scaled - Double(lowerIndex)
    let threshold = (Double(Self.ditherMatrix[row % 4][column % 4]) + 0.5) / 16

    return fraction > threshold ? min(lowerIndex + 1, Self.skyColorSteps - 1) : lowerIndex
  }

  // MARK: - 海面

  /// 沖から岸へ寄せる波を描きます。
  ///
  /// 横へ流すと川に見えてしまうため、波は縦方向に進めます。
  /// 深さから位相を作り、その山にあたる行だけへ横筋を置くことで、
  /// 波の帯が水平線から手前へ移動していきます。
  private func drawSwell(in context: inout GraphicsContext, size: CGSize, tick: Int) {
    let columnCount = max(Int(ceil(size.width / Self.cellSize)), 1)
    let allRowCount = max(Int(ceil(size.height / Self.cellSize)), 1)
    let horizonRow = Int(Self.horizonRatio * Double(allRowCount))
    // 岸辺から下は道路になるため、水面はそこまでを描きます。
    let rowCount = tidalShoreRow(rowCount: allRowCount)

    guard horizonRow + 1 < rowCount else { return }

    var ripplePath = Path()
    var crestPath = Path()

    for row in (horizonRow + 1)..<rowCount {
      let depth = Double(row - horizonRow) / Double(max(rowCount - horizonRow, 1))
      // 手前ほど波の間隔が広がるよう、深さを非線形に扱います。
      let progress = pow(depth, 0.7)
      let phase = progress * Self.swellFrequency - Double(tick) * Self.swellSpeed
      let crestHeight = sin(phase * 2 * .pi)

      // 列ごとのずれを足しても波が届かない行は、まとめて飛ばします。
      guard crestHeight > Self.swellThreshold - Self.swellWaveDepth * 2 * .pi else { continue }

      // 遠くの波ほど細かく、手前ほど筋がはっきり見えます。
      let chance = Self.swellChance * (0.35 + depth)
      // 波ごとに模様が変わるよう、何番目の波かを種に混ぜます。
      let waveIndex = Int(phase.rounded(.down))

      for column in 0..<columnCount {
        // 列ごとに位相をずらし、波の筋が一直線に揃わないようにします。
        let columnPhase = sin(Double(column) * Self.swellWaviness) * Self.swellWaveDepth
        let localHeight = sin((phase + columnPhase) * 2 * .pi)

        guard localHeight > Self.swellThreshold else { continue }

        // 頂点付近だけが白波になります。
        // 風が強いほどしきい値を下げ、白波が立ちやすくします。
        let isWhitecap = localHeight
          > Self.whitecapThreshold - windStrength * Self.windWhitecapBoost

        guard pseudoRandom(row &* 104_729 &+ column &+ waveIndex &* 7_919) < chance else {
          continue
        }

        let length = 2 + Int(pseudoRandom(row &* 53 &+ column &* 29) * 4)
        let rect = CGRect(
          x: CGFloat(column) * Self.cellSize,
          y: CGFloat(row) * Self.cellSize,
          width: CGFloat(length) * Self.cellSize,
          height: Self.cellSize
        )

        if isWhitecap {
          crestPath.addRect(rect)
        } else {
          ripplePath.addRect(rect)
        }
      }
    }

    context.fill(ripplePath, with: .color(sky.celestialTint.opacity(Self.rippleOpacity)))
    context.fill(crestPath, with: .color(Color.white.opacity(Self.whitecapOpacity)))
  }

  /// 太陽・月の真下に、手前ほど広がってまばらになる光の道を描きます。
  /// 粒の一部は描き直しのたびに入れ替わり、水面がゆらめいて見えます。
  private func drawReflectionPath(
    in context: inout GraphicsContext,
    size: CGSize,
    tick: Int
  ) {
    // 新月の夜は月そのものが見えないので、海に落ちる光の道も出しません。
    let strength = reflectionStrength
    guard strength > 0.02 else { return }

    let columnCount = max(Int(ceil(size.width / Self.cellSize)), 1)
    let allRowCount = max(Int(ceil(size.height / Self.cellSize)), 1)
    let horizonRow = Int(Self.horizonRatio * Double(allRowCount))
    let waterEndRow = tidalShoreRow(rowCount: allRowCount)

    guard horizonRow < waterEndRow else { return }

    let centerColumn = Int(Double(columnCount) * sky.celestialProgress)
    let bodyRadius = Double(celestialRadiusInCells())
    var path = Path()

    for row in horizonRow..<waterEndRow {
      let depth = Double(row - horizonRow) / Double(max(waterEndRow - horizonRow, 1))
      // 手前に来るほど光は横に広がり、粒はまばらになります。
      let halfWidth = max(bodyRadius * (1 + depth * Self.reflectionSpread), 1)
      let density = pow(1 - depth, 0.9) * Self.reflectionDensity

      for offset in -Int(halfWidth)...Int(halfWidth) {
        let column = centerColumn + offset
        guard column >= 0, column < columnCount else { continue }

        // 中心から離れるほど粒が現れにくくなります。
        let edgeFade = pow(1 - abs(Double(offset)) / halfWidth, 0.7)
        let chance = density * edgeFade

        // 一部の粒は留まり、残りが入れ替わることで、水面の一部だけが揺れます。
        let isStable = pseudoRandom(row &* 7_919 &+ column)
          < chance * Self.reflectionStableRatio
        let isFlickering = pseudoRandom(row &* 7_919 &+ column &+ tick &* 104_729)
          < chance * (1 - Self.reflectionStableRatio)

        guard isStable || isFlickering else { continue }

        path.addRect(
          CGRect(
            x: CGFloat(column) * Self.cellSize,
            y: CGFloat(row) * Self.cellSize,
            width: Self.cellSize,
            height: Self.cellSize
          )
        )
      }
    }

    // 月が細いほど、道も淡くなります。
    context.fill(
      path,
      with: .color(sky.celestialTint.opacity(Self.reflectionOpacity * strength))
    )
  }

  /// 波打ち際に白い泡を寄せます。周期的に前後して、寄せては返す動きになります。
  private func drawSurf(in context: inout GraphicsContext, size: CGSize, tick: Int) {
    let columnCount = max(Int(ceil(size.width / Self.cellSize)), 1)
    let rowCount = max(Int(ceil(size.height / Self.cellSize)), 1)
    // 潮の満ち引きで、波打ち際そのものの位置が上下します。
    let shoreRow = tidalShoreRow(rowCount: rowCount)

    // 寄せ引きの位相です。1のときが最も沖へ引き、0のときが最も岸へ寄せた状態です。
    let phase = (sin(Double(tick) / Self.surfPeriod * 2 * .pi) + 1) / 2
    var path = Path()

    for offset in 0..<Self.surfHeight {
      let row = shoreRow - offset - 1
      guard row >= 0, row < rowCount else { continue }

      // 岸に近い行ほど泡が残りやすく、沖へ行くほど波が引くと消えます。
      let coverage = phase * (1 - Double(offset) / Double(Self.surfHeight))

      for column in 0..<columnCount {
        guard pseudoRandom(row &* 8_191 &+ column &+ Int(phase * 7) &* 131) < coverage else {
          continue
        }

        path.addRect(
          CGRect(
            x: CGFloat(column) * Self.cellSize,
            y: CGFloat(row) * Self.cellSize,
            width: Self.cellSize,
            height: Self.cellSize
          )
        )
      }
    }

    context.fill(path, with: .color(Color.white.opacity(Self.surfOpacity)))
  }

  // MARK: - 地上

  /// 海の手前に岸辺と道路を敷きます。
  private func drawGround(in context: inout GraphicsContext, size: CGSize) {
    let shoreTop = tidalShoreY(size: size)
    let roadTop = snapped(CGFloat(Self.roadRatio) * size.height)

    context.fill(
      Path(CGRect(x: 0, y: shoreTop, width: size.width, height: roadTop - shoreTop)),
      with: .color(sky.shore)
    )

    context.fill(
      Path(CGRect(x: 0, y: roadTop, width: size.width, height: size.height - roadTop)),
      with: .color(sky.road)
    )
    drawDitheredEdge(in: &context, size: size, top: roadTop, color: sky.road)

    drawRoadWear(in: &context, size: size, roadTop: roadTop)
    drawRoadCenterLine(in: &context, size: size)
  }

  /// 道路の表面に、ひび割れと色あせを表す粒を散らします。
  private func drawRoadWear(
    in context: inout GraphicsContext,
    size: CGSize,
    roadTop: CGFloat
  ) {
    let columnCount = max(Int(ceil(size.width / Self.cellSize)), 1)
    let rowCount = max(Int(ceil(size.height / Self.cellSize)), 1)
    let startRow = max(Int(roadTop / Self.cellSize), 0)

    var crackPath = Path()
    var fadePath = Path()

    for row in startRow..<rowCount {
      for column in 0..<columnCount {
        let value = pseudoRandom(row &* 6151 &+ column &* 97)
        let rect = CGRect(
          x: CGFloat(column) * Self.cellSize,
          y: CGFloat(row) * Self.cellSize,
          width: Self.cellSize,
          height: Self.cellSize
        )

        if value < Self.roadCrackChance {
          crackPath.addRect(rect)
        } else if value > 1 - Self.roadFadeChance {
          fadePath.addRect(rect)
        }
      }
    }

    context.fill(crackPath, with: .color(Color.black.opacity(0.13)))
    context.fill(fadePath, with: .color(sky.roadLine.opacity(0.10)))
  }

  /// 面の上端を市松で削り、境目が直線に見えないようにします。
  private func drawDitheredEdge(
    in context: inout GraphicsContext,
    size: CGSize,
    top: CGFloat,
    color: Color
  ) {
    let columnCount = max(Int(ceil(size.width / Self.cellSize)), 1)
    let topRow = Int(top / Self.cellSize)
    var path = Path()

    for offset in 0..<Self.groundEdgeRows {
      // 上の行ほど面が現れにくく、下の行ほど埋まっていきます。
      let coverage = Double(offset + 1) / Double(Self.groundEdgeRows + 1)
      let row = topRow - Self.groundEdgeRows + offset
      guard row >= 0 else { continue }

      for column in 0..<columnCount {
        let threshold = (Double(Self.ditherMatrix[row % 4][column % 4]) + 0.5) / 16
        guard threshold < coverage else { continue }

        path.addRect(
          CGRect(
            x: CGFloat(column) * Self.cellSize,
            y: CGFloat(row) * Self.cellSize,
            width: Self.cellSize,
            height: Self.cellSize
          )
        )
      }
    }

    context.fill(path, with: .color(color))
  }

  /// 道路の中央に破線を引きます。
  private func drawRoadCenterLine(in context: inout GraphicsContext, size: CGSize) {
    let lineTop = snapped(CGFloat(Self.roadLineRatio) * size.height)
    let columnCount = max(Int(ceil(size.width / Self.cellSize)), 1)
    let stride = Self.roadDashLength + Self.roadDashGap

    var path = Path()
    var column = 0

    while column < columnCount {
      // 1マスずつ描き、経年で剥がれた箇所を抜いていきます。
      for offset in 0..<Self.roadDashLength {
        let lineColumn = column + offset
        guard lineColumn < columnCount else { break }
        guard pseudoRandom(lineColumn &* 3389) > Self.roadLineWearChance else { continue }

        path.addRect(
          CGRect(
            x: CGFloat(lineColumn) * Self.cellSize,
            y: lineTop,
            width: Self.cellSize,
            height: Self.cellSize
          )
        )
      }
      column += stride
    }

    context.fill(path, with: .color(sky.roadLine.opacity(0.5)))
  }

  /// 道路のわきにバス停を1本立てます。
  private func drawBusStop(in context: inout GraphicsContext, size: CGSize) {
    let cell = Self.cellSize
    let baseY = snapped(CGFloat(Self.roadRatio) * size.height)
    let signWidth = CGFloat(Self.signSize) * cell
    let poleTop = baseY - CGFloat(Self.poleHeight) * cell
    let signLeft = snapped(CGFloat(Self.busStopRatio) * size.width)
    let poleLeft = signLeft + (signWidth - CGFloat(Self.poleWidth) * cell) / 2

    // 支柱です。錆びて欠けた箇所を作るため、1マスずつ積み上げます。
    var polePath = Path()
    for offset in 0..<Self.poleHeight {
      guard pseudoRandom(offset &* 7717 &+ 13) > Self.poleWearChance else { continue }

      polePath.addRect(
        CGRect(
          x: snapped(poleLeft),
          y: poleTop + CGFloat(offset) * cell,
          width: CGFloat(Self.poleWidth) * cell,
          height: cell
        )
      )
    }
    context.fill(polePath, with: .color(sky.signboardInk.opacity(0.55)))

    // 標識の板です。ドットで組んだ丸い板にします。
    let signRadius = Self.signSize / 2
    let signOrigin = CGPoint(x: signLeft, y: poleTop - signWidth)
    let signCenter = CGPoint(
      x: signOrigin.x + CGFloat(signRadius) * cell,
      y: signOrigin.y + CGFloat(signRadius) * cell
    )

    drawPixelDisc(
      in: &context,
      centerX: signCenter.x,
      centerY: signCenter.y,
      radiusInCells: signRadius,
      color: sky.signboard,
      opacity: 1
    )

    // 板のふちです。外周1マスだけを暗く縁取ります。
    drawPixelDisc(
      in: &context,
      centerX: signCenter.x,
      centerY: signCenter.y,
      radiusInCells: signRadius,
      innerRadiusInCells: signRadius - 1,
      color: sky.signboardInk,
      opacity: 0.85
    )

    drawSignWeathering(in: &context, origin: signOrigin, radiusInCells: signRadius)

    // 板の中身は具体的な絵にせず、案内が書かれていることを示す横線2本だけにします。
    var mark = Path()
    mark.addRect(
      CGRect(x: signOrigin.x + 3 * cell, y: signOrigin.y + 4 * cell, width: 5 * cell, height: cell)
    )
    mark.addRect(
      CGRect(x: signOrigin.x + 3 * cell, y: signOrigin.y + 6 * cell, width: 5 * cell, height: cell)
    )
    context.fill(mark, with: .color(sky.signboardInk.opacity(0.78)))
  }

  /// 標識の板に色あせの粒を散らし、長く風雨にさらされた面にします。
  /// 丸い板からはみ出さないよう、円の内側だけを対象にします。
  private func drawSignWeathering(
    in context: inout GraphicsContext,
    origin: CGPoint,
    radiusInCells: Int
  ) {
    let cell = Self.cellSize
    let squaredLimit = radiusInCells * radiusInCells
    var path = Path()

    for row in 0..<Self.signSize {
      for column in 0..<Self.signSize {
        let verticalDistance = row - radiusInCells
        let horizontalDistance = column - radiusInCells
        let squaredDistance = verticalDistance * verticalDistance
          + horizontalDistance * horizontalDistance

        guard squaredDistance <= squaredLimit else { continue }
        guard pseudoRandom(row &* 1301 &+ column &* 71) < 0.12 else { continue }

        path.addRect(
          CGRect(
            x: origin.x + CGFloat(column) * cell,
            y: origin.y + CGFloat(row) * cell,
            width: cell,
            height: cell
          )
        )
      }
    }

    context.fill(path, with: .color(Color.black.opacity(0.14)))
  }

  // MARK: - 星

  /// 夜空に星を散らします。位置は毎回同じで、一部の星だけが瞬きます。
  /// - Parameter tick: 瞬きの周期番号です。これが変わるたびに、瞬く星の組み合わせが入れ替わります。
  private func drawStars(in context: inout GraphicsContext, size: CGSize, tick: Int) {
    let visibility = sky.nightness
    guard visibility > Self.starVisibilityThreshold else { return }

    var faintPath = Path()
    var whitePath = Path()
    var bluePath = Path()
    var warmPath = Path()

    for index in 0..<Self.starCount {
      let horizontal = pseudoRandom(index &* 4 &+ 1)
      // 指数を掛けてゆるやかに上空へ寄せ、文字が並ぶ画面下部には星を置きません。
      let vertical = Self.starFieldTopInset
        + pow(pseudoRandom(index &* 4 &+ 2), 1.8)
        * (Self.starFieldRatio - Self.starFieldTopInset)
      let brightness = pseudoRandom(index &* 4 &+ 3)

      // 瞬いている間だけ星を消し、ドット絵らしい明滅にします。
      let isBlinking = pseudoRandom(index &* 977 &+ tick) > 0.9
      guard !isBlinking else { continue }

      let originX = snapped(CGFloat(horizontal) * size.width)
      let originY = snapped(CGFloat(vertical) * size.height)

      // 大半を非常に暗い星にし、明るい星をごく少数に絞ることで、
      // 均一な粒が降っているようには見えない奥行きを作ります。
      if brightness > 0.992 {
        appendCross(to: &warmPath, x: originX, y: originY)
      } else if brightness > 0.94 {
        appendCell(to: &whitePath, x: originX, y: originY)
      } else if brightness > 0.80 {
        appendCell(to: &bluePath, x: originX, y: originY)
      } else {
        appendCell(to: &faintPath, x: originX, y: originY)
      }
    }

    context.fill(faintPath, with: .color(Self.faintStarColor.opacity(visibility * 0.26)))
    context.fill(bluePath, with: .color(Self.blueStarColor.opacity(visibility * 0.48)))
    context.fill(whitePath, with: .color(Self.brightStarColor.opacity(visibility * 0.88)))
    context.fill(warmPath, with: .color(Self.warmStarColor.opacity(visibility * 0.92)))
  }

  /// 1マスの星です。
  private func appendCell(to path: inout Path, x: CGFloat, y: CGFloat) {
    path.addRect(CGRect(x: x, y: y, width: Self.cellSize, height: Self.cellSize))
  }

  /// 明るい星を表す十字形です。中央と上下左右の5マスで構成します。
  private func appendCross(to path: inout Path, x: CGFloat, y: CGFloat) {
    appendCell(to: &path, x: x, y: y)
    appendCell(to: &path, x: x - Self.cellSize, y: y)
    appendCell(to: &path, x: x + Self.cellSize, y: y)
    appendCell(to: &path, x: x, y: y - Self.cellSize)
    appendCell(to: &path, x: x, y: y + Self.cellSize)
  }

  // MARK: - 雲

  /// 昼の空にドット絵の雲を置きます。夜が近づくにつれて薄くなります。
  private func drawClouds(in context: inout GraphicsContext, size: CGSize, tick: Int) {
    let visibility = 1 - sky.nightness
    guard visibility > 0.05 else { return }

    // 風で流れた距離です。時間と風速から求めるので、風が強いほど速く流れます。
    let elapsed = Double(tick) * Self.animationInterval
    let drift = elapsed * weather.windSpeed * Self.cloudDriftPerWind

    var path = Path()

    // 雲量が多いほど、雲の数を増やします。
    let extra = Int((weather.cloudCover * Double(Self.extraCloudCount)).rounded())
    let clouds = Self.cloudLayout + Self.extraCloudLayout.prefix(extra)

    for cloud in clouds {
      let unit = Self.cellSize * CGFloat(cloud.scale)
      // 画面の外へ出たら反対側から戻します。
      let driftedX = (cloud.x + drift).truncatingRemainder(dividingBy: 1.4) - 0.2
      let baseX = snapped(CGFloat(driftedX) * size.width)
      let baseY = snapped(CGFloat(cloud.y) * size.height)

      for (rowIndex, row) in Self.cloudRows.enumerated() {
        path.addRect(
          CGRect(
            x: baseX + CGFloat(row.offsetX) * unit,
            y: baseY + CGFloat(rowIndex) * unit,
            width: CGFloat(row.width) * unit,
            height: unit
          )
        )
      }
    }

    // 雲が多いほど厚く見せます。
    let thickness = 0.38 + weather.cloudCover * 0.34
    context.fill(path, with: .color(Color.white.opacity(visibility * thickness)))
    // 白のままでは夕焼けの空から浮くので、水平線の色で染めます。
    // 昼は淡い青なので白のまま、夕方は橙に寄ります。
    context.fill(
      path,
      with: .color(sky.skyBottom.opacity(visibility * thickness * Self.cloudTintStrength))
    )
  }

  // MARK: - 遠景と近景

  /// 水平線の向こうに見える対岸です。
  ///
  /// 空と海だけでは画面の奥が抜けてしまうため、遠くの陸地と建物の影を置きます。
  /// 色は空の色を暗くして作るので、時刻が変わっても風景から浮きません。
  private func drawDistantShore(in context: inout GraphicsContext, size: CGSize) {
    let cell = Self.cellSize
    let columnCount = max(Int(ceil(size.width / cell)), 1)
    let rowCount = max(Int(ceil(size.height / cell)), 1)
    let horizonRow = Int(Self.horizonRatio * Double(rowCount))

    var path = Path()
    for column in 0..<columnCount {
      let height = distantShoreHeight(atColumn: column)
      let topRow = max(horizonRow - height, 0)

      for row in topRow..<horizonRow {
        path.addRect(
          CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
        )
      }
    }

    // 空の色を暗くして作るので、時刻が変わっても風景から浮きません。
    context.fill(path, with: .color(sky.skyBottom))
    context.fill(path, with: .color(Color.black.opacity(Self.distantShoreDarkening)))

    drawDistantLights(in: &context, size: size, horizonRow: horizonRow, columnCount: columnCount)
  }

  /// 対岸にともる灯りです。夜だけ現れ、海の向こうに街があることを示します。
  private func drawDistantLights(
    in context: inout GraphicsContext,
    size: CGSize,
    horizonRow: Int,
    columnCount: Int
  ) {
    guard sky.nightness > Self.starVisibilityThreshold else { return }

    let cell = Self.cellSize
    var path = Path()
    for column in 0..<columnCount {
      let height = distantShoreHeight(atColumn: column)
      guard height > Self.distantShoreBaseHeight + 1 else { continue }
      guard pseudoRandom(column * 53 + 29) > Self.distantLightChance else { continue }

      // 建物の高さの範囲で、窓の位置をひとつ決めます。
      let offset = 1 + Int(pseudoRandom(column * 61 + 7) * Double(height - 2))
      let row = horizonRow - offset
      guard row >= 0 else { continue }

      path.addRect(
        CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
      )
    }

    context.fill(
      path,
      with: .color(Self.distantLightColor.opacity(sky.nightness))
    )
  }

  /// 電柱に取り付けた街灯です。夜だけ点灯し、路面に光だまりを落とします。
  ///
  /// 支柱は電柱として描いてあるので、ここでは腕木と灯りだけを足します。
  private func drawStreetLights(in context: inout GraphicsContext, size: CGSize) {
    for (index, ratio) in Self.utilityPoleRatios.enumerated()
    where Self.lightedPoleIndices.contains(index) {
      drawStreetLight(in: &context, size: size, horizontalRatio: ratio)
    }
  }

  private func drawStreetLight(
    in context: inout GraphicsContext,
    size: CGSize,
    horizontalRatio: Double
  ) {
    let cell = Self.cellSize
    let rowCount = max(Int(ceil(size.height / cell)), 1)
    let roadRow = Int(Self.roadRatio * Double(rowCount))
    let baseColumn = Int(horizontalRatio * size.width / cell)

    // 腕木です。電柱の支柱から片側へ伸ばします。
    let headRow = max(roadRow - Self.streetLightHeight, 0)
    var armPath = Path()
    for offset in 0..<Self.streetLightHeadWidth {
      armPath.addRect(
        CGRect(
          x: CGFloat(baseColumn - offset) * cell,
          y: CGFloat(headRow) * cell,
          width: cell,
          height: cell
        )
      )
    }

    // 腕木の先に吊る灯りの外側です。消えているときはここだけが見えます。
    armPath.addRect(
      CGRect(
        x: CGFloat(baseColumn - Self.streetLightHeadWidth + 1) * cell,
        y: CGFloat(headRow + 1) * cell,
        width: cell * 2,
        height: cell
      )
    )

    // 電柱と同じ色で塗り、別々の柱ではなく1本の電柱に見えるようにします。
    context.fill(armPath, with: .color(sky.skyBottom))
    context.fill(armPath, with: .color(Color.black.opacity(Self.utilityPoleInkOpacity)))

    guard isStreetLightOn else { return }

    // 灯り本体と、路面に落ちる光だまりです。
    var glowPath = Path()
    glowPath.addRect(
      CGRect(
        x: CGFloat(baseColumn - Self.streetLightHeadWidth + 1) * cell,
        y: CGFloat(headRow + 1) * cell,
        width: cell * 2,
        height: cell
      )
    )
    // 灯りそのものは、空の暗さに正比例させると薄暮でほとんど見えません。
    // 点いていることが分かる下限を設け、そこから夜に向けて強くします。
    context.fill(glowPath, with: .color(Self.streetLightColor.opacity(streetLightBulbOpacity)))

    // 光だまりは、濃さを一律にすると縁がくっきり切れて貼り紙のように見えます。
    // 中心から楕円状に弱め、粒の密度と濃さの両方を落として滲ませます。
    drawStreetLightBeam(
      in: &context,
      size: size,
      headRow: headRow,
      roadRow: roadRow,
      centerColumn: baseColumn - Self.streetLightHeadWidth + 1
    )

    // 光だまりだけは半分の大きさの粒で描きます。
    // 風景と同じ粗さだと段が目立つため、ここだけ細かくして滑らかに落とします。
    let glowCell = cell / CGFloat(Self.streetLightGlowSubdivision)
    let subdivision = Self.streetLightGlowSubdivision
    let poolCenterX = CGFloat(baseColumn - Self.streetLightHeadWidth + 1) * cell
    // 道路の手前端ではなく、少し奥から光が当たるようにします。
    let poolTopY = CGFloat(roadRow - Self.streetLightGlowLift) * cell
    let halfWidth = Double(Self.streetLightGlowWidth / 2 * subdivision)
    let depth = Double(Self.streetLightGlowDepth * subdivision)

    for rowOffset in 0..<(Self.streetLightGlowDepth * subdivision) {
      let y = poolTopY + CGFloat(rowOffset) * glowCell
      guard y < size.height else { continue }

      var rowPath = Path()
      // 縦は光だまりの中ほどが最も広くなるようにします。
      // 上端がいちばん広いと、切り取った長方形のように見えてしまいます。
      let vertical = (Double(rowOffset) - depth / 2) / (depth / 2)

      let halfSpan = Self.streetLightGlowWidth / 2 * subdivision
      for offset in -halfSpan...halfSpan {
        let horizontal = Double(abs(offset)) / halfWidth
        // 楕円の内側だけを塗ります。中心が最も明るく、縁へ向かってなだらかに消えます。
        let intensity = max(1 - horizontal * horizontal - vertical * vertical, 0)
        guard intensity > 0.02 else { continue }
        // 粒の密度も明るさに従わせ、縁ほどまばらにします。
        guard pseudoRandom(offset &* 13 &+ rowOffset &* 137 &+ baseColumn &* 7 &+ 91) < intensity else { continue }

        rowPath.addRect(
          CGRect(
            x: poolCenterX + CGFloat(offset) * glowCell,
            y: y,
            width: glowCell,
            height: glowCell
          )
        )
      }

      // 濃さも中ほどで最も強くします。密度と濃さの両方を落とすことで縁が滲みます。
      let rowStrength = max(1 - vertical * vertical, 0)
      context.fill(
        rowPath,
        with: .color(
          Self.streetLightColor.opacity(
            sky.nightness * Self.streetLightGlowOpacity * rowStrength * wetRoadFactor
          )
        )
      )
    }
  }

  /// 対岸のある列の高さです。ほとんどは低い陸地で、ときどき建物が立ちます。
  private func distantShoreHeight(atColumn column: Int) -> Int {
    let noise = pseudoRandom(column * 7 + 13)
    guard noise > Self.distantBuildingChance else {
      // 低い陸地です。1セルだけ起伏をつけます。
      return Self.distantShoreBaseHeight + (pseudoRandom(column * 31 + 5) > 0.6 ? 1 : 0)
    }

    let extra = pseudoRandom(column * 17 + 3)
    let span = Self.distantShoreMaxHeight - Self.distantShoreBaseHeight
    return Self.distantShoreBaseHeight + Int(extra * Double(span)) + 1
  }

  // MARK: - 太陽と月

  /// 太陽または月です。時刻に応じて弧を描くように移動します。
  /// 昼は大きな太陽、夜は小さな月へと、大きさが連続的に切り替わります。
  private func drawCelestialBody(in context: inout GraphicsContext, size: CGSize) {
    // 高度0のときに水平線上へ、高度1のときに天頂へ来ます。
    let verticalRatio = Self.horizonRatio
      - (Self.horizonRatio - Self.zenithRatio) * sky.celestialAltitude
    let centerX = snapped(CGFloat(sky.celestialProgress) * size.width)
    let centerY = snapped(CGFloat(verticalRatio) * size.height)

    drawPixelDisc(
      in: &context,
      centerX: centerX,
      centerY: centerY,
      radiusInCells: celestialRadiusInCells(),
      color: sky.celestialTint,
      opacity: 0.92,
      // 夜に近いほど月として扱い、実際の日付の満ち欠けで欠かします。
      moonPhase: sky.nightness > 0.5 ? MoonPhase.phase(at: Date()) : nil
    )
  }

  /// いまの時刻に対応する太陽・月の半径をセル数で返します。
  /// 海面に落ちる光の幅も、この半径を基準にします。
  private func celestialRadiusInCells() -> Int {
    Int(
      (Double(Self.sunRadiusCells)
        + Double(Self.moonRadiusCells - Self.sunRadiusCells) * sky.nightness).rounded()
    )
  }

  /// セルを敷き詰めて円を描きます。
  /// `innerRadiusInCells` を指定すると、その内側を抜いた輪になります。
  private func drawPixelDisc(
    in context: inout GraphicsContext,
    centerX: CGFloat,
    centerY: CGFloat,
    radiusInCells: Int,
    innerRadiusInCells: Int = 0,
    color: Color,
    opacity: Double,
    moonPhase: Double? = nil
  ) {
    guard radiusInCells > 0 else { return }

    var path = Path()
    // 半径の半分を足して判定を緩めます。
    // ちょうど半径の二乗で切ると、上下左右に1マスだけ角が飛び出た形になります。
    let squaredLimit = Self.squaredDiscLimit(forRadius: radiusInCells)
    // 内側の半径が0のときは中心のマスまで塗ります。
    let squaredInnerLimit = innerRadiusInCells > 0
      ? Self.squaredDiscLimit(forRadius: innerRadiusInCells)
      : -1

    for row in -radiusInCells...radiusInCells {
      for column in -radiusInCells...radiusInCells {
        let squaredDistance = Double(row * row + column * column)
        guard squaredDistance <= squaredLimit,
              squaredDistance > squaredInnerLimit else { continue }
        if let moonPhase,
           !Self.isLitByMoonPhase(
             column: column,
             row: row,
             radiusInCells: radiusInCells,
             phase: moonPhase
           ) {
          continue
        }
        path.addRect(
          CGRect(
            x: centerX + CGFloat(column) * Self.cellSize,
            y: centerY + CGFloat(row) * Self.cellSize,
            width: Self.cellSize,
            height: Self.cellSize
          )
        )
      }
    }

    context.fill(path, with: .color(color.opacity(opacity)))
  }

  // MARK: - 補助

  /// 海に落ちる光の道の強さです。
  ///
  /// 昼は太陽なので満ち欠けに関係なく満ちた強さで、
  /// 夜へ近づくほど月の照らされている割合に従います。
  /// 新月では月が見えないため、光の道も消えます。
  private var reflectionStrength: Double {
    let illuminated = (1 - cos(2 * .pi * MoonPhase.phase(at: Date()))) / 2
    return 1 - sky.nightness * (1 - illuminated)
  }

  /// 月のそのマスが照らされているかどうかです。
  ///
  /// 明暗の境目は、円を横切る楕円になります。
  /// その行の円の半幅に位相の余弦を掛けた位置が境目で、
  /// 新月へ向かう側か満月へ向かう側かで、どちら側が光るかが入れ替わります。
  private static func isLitByMoonPhase(
    column: Int,
    row: Int,
    radiusInCells: Int,
    phase: Double
  ) -> Bool {
    let radius = Double(radiusInCells)
    let halfWidth = (radius * radius - Double(row * row)).squareRoot()
    let terminator = cos(2 * .pi * phase) * halfWidth
    return phase < 0.5
      ? Double(column) > terminator
      : Double(column) < -terminator
  }

  /// ドットで円を描くときの、中心からの距離の二乗のしきい値です。
  /// 半径の二乗そのままでは角が飛び出るため、半径の半分だけ緩めます。
  private static func squaredDiscLimit(forRadius radius: Int) -> Double {
    Double(radius * radius) + Double(radius) / 2
  }

  /// 座標をセルの境界に合わせます。これによりすべての要素が同じ格子に乗ります。
  private func snapped(_ value: CGFloat) -> CGFloat {
    (value / Self.cellSize).rounded(.down) * Self.cellSize
  }

  /// 同じ種からは常に同じ値を返す擬似乱数です。
  /// 星や雲の配置を画面更新のたびに変えないために使います。
  private func pseudoRandom(_ seed: Int) -> Double {
    var value = UInt64(bitPattern: Int64(seed)) &+ 0x9E37_79B9_7F4A_7C15
    value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
    value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
    value = value ^ (value >> 31)
    return Double(value % 1_000_000) / 1_000_000
  }
}

#Preview("朝") {
  SkyBackground().environment(\.sky, SkyPalette.at(hour: 7))
}

#Preview("昼") {
  SkyBackground().environment(\.sky, SkyPalette.at(hour: 12))
}

#Preview("夕方") {
  SkyBackground().environment(\.sky, SkyPalette.at(hour: 17.5))
}

#Preview("夜") {
  SkyBackground().environment(\.sky, SkyPalette.at(hour: 22))
}
