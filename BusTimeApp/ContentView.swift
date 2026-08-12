import SwiftUI
import UIKit

// MARK: - Neumorphic design system

enum AppDesignMode: String, CaseIterable, Identifiable {
    case neumorphic
    case claymorphic
    case minimalCute
    case maximalism

    var id: String { rawValue }

    var title: String {
        switch self {
        case .neumorphic: return "シンプル"
        case .claymorphic: return "カラフル"
        case .minimalCute: return "やさしいモノクロ"
        case .maximalism: return "ネオンポップ"
        }
    }

    var shortTitle: String {
        switch self {
        case .neumorphic: return "シンプル"
        case .claymorphic: return "カラフル"
        case .minimalCute: return "モノクロ"
        case .maximalism: return "ネオン"
        }
    }

    var description: String {
        switch self {
        case .neumorphic:
            return "淡いグレーを基調にした、見やすく落ち着いた画面"
        case .claymorphic:
            return "青を基調にした、明るくはっきりした画面"
        case .minimalCute:
            return "白黒と丸い模様を使った、すっきり可愛い画面"
        case .maximalism:
            return "鮮やかな緑と太い線を使った、元気で目立つ画面"
        }
    }

    var prefersLightColorScheme: Bool {
        self != .neumorphic
    }

    var interfaceAccentColor: Color {
        switch self {
        case .minimalCute, .maximalism:
            return .minimalInk
        case .neumorphic, .claymorphic:
            return .neumoAccent
        }
    }
}

private struct AppDesignModeKey: EnvironmentKey {
    static let defaultValue: AppDesignMode = .neumorphic
}

extension EnvironmentValues {
    var appDesignMode: AppDesignMode {
        get { self[AppDesignModeKey.self] }
        set { self[AppDesignModeKey.self] = newValue }
    }
}

extension Color {
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    // Light: #E0E5EC / Dark: a neutral blue-gray equivalent.
    static let neumoBackground = adaptive(
        light: UIColor(red: 224 / 255, green: 229 / 255, blue: 236 / 255, alpha: 1),
        dark: UIColor(red: 36 / 255, green: 41 / 255, blue: 50 / 255, alpha: 1)
    )
    static let neumoSurfaceTop = adaptive(
        light: UIColor(red: 232 / 255, green: 237 / 255, blue: 243 / 255, alpha: 1),
        dark: UIColor(red: 45 / 255, green: 51 / 255, blue: 62 / 255, alpha: 1)
    )
    static let neumoSurface = neumoBackground
    static let neumoSurfaceBottom = adaptive(
        light: UIColor(red: 216 / 255, green: 222 / 255, blue: 231 / 255, alpha: 1),
        dark: UIColor(red: 31 / 255, green: 36 / 255, blue: 44 / 255, alpha: 1)
    )
    static let neumoHighlight = adaptive(
        light: .white,
        dark: UIColor(red: 62 / 255, green: 70 / 255, blue: 84 / 255, alpha: 1)
    )
    static let neumoText = adaptive(
        light: UIColor(red: 33 / 255, green: 45 / 255, blue: 66 / 255, alpha: 1),
        dark: UIColor(red: 232 / 255, green: 236 / 255, blue: 243 / 255, alpha: 1)
    )
    static let neumoMuted = adaptive(
        light: UIColor(red: 101 / 255, green: 113 / 255, blue: 132 / 255, alpha: 1),
        dark: UIColor(red: 164 / 255, green: 175 / 255, blue: 194 / 255, alpha: 1)
    )
    static let neumoAccent = Color(red: 0.24, green: 0.57, blue: 0.83)
    static let neumoAccentDeep = Color(red: 0.18, green: 0.44, blue: 0.69)
    static let neumoAccentSoft = Color(red: 0.76, green: 0.89, blue: 0.97)
    static let neumoGreen = Color(red: 0.24, green: 0.61, blue: 0.48)
    static let neumoWarning = Color(red: 0.84, green: 0.47, blue: 0.29)
    static let neumoShadow = adaptive(
        light: UIColor(red: 163 / 255, green: 177 / 255, blue: 198 / 255, alpha: 1),
        dark: UIColor(red: 16 / 255, green: 20 / 255, blue: 27 / 255, alpha: 1)
    )
    static let claySky = Color(red: 0.35, green: 0.74, blue: 0.96)
    static let claySkyDeep = Color(red: 0.20, green: 0.55, blue: 0.88)
    static let clayShadow = Color(red: 0.10, green: 0.42, blue: 0.76)
    static let clayYellow = Color(red: 1.0, green: 0.77, blue: 0.18)
    static let clayWarningText = Color(red: 0.76, green: 0.49, blue: 0.05)
    static let clayPurple = Color(red: 0.55, green: 0.38, blue: 0.91)
    static let clayMint = Color(red: 0.16, green: 0.78, blue: 0.72)
    static let minimalBackground = Color(red: 0.985, green: 0.98, blue: 0.965)
    static let minimalInk = Color(red: 0.08, green: 0.075, blue: 0.07)
    static let minimalSoft = Color(red: 0.91, green: 0.90, blue: 0.87)
    static let minimalBlush = Color(red: 0.95, green: 0.78, blue: 0.79)
    static let maximalNeon = Color(red: 0.0, green: 0.94, blue: 0.25)
    static let maximalInk = Color.black
    static let maximalPaper = Color.white
}

struct SoftWave: Shape {
    let verticalPosition: CGFloat
    let amplitude: CGFloat
    let frequency: Double
    let phase: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let startX = rect.minX - rect.width * 0.08
        let width = rect.width * 1.16
        let baseY = rect.height * verticalPosition
        path.move(to: CGPoint(x: startX, y: baseY))

        for step in 0...120 {
            let progress = Double(step) / 120
            let x = startX + CGFloat(progress) * width
            let y = baseY + CGFloat(sin((progress * frequency + phase) * Double.pi * 2)) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}

struct NeumorphicBackground: View {
    @Environment(\.appDesignMode) private var designMode

    var body: some View {
        Group {
            switch designMode {
            case .claymorphic:
                ClaymorphicBackground()
            case .minimalCute:
                MinimalCuteBackground()
            case .maximalism:
                MaximalismBackground()
            case .neumorphic:
                NeumorphicBackdrop()
            }
        }
    }
}

struct NeumorphicBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.neumoBackground

                Circle()
                    .fill(Color.neumoHighlight.opacity(0.16))
                    .frame(width: proxy.size.width * 0.95)
                    .blur(radius: 28)
                    .offset(x: -proxy.size.width * 0.42, y: -proxy.size.height * 0.43)

                Circle()
                    .fill(Color.neumoAccent.opacity(0.025))
                    .frame(width: proxy.size.width * 0.9)
                    .blur(radius: 36)
                    .offset(x: proxy.size.width * 0.43, y: proxy.size.height * 0.36)

                SoftWave(verticalPosition: 0.12, amplitude: 26, frequency: 1.05, phase: 0.12)
                    .stroke(Color.neumoHighlight.opacity(0.18), lineWidth: 2)
                    .blur(radius: 0.4)
                SoftWave(verticalPosition: 0.83, amplitude: 36, frequency: 1.28, phase: 0.56)
                    .stroke(Color.neumoAccent.opacity(0.025), lineWidth: 2)
                    .blur(radius: 0.6)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
    }
}

struct ClaymorphicBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.62, green: 0.87, blue: 0.99), Color(red: 0.83, green: 0.96, blue: 1.0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: proxy.size.width * 0.56)
                    .blur(radius: 18)
                    .offset(x: proxy.size.width * 0.40, y: -proxy.size.height * 0.35)

                Circle()
                    .fill(Color.claySkyDeep.opacity(0.24))
                    .frame(width: proxy.size.width * 0.52)
                    .blur(radius: 18)
                    .offset(x: -proxy.size.width * 0.44, y: proxy.size.height * 0.30)

                Circle()
                    .fill(Color.white.opacity(0.26))
                    .frame(width: 120, height: 120)
                    .blur(radius: 12)
                    .offset(x: proxy.size.width * 0.39, y: proxy.size.height * 0.24)

                SoftWave(verticalPosition: 0.10, amplitude: 38, frequency: 1.08, phase: 0.10)
                    .stroke(Color.white.opacity(0.34), lineWidth: 2)
                    .blur(radius: 0.6)
                SoftWave(verticalPosition: 0.88, amplitude: 48, frequency: 1.16, phase: 0.48)
                    .stroke(Color.white.opacity(0.24), lineWidth: 2)
                    .blur(radius: 0.8)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
    }
}

struct MinimalOrganicBlob: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.18))
        path.addCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.06, y: rect.minY + rect.height * 0.12),
            control1: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.minY - rect.height * 0.10),
            control2: CGPoint(x: rect.maxX - rect.width * 0.28, y: rect.minY + rect.height * 0.02)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.10, y: rect.maxY - rect.height * 0.18),
            control1: CGPoint(x: rect.maxX + rect.width * 0.10, y: rect.minY + rect.height * 0.40),
            control2: CGPoint(x: rect.maxX + rect.width * 0.02, y: rect.maxY - rect.height * 0.24)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.06, y: rect.maxY - rect.height * 0.06),
            control1: CGPoint(x: rect.maxX - rect.width * 0.40, y: rect.maxY + rect.height * 0.08),
            control2: CGPoint(x: rect.minX + rect.width * 0.26, y: rect.maxY + rect.height * 0.02)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.18),
            control1: CGPoint(x: rect.minX - rect.width * 0.10, y: rect.maxY - rect.height * 0.34),
            control2: CGPoint(x: rect.minX - rect.width * 0.06, y: rect.minY + rect.height * 0.36)
        )
        path.closeSubpath()
        return path
    }
}

