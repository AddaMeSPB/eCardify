import SwiftUI
import L10nResources

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < 2 {
                        Button(action: { hasSeenOnboarding = true }) {
                            Text(L("Skip"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                }

                TabView(selection: $currentPage) {
                    OnboardingPageView(
                        icon: "creditcard.fill",
                        iconColor: .blue,
                        title: L("Create stunning digital business cards"),
                        description: L("Design your professional identity with custom templates, colors, and layouts.")
                    )
                    .tag(0)

                    OnboardingPageView(
                        icon: "wallet.pass.fill",
                        iconColor: .orange,
                        title: L("Apple Wallet Ready"),
                        description: L("Add your card directly to Apple Wallet for instant access anywhere, anytime.")
                    )
                    .tag(1)

                    OnboardingPageView(
                        icon: "qrcode",
                        iconColor: .green,
                        title: L("Share Instantly"),
                        description: L("Share via QR code or link. Recipients don't need the app to view your card.")
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                // Bottom button
                if currentPage == 2 {
                    Button(action: { hasSeenOnboarding = true }) {
                        Text(L("Get Started"))
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                } else {
                    Button(action: { withAnimation { currentPage += 1 } }) {
                        Text("Next")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

struct OnboardingPageView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .foregroundStyle(iconColor)
                .padding(.bottom, 20)

            Text(title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }
}
