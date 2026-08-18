import SwiftUI

/// 画面全体で共有する寸法です。値をここに集約し、画面ごとの数値のばらつきを防ぎます。
enum SkyMetrics {
  /// カードの角丸半径です。
  static let cardRadius: CGFloat = 22
  /// カード内側の余白です。
  static let cardPadding: CGFloat = 18
  /// 画面左右の余白です。
  static let screenPadding: CGFloat = 20
  /// アクセシビリティ文字サイズ時の画面左右の余白です。
  static let compactScreenPadding: CGFloat = 12
  /// カード同士の間隔です。
  static let sectionSpacing: CGFloat = 20
  /// タップ領域として確保する最小の一辺です。
  static let minimumTapSize: CGFloat = 44
  /// カード輪郭線の太さです。
  static let borderWidth: CGFloat = 1
  /// 本文の横幅の上限です。
  ///
  /// iPadのように横に広い画面では、1列のまま画面いっぱいに広げると
  /// 1行が長くなりすぎて目で追いにくくなります。読みやすい幅で止めます。
  static let contentMaxWidth: CGFloat = 520
}

// MARK: - カード

/// カードの地の濃さの決め方をまとめたものです。
enum SkyCardOpacity {
  /// 設定できる濃さの下限です。地を1枚だけ塗った、最も背景が透ける状態です。
  static let minimum: Double = 0
  /// 設定できる濃さの上限です。
  static let maximum: Double = 1
  /// 初期値です。
  static let standard: Double = 0.5
  /// 文字が詰まった面で追加する濃さです。
  static let denseBoost: Double = 0.25

  /// 背景を隠す地をどれだけ効かせるかを返します。
  /// 1で背景が完全に隠れ、0で半透明の地だけになります。
  ///
  /// 「透明度を下げる」がオンのときは、設定の濃さにかかわらず地を敷き切ります。
  /// 背景の風景が透けること自体がこの設定で避けたいことなので、
  /// 濃さの好みより、読みやすさの求めを優先します。
  static func coverage(
    for value: Double,
    isDense: Bool,
    reduceTransparency: Bool = false
  ) -> Double {
    guard !reduceTransparency else { return maximum }

    let boosted = value + (isDense ? denseBoost : 0)
    return min(max(boosted, minimum), maximum)
  }
}

private struct SkyCardOpacityKey: EnvironmentKey {
  static let defaultValue: Double = SkyCardOpacity.standard
}

extension EnvironmentValues {
  /// カードの地の濃さです。0が最も透け、1が最も濃くなります。設定画面で変えられます。
  var skyCardOpacity: Double {
    get { self[SkyCardOpacityKey.self] }
    set { self[SkyCardOpacityKey.self] = newValue }
  }
}

/// ボタンの輪郭の濃さです。
///
/// このアプリのボタンは、塗りつぶさないものには薄い輪郭を引いています。
/// iPhoneの「ボタンの形」設定は、押せる範囲をはっきり示すためのものなので、
/// オンのときは輪郭をはっきりさせて、文字との区別が付くようにします。
enum SkyButtonOutline {
  /// ふだんの濃さです。風景を邪魔しない薄さにしています。
  static let normal: Double = 0.22
  /// 「ボタンの形」がオンのときの濃さです。
  static let emphasized: Double = 0.65

  static func opacity(showButtonShapes: Bool) -> Double {
    showButtonShapes ? emphasized : normal
  }
}

/// カードの地と輪郭を与える修飾子です。
private struct SkyCardModifier: ViewModifier {
  @Environment(\.sky) private var sky
  @Environment(\.skyCardOpacity) private var cardOpacity
  /// iPhoneの「透明度を下げる」設定です。
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  let radius: CGFloat
  let padding: CGFloat
  /// 文字や数字が詰まった面かどうかです。
  /// あてはまる場合は、設定された濃さよりさらに濃く塗ります。
  let isDense: Bool

  /// 背景を隠す地をどれだけ効かせるかです。1で完全に隠れます。
  private var coverage: Double {
    SkyCardOpacity.coverage(
      for: cardOpacity,
      isDense: isDense,
      reduceTransparency: reduceTransparency
    )
  }

  func body(content: Content) -> some View {
    content
      .padding(padding)
      .background(
        ZStack {
          // 半透明の地です。背景の風景がうっすら残ります。
          RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(sky.surface)

          // 不透明の地です。濃さに応じて重ね、最大で背景を完全に隠します。
          RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(sky.surfaceOpaque)
            .opacity(coverage)
        }
      )
      .overlay(
        RoundedRectangle(cornerRadius: radius, style: .continuous)
          .stroke(sky.surfaceBorder, lineWidth: SkyMetrics.borderWidth)
      )
  }
}

extension View {
  /// 時刻連動の配色でカードの見た目を与えます。
  /// - Parameter isDense: 文字が詰まった面で、背景の透けをさらに抑えたいときに指定します。
  func skyCard(
    radius: CGFloat = SkyMetrics.cardRadius,
    padding: CGFloat = SkyMetrics.cardPadding,
    isDense: Bool = false
  ) -> some View {
    modifier(SkyCardModifier(radius: radius, padding: padding, isDense: isDense))
  }
}

// MARK: - ボタン

/// 押している間だけわずかに縮む、影を使わないボタンスタイルです。
struct SkyPressStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  /// 押下時の縮小率です。
  private let pressedScale: CGFloat = 0.97

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? pressedScale : 1)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
  }
}