struct MinimalDotPattern: View {
    var color: Color = .minimalInk

    var body: some View {
        Canvas { context, size in
            for x in stride(from: CGFloat(3), through: size.width, by: CGFloat(10)) {
                for y in stride(from: CGFloat(3), through: size.height, by: CGFloat(10)) {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)),
                        with: .color(color.opacity(0.28))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct MinimalCuteBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.minimalBackground

                MinimalOrganicBlob()
                    .fill(Color.minimalSoft.opacity(0.72))
                    .frame(width: proxy.size.width * 0.86, height: proxy.size.width * 0.68)
                    .rotationEffect(.degrees(-14))
                    .offset(x: -proxy.size.width * 0.36, y: -proxy.size.height * 0.38)

                MinimalOrganicBlob()
                    .fill(Color.minimalInk.opacity(0.94))
                    .frame(width: proxy.size.width * 0.52, height: proxy.size.width * 0.42)
                    .rotationEffect(.degrees(18))
                    .offset(x: proxy.size.width * 0.43, y: -proxy.size.height * 0.31)

                MinimalDotPattern()
                    .frame(width: proxy.size.width * 0.34, height: 150)
                    .rotationEffect(.degrees(-7))
                    .offset(x: proxy.size.width * 0.23, y: -proxy.size.height * 0.15)

                MinimalOrganicBlob()
                    .fill(Color.minimalSoft.opacity(0.46))
                    .frame(width: proxy.size.width * 0.72, height: proxy.size.width * 0.52)
                    .rotationEffect(.degrees(24))
                    .offset(x: proxy.size.width * 0.38, y: proxy.size.height * 0.39)

                Circle()
                    .fill(Color.minimalBlush.opacity(0.72))
                    .frame(width: 46, height: 46)
                    .offset(x: -proxy.size.width * 0.38, y: proxy.size.height * 0.35)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
    }
}

struct MaximalStripePattern: View {
    var body: some View {
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.maximalNeon)
            )

            var stripes = Path()
            for offset in stride(
                from: -size.height,
                through: size.width + size.height,
                by: CGFloat(86)
            ) {
                stripes.move(to: CGPoint(x: offset, y: size.height))
                stripes.addLine(to: CGPoint(x: offset + size.height, y: 0))
            }
            context.stroke(stripes, with: .color(.white), lineWidth: 34)
        }
        .allowsHitTesting(false)
    }
}

struct MaximalismBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                MaximalStripePattern()

                Circle()
                    .stroke(Color.maximalInk, lineWidth: 60)
                    .frame(width: proxy.size.width * 0.58, height: proxy.size.width * 0.58)
                    .offset(x: -proxy.size.width * 0.67, y: -proxy.size.height * 0.30)

                Rectangle()
                    .fill(Color.maximalInk)
                    .frame(width: proxy.size.width * 0.48, height: 130)
                    .rotationEffect(.degrees(8))
                    .offset(x: proxy.size.width * 0.43, y: -proxy.size.height * 0.42)

                Circle()
                    .fill(Color.maximalInk)
                    .frame(width: proxy.size.width * 0.46, height: proxy.size.width * 0.46)
                    .offset(x: proxy.size.width * 0.43, y: proxy.size.height * 0.34)

                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.maximalInk, lineWidth: 22)
                    .frame(width: proxy.size.width * 0.52, height: 180)
                    .rotationEffect(.degrees(-12))
                    .offset(x: -proxy.size.width * 0.40, y: proxy.size.height * 0.40)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
    }
}

enum NeumorphicMode: Equatable {
    /// 背景から押し出された凸面。
    case convex
    /// 背景へ彫り込まれた凹面。
    case concave
}

private struct NeumorphicInsetOverlay<S: Shape>: View {
    let shape: S
    let shadowRadius: CGFloat
    let offset: CGFloat

    var body: some View {
        ZStack {
            // 凹面では左上の内壁が暗く、右下の内壁が光を受ける。
            shape
                .stroke(Color.neumoShadow.opacity(0.72), lineWidth: max(4, offset * 2.4))
                .blur(radius: shadowRadius * 0.48)
                .offset(x: -offset * 0.58, y: -offset * 0.58)

            shape
                .stroke(Color.neumoHighlight.opacity(0.86), lineWidth: max(4, offset * 2.2))
                .blur(radius: shadowRadius * 0.42)
                .offset(x: offset * 0.58, y: offset * 0.58)
        }
        .mask(shape)
        .allowsHitTesting(false)
    }
}

struct NeumorphicSurface<S: Shape>: ViewModifier {
    let shape: S
    /// convexは凸、concaveは凹。
    var mode: NeumorphicMode = .convex
    /// 影のぼかし半径。
    var shadowRadius: CGFloat = 12
    /// 左上／右下へ移動する影の距離。
    var offset: CGFloat = 7
    /// ボタン押下時は一時的に凹面へ切り替える。
    var pressed: Bool = false
    @Environment(\.appDesignMode) private var designMode

