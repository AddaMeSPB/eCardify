import SwiftUI
import CoreImage.CIFilterBuiltins
import DesignSystem
import L10nResources
import ECSharedModels
import ComposableArchitecture

// MARK: - Reducer

@Reducer
public struct CardCreated {
    @ObservableState
    public struct State: Equatable {
        public var walletPass: WalletPass
        public var publicURL: String
        public var linkCopied: Bool = false

        public init(walletPass: WalletPass) {
            self.walletPass = walletPass
            self.publicURL = "https://ecardify.byalif.app/c/\(walletPass.publicSlug ?? walletPass.id)"
        }
    }

    @CasePathable
    public enum Action {
        case addToWallet
        case shareCard
        case copyLink
        case done
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .copyLink:
                UIPasteboard.general.string = state.publicURL
                state.linkCopied = true
                return .none
            case .addToWallet, .shareCard, .done:
                return .none
            }
        }
    }
}

// MARK: - View

public struct CardCreatedView: View {
    @Bindable public var store: StoreOf<CardCreated>
    @State private var animateCheckmark = false
    @State private var animateContent = false

    public init(store: StoreOf<CardCreated>) {
        self.store = store
    }

    private var vCard: VCard { store.walletPass.vCard }

    // MARK: Body

    public var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: ECSpacing.xl) {
                        successHeader
                        cardPreviewSection
                        publicLinkSection
                        qrCodeSection
                        actionButtonsSection
                        footerText
                    }
                    .padding(.horizontal, ECSpacing.md)
                    .padding(.vertical, ECSpacing.xxl)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.send(.done)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                animateCheckmark = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                animateContent = true
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.05, green: 0.05, blue: 0.15),
                Color.black,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Success Header

    private var successHeader: some View {
        VStack(spacing: ECSpacing.sm) {
            ZStack {
                // Outer glow
                Circle()
                    .fill(ECColors.success.opacity(0.15))
                    .frame(width: 100, height: 100)
                    .scaleEffect(animateCheckmark ? 1.0 : 0.3)

                // Inner circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ECColors.success, ECColors.success.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .scaleEffect(animateCheckmark ? 1.0 : 0.1)

                // Checkmark
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .scaleEffect(animateCheckmark ? 1.0 : 0.1)
            }
            .shadow(color: ECColors.success.opacity(0.4), radius: 16, y: 4)

            Text(L("Your card is ready! 🎉"))
                .font(ECTypography.largeTitle())
                .foregroundStyle(.white)

            Text(L("Beautiful work — time to make an unforgettable first impression."))
                .font(ECTypography.subheadline())
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 20)
    }

    // MARK: - Card Preview

    private var cardPreviewSection: some View {
        VStack(spacing: ECSpacing.md) {
            HStack(spacing: ECSpacing.md) {
                avatarView
                cardInfo
                Spacer()
            }
        }
        .padding(ECSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: ECRadius.lg)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: ECRadius.lg)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 30)
    }

    private var avatarView: some View {
        Group {
            if let avatarURL = vCard.imageURLs.first(where: { $0.type == .thumbnail || $0.type == .logo }),
               let url = URL(string: avatarURL.urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        avatarPlaceholder
                    }
                }
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: ECRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ECRadius.md)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }

    private var avatarPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [ECColors.primary, ECColors.primaryDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text(initials)
                .font(ECTypography.headline(.bold))
                .foregroundStyle(.white)
        }
    }

    private var initials: String {
        let first = vCard.contact.firstName.prefix(1)
        let last = vCard.contact.lastName.prefix(1)
        return "\(first)\(last)".uppercased()
    }

    private var cardInfo: some View {
        VStack(alignment: .leading, spacing: ECSpacing.xxs) {
            Text(vCard.contact.fullName)
                .font(ECTypography.headline())
                .foregroundStyle(.white)

            if !vCard.position.isEmpty {
                Text(vCard.position)
                    .font(ECTypography.subheadline())
                    .foregroundStyle(.white.opacity(0.7))
            }

            if let org = vCard.organization, !org.isEmpty {
                Text(org)
                    .font(ECTypography.caption(.medium))
                    .foregroundStyle(ECColors.primary)
            }
        }
    }

    // MARK: - Public Link

    private var publicLinkSection: some View {
        VStack(alignment: .leading, spacing: ECSpacing.xs) {
            ECSectionHeader(L("Public Link"))
                .foregroundStyle(.white)

            HStack(spacing: ECSpacing.xs) {
                Image(systemName: "link")
                    .font(ECTypography.caption())
                    .foregroundStyle(ECColors.primary)

                Text(store.publicURL)
                    .font(ECTypography.caption())
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button {
                    store.send(.copyLink)
                } label: {
                    Text(store.linkCopied ? L("Copied!") : L("Copy"))
                        .font(ECTypography.caption(.semibold))
                        .foregroundStyle(store.linkCopied ? ECColors.success : ECColors.primary)
                }
            }
            .padding(ECSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: ECRadius.sm)
                    .fill(.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: ECRadius.sm)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 30)
    }

    // MARK: - QR Code

    private var qrCodeSection: some View {
        VStack(spacing: ECSpacing.sm) {
            ECSectionHeader(L("QR Code"))
                .foregroundStyle(.white)

            if let qrImage = generateQRCode(from: store.publicURL) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .padding(ECSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: ECRadius.lg)
                            .fill(.white)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: ECRadius.lg))
                    .shadow(color: ECColors.primary.opacity(0.2), radius: 12, y: 4)
            }

            Text(L("Scan to view your card"))
                .font(ECTypography.caption())
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 30)
    }

    // MARK: - Action Buttons

    private var actionButtonsSection: some View {
        VStack(spacing: ECSpacing.sm) {
            // Save to Wallet — primary
            Button {
                store.send(.addToWallet)
            } label: {
                HStack(spacing: ECSpacing.xs) {
                    Image(systemName: "wallet.pass.fill")
                    Text(L("Save to Wallet"))
                }
            }
            .buttonStyle(.ecPrimary)

            HStack(spacing: ECSpacing.sm) {
                // Share
                Button {
                    store.send(.shareCard)
                } label: {
                    HStack(spacing: ECSpacing.xxs) {
                        Image(systemName: "square.and.arrow.up")
                        Text(L("Share"))
                    }
                }
                .buttonStyle(.ecSecondary)

                // Copy Link
                Button {
                    store.send(.copyLink)
                } label: {
                    HStack(spacing: ECSpacing.xxs) {
                        Image(systemName: store.linkCopied ? "checkmark" : "doc.on.doc")
                        Text(store.linkCopied ? L("Copied!") : L("Copy Link"))
                    }
                }
                .buttonStyle(.ecSecondary)
            }
        }
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 30)
    }

    // MARK: - Footer

    private var footerText: some View {
        HStack(spacing: ECSpacing.xxs) {
            Image(systemName: "globe")
                .font(ECTypography.caption())

            Text(L("Your card is live at ecardify.byalif.app"))
                .font(ECTypography.caption())
        }
        .foregroundStyle(.white.opacity(0.4))
        .padding(.top, ECSpacing.sm)
    }

    // MARK: - QR Code Generator

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }

        // Scale up the QR code for crisp rendering
        let scale = 10.0
        let scaledImage = outputImage.transformed(
            by: CGAffineTransform(scaleX: scale, y: scale)
        )

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Preview

#Preview("Card Created") {
    CardCreatedView(
        store: Store(
            initialState: CardCreated.State(walletPass: .mock)
        ) {
            CardCreated()
        }
    )
    .preferredColorScheme(.dark)
}
