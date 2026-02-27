import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "house.fill",
            iconColor: .blue,
            title: "Welcome to OwnedIt",
            description: "Your home inventory, organized. Track everything you own in one place."
        ),
        OnboardingPage(
            icon: "archivebox.fill",
            iconColor: .orange,
            title: "Catalog Everything",
            description: "Add items with photos, serial numbers, purchase info, and condition. Perfect for insurance claims."
        ),
        OnboardingPage(
            icon: "map.fill",
            iconColor: .green,
            title: "Organize by Room",
            description: "Group your belongings by room for a clear picture of what you own and where."
        ),
        OnboardingPage(
            icon: "shield.checkmark.fill",
            iconColor: .purple,
            title: "Protect What Matters",
            description: "Store receipts, track warranties, and export your inventory — so you're ready when it counts."
        )
    ]

    private var isLastPage: Bool { currentPage == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip", action: onComplete)
                    .foregroundStyle(.secondary)
                    .padding()
            }

            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    VStack(spacing: 24) {
                        Spacer()
                        Image(systemName: page.icon)
                            .font(.system(size: 80))
                            .foregroundStyle(page.iconColor)
                            .padding(.bottom, 8)

                        Text(page.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        Text(page.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut, value: currentPage)

            Button {
                if isLastPage {
                    onComplete()
                } else {
                    withAnimation { currentPage += 1 }
                }
            } label: {
                Text(isLastPage ? "Get Started" : "Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
            }
            .padding(.bottom, 32)
        }
    }
}

private struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
}