    private var effectiveMode: NeumorphicMode {
        pressed ? .concave : mode
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if designMode == .maximalism {
            content
                .background(
                    shape
                        .fill(Color.maximalPaper)
                        .shadow(
                            color: Color.maximalInk,
                            radius: 0,
                            x: pressed ? 3 : 7,
                            y: pressed ? 3 : 7
                        )
                )
                .overlay(shape.stroke(Color.maximalInk, lineWidth: pressed ? 2 : 3))
        } else if designMode == .minimalCute {
            content
                .background(
                    shape
                        .fill(Color.white.opacity(0.96))
                        .shadow(
                            color: Color.minimalInk.opacity(pressed ? 0.04 : 0.10),
                            radius: shadowRadius * 0.72,
                            x: 0,
                            y: max(3, offset * 0.72)
                        )
                )
                .overlay(
                    shape.stroke(Color.minimalInk.opacity(pressed ? 0.22 : 0.12), lineWidth: 1)
                )
        } else if designMode == .claymorphic {
            content
                .background(
                    shape
                        .fill(Color.white.opacity(0.97))
                        .shadow(color: Color.white.opacity(0.8), radius: shadowRadius * 0.62, x: -offset, y: -offset)
                        .shadow(color: Color.clayShadow.opacity(pressed ? 0.14 : 0.28), radius: shadowRadius * 1.25, x: offset, y: offset * 1.25)
                )
                .overlay(shape.stroke(Color.white.opacity(0.72), lineWidth: 1))
        } else if effectiveMode == .concave {
            content
                .background(shape.fill(Color.neumoBackground))
                .overlay(
                    NeumorphicInsetOverlay(
                        shape: shape,
                        shadowRadius: shadowRadius,
                        offset: offset
                    )
                )
        } else {
            content
                .background(
                    shape
                        .fill(
                            LinearGradient(
                                colors: [.neumoSurfaceTop, .neumoSurface, .neumoSurfaceBottom],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(
                            color: Color.neumoHighlight.opacity(0.94),
                            radius: shadowRadius,
                            x: -offset,
                            y: -offset
                        )
                        .shadow(
                            color: Color.neumoShadow.opacity(0.64),
                            radius: shadowRadius,
                            x: offset,
                            y: offset
                        )
                )
                .overlay(
                    shape.stroke(
                        LinearGradient(
                            colors: [
                                Color.neumoHighlight.opacity(0.74),
                                Color.clear,
                                Color.neumoShadow.opacity(0.16)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                )
        }
    }
}

extension View {
    /// 既存画面向けの簡易指定。depthから影半径とオフセットを算出する。
    func neumorphicSurface<S: Shape>(in shape: S, depth: CGFloat = 12, pressed: Bool = false) -> some View {
        modifier(
            NeumorphicSurface(
                shape: shape,
                mode: .convex,
                shadowRadius: depth,
                offset: depth * 0.58,
                pressed: pressed
            )
        )
    }

    /// 凸凹、影半径、オフセットを個別に指定する再利用可能API。
    func neumorphicSurface<S: Shape>(
        in shape: S,
        mode: NeumorphicMode,
        shadowRadius: CGFloat = 12,
        offset: CGFloat = 7,
        pressed: Bool = false
    ) -> some View {
        modifier(
            NeumorphicSurface(
                shape: shape,
                mode: mode,
                shadowRadius: shadowRadius,
                offset: offset,
                pressed: pressed
            )
        )
    }

    func clayCard<S: Shape>(in shape: S, elevation: CGFloat = 18) -> some View {
        background(
            shape
                .fill(Color.white.opacity(0.97))
                .shadow(color: Color.white.opacity(0.75), radius: elevation * 0.45, x: -5, y: -5)
                .shadow(color: Color.clayShadow.opacity(0.27), radius: elevation, x: 8, y: 12)
        )
        .overlay(shape.stroke(Color.white.opacity(0.72), lineWidth: 1))
    }
}

/// 通常時は凸、押下時は凹へ切り替わるNeumorphismボタン。
struct NeumorphicButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 18
    var shadowRadius: CGFloat = 10
    var offset: CGFloat = 6

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .neumorphicSurface(
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                mode: configuration.isPressed ? .concave : .convex,
                shadowRadius: shadowRadius,
                offset: offset,
                pressed: configuration.isPressed
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

/// 凹んだトラックと凸のノブを組み合わせたToggleStyle。
struct NeumorphicToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                configuration.label
                Spacer()
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(Color.neumoBackground)
                        .frame(width: 54, height: 30)
                        .neumorphicSurface(
                            in: Capsule(),
                            mode: .concave,
                            shadowRadius: 6,
                            offset: 3
                        )
                    Circle()
                        .fill(configuration.isOn ? Color.neumoAccent : Color.neumoSurface)
                        .frame(width: 24, height: 24)
                        .shadow(color: Color.neumoHighlight.opacity(0.8), radius: 3, x: -2, y: -2)
                        .shadow(color: Color.neumoShadow.opacity(0.55), radius: 4, x: 2, y: 2)
                        .padding(3)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// 凹んだトラックと凸ノブを持つ、0...1以外の範囲にも対応したSlider。
struct NeumorphicSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var tint: Color = .neumoAccent

    private var progress: Double {
        guard range.upperBound > range.lowerBound else { return 0 }
        return min(max((value - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            let knobSize: CGFloat = 26
            let travel = max(0, proxy.size.width - knobSize)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.neumoBackground)
                    .frame(height: 10)
                    .neumorphicSurface(
                        in: Capsule(),
                        mode: .concave,
                        shadowRadius: 5,
                        offset: 3
                    )

                Capsule()
                    .fill(tint.opacity(0.7))
                    .frame(width: knobSize / 2 + travel * progress, height: 6)

                Circle()
                    .fill(Color.neumoSurface)
                    .frame(width: knobSize, height: knobSize)
                    .shadow(color: Color.neumoHighlight.opacity(0.85), radius: 4, x: -3, y: -3)
                    .shadow(color: Color.neumoShadow.opacity(0.6), radius: 5, x: 3, y: 3)
                    .offset(x: travel * progress)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let newProgress = min(max(gesture.location.x / max(proxy.size.width, 1), 0), 1)
                        value = range.lowerBound + (range.upperBound - range.lowerBound) * newProgress
                    }
            )
        }
        .frame(height: 34)
        .accessibilityValue(Text("\(Int(progress * 100))%"))
    }
}

struct SoftPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct IconBubble: View {
    let systemName: String
    var tint: Color = .neumoAccent
    var size: CGFloat = 42

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .neumorphicSurface(
                in: Circle(),
                mode: .convex,
                shadowRadius: 8,
                offset: 5
            )
    }
}

struct SectionHeading: View {
    let eyebrow: String
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    @Environment(\.appDesignMode) private var designMode

    var body: some View {
        DynamicTypeStack(verticalAlignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(eyebrow.uppercased())
                    .dynamicFont(size: 10, relativeTo: .caption2, weight: .bold, design: .rounded)
                    .tracking(1.1)
                    .foregroundStyle(designMode.interfaceAccentColor)
                Text(title)
                    .dynamicFont(
                        size: 21,
                        relativeTo: .title2,
                        weight: .bold,
                        design: designMode == .minimalCute ? .serif : .rounded
                    )
                    .foregroundStyle(Color.neumoText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.neumoMuted)
                }
                .buttonStyle(SoftPressButtonStyle())
            }
        }
    }
}

private enum MainTab: Hashable {
    case home
    case timetable

    var title: String {
        switch self {
        case .home:
            return "ホーム"
        case .timetable:
            return "時刻表"
        }
    }

    var systemName: String {
        switch self {
        case .home:
            return "house.fill"
        case .timetable:
            return "clock.fill"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .home:
            return "ホームタブ"
        case .timetable:
            return "時刻表タブ"
        }
    }
}

private struct MainTabBar: View {
    @Binding var selection: MainTab
    @Environment(\.appDesignMode) private var designMode

    var body: some View {
        HStack(spacing: 8) {
            legacyTabButton(.home)
            legacyTabButton(.timetable)
        }
        .padding(8)
        .neumorphicSurface(
            in: RoundedRectangle(cornerRadius: 24, style: .continuous),
            depth: 12
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func legacyTabButton(_ tab: MainTab) -> some View {
        let isSelected = selection == tab

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selection = tab
            }
        } label: {
            Label(tab.title, systemImage: tab.systemName)
                .dynamicFont(size: 14, relativeTo: .subheadline, weight: .bold)
                .foregroundStyle(isSelected ? selectedForeground : Color.neumoMuted)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(isSelected ? selectedBackground : Color.clear)
                )
                .neumorphicSurface(
                    in: RoundedRectangle(cornerRadius: 17, style: .continuous),
                    mode: isSelected ? .concave : .convex,
                    shadowRadius: isSelected ? 5 : 6,
                    offset: isSelected ? 3 : 4
                )
        }
        .buttonStyle(SoftPressButtonStyle())
        .accessibilityLabel(tab.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectedForeground: Color {
        switch designMode {
        case .minimalCute:
            return .white
        case .maximalism:
            return .maximalInk
        case .neumorphic, .claymorphic:
            return .white
        }
    }

    private var selectedBackground: Color {
        switch designMode {
        case .minimalCute:
            return .minimalInk
        case .maximalism:
            return .maximalNeon
        case .neumorphic:
            return .neumoAccent
        case .claymorphic:
            return .claySkyDeep
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var settingsViewModel = SettingsViewModel()
    @StateObject private var notificationViewModel = NotificationViewModel()
    @State private var selectedTab: MainTab = .home
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var currentDesignMode: AppDesignMode {
        coordinator.designMode
    }

    private var dashboardAccentColor: Color {
        currentDesignMode.interfaceAccentColor
    }

    private var scheduledBusIDs: Set<String> {
        Set(notificationViewModel.scheduledNotifications.map(\.busID))
    }

    private var dashboardHorizontalPadding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 12 : 20
    }

    var body: some View {
        NavigationStack {
            mainTabContent
            .background(NeumorphicBackground())
            .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(currentDesignMode.prefersLightColorScheme ? .light : nil)
            .onAppear {
                coordinator.send(.launch)
                viewModel.refreshRouteAvailability()
                viewModel.performSearch()
                viewModel.checkLocationAndSetOrigin()
                notificationViewModel.refresh()
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    viewModel.refreshForAppActivation()
                    viewModel.checkLocationAndSetOrigin()
                    settingsViewModel.refreshLiveActivityAvailability()
                }
            }
            .onChange(of: viewModel.selectedRoute) { _ in
                viewModel.performSearch()
            }
            .sheet(isPresented: Binding(
                get: { coordinator.isTutorialPresented },
                set: { if !$0 { coordinator.send(.dismiss) } }
            )) {
                TutorialView()
                    .environment(\.appDesignMode, currentDesignMode)
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: Binding(
                get: { coordinator.isSettingsPresented },
                set: { if !$0 { coordinator.send(.dismiss) } }
            )) {
                SettingsView(viewModel: settingsViewModel) { mode in
                    coordinator.send(.changeDesignMode(mode))
                }
                    .environment(\.appDesignMode, currentDesignMode)
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: Binding(
                get: { coordinator.isNotificationsPresented },
                set: { if !$0 { coordinator.send(.dismiss) } }
            )) {
                NotificationManagementView(
                    viewModel: notificationViewModel,
                    liveActivityBusID: viewModel.trackedBusId,
                    onEndLiveActivity: viewModel.endLiveActivity
                )
                .environment(\.appDesignMode, currentDesignMode)
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: Binding(
                get: { coordinator.isNotificationOptionsPresented },
                set: { if !$0 { coordinator.send(.dismiss) } }
            )) {
                if let bus = coordinator.selectedBus {
                    NotificationOptionsView(
                        bus: bus,
                        routeName: viewModel.selectedRoute.rawValue,
                        scheduledNotification: notificationViewModel.notification(for: bus.id),
                        permissionStatus: notificationViewModel.permissionStatus,
                        liveActivityBusID: viewModel.trackedBusId,
                        isLiveActivityEnabled: settingsViewModel.shouldUseLiveActivity,
                        isLiveActivityAvailable: settingsViewModel.isLiveActivityAvailable,
                        onOpenNotificationSettings: notificationViewModel.openNotificationSettings,
                        onSchedule: { minutes in scheduleNotification(minutes: minutes) },
                        onStartLiveActivity: {
                            if notificationViewModel.notification(for: bus.id) == nil {
                                scheduleNotification(minutes: 5, startLiveActivity: true)
                            } else {
                                viewModel.startLiveActivity(for: bus)
                                coordinator.send(.dismiss)
                            }
                        },
                        onEndLiveActivity: {
                            viewModel.endLiveActivity()
                        }
                    )
                    .environment(\.appDesignMode, currentDesignMode)
                    .presentationDragIndicator(.visible)
                }
            }
            .alert("通知設定", isPresented: Binding(
                get: { coordinator.isNotificationResultPresented },
                set: { if !$0 { coordinator.send(.dismiss) } }
            )) {
                Button("OK") { coordinator.send(.dismiss) }
            } message: {
                Text(coordinator.notificationMessage ?? "")
            }
            .alert(
                "Live Activityエラー",
                isPresented: Binding(
                    get: { coordinator.isLiveActivityErrorPresented },
                    set: { if !$0 {
                        viewModel.liveActivityError = nil
                        coordinator.send(.clearError)
                    } }
                )
            ) {
                Button("設定を確認") {
                    viewModel.openAppSettings()
                    viewModel.liveActivityError = nil
                    coordinator.send(.clearError)
                }
                Button("OK") {
                    viewModel.liveActivityError = nil
                    coordinator.send(.clearError)
                }
            } message: {
                Text(coordinator.liveActivityErrorMessage ?? "Live Activityでエラーが発生しました。")
            }
            .onChange(of: viewModel.liveActivityError) { errorMessage in
                if let errorMessage {
                    coordinator.send(.liveActivityFailed(errorMessage))
                    viewModel.liveActivityError = nil
                }
            }
        }
        .environment(\.appDesignMode, currentDesignMode)
    }

    @ViewBuilder
    private var mainTabContent: some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            liquidGlassTabContent
        } else {
            legacyTabContent
        }
#else
        legacyTabContent
#endif
    }

