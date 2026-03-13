import CoreNFC
import PassKit
import SwiftUI
import Foundation
import DesignSystem
import L10nResources
import ECSharedModels
import SwiftUIExtension
import ComposableArchitecture

@Reducer
public struct WalletPassDetails {

    @ObservableState
    public struct State: Equatable, Identifiable {
        public var id: String { wp.id }
        public var wp: WalletPass
        public var vCard: VCard
        public var qrCodeImage: Image? = nil
        public var isNFCAvailable: Bool = false
        public var nfcWriteStatus: NFCWriteStatus = .idle

        public enum NFCWriteStatus: Equatable {
            case idle
            case writing
            case success
            case failed(String)
        }
    }

    @CasePathable
    public enum Action: Equatable {
        case onAppear
        case addPassToWallet
        case qrCode(Image)
        case viewCardButtonTapped
        case writeNFCVCard
        case writeNFCURL
        case nfcWriteResult(Result<Bool, NFCWriteError>)
        case dismissNFCStatus
    }

    public struct NFCWriteError: Error, Equatable {
        public let message: String
        public init(_ error: Error) {
            self.message = error.localizedDescription
        }
    }

    @Dependency(\.nfcCardShareClient) var nfcClient
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce(self.core)
    }

    func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            state.isNFCAvailable = nfcClient.isAvailable()

            // Skip QR generation if already cached
            guard state.qrCodeImage == nil else { return .none }

            let vCardRepresentation = state.vCard.vCardRepresentation

            return .run { [vCardRepresentation] send in
                if let image = Self.generateQRCode(from: vCardRepresentation) {
                    let swiftuiImage = Image(uiImage: image)
                    await send(.qrCode(swiftuiImage))
                }
            }

        case .qrCode(let image):
            state.qrCodeImage = image
            return .none

        case .addPassToWallet:
            return .none

        case .viewCardButtonTapped:
            return .none

        case .writeNFCVCard:
            state.nfcWriteStatus = .writing
            let vCardString = state.vCard.vCardRepresentation
            return .run { send in
                do {
                    try await nfcClient.writeVCard(vCardString)
                    await send(.nfcWriteResult(.success(true)))
                } catch {
                    await send(.nfcWriteResult(.failure(NFCWriteError(error))))
                }
            }

        case .writeNFCURL:
            state.nfcWriteStatus = .writing
            return .run { send in
                do {
                    guard let url = URL(string: "https://apps.apple.com/app/ecardify/id6452084315") else { return }
                    try await nfcClient.writeURL(url)
                    await send(.nfcWriteResult(.success(true)))
                } catch {
                    await send(.nfcWriteResult(.failure(NFCWriteError(error))))
                }
            }

        case .nfcWriteResult(.success):
            state.nfcWriteStatus = .success
            return .run { send in
                try await clock.sleep(for: .seconds(2))
                await send(.dismissNFCStatus)
            }

        case .nfcWriteResult(.failure(let error)):
            if error.message.contains("cancelled") {
                state.nfcWriteStatus = .idle
            } else {
                state.nfcWriteStatus = .failed(error.message)
            }
            return .none

        case .dismissNFCStatus:
            state.nfcWriteStatus = .idle
            return .none
        }
    }

    /// Shared CIContext — creating one per call is expensive.
    private static let ciContext = CIContext()

    private static func generateQRCode(from string: String) -> UIImage? {
        let data = string.data(using: .utf8)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let outputImage = filter.outputImage else { return nil }

        let transformedImage = outputImage.transformed(
            by: CGAffineTransform(scaleX: 10, y: 10)
        )
        guard let cgImage = ciContext.createCGImage(
            transformedImage,
            from: transformedImage.extent
        ) else { return nil }

        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Card Details View

public struct WalletPassDetailsView: View {

    @State private var isShareViewPresented = false
    @Bindable public var store: StoreOf<WalletPassDetails>

    public init(store: StoreOf<WalletPassDetails>) {
        self.store = store
    }

    public var body: some View {
        cardContent
            .contentShape(Rectangle())
            .onTapGesture {
                store.send(.viewCardButtonTapped)
            }
            .contextMenu {
                contextMenuItems
            }
            .onAppear {
                store.send(.onAppear)
            }
            .sheet(isPresented: $isShareViewPresented) {
                ActivityView(
                    activityItems: [
                        URL(string: "https://apps.apple.com/pt/app/ecardify/id6452084315?l=en-GB")!
                    ]
                )
                .ignoresSafeArea()
            }
            .overlay {
                nfcStatusOverlay
            }
    }

    // MARK: - Avatar Color Palette

    /// Deterministic color from name — each card gets a unique accent
    private var avatarGradient: [Color] {
        let palette: [[Color]] = [
            [Color(red: 0.14, green: 0.48, blue: 0.57), Color(red: 0.22, green: 0.58, blue: 0.67)], // teal
            [Color(red: 0.55, green: 0.27, blue: 0.68), Color(red: 0.65, green: 0.38, blue: 0.76)], // purple
            [Color(red: 0.82, green: 0.47, blue: 0.25), Color(red: 0.90, green: 0.56, blue: 0.35)], // amber
            [Color(red: 0.22, green: 0.56, blue: 0.42), Color(red: 0.36, green: 0.69, blue: 0.56)], // green
            [Color(red: 0.20, green: 0.40, blue: 0.70), Color(red: 0.30, green: 0.52, blue: 0.80)], // blue
            [Color(red: 0.75, green: 0.32, blue: 0.32), Color(red: 0.85, green: 0.42, blue: 0.42)], // rose
        ]
        let hash = abs(store.vCard.contact.fullName.hashValue)
        return palette[hash % palette.count]
    }

    private var initials: String {
        let name = store.vCard.contact.fullName
        guard !name.isEmpty else { return "?" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    // MARK: - Card Content

    private var cardContent: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: avatarGradient,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4)
                .padding(.vertical, ECSpacing.sm)

            HStack(spacing: ECSpacing.md) {
                // Avatar
                thumbnailView

                // Info column
                VStack(alignment: .leading, spacing: 3) {
                    // Name — prominent
                    Text(store.vCard.contact.fullName)
                        .font(.system(.title3, weight: .semibold))
                        .foregroundStyle(ECColors.textPrimary)
                        .lineLimit(1)

                    // Position — readable
                    if !store.vCard.position.isEmpty {
                        Text(store.vCard.position)
                            .font(ECTypography.subheadline())
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                    }

                    // Organization — with icon
                    if let org = store.vCard.organization, !org.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(avatarGradient[0].opacity(0.7))
                            Text(org)
                                .font(ECTypography.footnote())
                                .foregroundStyle(Color(.secondaryLabel))
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: ECSpacing.xxs)

                // Right side: QR code + chevron
                HStack(spacing: ECSpacing.sm) {
                    if let image = store.qrCodeImage {
                        image
                            .resizable()
                            .interpolation(.none)
                            .aspectRatio(1, contentMode: .fit)
                            .frame(width: 52, height: 52)
                            .padding(6)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: ECRadius.sm))
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }
            .padding(.leading, ECSpacing.sm)
            .padding(.trailing, ECSpacing.md)
        }
        .padding(.vertical, ECSpacing.sm)
        .background(ECColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: ECRadius.lg))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private var thumbnailView: some View {
        if let imageUrl = store.vCard.imageURLs.first(where: { $0.type == .thumbnail }) {
            AsyncImage(url: URL(string: imageUrl.urlString)) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if phase.error != nil {
                    initialsAvatar
                } else {
                    ProgressView()
                        .tint(ECColors.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())
        } else {
            initialsAvatar
        }
    }

    private var initialsAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: avatarGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(initials)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: 56, height: 56)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            store.send(.viewCardButtonTapped)
        } label: {
            Label(L("View Card"), systemImage: "creditcard.fill")
        }

        Button {
            isShareViewPresented.toggle()
        } label: {
            Label(L("Share"), systemImage: "square.and.arrow.up")
        }

        if store.isNFCAvailable {
            Button {
                store.send(.writeNFCVCard)
            } label: {
                Label(L("Write to NFC Tag"), systemImage: "wave.3.right")
            }

            Button {
                store.send(.writeNFCURL)
            } label: {
                Label(L("Write App Link to NFC"), systemImage: "link.badge.plus")
            }
        }

        Button {
            store.send(.addPassToWallet)
        } label: {
            Label(L("Add to Apple Wallet"), systemImage: "wallet.pass.fill")
        }
    }

    // MARK: - NFC Status Overlay

    @ViewBuilder
    private var nfcStatusOverlay: some View {
        switch store.nfcWriteStatus {
        case .idle:
            EmptyView()
        case .writing:
            nfcBanner(
                icon: nil,
                text: L("Hold near NFC tag..."),
                color: ECColors.primary,
                showProgress: true
            )
        case .success:
            nfcBanner(
                icon: "checkmark.circle.fill",
                text: L("Written!"),
                color: ECColors.success,
                showProgress: false
            )
        case .failed(let message):
            nfcBanner(
                icon: "xmark.circle.fill",
                text: message,
                color: ECColors.error,
                showProgress: false
            )
            .onTapGesture {
                store.send(.dismissNFCStatus)
            }
        }
    }

    private func nfcBanner(
        icon: String?,
        text: String,
        color: Color,
        showProgress: Bool
    ) -> some View {
        HStack(spacing: ECSpacing.xs) {
            if showProgress {
                ProgressView()
                    .tint(.white)
            }
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(.white)
            }
            Text(text)
                .font(ECTypography.caption(.medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, ECSpacing.md)
        .padding(.vertical, ECSpacing.sm)
        .background(color)
        .clipShape(Capsule())
        .shadow(color: color.opacity(0.3), radius: 4, y: 2)
    }
}

// MARK: - Preview

struct WalletPassDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        WalletPassDetailsView(
            store: .init(
                initialState: WalletPassDetails.State(wp: .mock, vCard: .demo)
            ) {
                WalletPassDetails()
            }
        )
        .padding()
        .background(ECColors.groupedBackground)
    }
}
