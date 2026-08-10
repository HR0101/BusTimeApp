import SwiftUI

struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDesignMode) private var designMode
    @StateObject private var viewModel = TutorialViewModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("WELCOME")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
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
        .preferredColorScheme(designMode == .claymorphic ? .light : nil)
    }
}

struct TutorialPage: View {
    let title: String
    let description: String
    let systemName: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.neumoAccent.opacity(0.11))
                    .frame(width: 170, height: 170)
                IconBubble(systemName: systemName, tint: .neumoAccent, size: 88)
            }
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.neumoText)
                .multilineTextAlignment(.center)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(Color.neumoMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