    private var legacyTabContent: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                homeTab
                    .tag(MainTab.home)

                TimetableTabView(
                    viewModel: viewModel,
                    scheduledBusIDs: scheduledBusIDs,
                    onSelectBus: selectBus
                )
                .tag(MainTab.timetable)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.2), value: selectedTab)

            MainTabBar(selection: $selectedTab)
        }
    }

#if compiler(>=6.2)
    @available(iOS 26.0, *)
    private var liquidGlassTabContent: some View {
        TabView(selection: $selectedTab) {
            homeTab
                .tabItem {
                    Label("ホーム", systemImage: MainTab.home.systemName)
                        .accessibilityLabel(MainTab.home.accessibilityLabel)
                }
                .tag(MainTab.home)

            TimetableTabView(
                viewModel: viewModel,
                scheduledBusIDs: scheduledBusIDs,
                onSelectBus: selectBus
            )
            .tabItem {
                Label("時刻表", systemImage: MainTab.timetable.systemName)
                    .accessibilityLabel(MainTab.timetable.accessibilityLabel)
            }
            .tag(MainTab.timetable)
        }
        .tabViewStyle(.tabBarOnly)
        .tint(Color.primary)
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
    }
#endif

    private var homeTab: some View {
        ScrollView(showsIndicators: false) {
            Group {
                if currentDesignMode == .claymorphic {
                    claymorphicDashboard
                } else {
                    neumorphicDashboard
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.985)))
        }
    }

    private var neumorphicDashboard: some View {
        VStack(spacing: 24) {
            appHeader
            SearchCriteriaBanner(
                criteria: viewModel.searchCriteriaDescription,
                result: viewModel.searchResultDescription
            )

            if case let .serviceUnavailable(message) = viewModel.state {
                ServiceMessageCard(message: message)
            } else if case let .failed(message) = viewModel.state {
                ServiceMessageCard(message: message)
            } else if let nextBus = viewModel.searchResults.first {
                NextBusCard(
                    bus: nextBus,
                    routeName: viewModel.selectedRoute.rawValue,
                    countdown: viewModel.countdownMessages[nextBus.id],
                    isNotificationScheduled: scheduledBusIDs.contains(nextBus.id)
                ) {
                    selectBus(nextBus)
                }
            } else {
                EmptyBusCard()
            }

            RouteSelectorCard(viewModel: viewModel, locationAction: viewModel.checkLocationAndSetOrigin)
            SearchPanel(viewModel: viewModel)

            if viewModel.holidayMessage == nil {
                upcomingSection
            }

            serviceFooter
        }
        .padding(.horizontal, dashboardHorizontalPadding)
        .padding(.top, 14)
        .padding(.bottom, 32)
    }

    private var claymorphicDashboard: some View {
        VStack(spacing: 20) {
            ClayHeaderBar(
                helpAction: { coordinator.send(.showTutorial) },
                settingsAction: { coordinator.send(.showSettings) },
                notificationAction: { coordinator.send(.showNotifications) },
                notificationCount: notificationViewModel.scheduledNotifications.count
            )
            SearchCriteriaBanner(
                criteria: viewModel.searchCriteriaDescription,
                result: viewModel.searchResultDescription
            )

            if case let .serviceUnavailable(message) = viewModel.state {
                ClayMessageCard(message: message)
            } else if case let .failed(message) = viewModel.state {
                ClayMessageCard(message: message)
            } else if let nextBus = viewModel.searchResults.first {
                ClayNextBusHero(
                    bus: nextBus,
                    countdown: viewModel.countdownMessages[nextBus.id],
                    isNotificationScheduled: scheduledBusIDs.contains(nextBus.id)
                ) {
                    selectBus(nextBus)
                }
            } else {
                ClayMessageCard(message: "条件に合うバスがありません。時刻を変更して再検索してください。")
            }

            ClayRouteSearchCard(
                viewModel: viewModel,
                locationAction: viewModel.checkLocationAndSetOrigin
            )

            if viewModel.holidayMessage == nil {
                ClayUpcomingCard(
                    buses: viewModel.searchResults,
                    countdowns: viewModel.countdownMessages,
                    scheduledBusIDs: scheduledBusIDs,
                    reasons: Dictionary(
                        uniqueKeysWithValues: viewModel.searchResults.map {
                            ($0.id, viewModel.resultReason(for: $0))
                        }
                    )
                ) { bus in
                    selectBus(bus)
                }
            }

            serviceFooter
        }
        .padding(.horizontal, dashboardHorizontalPadding)
        .padding(.top, 14)
        .padding(.bottom, 34)
    }

    private var serviceFooter: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.neumoGreen)
                .frame(width: 7, height: 7)
            Text("平日のみ運行  •  時刻表は現地案内を優先します")
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.neumoMuted)
        }
        .padding(.top, 2)
    }

    private func selectBus(_ bus: Bus) {
        coordinator.send(.selectBus(bus))
    }

    private var appHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 13) {
                appBrand
                Spacer(minLength: 8)
                appHeaderActions
            }

            VStack(alignment: .leading, spacing: 10) {
                appBrand
                appHeaderActions
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var appBrand: some View {
        DynamicTypeStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(
                        currentDesignMode == .minimalCute
                            ? Color.minimalSoft.opacity(0.88)
                            : (currentDesignMode == .maximalism
                                ? Color.maximalNeon
                                : Color.neumoAccent.opacity(0.11))
                    )
                    .frame(width: 52, height: 52)
                Image(systemName: "bus.fill")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(dashboardAccentColor)
            }
            .shadow(color: Color.white.opacity(0.9), radius: 7, x: -4, y: -4)
            .shadow(color: Color.neumoShadow.opacity(0.08), radius: 7, x: 4, y: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text("コロンブスシティ")
                    .dynamicFont(
                        size: 20,
                        relativeTo: .title3,
                        weight: .bold,
                        design: currentDesignMode == .minimalCute ? .serif : .rounded
                    )
                    .foregroundStyle(Color.neumoText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("SHUTTLE SERVICE")
                    .dynamicFont(size: 10, relativeTo: .caption2, weight: .bold, design: .rounded)
                    .tracking(1.8)
                    .foregroundStyle(Color.neumoMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var appHeaderActions: some View {
        HStack(spacing: 10) {
            Button {
                coordinator.send(.showNotifications)
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: scheduledBusIDs.isEmpty ? "bell" : "bell.badge.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("通知")
                        .dynamicFont(size: 9, relativeTo: .caption2, weight: .bold)
                }
                .foregroundStyle(dashboardAccentColor)
                .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(SoftPressButtonStyle())
            .accessibilityLabel("設定した通知を確認")

            Button {
                coordinator.send(.showSettings)
            } label: {
                IconBubble(systemName: "gearshape.fill", tint: dashboardAccentColor, size: 44)
            }
            .buttonStyle(SoftPressButtonStyle())
            .accessibilityLabel("設定を開く")

            Button {
                coordinator.send(.showTutorial)
            } label: {
                IconBubble(
                    systemName: "questionmark",
                    tint: currentDesignMode == .maximalism
                        ? .maximalInk
                        : (currentDesignMode == .minimalCute ? .minimalInk : .neumoMuted),
                    size: 44
                )
            }
            .buttonStyle(SoftPressButtonStyle())
            .accessibilityLabel("使い方を開く")
        }
    }

    private var upcomingSection: some View {
        VStack(spacing: 12) {
            SectionHeading(
                eyebrow: "UP NEXT",
                title: "候補のバス",
                actionTitle: "\(viewModel.searchResults.count)便表示",
                action: nil
            )

            ForEach(viewModel.searchResults) { bus in
                BusResultRow(
                    bus: bus,
                    viewModel: viewModel,
                    isNotificationScheduled: scheduledBusIDs.contains(bus.id),
                    reason: viewModel.resultReason(for: bus)
                ) {
                    selectBus(bus)
                }
            }
        }
    }

    private func scheduleNotification(
        minutes: Int,
        startLiveActivity: Bool? = nil
    ) {
        guard let bus = coordinator.selectedBus else { return }
        notificationViewModel.scheduleNotification(
            for: bus,
            routeName: viewModel.selectedRoute.rawValue,
            minutesBefore: minutes
        ) { result in
            switch result {
            case let .success(item):
                let shouldStartLiveActivity = startLiveActivity
                    ?? settingsViewModel.shouldUseLiveActivity
                let liveActivityMessage = startLiveActivityIfNeeded(
                    for: bus,
                    shouldStart: shouldStartLiveActivity
                )
                coordinator.send(.notificationScheduled(
                    "通知を設定しました。\n\n\(item.busDescription)\n\(item.notificationDescription)にお知らせします。\(liveActivityMessage)\n\n※時刻表の予定です。遅延・運休は反映されません。"
                ))
            case let .failure(error):
                coordinator.send(.notificationScheduled(error.localizedDescription))
            }
        }
    }

    private func startLiveActivityIfNeeded(for bus: Bus, shouldStart: Bool) -> String {
        guard shouldStart else { return "" }

        if viewModel.trackedBusId == bus.id {
            return "\nLive Activityも表示中です。"
        }

        guard viewModel.trackedBusId == nil else {
            return "\n別の便をLive Activityで表示中のため、通常通知だけを設定しました。"
        }

        viewModel.startLiveActivity(for: bus)
        if viewModel.trackedBusId == bus.id {
            return "\nLive Activityも開始しました。"
        }

        // 通常通知は登録済みなので、Live Activityの失敗も同じ完了画面で伝えます。
        viewModel.liveActivityError = nil
        return "\n通常通知は設定されましたが、Live Activityは開始できませんでした。"
    }
}

struct TimetableTabView: View {
    @ObservedObject var viewModel: HomeViewModel
    let scheduledBusIDs: Set<String>
    let onSelectBus: (Bus) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var horizontalPadding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 12 : 20
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                timetableHeader

                if let holidayMessage = viewModel.holidayMessage {
                    ServiceMessageCard(message: holidayMessage)
                } else if viewModel.currentFullTimetable.isEmpty {
                    EmptyBusCard()
                } else {
                    timetableList
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
    }

    private var timetableHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(eyebrow: "TIMETABLE", title: "時刻表")

            DynamicTypeStack(verticalAlignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.selectedRoute.rawValue)
                        .dynamicFont(size: 17, relativeTo: .headline, weight: .bold, design: .rounded)
                        .foregroundStyle(Color.neumoText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(viewModel.selectedRoute.guidance)
                        .font(.caption)
                        .foregroundStyle(Color.neumoMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(viewModel.currentFullTimetable.count)便")
                    .dynamicFont(size: 15, relativeTo: .subheadline, weight: .bold)
                    .foregroundStyle(Color.neumoAccentDeep)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.neumoAccentSoft.opacity(0.62)))
            }

            Label(
                "ルートを変更する場合は、ホームタブで出発地と目的地を選択してください",
                systemImage: "arrow.left.arrow.right"
            )
            .font(.caption2)
            .foregroundStyle(Color.neumoMuted)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .neumorphicSurface(in: RoundedRectangle(cornerRadius: 24, style: .continuous), depth: 12)
    }

    private var timetableList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("出発")
                Spacer()
                Text("到着")
                Text("")
                    .frame(width: 42)
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.neumoMuted)
            .padding(.horizontal, 18)
            .padding(.vertical, 13)

            ForEach(viewModel.currentFullTimetable) { bus in
                BusTimetableRow(
                    bus: bus,
                    isRecommended: viewModel.searchResults.contains(where: { $0.id == bus.id }),
                    isNotificationScheduled: scheduledBusIDs.contains(bus.id),
                    action: { onSelectBus(bus) }
                )
            }
        }
        .neumorphicSurface(in: RoundedRectangle(cornerRadius: 24, style: .continuous), depth: 14)
    }
}

