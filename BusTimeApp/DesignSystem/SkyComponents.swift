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
}

// MARK: - カード

/// カードの地と輪郭を与える修飾子です。
private struct SkyCardModifier: ViewModifier {
  @Environment(\.sky) private var sky

  let radius: CGFloat
  let padding: CGFloat

  func body(content: Content) -> some View {
    content
      .padding(padding)
      .background(
        RoundedRectangle(cornerRadius: radius, style: .continuous)
          .fill(sky.surface)
      )
      .overlay(
        RoundedRectangle(cornerRadius: radius, style: .continuous)
          .stroke(sky.surfaceBorder, lineWidth: SkyMetrics.borderWidth)
      )
  }
}

extension View {
  /// 時刻連動の配色でカードの見た目を与えます。
  func skyCard(
    radius: CGFloat = SkyMetrics.cardRadius,
    padding: CGFloat = SkyMetrics.cardPadding
  ) -> some View {
    modifier(SkyCardModifier(radius: radius, padding: padding))
  }
}

// MARK: - ボタン

/// 押している間だけわずかに縮む、影を使わないボタンスタイルです。
struct SkyPressStyle: ButtonStyle {
  /// 押下時の縮小率です。
  private let pressedScale: CGFloat = 0.97

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? pressedScale : 1)
      .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
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
        .foregroundStyle(Color.white)
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
            .stroke(sky.ink.opacity(0.28), lineWidth: SkyMetrics.borderWidth)
        )
    }
    .buttonStyle(SkyPressStyle())
  }
}

/// ヘッダーなどで使う、輪郭だけの円形アイコンボタンです。
struct SkyIconButton: View {
  @Environment(\.sky) private var sky

  let systemImage: String
  let accessibilityLabel: String
  var isHighlighted: Bool = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(isHighlighted ? Color.white : sky.ink)
        .frame(width: SkyMetrics.minimumTapSize, height: SkyMetrics.minimumTapSize)
        .background(
          Circle().fill(isHighlighted ? sky.accent : Color.clear)
        )
        .overlay(
          Circle().stroke(
            isHighlighted ? Color.clear : sky.ink.opacity(0.22),
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

  let title: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .dynamicFont(size: 14, relativeTo: .subheadline, weight: .bold, design: .rounded)
        .foregroundStyle(isSelected ? Color.white : sky.inkSecondary)
        .frame(maxWidth: .infinity)
        .frame(minHeight: SkyMetrics.minimumTapSize)
        .background(
          Capsule().fill(isSelected ? sky.accent : Color.clear)
        )
        .overlay(
          Capsule().stroke(
            isSelected ? Color.clear : sky.ink.opacity(0.2),
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

  let text: String

  var body: some View {
    Text(text)
      .dynamicFont(size: 11, relativeTo: .caption2, weight: .bold, design: .rounded)
      .tracking(1.6)
      .foregroundStyle(sky.inkSecondary)
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
        .foregroundStyle(isWarning ? sky.warning : sky.inkSecondary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
