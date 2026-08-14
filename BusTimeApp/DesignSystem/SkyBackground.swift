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
  /// 動く層の基準時刻です。画面の再描画で周期がずれないよう、固定の起点を使います。
  private static let animationEpoch = Date(timeIntervalSinceReferenceDate: 0)
  /// 星の瞬きが変わる周期です。描き直し何回ぶんかで指定します。
  private static let twinkleTicks = 4
  /// 湖面の光の粒のうち、位置が変わらない割合です。
  /// 残りが入れ替わることで、水面全体ではなく一部だけがゆらめきます。
  private static let reflectionStableRatio: Double = 0.62
  /// 星を描く空の暗さの下限です。これより明るいと星は見えません。
  /// 夕焼けの残る空に星が出ないよう、暗さがある程度進んでから現れるようにします。
  private static let starVisibilityThreshold: Double = 0.22
  /// 画面に散らす星の数です。1粒が小さいぶん、数を多めにします。
  private static let starCount = 230
  /// 星を散らす範囲の下限です。画面の上からこの割合までに収め、空を見上げた構図にします。
  private static let starFieldRatio: Double = 0.45
  /// 星を散らす範囲の上限です。ステータスバーの真上に星が固まらないよう余白を空けます。
  private static let starFieldTopInset: Double = 0.03

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

  /// 水平線の位置です。これより下は湖面で、太陽・月もこの高さに沈みます。
  private static let horizonRatio: Double = 0.55
  /// 湖面の横波の細かさです。値が小さいほど大きなうねりになります。
  private static let waveFrequency: Double = 0.19
  /// 波の山と谷で色を何段ずらすかです。映り込みの位置だけでは分かりにくい明暗を補います。
  private static let waveBrightness: Double = 1.45
  /// 湖面の横波の振幅です。空を映す位置をこの分だけ揺らします。
  private static let waveAmplitude: Double = 0.016
  /// 波が進む速さです。描き直し1回あたりに位相がどれだけ進むかを表します。
  private static let waveSpeed: Double = 0.22
  /// 空と湖面が混ざり合う帯の広さです。水平線の上下それぞれにこの割合だけ広がります。
  private static let horizonBlendBand: Double = 0.022
  /// 水際にかかる霞の広さです。
  private static let hazeBand: Double = 0.034
  /// 水際の霞の密度です。
  private static let hazeDensity: Double = 0.55
  /// 水際の霞の濃さです。
  private static let hazeOpacity: Double = 0.16
  /// 湖面に落ちる光の道の濃さです。文字の読みやすさを保つため控えめにします。
  private static let reflectionOpacity: Double = 0.26
  /// 光の道が水平線から手前に向かって広がる倍率です。
  private static let reflectionSpread: Double = 1.8
  /// 水際での光の粒の密度です。手前に向かって減っていきます。
  private static let reflectionDensity: Double = 0.5
  /// さざ波を置く行の間隔です。
  private static let rippleRowInterval = 3
  /// 各マスからさざ波が始まる確率です。
  private static let rippleChance: Double = 0.035
  /// さざ波の濃さです。
  private static let rippleOpacity: Double = 0.07
  /// さざ波が流れる速さです。描き直し1回あたりに進むマス数を表します。
  private static let rippleSpeed: Double = 0.9
  /// 水平線近くのさざ波が流れる速さの割合です。遠いほどゆっくり動いて見えます。
  private static let rippleDistantSpeedRatio: Double = 0.35

  /// 岸辺が始まる位置です。ここで湖が終わります。
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
  /// 湖面と、その上に重なる岸辺の水打ち際・バス停までをまとめて描きます。
  private var animatedLayer: some View {
    TimelineView(.periodic(from: Self.animationEpoch, by: Self.animationInterval)) { timeline in
      let tick = Int(timeline.date.timeIntervalSinceReferenceDate / Self.animationInterval)

      Canvas { context, size in
        drawWater(in: &context, size: size, tick: tick)
        drawWaterSurface(in: &context, size: size, tick: tick)
        drawReflectionPath(in: &context, size: size, tick: tick)
        drawStars(in: &context, size: size, tick: tick / Self.twinkleTicks)
        drawShoreEdge(in: &context, size: size)
        drawBusStop(in: &context, size: size)
      }
    }
  }

  // MARK: - 空

  /// 空を数色だけで塗ります。
  /// 色の境目はベイヤーディザの市松模様でつなぎ、限られた色数のまま階調を表現します。
  /// 画面全体を空の色で埋め、湖面は動く層があとから重ねます。
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

  /// 湖面を描きます。水平線を鏡として空を映し、映る位置は時間とともに波打ちます。
  private func drawWater(in context: inout GraphicsContext, size: CGSize, tick: Int) {
    let colors = sky.quantizedWaterColors(steps: Self.skyColorSteps)
    let columnCount = max(Int(ceil(size.width / Self.cellSize)), 1)
    let rowCount = max(Int(ceil(size.height / Self.cellSize)), 1)
    let band = Self.horizonBlendBand
    let startRow = max(Int((Self.horizonRatio - band) * Double(rowCount)), 0)
    let endRow = min(Int(Self.shoreRatio * Double(rowCount)), rowCount)

    guard startRow < endRow else { return }

    // 波の位相です。時間とともに進み、映り込み全体が上下に揺れます。
    let phase = Double(tick) * Self.waveSpeed
    var paths = [Path](repeating: Path(), count: colors.count)

    for row in startRow..<endRow {
      let rawRatio = Double(row) / Double(max(rowCount - 1, 1))
      let depth = rawRatio - Self.horizonRatio
      let waveOffset = sin(Double(row) * Self.waveFrequency + phase)
      let mirroredRatio = max(Self.horizonRatio - depth + waveOffset * Self.waveAmplitude, 0)
      let blendRatio = (rawRatio - (Self.horizonRatio - band)) / (2 * band)
      // 波の山では明るく、谷では暗く見えるよう、選ぶ色を1段ずらします。
      let brightnessShift = Int((waveOffset * Self.waveBrightness).rounded())

      var runStartColumn = 0
      var runColorIndex = waterColorIndex(
        row: row,
        column: 0,
        mirroredRatio: mirroredRatio,
        blendRatio: blendRatio,
        brightnessShift: brightnessShift
      )

      for column in 1...columnCount {
        // 行末では必ず区切るため、範囲外には使わない番号を割り当てます。
        let colorIndex = column < columnCount
          ? waterColorIndex(
              row: row,
              column: column,
              mirroredRatio: mirroredRatio,
              blendRatio: blendRatio,
              brightnessShift: brightnessShift
            )
          : -2

        guard colorIndex != runColorIndex else { continue }

        // -1のマスは空のまま残すため、塗りません。
        if runColorIndex >= 0 {
          paths[runColorIndex].addRect(
            CGRect(
              x: CGFloat(runStartColumn) * Self.cellSize,
              y: CGFloat(row) * Self.cellSize,
              width: CGFloat(column - runStartColumn) * Self.cellSize,
              height: Self.cellSize
            )
          )
        }

        runStartColumn = column
        runColorIndex = colorIndex
      }
    }

    for (index, color) in colors.enumerated() {
      context.fill(paths[index], with: .color(color))
    }
  }

  /// 岸辺の水打ち際です。湖面の上に重ねる必要があるため、動く層で描きます。
  private func drawShoreEdge(in context: inout GraphicsContext, size: CGSize) {
    let shoreTop = snapped(CGFloat(Self.shoreRatio) * size.height)
    drawDitheredEdge(in: &context, size: size, top: shoreTop, color: sky.shore)
  }

  /// そのマスに塗る湖面の色番号を返します。
  /// 水際の帯では一部のマスを空のまま残すため、その場合は-1を返します。
  private func waterColorIndex(
    row: Int,
    column: Int,
    mirroredRatio: Double,
    blendRatio: Double,
    brightnessShift: Int
  ) -> Int {
    if blendRatio < 1 {
      // 帯の中では、下へ進むほど湖面が選ばれやすくなります。
      // 色の選択とは別のマス目を参照し、2つのディザが重ならないようにします。
      let blendThreshold =
        (Double(Self.ditherMatrix[(row + 2) % 4][(column + 1) % 4]) + 0.5) / 16
      guard blendThreshold < blendRatio else { return -1 }
    }

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

  // MARK: - 湖面

  /// 水際の霞と、湖面を流れるさざ波を描きます。
  private func drawWaterSurface(in context: inout GraphicsContext, size: CGSize, tick: Int) {
    let columnCount = max(Int(ceil(size.width / Self.cellSize)), 1)
    let rowCount = max(Int(ceil(size.height / Self.cellSize)), 1)
    let horizonRow = Int(Self.horizonRatio * Double(rowCount))
    // 岸辺から下は道路になるため、水面はそこまでを描きます。
    let waterEndRow = min(Int(Self.shoreRatio * Double(rowCount)), rowCount)

    guard horizonRow < waterEndRow else { return }

    drawHorizonHaze(
      in: &context,
      columnCount: columnCount,
      rowCount: rowCount,
      horizonRow: horizonRow
    )

    drawRipples(
      in: &context,
      columnCount: columnCount,
      rowCount: waterEndRow,
      horizonRow: horizonRow,
      tick: tick
    )
  }

  /// 水際に霞んだ光を散らし、空と湖面の境目を曖昧にします。
  /// 水平線に近いほど密で、離れるにつれて消えていきます。
  private func drawHorizonHaze(
    in context: inout GraphicsContext,
    columnCount: Int,
    rowCount: Int,
    horizonRow: Int
  ) {
    let bandRows = Int(Self.hazeBand * Double(rowCount))
    guard bandRows > 0 else { return }

    var path = Path()

    for row in (horizonRow - bandRows)...(horizonRow + bandRows) {
      guard row >= 0, row < rowCount else { continue }

      let distance = Double(abs(row - horizonRow)) / Double(bandRows)
      let density = pow(1 - distance, 2.0) * Self.hazeDensity

      for column in 0..<columnCount {
        guard pseudoRandom(row &* 15_485_863 &+ column) < density else { continue }

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

    context.fill(path, with: .color(sky.celestialTint.opacity(Self.hazeOpacity)))
  }

  /// 湖面全体に短い横筋を散らし、さざ波を表します。
  /// 筋は形を保ったまま横へ流れ、手前の行ほど速く動きます。
  private func drawRipples(
    in context: inout GraphicsContext,
    columnCount: Int,
    rowCount: Int,
    horizonRow: Int,
    tick: Int
  ) {
    var path = Path()

    for row in stride(from: horizonRow + 2, to: rowCount, by: Self.rippleRowInterval) {
      // 遠い行はゆっくり、手前の行ほど速く流れます。
      let depth = Double(row - horizonRow) / Double(max(rowCount - horizonRow, 1))
      let speed = Self.rippleSpeed * (Self.rippleDistantSpeedRatio + depth)
      let shift = Int(Double(tick) * speed)

      for column in 0..<columnCount {
        // 参照する位置をずらすことで、模様そのものが横へ移動します。
        let sourceColumn = (column + shift) % columnCount
        guard pseudoRandom(row &* 104_729 &+ sourceColumn) < Self.rippleChance else { continue }

        // 2〜4マスの短い横線にして、水面のきらめきに見せます。
        let length = 2 + Int(pseudoRandom(row &* 31 &+ sourceColumn &* 17) * 3)
        path.addRect(
          CGRect(
            x: CGFloat(column) * Self.cellSize,
            y: CGFloat(row) * Self.cellSize,
            width: CGFloat(length) * Self.cellSize,
            height: Self.cellSize
          )
        )
      }
    }

    context.fill(path, with: .color(sky.celestialTint.opacity(Self.rippleOpacity)))
  }

  /// 太陽・月の真下に、手前ほど広がってまばらになる光の道を描きます。
  /// 粒の一部は描き直しのたびに入れ替わり、水面がゆらめいて見えます。
  private func drawReflectionPath(
    in context: inout GraphicsContext,
    size: CGSize,
    tick: Int
  ) {
    let columnCount = max(Int(ceil(size.width / Self.cellSize)), 1)
    let rowCount = max(Int(ceil(size.height / Self.cellSize)), 1)
    let horizonRow = Int(Self.horizonRatio * Double(rowCount))
    let waterEndRow = min(Int(Self.shoreRatio * Double(rowCount)), rowCount)

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
        let isStable = pseudoRandom(row &* 7919 &+ column)
          < chance * Self.reflectionStableRatio
        let isFlickering = pseudoRandom(row &* 7919 &+ column &+ tick &* 104_729)
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

  // MARK: - 地上

  /// 湖の手前に岸辺と道路を敷きます。
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
    context.fill(polePath, with: .color(sky.roadLine.opacity(0.5)))

    // 標識の板です。
    let signRect = CGRect(
      x: signLeft,
      y: poleTop - signWidth,
      width: signWidth,
      height: signWidth
    )
    context.fill(Path(signRect), with: .color(sky.signboard))
    context.stroke(
      Path(signRect),
      with: .color(sky.road.opacity(0.55)),
      lineWidth: cell
    )

    // 標識の中に、バスの窓とタイヤを表す印を置きます。
    var mark = Path()
    mark.addRect(
      CGRect(x: signRect.minX + 2 * cell, y: signRect.minY + 3 * cell, width: 7 * cell, height: 2 * cell)
    )
    mark.addRect(
      CGRect(x: signRect.minX + 3 * cell, y: signRect.minY + 7 * cell, width: 2 * cell, height: cell)
    )
    mark.addRect(
      CGRect(x: signRect.minX + 6 * cell, y: signRect.minY + 7 * cell, width: 2 * cell, height: cell)
    )
    context.fill(mark, with: .color(sky.road.opacity(0.72)))

    drawSignWeathering(in: &context, signRect: signRect)
  }

  /// 標識の板に色あせの粒を散らし、長く風雨にさらされた面にします。
  private func drawSignWeathering(in context: inout GraphicsContext, signRect: CGRect) {
    let cell = Self.cellSize
    var path = Path()

    for row in 0..<Self.signSize {
      for column in 0..<Self.signSize {
        guard pseudoRandom(row &* 1301 &+ column &* 71) < 0.12 else { continue }

        path.addRect(
          CGRect(
            x: signRect.minX + CGFloat(column) * cell,
            y: signRect.minY + CGFloat(row) * cell,
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
  /// 湖面に落ちる光の幅も、この半径を基準にします。
  private func celestialRadiusInCells() -> Int {
    Int(
      (Double(Self.sunRadiusCells)
        + Double(Self.moonRadiusCells - Self.sunRadiusCells) * sky.nightness).rounded()
    )
  }

  /// セルを敷き詰めて円を描きます。
  private func drawPixelDisc(
    in context: inout GraphicsContext,
    centerX: CGFloat,
    centerY: CGFloat,
    radiusInCells: Int,
    color: Color,
    opacity: Double
  ) {
    guard radiusInCells > 0 else { return }

    var path = Path()
    let squaredLimit = radiusInCells * radiusInCells

    for row in -radiusInCells...radiusInCells {
      for column in -radiusInCells...radiusInCells {
        guard row * row + column * column <= squaredLimit else { continue }
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