struct BusNotificationActionButton: View {
    let isScheduled: Bool
    let action: () -> Void
    @Environment(\.appDesignMode) private var designMode

    private var accentColor: Color {
        designMode.interfaceAccentColor
    }

    var body: some View {
        Button(action: action) {
            Label(
                isScheduled ? "設定済み" : "通知",
                systemImage: isScheduled ? "bell.fill" : "bell"
            )
            .font(.caption2.weight(.bold))
            .foregroundStyle(
                designMode == .minimalCute || designMode == .maximalism
                    ? Color.minimalInk
                    : (isScheduled ? Color.neumoAccentDeep : Color.neumoAccent)
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(
                        designMode == .minimalCute
                            ? Color.minimalSoft.opacity(isScheduled ? 0.92 : 0.56)
                            : (designMode == .maximalism
                                ? Color.maximalNeon
                                : (isScheduled ? Color.neumoAccentSoft.opacity(0.8) : accentColor.opacity(0.08)))
                    )
            )
        }
        .buttonStyle(SoftPressButtonStyle())
        .accessibilityLabel(isScheduled ? "この便は通知設定済み" : "この便の通知を設定")
        .accessibilityHint("出発前に通知する方法を選びます")
    }
}

// MARK: - Claymorphism dashboard

struct ClayHeaderBar: View {
    let helpAction: () -> Void
    let settingsAction: () -> Void
    let notificationAction: () -> Void
    let notificationCount: Int

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 13) {
                brand
                Spacer(minLength: 8)
                actions
            }

            VStack(alignment: .leading, spacing: 10) {
                brand
                actions.frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(15)
        .clayCard(in: RoundedRectangle(cornerRadius: 25, style: .continuous), elevation: 18)
    }

    private var brand: some View {
        DynamicTypeStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.claySky, .claySkyDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                Image(systemName: "bus.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            .shadow(color: Color.clayShadow.opacity(0.32), radius: 10, x: 5, y: 7)

            VStack(alignment: .leading, spacing: 3) {
                Text("コロンブスシティ")
                    .dynamicFont(size: 19, relativeTo: .title3, weight: .bold, design: .rounded)
                    .foregroundStyle(Color.neumoText)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 5) {
                    Circle().fill(Color.clayMint).frame(width: 6, height: 6)
                    Text("SHUTTLE IS ACTIVE")
                        .dynamicFont(size: 9, relativeTo: .caption2, weight: .bold, design: .rounded)
                        .tracking(1.2)
                        .foregroundStyle(Color.neumoMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button(action: notificationAction) {
                VStack(spacing: 2) {
                    Image(systemName: notificationCount == 0 ? "bell" : "bell.badge.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("通知")
                        .dynamicFont(size: 9, relativeTo: .caption2, weight: .bold)
                }
                .foregroundStyle(Color.claySkyDeep)
                .frame(minWidth: 44, minHeight: 44)
                .background(Circle().fill(Color(red: 0.91, green: 0.96, blue: 0.99)))
            }
            .buttonStyle(SoftPressButtonStyle())
            .accessibilityLabel("設定した通知を確認（\(notificationCount)件）")

            Button(action: settingsAction) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.claySkyDeep)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color(red: 0.91, green: 0.96, blue: 0.99)))
            }
            .buttonStyle(SoftPressButtonStyle())
            .accessibilityLabel("設定を開く")

            Button(action: helpAction) {
                Image(systemName: "questionmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.claySkyDeep)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color(red: 0.91, green: 0.96, blue: 0.99)))
            }
            .buttonStyle(SoftPressButtonStyle())
            .accessibilityLabel("使い方を開く")
        }
    }
}

struct ClayNextBusHero: View {
    let bus: Bus
    let countdown: String?
    let isNotificationScheduled: Bool
    let notifyAction: () -> Void

