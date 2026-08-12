import SwiftUI

struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDesignMode) private var designMode
    @StateObject private var viewModel = TutorialViewModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("WELCOME")
                    .dynamicFont(size: 11, relativeTo: .caption, weight: .bold, design: .rounded)
                    .tracking(2)
                    .foregroundStyle(Color.neumoAccent)
                Spacer()
                Button { dismiss() } label: {
                    IconBubble(systemName: "xmark", tint: .neumoMuted, size: 38)
                }
                .buttonStyle(SoftPressButtonStyle())
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)

            TabView(selection: $viewModel.currentPage) {
                ForEach(viewModel.pages) { page in
                    TutorialPage(title: page.title, description: page.description, systemName: page.systemName)
                        .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button {
                if viewModel.isLastPage {
                    dismiss()
                } else {
                    viewModel.nextPage()
                }
            } label: {
                HStack {
                    Text(viewModel.isLastPage ? "はじめる" : "次へ")
                    Spacer()
                    Image(systemName: viewModel.isLastPage ? "checkmark" : "arrow.right")
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [.neumoAccent, .neumoAccentDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
                )
                .shadow(color: Color.neumoAccent.opacity(0.23), radius: 12, x: 5, y: 7)
            }
            .buttonStyle(SoftPressButtonStyle())
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
        }
        .background(NeumorphicBackground())
        .preferredColorScheme(designMode.prefersLightColorScheme ? .light : nil)
    }
}

struct TutorialPage: View {
    let title: String
    let description: String
    let systemName: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 18 : 24) {
                Spacer(minLength: dynamicTypeSize.isAccessibilitySize ? 12 : 52)
                ZStack {
                    Circle()
                        .fill(Color.neumoAccent.opacity(0.11))
                        .frame(
                            width: dynamicTypeSize.isAccessibilitySize ? 120 : 170,
                            height: dynamicTypeSize.isAccessibilitySize ? 120 : 170
                        )
                    IconBubble(
                        systemName: systemName,
                        tint: .neumoAccent,
                        size: dynamicTypeSize.isAccessibilitySize ? 68 : 88
                    )
                }
                Text(title)
                    .dynamicFont(size: 28, relativeTo: .title, weight: .bold, design: .rounded)
                    .foregroundStyle(Color.neumoText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(Color.neumoMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 24)
            }
            .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 20 : 34)
            .frame(maxWidth: .infinity)
        }
    }
}
