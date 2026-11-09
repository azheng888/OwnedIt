import SwiftUI

/// Onboarding styled like modern App Store screenshots: a bold editorial headline
/// (one accented phrase) above a live, miniature mock of the real UI.
struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var page = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pages: [Page] = [
        Page(lead: "Everything you own,", accent: "accounted for.",
             body: "Photos, serial numbers, receipts and value — one calm, private ledger.", mock: .value),
        Page(lead: "Snap it. Scan it.", accent: "Done.",
             body: "Take photos, scan barcodes to fill details, and scan paper receipts straight to PDF.", mock: .capture),
        Page(lead: "Ready for the day", accent: "it counts.",
             body: "See what's missing for an insurance claim, then export a polished report in one tap.", mock: .readiness),
        Page(lead: "Stay ahead of", accent: "upkeep.",
             body: "Recurring maintenance reminders and warranty alerts before they expire.", mock: .reminders),
    ]

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip", action: onComplete)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.secondaryText)
                    .opacity(isLast ? 0 : 1)
                    .animation(Motion.snappy, value: isLast)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    PageView(page: pages[index], isCurrent: page == index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            PageDots(count: pages.count, current: page)
                .padding(.bottom, 20)

            Button {
                if isLast {
                    onComplete()
                } else {
                    withAnimation(reduceMotion ? nil : Motion.enter) { page += 1 }
                }
            } label: {
                Text(isLast ? "Get Started" : "Continue")
                    .contentTransition(.opacity)
            }
            .buttonStyle(.primary)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .sensoryFeedback(.selection, trigger: page)
        }
        .themedScreen()
    }

    struct Page {
        enum Mock { case value, capture, readiness, reminders }
        let lead: String
        let accent: String
        let body: String
        let mock: Mock
    }
}

// MARK: - Page

private struct PageView: View {
    let page: OnboardingView.Page
    let isCurrent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                (Text(page.lead + "\n") + Text(page.accent).foregroundColor(Theme.secondaryText))
                    .font(.system(size: 38, design: .serif))
                    .tracking(-0.5)
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(page.body)
                    .font(.body)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer(minLength: 24)

            Group {
                switch page.mock {
                case .value: ValueMock(active: isCurrent)
                case .capture: CaptureMock(active: isCurrent)
                case .readiness: ReadinessMock(active: isCurrent)
                case .reminders: RemindersMock(active: isCurrent)
                }
            }
            .padding(.horizontal, 24)
            .accessibilityHidden(true)

            Spacer(minLength: 24)
        }
    }
}

/// Stagger children in when their page becomes current; reset when it leaves so it replays.
private struct Stagger: ViewModifier {
    let active: Bool
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 12)
            .scaleEffect(shown || reduceMotion ? 1 : 0.97)
            .onChange(of: active, initial: true) { _, isActive in
                if isActive {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.2) : Motion.enter.delay(0.08 + Double(index) * 0.06)) {
                        shown = true
                    }
                } else {
                    shown = false
                }
            }
    }
}

private extension View {
    func stagger(_ active: Bool, _ index: Int) -> some View { modifier(Stagger(active: active, index: index)) }
}

// MARK: - Mocks

private struct MockRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let trailing: String
    var tint: Color = Theme.secondaryText

    var body: some View {
        HStack(spacing: 12) {
            IconTile(systemName: icon, color: tint, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium))
                Text(subtitle).font(.caption).foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            Text(trailing).font(.subheadline.weight(.semibold)).monospacedDigit()
        }
        .card(padding: 12)
    }
}

private struct ValueMock: View {
    let active: Bool
    @State private var value: Double = 0

    var body: some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total value").font(.subheadline).foregroundStyle(Theme.secondaryText)
                Text(value, format: AppFormat.wholeCurrency)
                    .font(.hero(40))
                    .contentTransition(.numericText(value: value))
                Text("48 items · 6 rooms").font(.subheadline).foregroundStyle(Theme.secondaryText)
            }
            .card(padding: 20)
            .stagger(active, 0)

            MockRow(icon: "tv", title: "OLED Television", subtitle: "Electronics · Living Room", trailing: "$1,899").stagger(active, 1)
            MockRow(icon: "sofa", title: "Linen Sofa", subtitle: "Furniture · Living Room", trailing: "$2,450").stagger(active, 2)
            MockRow(icon: "sparkles", title: "Engagement Ring", subtitle: "Jewelry · Bedroom", trailing: "$6,200").stagger(active, 3)
        }
        .onChange(of: active, initial: true) { _, isActive in
            if isActive {
                value = 0
                withAnimation(.easeOut(duration: 0.9).delay(0.2)) { value = 24_380 }
            }
        }
    }
}

private struct CaptureMock: View {
    let active: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                tile(icon: "camera.fill", title: "Photos").stagger(active, 0)
                tile(icon: "barcode.viewfinder", title: "Barcode").stagger(active, 1)
                tile(icon: "doc.viewfinder", title: "Receipt").stagger(active, 2)
            }
            MockRow(icon: "laptopcomputer", title: "MacBook Pro 14\"", subtitle: "Serial C02XK1…", trailing: "$2,399").stagger(active, 3)
            MockRow(icon: "doc.richtext.fill", title: "Apple Store Receipt.pdf", subtitle: "Scanned · 1 page", trailing: "", tint: Theme.warning).stagger(active, 4)
        }
    }

    private func tile(icon: String, title: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(Theme.secondaryText)
            Text(title).font(.caption.weight(.medium))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 96)
        .card(padding: 0)
    }
}

private struct ReadinessMock: View {
    let active: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                ProgressRing(progress: active ? 0.92 : 0, color: Theme.ink)
                    .frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Claim readiness").font(.subheadline).foregroundStyle(Theme.secondaryText)
                    Text("Well documented").font(.body.weight(.medium))
                }
                Spacer()
            }
            .card(padding: 18)
            .stagger(active, 0)

            MockRow(icon: "camera", title: "Missing photos", subtitle: "Tap to fix", trailing: "2", tint: Theme.warning).stagger(active, 1)
            MockRow(icon: "doc.richtext", title: "Inventory Report.pdf", subtitle: "Ready to share", trailing: "", tint: Theme.secondaryText).stagger(active, 2)
        }
    }
}

private struct RemindersMock: View {
    let active: Bool

    var body: some View {
        VStack(spacing: 10) {
            MockRow(icon: "wind", title: "Replace air filter", subtitle: "Furnace · Due today", trailing: "", tint: Theme.warning).stagger(active, 0)
            MockRow(icon: "flame", title: "Descale espresso machine", subtitle: "Due in 5 days · Monthly", trailing: "", tint: Theme.warning).stagger(active, 1)
            MockRow(icon: "checkmark.shield", title: "Warranty ending", subtitle: "Dishwasher · Mar 14", trailing: "", tint: Theme.warning).stagger(active, 2)
            MockRow(icon: "smoke", title: "Test smoke detectors", subtitle: "Every 6 months", trailing: "", tint: Theme.secondaryText).stagger(active, 3)
        }
    }
}

// MARK: - Page dots

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Theme.ink : Theme.hairline)
                    .frame(width: index == current ? 22 : 7, height: 7)
            }
        }
        .animation(Motion.snappy, value: current)
        .accessibilityElement()
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}
