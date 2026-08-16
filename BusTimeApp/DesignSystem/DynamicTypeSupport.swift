import SwiftUI

/// デザイン上の基準サイズを保ちながら、iPhoneの文字サイズ設定に追従させます。
private struct ScaledSystemFontModifier: ViewModifier {
    @ScaledMetric private var size: CGFloat
    /// iPhoneの「文字を太くする」設定です。
    @Environment(\.legibilityWeight) private var legibilityWeight
    private let weight: Font.Weight
    private let design: Font.Design

    init(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle,
        weight: Font.Weight,
        design: Font.Design
    ) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: resolvedWeight, design: design))
    }

    /// 実際に使う太さです。
    ///
    /// 「文字を太くする」設定は、太さを明示したフォントには自動では効きません。
    /// このアプリは見出しやボタンで太さを指定しているため、
    /// 設定がオンのときは自分で1段階上げて追従させます。
    private var resolvedWeight: Font.Weight {
        guard legibilityWeight == .bold else { return weight }

        switch weight {
        case .ultraLight:
            return .light
        case .thin:
            return .regular
        case .light:
            return .medium
        case .regular:
            return .semibold
        case .medium, .semibold:
            return .bold
        case .bold:
            return .heavy
        default:
            return .black
        }
    }
}

extension View {
    /// 固定ポイントではなく、指定したテキストスタイルを基準に拡大・縮小するフォントです。
    func dynamicFont(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .body,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> some View {
        modifier(
            ScaledSystemFontModifier(
                size: size,
                relativeTo: textStyle,
                weight: weight,
                design: design
            )
        )
    }
}

/// タップ領域の一辺を、文字サイズ設定に合わせて広げます。
private struct ScaledTapTargetModifier: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = SkyMetrics.minimumTapSize

    func body(content: Content) -> some View {
        content.frame(minWidth: side, minHeight: side)
    }
}

extension View {
    /// 指で押せる最小の大きさを確保しつつ、文字サイズに合わせて広がるようにします。
    ///
    /// 固定の44ptで囲むと、文字を大きくする設定にしたときに
    /// 中のアイコンだけが枠からはみ出してしまいます。
    func scaledTapTarget() -> some View {
        modifier(ScaledTapTargetModifier())
    }
}

/// 通常の文字サイズでは横並び、アクセシビリティ文字サイズでは縦並びになる共通レイアウトです。
struct DynamicTypeStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let horizontalAlignment: HorizontalAlignment
    private let verticalAlignment: VerticalAlignment
    private let spacing: CGFloat
    private let content: () -> Content

    init(
        horizontalAlignment: HorizontalAlignment = .leading,
        verticalAlignment: VerticalAlignment = .center,
        spacing: CGFloat = 12,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: horizontalAlignment, spacing: spacing, content: content)
            } else {
                HStack(alignment: verticalAlignment, spacing: spacing, content: content)
            }
        }
    }
}
