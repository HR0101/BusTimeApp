import SwiftUI

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

  /// 雲を置く位置と大きさです。位置は画面に対する比率、大きさはセルの倍率です。
  private static let cloudLayout: [(x: Double, y: Double, scale: Int)] = [
    (0.06, 0.09, 4),
    (0.63, 0.05, 6),
    (0.36, 0.21, 4)
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
      drawClouds(in: &context, size: size)
      drawCelestialBody(in: &context, size: size)
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
    if reduceMotion {
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
    drawWater(in: &context, size: size, tick: tick)
    drawSwell(in: &context, size: size, tick: tick)
    drawReflectionPath(in: &context, size: size, tick: tick)
    drawStars(in: &context, size: size, tick: tick / Self.twinkleTicks)
    drawShoreEdge(in: &context, size: size)
    drawSurf(in: &context, size: size, tick: tick)
    drawBusStop(in: &context, size: size)
  }

  /// 流れ星だけを描く層です。星が見える時間帯にだけ動かします。
  ///
  /// 流れ星は動きそのものが中身なので、
  /// 「視差効果を減らす」設定がオンのときは出しません。
  @ViewBuilder
  private var shootingStarLayer: some View {
    if !reduceMotion, sky.nightness > Self.starVisibilityThreshold {
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
    if weather.isRaining {
      if reduceMotion {
        Canvas { context, size in
          drawRain(in: &context, size: size, frame: Self.stillTick)
        }
      } else {
        TimelineView(.periodic(from: Self.animationEpoch, by: Self.rainInterval)) { timeline in
          let frame = Int(timeline.date.timeIntervalSinceReferenceDate / Self.rainInterval)

          Canvas { context, size in
            drawRain(in: &context, size: size, frame: frame)
          }
        }
      }
    }
  }

  // MARK: - 雨

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

        path.addRect(
          CGRect(
            x: CGFloat(baseColumn) * Self.cellSize,
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
    let endRow = min(Int(Self.shoreRatio * Double(rowCount)), rowCount)

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
    let shoreTop = snapped(CGFloat(Self.shoreRatio) * size.height)
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
    let rowCount = min(Int(Self.shoreRatio * Double(allRowCount)), allRowCount)

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
        let isWhitecap = localHeight > Self.whitecapThreshold

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
    let columnCount = max(Int(ceil(size.width / Self.cellSize)), 1)
    let allRowCount = max(Int(ceil(size.height / Self.cellSize)), 1)
    let horizonRow = Int(Self.horizonRatio * Double(allRowCount))
    let waterEndRow = min(Int(Self.shoreRatio * Double(allRowCount)), allRowCount)

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

    context.fill(path, with: .color(sky.celestialTint.opacity(Self.reflectionOpacity)))
  }

  /// 波打ち際に白い泡を寄せます。周期的に前後して、寄せては返す動きになります。
  private func drawSurf(in context: inout GraphicsContext, size: CGSize, tick: Int) {
    let columnCount = max(Int(ceil(size.width / Self.cellSize)), 1)
    let rowCount = max(Int(ceil(size.height / Self.cellSize)), 1)
    let shoreRow = Int(Self.shoreRatio * Double(rowCount))

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
    let shoreTop = snapped(CGFloat(Self.shoreRatio) * size.height)
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
  private func drawClouds(in context: inout GraphicsContext, size: CGSize) {
    let visibility = 1 - sky.nightness
    guard visibility > 0.05 else { return }

    var path = Path()

    for cloud in Self.cloudLayout {
      let unit = Self.cellSize * CGFloat(cloud.scale)
      let baseX = snapped(CGFloat(cloud.x) * size.width)
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

    context.fill(path, with: .color(Color.white.opacity(visibility * 0.38)))
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
      opacity: 0.92
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
    opacity: Double
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