    var body: some View {
        VStack(spacing: -28) {
            ZStack {
                RoundedRectangle(cornerRadius: 31, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.24, green: 0.67, blue: 0.96), Color(red: 0.16, green: 0.52, blue: 0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 118, height: 118)
                    .offset(x: 128, y: -67)
                Circle()
                    .fill(Color.claySky.opacity(0.5))
                    .frame(width: 78, height: 78)
                    .offset(x: -145, y: 72)
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 38, height: 38)
                    .offset(x: 116, y: 61)

                VStack(spacing: 13) {
                    DynamicTypeStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("NEXT SHUTTLE")
                                .dynamicFont(size: 10, relativeTo: .caption2, weight: .bold, design: .rounded)
                                .tracking(1.6)
                                .foregroundStyle(.white.opacity(0.78))
                            Text("次のバス")
                                .dynamicFont(size: 22, relativeTo: .title2, weight: .bold, design: .rounded)
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(countdown ?? "まもなく")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.claySkyDeep)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.white.opacity(0.92)))
                    }

                    DynamicTypeStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 84, height: 84)
                                .shadow(color: Color.clayShadow.opacity(0.36), radius: 13, x: 7, y: 10)
                            Circle()
                                .fill(Color.clayYellow)
                                .frame(width: 22, height: 22)
                                .offset(x: 31, y: -30)
                            Image(systemName: "bus.fill")
                                .font(.system(size: 39, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.claySky, .claySkyDeep],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }

                        VStack(alignment: .leading, spacing: 7) {
                            Text(bus.originName)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 5) {
                                Circle().fill(.white).frame(width: 7, height: 7)
                                Capsule().fill(.white.opacity(0.5)).frame(width: 46, height: 3)
                                Image(systemName: "arrow.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                            Text(bus.destinationName)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(21)
            }
            .frame(minHeight: 228)
            .shadow(color: Color.clayShadow.opacity(0.34), radius: 22, x: 9, y: 14)

            VStack(spacing: 14) {
                DynamicTypeStack(verticalAlignment: .lastTextBaseline, spacing: 11) {
                    Text(bus.departure)
                        .dynamicFont(size: 36, relativeTo: .largeTitle, weight: .bold, design: .rounded)
                        .foregroundStyle(Color.neumoText)
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.claySkyDeep)
                    Text(bus.arrival)
                        .dynamicFont(size: 27, relativeTo: .title, weight: .bold, design: .rounded)
                        .foregroundStyle(Color.neumoMuted)
                    BusNotificationActionButton(
                        isScheduled: isNotificationScheduled,
                        action: notifyAction
                    )
                }

                Text(bus.stopSummary)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.neumoMuted)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.top, 43)
            .padding(.bottom, 18)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color.white))
            .shadow(color: Color.clayShadow.opacity(0.25), radius: 20, x: 8, y: 13)
        }
    }
}

struct ClayMessageCard: View {
    let message: String

    var body: some View {
        DynamicTypeStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.clayYellow.opacity(0.92))
                    .frame(width: 52, height: 52)
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("SERVICE INFORMATION")
                    .dynamicFont(size: 9, relativeTo: .caption2, weight: .bold, design: .rounded)
                    .tracking(1.1)
                    .foregroundStyle(Color.claySkyDeep)
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.neumoText)
            }
        }
        .padding(18)
        .clayCard(in: RoundedRectangle(cornerRadius: 25, style: .continuous), elevation: 18)
    }
}

struct ClayRouteSearchCard: View {
    @ObservedObject var viewModel: BusTimetableViewModel
    let locationAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            DynamicTypeStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("PLAN YOUR RIDE")
                        .dynamicFont(size: 9, relativeTo: .caption2, weight: .bold, design: .rounded)
                        .tracking(1.4)
                        .foregroundStyle(Color.claySkyDeep)
                    Text("乗車プラン")
                        .dynamicFont(size: 22, relativeTo: .title2, weight: .bold, design: .rounded)
                        .foregroundStyle(Color.neumoText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "square.grid.2x2.fill")
                    .font(.title3)
                    .foregroundStyle(Color.claySkyDeep)
            }

            TripEndpointSelector(viewModel: viewModel)

            DynamicTypeStack(spacing: 9) {
                ClaySearchTypeChip(
                    title: BusTimetableViewModel.SearchType.departure.shortTitle,
                    systemName: "arrow.up.right",
                    isSelected: viewModel.searchType == .departure
                ) {
                    viewModel.searchType = .departure
                }
                ClaySearchTypeChip(
                    title: BusTimetableViewModel.SearchType.arrival.shortTitle,
                    systemName: "flag.checkered",
                    isSelected: viewModel.searchType == .arrival
                ) {
                    viewModel.searchType = .arrival
                }
            }

            Text(viewModel.searchType.explanation)
                .font(.caption)
                .foregroundStyle(Color.neumoMuted)
                .fixedSize(horizontal: false, vertical: true)

            DynamicTypeStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color.clayPurple.opacity(0.13))
                        .frame(width: 48, height: 48)
                    Image(systemName: "clock.fill")
                        .foregroundStyle(Color.clayPurple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.searchType.timeTitle)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.neumoMuted)
                    DatePicker("", selection: $viewModel.searchTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    viewModel.setSearchToCurrentTime()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("現在時刻")
                            .dynamicFont(size: 9, relativeTo: .caption2, weight: .bold)
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.claySkyDeep)
                    .frame(width: 58, height: 48)
                    .background(Capsule().fill(Color.neumoAccentSoft.opacity(0.58)))
                }
                .buttonStyle(SoftPressButtonStyle())
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.96, green: 0.98, blue: 0.995))
            )

            Button(action: locationAction) {
                HStack {
                    Image(systemName: "location.fill")
                    Text("現在地から路線を選ぶ")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.claySkyDeep)
            }
            .buttonStyle(SoftPressButtonStyle())
            .padding(.horizontal, 2)

            Button {
                viewModel.performSearch()
            } label: {
                HStack(spacing: 0) {
                    Text("この条件で検索")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 18)
                    ZStack {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(Color.clayYellow)
                            .frame(width: 58, height: 54)
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(minHeight: 54)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.claySky, .claySkyDeep],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: Color.clayShadow.opacity(0.32), radius: 13, x: 6, y: 9)
            }
            .buttonStyle(SoftPressButtonStyle())
        }
        .padding(19)
        .clayCard(in: RoundedRectangle(cornerRadius: 27, style: .continuous), elevation: 20)
    }
}

struct ClaySearchTypeChip: View {
    let title: String
    let systemName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemName)
                Text(title)
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(isSelected ? Color.claySkyDeep : Color.neumoMuted)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.neumoAccentSoft.opacity(0.75) : Color(red: 0.95, green: 0.97, blue: 0.99))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.claySky.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(SoftPressButtonStyle())
    }
}

struct ClayUpcomingCard: View {
    let buses: [Bus]
    let countdowns: [String: String]
    let scheduledBusIDs: Set<String>
    let reasons: [String: String]
    let action: (Bus) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("UPCOMING")
                        .dynamicFont(size: 9, relativeTo: .caption2, weight: .bold, design: .rounded)
                        .tracking(1.3)
                        .foregroundStyle(Color.claySkyDeep)
                    Text("候補のバス")
                        .dynamicFont(size: 21, relativeTo: .title2, weight: .bold, design: .rounded)
                        .foregroundStyle(Color.neumoText)
                }
                Spacer()
                Text("\(buses.count) RIDES")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.claySkyDeep)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.neumoAccentSoft.opacity(0.65)))
            }
            .padding(18)

            if buses.isEmpty {
                Text("候補のバスがありません")
                    .font(.subheadline)
                    .foregroundStyle(Color.neumoMuted)
                    .padding(.bottom, 20)
            } else {
                ForEach(Array(buses.enumerated()), id: \.element.id) { index, bus in
                    ClayUpcomingRow(
                        bus: bus,
                        countdown: countdowns[bus.id],
                        tint: index.isMultiple(of: 2) ? .clayPurple : .clayMint,
                        isNotificationScheduled: scheduledBusIDs.contains(bus.id),
                        reason: reasons[bus.id]
                    ) {
                        action(bus)
                    }
                    if bus.id != buses.last?.id {
                        Divider().padding(.leading, 74)
                    }
                }
            }
        }
        .clayCard(in: RoundedRectangle(cornerRadius: 27, style: .continuous), elevation: 20)
    }
}

struct ClayUpcomingRow: View {
    let bus: Bus
    let countdown: String?
    let tint: Color
    let isNotificationScheduled: Bool
    let reason: String?
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 13) {
                        icon
                        details
                    }
                    controls.frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(spacing: 13) {
                    icon
                    details
                    Spacer(minLength: 0)
                    controls
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
    }

    private var icon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.16))
                .frame(width: 46, height: 46)
            Image(systemName: "bus.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(bus.departure)
                    .dynamicFont(size: 20, relativeTo: .title3, weight: .bold, design: .rounded)
                    .foregroundStyle(Color.neumoText)
                Image(systemName: "arrow.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.claySkyDeep)
                Text(bus.arrival)
                    .dynamicFont(size: 16, relativeTo: .body, weight: .semibold, design: .rounded)
                    .foregroundStyle(Color.neumoMuted)
            }
            Text(bus.stopSummary)
                .font(.caption2)
                .foregroundStyle(Color.neumoMuted)
                .fixedSize(horizontal: false, vertical: true)
            if let reason {
                Text(reason)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.claySkyDeep)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .trailing, spacing: 5) {
            if let countdown {
                Text(countdown)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.claySkyDeep)
            }
            BusNotificationActionButton(
                isScheduled: isNotificationScheduled,
                action: action
            )
        }
    }
}

struct NextBusCard: View {
    let bus: Bus
    let routeName: String
    let countdown: String?
    let isNotificationScheduled: Bool
    let notifyAction: () -> Void
    @Environment(\.appDesignMode) private var designMode

    private var accentColor: Color {
        designMode.interfaceAccentColor
    }

    private var accentDeepColor: Color {
        designMode == .minimalCute || designMode == .maximalism ? .minimalInk : .neumoAccentDeep
    }

