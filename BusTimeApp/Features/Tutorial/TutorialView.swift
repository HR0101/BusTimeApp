import SwiftUI

struct TutorialView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.sky) private var sky
  @StateObject private var viewModel = TutorialViewModel()
  let onComplete: () -> Void

  init(onComplete: @escaping () -> Void = {}) {
    self.onComplete = onComplete
  }

  var body: some View {
    VStack(spacing: 0) {
      header

      TabView(selection: $viewModel.currentPage) {
        ForEach(viewModel.pages) { page in
          TutorialPage(
            title: page.title,
            description: page.description,
            systemName: page.systemName
          )
          .tag(page.id)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .always))

      advanceButton
    }
    .background(SkyBackground())
  }

  private var header: some View {
    HStack {
      SkySectionLabel(text: L10n.Tutorial.section)
      Spacer()
      SkyIconButton(
        systemImage: "xmark",
        accessibilityLabel: L10n.Tutorial.closeAccessibility
      ) {
        dismiss()
      }
    }
    .padding(.horizontal, SkyMetrics.screenPadding)
    .padding(.top, 18)
  }

  private var advanceButton: some View {
    Button {
      if viewModel.isLastPage {
        onComplete()
        dismiss()
      } else {
        viewModel.nextPage()
      }
    } label: {
      HStack {
        Text(viewModel.isLastPage ? L10n.Tutorial.start : L10n.Tutorial.next)
        Spacer()
        Image(systemName: viewModel.isLastPage ? "checkmark" : "arrow.right")
      }
      .dynamicFont(size: 15, relativeTo: .subheadline, weight: .bold, design: .rounded)
      .foregroundStyle(sky.accentInk)
      .padding(.horizontal, 20)
      .frame(maxWidth: .infinity, minHeight: 52)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(sky.accent)
      )
    }
    .buttonStyle(SkyPressStyle())
    .padding(.horizontal, SkyMetrics.screenPadding)
    .padding(.bottom, 22)
  }
}

struct TutorialPage: View {
  @Environment(\.sky) private var sky
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  let title: String
  let description: String
  let systemName: String

  /// アイコンの基準サイズです。
  private var iconSize: CGFloat {
    dynamicTypeSize.isAccessibilitySize ? 48 : 64
  }

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 18 : 24) {
        Spacer(minLength: dynamicTypeSize.isAccessibilitySize ? 12 : 48)

        Image(systemName: systemName)
          .dynamicFont(size: iconSize, relativeTo: .largeTitle, weight: .light)
          .foregroundStyle(sky.accentReadable)

        Text(title)
          .dynamicFont(size: 26, relativeTo: .title, weight: .bold, design: .rounded)
          .foregroundStyle(sky.ink)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)

        Text(description)
          .dynamicFont(size: 14, relativeTo: .subheadline, weight: .medium)
          .foregroundStyle(sky.inkSecondary)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)

        Spacer(minLength: 24)
      }
      .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 20 : 32)
      .frame(maxWidth: .infinity)
    }
  }
}