/// 主要な操作に使う、塗りつぶしのボタンです。
struct SkyPrimaryButton: View {
  @Environment(\.sky) private var sky

  let title: String
  let systemImage: String
  let action: () -> Void

  /// ボタンの角丸半径です。
  private let radius: CGFloat = 14

  var body: some View {
    Button(action: action) {
      Label(title, systemImage: systemImage)
        .dynamicFont(size: 15, relativeTo: .subheadline, weight: .bold, design: .rounded)
        .foregroundStyle(sky.accentInk)
        .padding(.horizontal, 18)
        .frame(minHeight: SkyMetrics.minimumTapSize)
        .background(
          RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(sky.accent)
        )
    }
    .buttonStyle(SkyPressStyle())
  }
}

/// 補助的な操作に使う、枠線だけのボタンです。
struct SkySecondaryButton: View {
  @Environment(\.sky) private var sky
  /// iPhoneの「ボタンの形」設定です。
  @Environment(\.accessibilityShowButtonShapes) private var showButtonShapes

  let title: String
  let systemImage: String
  let action: () -> Void

  /// ボタンの角丸半径です。
  private let radius: CGFloat = 14

  var body: some View {
    Button(action: action) {
      Label(title, systemImage: systemImage)
        .dynamicFont(size: 15, relativeTo: .subheadline, weight: .bold, design: .rounded)
        .foregroundStyle(sky.ink)
        .padding(.horizontal, 18)
        .frame(minHeight: SkyMetrics.minimumTapSize)
        .background(
          RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(
              sky.ink.opacity(SkyButtonOutline.opacity(showButtonShapes: showButtonShapes)),
              lineWidth: SkyMetrics.borderWidth
            )
        )
    }
    .buttonStyle(SkyPressStyle())
  }
}

/// ヘッダーなどで使う、輪郭だけの円形アイコンボタンです。
struct SkyIconButton: View {
  @Environment(\.sky) private var sky
  /// iPhoneの「ボタンの形」設定です。
  @Environment(\.accessibilityShowButtonShapes) private var showButtonShapes

  let systemImage: String
  let accessibilityLabel: String
  var isHighlighted: Bool = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .dynamicFont(size: 16, relativeTo: .body, weight: .semibold)
        .foregroundStyle(isHighlighted ? sky.accentInk : sky.ink)
        .scaledTapTarget()
        .background(
          Circle().fill(isHighlighted ? sky.accent : Color.clear)
        )
        .overlay(
          Circle().stroke(
            isHighlighted
              ? Color.clear
              : sky.ink.opacity(SkyButtonOutline.opacity(showButtonShapes: showButtonShapes)),
            lineWidth: SkyMetrics.borderWidth
          )
        )
    }
    .buttonStyle(SkyPressStyle())
    .accessibilityLabel(accessibilityLabel)
  }
}

/// 2択以上の選択に使う、小さなチップです。
struct SkyChip: View {
  @Environment(\.sky) private var sky
  /// iPhoneの「ボタンの形」設定です。
  @Environment(\.accessibilityShowButtonShapes) private var showButtonShapes

  let title: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .dynamicFont(size: 14, relativeTo: .subheadline, weight: .bold, design: .rounded)
        .foregroundStyle(isSelected ? sky.accentInk : sky.ink)
        .frame(maxWidth: .infinity)
        .frame(minHeight: SkyMetrics.minimumTapSize)
        .background(
          Capsule().fill(isSelected ? sky.accent : Color.clear)
        )
        .overlay(
          Capsule().stroke(
            isSelected
              ? Color.clear
              : sky.ink.opacity(SkyButtonOutline.opacity(showButtonShapes: showButtonShapes)),
            lineWidth: SkyMetrics.borderWidth
          )
        )
    }
    .buttonStyle(SkyPressStyle())
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

// MARK: - 文字とレイアウトの部品

/// セクションの上に置く、字間を広げた小さな見出しです。
struct SkySectionLabel: View {
  @Environment(\.sky) private var sky
  @ScaledMetric(relativeTo: .caption) private var letterSpacing: CGFloat = 1.2

  let text: String

  var body: some View {
    Text(text)
      // 標準のテキストスタイルを直接使い、Dynamic Type監査でも追従を判定できるようにします。
      .font(.system(.caption, design: .rounded, weight: .heavy))
      .tracking(letterSpacing)
      .foregroundStyle(sky.ink)
      .accessibilityAddTraits(.isHeader)
  }
}

/// 情報の区切りに使う、極細の水平線です。
struct SkyDivider: View {
  @Environment(\.sky) private var sky

  var body: some View {
    Rectangle()
      .fill(sky.inkFaint)
      .frame(height: SkyMetrics.borderWidth)
      .accessibilityHidden(true)
  }
}

/// 補足を伝えるメッセージ行です。
struct SkyNoticeRow: View {
  @Environment(\.sky) private var sky

  let message: String
  var systemImage: String = "info.circle"
  var isWarning: Bool = false

  var body: some View {
    DynamicTypeStack(verticalAlignment: .top, spacing: 8) {
      Image(systemName: systemImage)
        .font(.caption.weight(.bold))
        .foregroundStyle(isWarning ? sky.warning : sky.inkSecondary)
      Text(message)
        .dynamicFont(size: 12, relativeTo: .caption, weight: .medium)
        // 注意状態はアイコンの形と文面で伝え、本文は常に高コントラスト色にします。
        .foregroundStyle(isWarning ? sky.ink : sky.inkSecondary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
