import SwiftUI

/// デザイン上の基準サイズを保ちながら、iPhoneの文字サイズ設定に追従させます。
private struct ScaledSystemFontModifier: ViewModifier {
    @ScaledMetric private var size: CGFloat
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
        content.font(.system(size: size, weight: weight, design: design))
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
