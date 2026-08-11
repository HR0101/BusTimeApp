import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SettingsViewModel
    let onModeChanged: (AppDesignMode) -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    HStack(spacing: 14) {
                        IconBubble(systemName: "paintpalette.fill", tint: .neumoAccent, size: 52)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("画面デザイン")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.neumoText)
                            Text("アプリ全体の見た目を選択できます")
                                .font(.caption)
                                .foregroundStyle(Color.neumoMuted)
                        }
                        Spacer()
                    }
                    .padding(18)
                    .neumorphicSurface(in: RoundedRectangle(cornerRadius: 24, style: .continuous), depth: 12)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("外観")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.neumoText)

                        ForEach(AppDesignMode.allCases) { mode in
                            SettingsDesignOption(
                                mode: mode,
                                isSelected: viewModel.selectedMode == mode
                            ) {
                                withAnimation(.easeInOut(duration: 0.28)) {
                                    viewModel.select(mode)
                                    onModeChanged(mode)
                                }
                            }
                        }
                    }

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.icloud.fill")
                            .foregroundStyle(Color.neumoAccent)
                        Text("選択したデザインは自動的に保存され、次回起動時にも引き継がれます。")
                            .font(.caption)
                            .foregroundStyle(Color.neumoMuted)
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(NeumorphicBackground())
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") { dismiss() }
                        .fontWeight(.bold)
                        .foregroundStyle(Color.neumoAccentDeep)
                }
            }
            .preferredColorScheme(viewModel.selectedMode == .claymorphic ? .light : nil)
        }
    }
}

struct SettingsDesignOption: View {
    let mode: AppDesignMode
    let isSelected: Bool
    let action: () -> Void

    private var title: String {
        mode == .neumorphic ? "ネオモーフィズム" : "クレイモーフィズム"
    }

    private var description: String {
        mode == .neumorphic
            ? "光と影のコントラストで奥行きを表現"
            : "青い背景と白いカードを重ねた立体表現"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                SettingsDesignPreview(mode: mode)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.neumoText)
                    Text(description)
                        .font(.caption2)
                        .foregroundStyle(Color.neumoMuted)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }

                Spacer(minLength: 4)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isSelected ? Color.neumoAccent : Color.neumoMuted.opacity(0.45))
            }
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? Color.neumoAccent.opacity(0.48) : Color.white.opacity(0.65), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: Color.white.opacity(0.9), radius: 9, x: -5, y: -5)
            .shadow(color: Color.neumoShadow.opacity(0.18), radius: 12, x: 6, y: 8)
        }
        .buttonStyle(SoftPressButtonStyle())
        .accessibilityLabel("\(title)\(isSelected ? "、選択中" : "")")
    }
}

struct SettingsDesignPreview: View {
    let mode: AppDesignMode

    var body: some View {
        ZStack {
            if mode == .neumorphic {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Color.neumoBackground)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.neumoSurface)
                    .frame(width: 38, height: 24)
                    .shadow(color: .white, radius: 4, x: -3, y: -3)
                    .shadow(color: Color.neumoShadow.opacity(0.3), radius: 5, x: 3, y: 4)
                Circle()
                    .fill(Color.neumoAccent)
                    .frame(width: 12, height: 12)
                    .offset(x: 19, y: -18)
            } else {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.claySky, .claySkyDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 40, height: 28)
                    .shadow(color: Color.clayShadow.opacity(0.38), radius: 5, x: 3, y: 4)
                Circle()
                    .fill(Color.clayYellow)
                    .frame(width: 13, height: 13)
                    .offset(x: 20, y: -18)
            }
        }
        .frame(width: 66, height: 66)
    }
}
