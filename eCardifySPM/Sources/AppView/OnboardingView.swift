import SwiftUI
import DesignSystem
import L10nResources

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    private let pages: [(icon: String, gradient: [Color], title: String, subtitle: String)] = [
        (
            "creditcard.and.123",
            [Color(red: 0.14, green: 0.48, blue: 0.57), Color(red: 0.22, green: 0.58, blue: 0.67)],
            "Create stunning digital business cards",
            "Design your professional identity with custom templates, colors, and layouts."
        ),
        (
            "wallet.pass.fill",
            [Color(red: 0.82, green: 0.47, blue: 0.25), Color(red: 0.90, green: 0.56, blue: 0.35)],
            "Apple Wallet Ready",
            "Add your card directly to Apple Wallet for instant access anywhere, anytime."
        ),
        (
            "qrcode.viewfinder",
            [Color(red: 0.22, green: 0.56, blue: 0.42), Color(red: 0.36, green: 0.69, blue: 0.56)],
            "Share Instantly",
            "Share via QR code, NFC, or link. Recipients don't need the app to view your card."
        )
    ]

    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: pages[currentPage].gradient.map { $0.opacity(0.15) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentPage)

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button {
                            hasSeenOnboarding = true
                        } label: {
                            Text(L("Skip"))
                                .font(ECTypography.subheadline(.medium))
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                        .padding(.trailing, ECSpacing.lg)
                        .padding(.top, ECSpacing.xs)
                    }
                }
                .frame(height: 44)

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(
                            icon: page.icon,
                            gradientColors: page.gradient,
                            title: L(String.LocalizationValue(stringLiteral: page.title)),
                            description: L(String.LocalizationValue(stringLiteral: page.subtitle))
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentPage)

                // Custom page indicator
                HStack(spacing: ECSpacing.xs) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? ECColors.primary : ECColors.primary.opacity(0.25))
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, ECSpacing.xl)

                // Action button
                Button {
                    if currentPage == pages.count - 1 {
                        withAnimation { hasSeenOnboarding = true }
                    } else {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            currentPage += 1
                        }
                    }
                } label: {
                    Text(currentPage == pages.count - 1 ? L("Get Started") : L("Next"))
                }
                .buttonStyle(.ecPrimary)
                .padding(.horizontal, ECSpacing.xxl)
                .padding(.bottom, ECSpacing.xxxl)
                .sensoryFeedback(.impact(flexibility: .soft), trigger: currentPage)
            }
        }
    }
}

// MARK: - Page View

private struct OnboardingPageView: View {
    let icon: String
    let gradientColors: [Color]
    let title: String
    let description: String

    // When animations are disabled (e.g. during snapshot tests),
    // start fully visible so the capture isn't blank.
    @State private var isAppeared = !UIView.areAnimationsEnabled

    var body: some View {
        VStack(spacing: ECSpacing.xl) {
            Spacer()

            // Icon with gradient circle background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                    .shadow(color: gradientColors[0].opacity(0.3), radius: 20, y: 8)

                Image(systemName: icon)
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating.speed(0.5), isActive: isAppeared)
            }
            .scaleEffect(isAppeared ? 1.0 : 0.8)
            .opacity(isAppeared ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: isAppeared)
            .padding(.bottom, ECSpacing.md)

            // Title
            Text(title)
                .font(ECTypography.sectionTitle(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(ECColors.textPrimary)
                .padding(.horizontal, ECSpacing.xl)
                .offset(y: isAppeared ? 0 : 20)
                .opacity(isAppeared ? 1.0 : 0.0)
                .animation(.spring(response: 0.5).delay(0.2), value: isAppeared)

            // Description
            Text(description)
                .font(ECTypography.body())
                .foregroundStyle(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, ECSpacing.xxl)
                .offset(y: isAppeared ? 0 : 20)
                .opacity(isAppeared ? 1.0 : 0.0)
                .animation(.spring(response: 0.5).delay(0.3), value: isAppeared)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear { isAppeared = true }
        .onDisappear { isAppeared = false }
    }
}
