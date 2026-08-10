content = File.read("BusTimeApp/ContentView.swift")

# Add LiquidGlassButtonStyle
glass_style = <<~SWIFT
struct LiquidGlassButtonStyle: ButtonStyle {
    var tintColor: Color = .columbusBlue
    var isDestructive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.columbusGlassBg.opacity(configuration.isPressed ? 0.5 : 0.8))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                    )
                    .shadow(color: isDestructive ? Color.red.opacity(0.15) : tintColor.opacity(0.15), radius: 8, x: 0, y: 4)
            )
            .foregroundColor(isDestructive ? .red : tintColor)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

SWIFT

content.sub!("struct ContentView: View {", glass_style + "struct ContentView: View {")

# Update "現在時刻で検索" button
content.sub!(/Button\(action: \{ viewModel.setSearchToCurrentTime\(\) \}\) \{.*?.foregroundColor\(\.columbusBlue\)\n                        \}/m, <<~SWIFT)
                    }
                } header: {
                    Text("検索条件")
                }
                
                if viewModel.searchType == .departure {
                    Section {
                        Button(action: { viewModel.setSearchToCurrentTime() }) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("現在時刻で検索")
                                    .fontWeight(.bold)
                                Spacer()
                            }
                        }
                        .buttonStyle(LiquidGlassButtonStyle())
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
SWIFT

# Update "この条件で検索" button
content.sub!(/Button\(action: \{ viewModel.performSearch\(\) \}\) \{.*?.listRowInsets\(EdgeInsets\(\)\)/m, <<~SWIFT)
Button(action: { viewModel.performSearch() }) {
                        Text("この条件で検索")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .font(.title3.bold())
                    }
                    .buttonStyle(LiquidGlassButtonStyle())
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
SWIFT

# Update "Live Activityを終了" button
content.sub!(/Button\(action: \{.*?viewModel.endLiveActivity\(\).*?\}\) \{.*?\.listRowInsets\(EdgeInsets\(top: 0, leading: 16, bottom: 12, trailing: 16\)\)/m, <<~SWIFT)
Button(action: {
                            viewModel.endLiveActivity()
                        }) {
                            HStack {
                                Image(systemName: "stop.circle.fill")
                                Text("実行中のLive Activityを終了")
                                    .fontWeight(.bold)
                                Spacer()
                            }
                        }
                        .buttonStyle(LiquidGlassButtonStyle(isDestructive: true))
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
SWIFT

# Update BusResultRow backgrounds to be wider by removing inner horizontal padding and using listRowInsets
content.sub!(/\.padding\(\.horizontal, 16\)\n        \.background\(\n            RoundedRectangle\(cornerRadius: 16\)\n                \.fill\(Color\.columbusGlassBg\.opacity\(0\.7\)\)\n                \.background\(\.ultraThinMaterial, in: RoundedRectangle\(cornerRadius: 16\)\)\n                \.shadow\(color: Color\.columbusBlue\.opacity\(0\.1\), radius: 8, x: 0, y: 4\)\n        \)\n        \.listRowBackground\(Color\.clear\)\n        \.listRowInsets\(EdgeInsets\(top: 4, leading: 16, bottom: 4, trailing: 16\)\)/m, <<~SWIFT)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.columbusGlassBg.opacity(0.8))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                )
                .shadow(color: Color.columbusBlue.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4))
SWIFT

content.sub!(/\.padding\(\.horizontal, 16\)\n        \.background\(\n            RoundedRectangle\(cornerRadius: 12\)\n                \.fill\(Color\.columbusGlassBg\.opacity\(0\.4\)\)\n                \.background\(\.ultraThinMaterial, in: RoundedRectangle\(cornerRadius: 12\)\)\n        \)\n        \.listRowBackground\(Color\.clear\)\n        \.listRowInsets\(EdgeInsets\(top: 4, leading: 16, bottom: 4, trailing: 16\)\)/m, <<~SWIFT)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.columbusGlassBg.opacity(0.5))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                )
        )
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
SWIFT

# Set List to .plain to avoid insetGrouped margins entirely
content.sub!("List {", "List {\n")
content.sub!(/\.scrollContentBackground\(\.hidden\)/, ".listStyle(.plain)\n            .scrollContentBackground(.hidden)")


File.write("BusTimeApp/ContentView.swift", content)