    private var cardColors: [Color] {
        switch designMode {
        case .claymorphic, .minimalCute, .maximalism:
            return [Color.white, Color.white.opacity(0.94)]
        case .neumorphic:
            return [Color.neumoSurfaceTop, Color.neumoSurface, Color.neumoSurfaceBottom]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 19) {
            DynamicTypeStack(verticalAlignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("次のバス")
                        .dynamicFont(
                            size: designMode == .minimalCute || designMode == .maximalism ? 15 : 12,
                            relativeTo: .subheadline,
                            weight: .bold,
                            design: designMode == .minimalCute ? .serif : .rounded
                        )
                        .foregroundStyle(accentColor)
                    Text("NEXT DEPARTURE")
                        .dynamicFont(size: 9, relativeTo: .caption2, weight: .bold, design: .rounded)
                        .tracking(1.5)
                        .foregroundStyle(Color.neumoMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let countdown {
                    Text(countdown)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(designMode == .minimalCute ? Color.white : accentDeepColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(
                                designMode == .minimalCute
                                    ? Color.minimalInk
                                    : (designMode == .maximalism
                                        ? Color.maximalNeon
                                        : Color.neumoAccentSoft.opacity(0.65))
                            )
                        )
                }
            }

            DynamicTypeStack(verticalAlignment: .bottom, spacing: 12) {
                TimePoint(time: bus.departure, label: bus.originName, isPrimary: true)

                VStack(spacing: 6) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(accentColor)
                    Capsule()
                        .fill(accentColor.opacity(0.25))
                        .frame(width: 48, height: 3)
                }
                .padding(.bottom, 20)

                TimePoint(time: bus.arrival, label: bus.destinationName, isPrimary: false)
            }

            DynamicTypeStack(spacing: 8) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.caption)
                    .foregroundStyle(Color.neumoMuted)
                Text(routeName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.neumoMuted)
                    .fixedSize(horizontal: false, vertical: true)
                BusNotificationActionButton(
                    isScheduled: isNotificationScheduled,
                    action: notifyAction
                )
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: cardColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    (designMode == .minimalCute || designMode == .maximalism
                        ? Color.minimalInk
                        : (designMode == .claymorphic ? Color.white : Color.neumoHighlight)
                    ).opacity(designMode == .maximalism ? 1 : (designMode == .minimalCute ? 0.14 : 0.42)),
                    lineWidth: designMode == .maximalism ? 3 : 1
                )
        )
        .shadow(
            color: designMode == .minimalCute || designMode == .maximalism
                ? Color.clear
                : (designMode == .claymorphic ? Color.white : Color.neumoHighlight).opacity(designMode == .claymorphic ? 1.0 : 0.94),
            radius: designMode == .claymorphic ? 18 : 23,
            x: designMode == .claymorphic ? -9 : -12,
            y: designMode == .claymorphic ? -9 : -12
        )
        .shadow(
            color: designMode == .maximalism
                ? Color.maximalInk
                : (designMode == .minimalCute
                    ? Color.minimalInk.opacity(0.12)
                    : (designMode == .claymorphic ? Color.clayShadow : Color.neumoShadow).opacity(designMode == .claymorphic ? 0.30 : 0.64)),
            radius: designMode == .maximalism ? 0 : (designMode == .minimalCute ? 14 : (designMode == .claymorphic ? 24 : 26)),
            x: designMode == .maximalism ? 8 : (designMode == .minimalCute ? 0 : (designMode == .claymorphic ? 10 : 12)),
            y: designMode == .maximalism ? 8 : (designMode == .minimalCute ? 8 : (designMode == .claymorphic ? 13 : 16))
        )
    }
}

struct TimePoint: View {
    let time: String
    let label: String
    let isPrimary: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(time)
                .dynamicFont(
                    size: isPrimary ? 40 : 31,
                    relativeTo: isPrimary ? .largeTitle : .title,
                    weight: .bold,
                    design: .rounded
                )
                .foregroundStyle(isPrimary ? Color.neumoText : Color.neumoMuted)
                .minimumScaleFactor(0.7)
            Text(label)
                .dynamicFont(size: 11, relativeTo: .caption, weight: .medium)
                .foregroundStyle(Color.neumoMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SearchCriteriaBanner: View {
    let criteria: String
    let result: String
    @Environment(\.appDesignMode) private var designMode

    var body: some View {
        DynamicTypeStack(verticalAlignment: .top, spacing: 12) {
            IconBubble(
                systemName: "magnifyingglass.circle.fill",
                tint: designMode.interfaceAccentColor,
                size: 42
            )
            VStack(alignment: .leading, spacing: 5) {
                Text("現在の検索条件")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.neumoMuted)
                Text(criteria)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.neumoText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(result)
                    .font(.caption)
                    .foregroundStyle(Color.neumoMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(15)
        .neumorphicSurface(in: RoundedRectangle(cornerRadius: 20, style: .continuous), depth: 9)
        .accessibilityElement(children: .combine)
    }
}

struct ServiceMessageCard: View {
    let message: String

    var body: some View {
        DynamicTypeStack(spacing: 14) {
            IconBubble(systemName: "calendar.badge.exclamationmark", tint: .neumoWarning, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text("本日の運行")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.neumoText)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.neumoMuted)
            }
        }
        .padding(18)
        .neumorphicSurface(in: RoundedRectangle(cornerRadius: 24, style: .continuous), depth: 12)
    }
}

struct EmptyBusCard: View {
    var body: some View {
        VStack(spacing: 10) {
            IconBubble(systemName: "bus", tint: .neumoMuted, size: 54)
            Text("条件に合うバスがありません")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.neumoText)
            Text("ルートや時刻を変更して再検索してください")
                .font(.caption)
                .foregroundStyle(Color.neumoMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .neumorphicSurface(in: RoundedRectangle(cornerRadius: 24, style: .continuous), depth: 12)
    }
}

struct RouteSelectorCard: View {
    @ObservedObject var viewModel: BusTimetableViewModel
    let locationAction: () -> Void
    @Environment(\.appDesignMode) private var designMode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DynamicTypeStack(spacing: 8) {
                Label("出発地と目的地", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.neumoText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("TRIP")
                    .dynamicFont(size: 9, relativeTo: .caption2, weight: .bold, design: .rounded)
                    .tracking(1.2)
                    .foregroundStyle(Color.neumoMuted)
            }

            TripEndpointSelector(viewModel: viewModel)

            Button(action: locationAction) {
                HStack(spacing: 7) {
                    Image(systemName: "location.fill")
                    Text("現在地を出発地にする")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(designMode.interfaceAccentColor)
            }
            .buttonStyle(SoftPressButtonStyle())
            .padding(.horizontal, 4)
        }
        .padding(18)
        .neumorphicSurface(in: RoundedRectangle(cornerRadius: 24, style: .continuous), depth: 12)
    }
}

struct TripEndpointSelector: View {
    @ObservedObject var viewModel: BusTimetableViewModel
    @Environment(\.appDesignMode) private var designMode

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    endpointMenus
                }
                VStack(spacing: 8) {
                    endpointMenus
                }
            }

            Label(viewModel.selectedRoute.guidance, systemImage: "info.circle.fill")
                .font(.caption)
                .foregroundStyle(Color.neumoMuted)
                .fixedSize(horizontal: false, vertical: true)

            if let message = viewModel.routeAvailabilityMessage {
                Label(message, systemImage: "exclamationmark.circle.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("現在地と現在時刻から、本日利用できる組み合わせだけを表示しています")
                    .font(.caption2)
                    .foregroundStyle(Color.neumoMuted)
            }
        }
    }

    @ViewBuilder
    private var endpointMenus: some View {
        EndpointMenu(
            title: "出発地",
            selected: viewModel.selectedOrigin,
            options: viewModel.availableOrigins,
            action: viewModel.selectOrigin
        )

        Button(action: viewModel.swapEndpoints) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(
                    viewModel.canSwapEndpoints
                        ? (designMode == .minimalCute || designMode == .maximalism ? Color.minimalInk : Color.neumoAccentDeep)
                        : Color.neumoMuted
                )
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(
                        designMode == .minimalCute
                            ? Color.minimalSoft.opacity(0.76)
                            : (designMode == .maximalism
                                ? Color.maximalNeon
                                : Color.neumoAccentSoft.opacity(0.45))
                    )
                )
        }
        .buttonStyle(SoftPressButtonStyle())
        .disabled(!viewModel.canSwapEndpoints)
        .accessibilityLabel("出発地と目的地を入れ替える")

        EndpointMenu(
            title: "目的地",
            selected: viewModel.selectedDestination,
            options: viewModel.availableDestinations,
            action: viewModel.selectDestination
        )
    }
}

struct EndpointMenu: View {
    let title: String
    let selected: BusTimetableViewModel.Stop
    let options: [BusTimetableViewModel.Stop]
    let action: (BusTimetableViewModel.Stop) -> Void
    @Environment(\.appDesignMode) private var designMode

    private var isSelectedStopAvailable: Bool {
        options.contains(selected)
    }

    var body: some View {
        Menu {
            ForEach(options) { stop in
                Button {
                    action(stop)
                } label: {
                    Label(stop.rawValue, systemImage: stop == selected ? "checkmark.circle.fill" : stop.systemName)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.neumoMuted)
                HStack(spacing: 6) {
                    Image(systemName: isSelectedStopAvailable ? selected.systemName : "clock.fill")
                        .foregroundStyle(designMode.interfaceAccentColor)
                    Text(isSelectedStopAvailable ? selected.rawValue : "本日の運行終了")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.neumoText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    Spacer(minLength: 2)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(designMode.interfaceAccentColor)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color.white.opacity(0.66))
            )
        }
        .buttonStyle(SoftPressButtonStyle())
        .disabled(options.isEmpty)
        .accessibilityLabel(
            isSelectedStopAvailable
                ? "\(title)、\(selected.rawValue)"
                : "\(title)、本日の運行終了"
        )
    }
}

