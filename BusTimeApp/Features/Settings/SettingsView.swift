import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SettingsViewModel
    let onModeChanged: (AppDesignMode) -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    DynamicTypeStack(spacing: 14) {
                        IconBubble(systemName: "paintpalette.fill", tint: .neumoAccent, size: 52)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("画面の見た目")
                                .dynamicFont(size: 22, relativeTo: .title2, weight: .bold, design: .rounded)
                                .foregroundStyle(Color.neumoText)
                            Text("アプリ全体の見た目を選択できます")
                                .font(.caption)
                                .foregroundStyle(Color.neumoMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .neumorphicSurface(in: RoundedRectangle(cornerRadius: 24, style: .continuous), depth: 12)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("デザインを選ぶ")
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

                    VStack(alignment: .leading, spacing: 12) {
                        Text("バスのお知らせ")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.neumoText)

                        Toggle(
                            isOn: Binding(
                                get: { viewModel.prefersLiveActivity },
                                set: viewModel.setLiveActivityEnabled
                            )
                        ) {
                            VStack(alignment: .leading, spacing: 4) {
                                Label(
                                    "Live Activityを使う",
                                    systemImage: "lock.rectangle.on.rectangle"
                                )
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.neumoText)
                                Text("通常の通知と一緒に、ロック画面やDynamic Islandへ残り時間を表示します。")
                                    .font(.caption2)
                                    .foregroundStyle(Color.neumoMuted)
                            }
                        }
                        .tint(Color.neumoAccent)
                        .disabled(!viewModel.isLiveActivityAvailable)

                        if !viewModel.isLiveActivityAvailable {
                            Label(
                                "この端末では利用できないか、iPhoneの設定でLive Activityがオフになっています。",
                                systemImage: "info.circle"
                            )
                            .font(.caption2)
                            .foregroundStyle(Color.neumoWarning)
                        } else {
                            Text("対応端末では最初からオンです。ここでいつでも変更できます。")
                                .font(.caption2)
                                .foregroundStyle(Color.neumoMuted)
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.76))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

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
            .preferredColorScheme(viewModel.selectedMode.prefersLightColorScheme ? .light : nil)
            .onAppear {
                viewModel.refreshLiveActivityAvailability()
            }
        }
    }
}

struct SettingsDesignOption: View {
    let mode: AppDesignMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            DynamicTypeStack(spacing: 14) {
                SettingsDesignPreview(mode: mode)

                VStack(alignment: .leading, spacing: 5) {
                    Text(mode.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.neumoText)
                    Text(mode.description)
                        .font(.caption2)
                        .foregroundStyle(Color.neumoMuted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

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
        .accessibilityLabel("\(mode.title)\(isSelected ? "、選択中" : "")")
    }
}

struct SettingsDesignPreview: View {
    let mode: AppDesignMode

    var body: some View {
        ZStack {
            switch mode {
            case .neumorphic:
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
            case .claymorphic:
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
            case .minimalCute:
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Color.minimalBackground)
                MinimalOrganicBlob()
                    .fill(Color.minimalSoft)
                    .frame(width: 48, height: 38)
                    .offset(x: -14, y: -10)
                MinimalOrganicBlob()
                    .fill(Color.minimalInk)
                    .frame(width: 34, height: 28)
                    .rotationEffect(.degrees(16))
                    .offset(x: 20, y: 4)
                MinimalDotPattern()
                    .frame(width: 26, height: 24)
                    .offset(x: -8, y: 18)
                Circle()
                    .fill(Color.minimalBlush)
                    .frame(width: 10, height: 10)
                    .offset(x: 22, y: -20)
            case .maximalism:
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Color.maximalNeon)
                MaximalStripePattern()
                    .frame(width: 66, height: 66)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                Circle()
                    .stroke(Color.maximalInk, lineWidth: 9)
                    .frame(width: 48, height: 48)
                    .offset(x: -19, y: -14)
                Rectangle()
                    .fill(Color.maximalInk)
                    .frame(width: 38, height: 22)
                    .offset(x: 21, y: 17)
            }
        }
        .frame(width: 66, height: 66)
    }
}