struct SearchPanel: View {
    @ObservedObject var viewModel: BusTimetableViewModel
    @Environment(\.appDesignMode) private var designMode

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionHeading(eyebrow: "SEARCH", title: "時刻を検索")

            DynamicTypeStack(spacing: 10) {
                SearchModeButton(
                    title: "出発から探す",
                    systemName: "arrow.up.right",
                    isSelected: viewModel.searchType == .departure
                ) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        viewModel.searchType = .departure
                    }
                }
                SearchModeButton(
                    title: "到着までに探す",
                    systemName: "flag.checkered",
                    isSelected: viewModel.searchType == .arrival
                ) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        viewModel.searchType = .arrival
                    }
                }
            }

            Text(viewModel.searchType.explanation)
                .font(.caption)
                .foregroundStyle(Color.neumoMuted)
                .fixedSize(horizontal: false, vertical: true)

            TimePickerRow(title: viewModel.searchType.timeTitle, date: $viewModel.searchTime) {
                viewModel.setSearchToCurrentTime()
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98)))

            Button {
                withAnimation(.easeOut(duration: 0.22)) {
                    viewModel.performSearch()
                }
            } label: {
                HStack {
                    Text("この条件で検索")
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.bold))
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(designMode == .maximalism ? Color.maximalInk : Color.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: designMode == .minimalCute
                                    ? [Color.minimalInk, Color.black]
                                    : (designMode == .maximalism
                                        ? [Color.maximalNeon, Color.maximalNeon]
                                        : [Color.neumoAccent, Color.neumoAccentDeep]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(
                    color: (designMode == .maximalism
                        ? Color.maximalInk
                        : designMode.interfaceAccentColor).opacity(0.23),
                    radius: 13,
                    x: 5,
                    y: 7
                )
            }
            .buttonStyle(SoftPressButtonStyle())
        }
        .padding(18)
        .neumorphicSurface(in: RoundedRectangle(cornerRadius: 24, style: .continuous), depth: 12)
    }
}

struct SearchModeButton: View {
    let title: String
    let systemName: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.appDesignMode) private var designMode

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemName)
                    .font(.caption.weight(.bold))
                Text(title)
                    .font(.caption.weight(.bold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(
                isSelected
                    ? (designMode == .minimalCute || designMode == .maximalism ? Color.minimalInk : Color.neumoAccentDeep)
                    : Color.neumoMuted
            )
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isSelected
                            ? (designMode == .minimalCute
                                ? Color.minimalSoft.opacity(0.62)
                                : (designMode == .maximalism
                                    ? Color.maximalNeon
                                    : Color.neumoAccentSoft.opacity(0.42)))
                            : Color.clear
                    )
            )
            .neumorphicSurface(
                in: RoundedRectangle(cornerRadius: 14, style: .continuous),
                mode: isSelected ? .concave : .convex,
                shadowRadius: 6,
                offset: 3
            )
        }
        .buttonStyle(SoftPressButtonStyle())
    }
}

struct TimePickerRow: View {
    let title: String
    @Binding var date: Date
    let currentAction: () -> Void
    @Environment(\.appDesignMode) private var designMode

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                timeSelection
                Spacer(minLength: 8)
                currentTimeButton
            }

            VStack(alignment: .leading, spacing: 10) {
                timeSelection
                currentTimeButton
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .neumorphicSurface(in: RoundedRectangle(cornerRadius: 18, style: .continuous), depth: 8)
    }

    private var timeSelection: some View {
        HStack(spacing: 12) {
            IconBubble(
                systemName: "clock.fill",
                tint: designMode.interfaceAccentColor,
                size: 42
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.neumoMuted)
                    .fixedSize(horizontal: false, vertical: true)
                DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .dynamicFont(size: 25, relativeTo: .title2, weight: .bold, design: .rounded)
                    .tint(Color.neumoText)
                    .fixedSize()
            }
        }
    }

    private var currentTimeButton: some View {
        Button(action: currentAction) {
            Label("現在時刻にする", systemImage: "clock.arrow.circlepath")
                .font(.caption.weight(.bold))
                .foregroundStyle(designMode.interfaceAccentColor)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
            }
            .buttonStyle(NeumorphicButtonStyle(cornerRadius: 14, shadowRadius: 6, offset: 3))
            .accessibilityHint("選択中の検索方法を変えずに現在時刻を入力します")
    }
}

struct BusResultRow: View {
    let bus: Bus
    @ObservedObject var viewModel: BusTimetableViewModel
    let isNotificationScheduled: Bool
    let reason: String
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    details
                    controls.frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(spacing: 14) {
                    details
                    Spacer(minLength: 0)
                    controls
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .neumorphicSurface(in: RoundedRectangle(cornerRadius: 20, style: .continuous), depth: 9)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Text("おすすめ")
                    .dynamicFont(size: 10, relativeTo: .caption2, weight: .bold)
                    .foregroundStyle(Color.neumoAccentDeep)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.neumoAccentSoft.opacity(0.78)))
                if let note = bus.note {
                    Text(note)
                        .dynamicFont(size: 10, relativeTo: .caption2, weight: .bold)
                        .foregroundStyle(Color.neumoMuted)
                        .lineLimit(2)
                }
            }
            DynamicTypeStack(verticalAlignment: .lastTextBaseline, spacing: 8) {
                Text(bus.departure)
                    .dynamicFont(size: 29, relativeTo: .title, weight: .bold, design: .rounded)
                    .foregroundStyle(Color.neumoText)
                    .minimumScaleFactor(0.75)
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.neumoAccent)
                Text(bus.arrival)
                    .dynamicFont(size: 23, relativeTo: .title2, weight: .bold, design: .rounded)
                    .foregroundStyle(Color.neumoMuted)
                    .minimumScaleFactor(0.75)
            }
            Text(bus.stopSummary)
                .font(.caption)
                .foregroundStyle(Color.neumoMuted)
                .fixedSize(horizontal: false, vertical: true)
            Text(reason)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.neumoAccentDeep)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var controls: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if let countdown = viewModel.countdownMessages[bus.id] {
                Text(countdown)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(countdown == "出発済み" ? Color.neumoMuted : Color.neumoAccentDeep)
                    .multilineTextAlignment(.trailing)
            }
            BusNotificationActionButton(
                isScheduled: isNotificationScheduled,
                action: action
            )
        }
    }
}

struct BusTimetableRow: View {
    let bus: Bus
    let isRecommended: Bool
    let isNotificationScheduled: Bool
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        recommendationMarker
                        departureAndArrival
                    }
                    Text(bus.stopSummary)
                        .font(.caption2)
                        .foregroundStyle(Color.neumoMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    BusNotificationActionButton(
                        isScheduled: isNotificationScheduled,
                        action: action
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(spacing: 10) {
                    recommendationMarker
                    departureAndNote
                        .frame(width: 76, alignment: .leading)
                    routeLine
                    Text(bus.arrival)
                        .dynamicFont(size: 17, relativeTo: .body, weight: .semibold, design: .rounded)
                        .foregroundStyle(Color.neumoMuted)
                        .frame(width: 52, alignment: .trailing)
                    BusNotificationActionButton(
                        isScheduled: isNotificationScheduled,
                        action: action
                    )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            isRecommended
                ? Color.neumoAccent.opacity(0.055)
                : Color.clear
        )
    }

    @ViewBuilder
    private var recommendationMarker: some View {
        if isRecommended {
            Capsule()
                .fill(Color.neumoAccent)
                .frame(width: 4, height: 28)
                .accessibilityHidden(true)
        }
    }

    private var departureAndNote: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(bus.departure)
                .dynamicFont(size: 19, relativeTo: .title3, weight: .bold, design: .rounded)
                .foregroundStyle(Color.neumoText)
            if let note = bus.note {
                Text(note)
                    .dynamicFont(size: 9, relativeTo: .caption2, weight: .medium)
                    .foregroundStyle(Color.neumoMuted)
                    .lineLimit(2)
            }
        }
    }

    private var departureAndArrival: some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(bus.departure)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.neumoText)
            Image(systemName: "arrow.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.neumoAccent)
            Text(bus.arrival)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.neumoMuted)
            if let note = bus.note {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(Color.neumoMuted)
            }
        }
    }

    private var routeLine: some View {
        HStack(spacing: 6) {
            Circle().fill(Color.neumoAccent.opacity(0.7)).frame(width: 5, height: 5)
            Rectangle().fill(Color.neumoAccent.opacity(0.18)).frame(height: 1)
            Image(systemName: "bus.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.neumoAccent)
            Rectangle().fill(Color.neumoAccent.opacity(0.18)).frame(height: 1)
            Circle().fill(Color.neumoAccent.opacity(0.7)).frame(width: 5, height: 5)
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
