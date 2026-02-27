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

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce(self.core)
    }

    func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            state.isNFCAvailable = nfcClient.isAvailable()
            let vCardRepresentation = state.vCard.vCardRepresentation

            return .run { [vCardRepresentation] send in
                if let image = generateQRCode(from: vCardRepresentation) {
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
                try await Task.sleep(for: .seconds(2))
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

    private func generateQRCode(from string: String) -> UIImage? {
        let data = string.data(using: .utf8)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let outputImage = filter.outputImage else { return nil }

        let transformedImage = outputImage.transformed(
            by: CGAffineTransform(scaleX: 10, y: 10)
        )
        let context = CIContext()
        guard let cgImage = context.createCGImage(
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

    // MARK: - Card Content

    private var cardContent: some View {
        HStack(spacing: ECSpacing.sm) {
            // Thumbnail
            thumbnailView

            // Info
            VStack(alignment: .leading, spacing: ECSpacing.xxs) {
                // Logo + Name row
                if let imageUrl = store.vCard.imageURLs.first(where: { $0.type == .icon }) {
                    AsyncImage(url: URL(string: imageUrl.urlString)) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fit)
                        } else {
                            EmptyView()
                        }
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Text(store.vCard.contact.fullName)
                    .font(ECTypography.headline())
                    .foregroundStyle(ECColors.textPrimary)
                    .lineLimit(1)

                if !store.vCard.position.isEmpty {
                    Text(store.vCard.position)
                        .font(ECTypography.caption())
                        .foregroundStyle(ECColors.textSecondary)
                        .lineLimit(1)
                }

                if let org = store.vCard.organization, !org.isEmpty {
                    Text(org)
                        .font(ECTypography.caption())
                        .foregroundStyle(ECColors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: ECSpacing.xs)

            // QR Code
            if let image = store.qrCodeImage {
                image
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: ECRadius.sm))
            }
        }
        .padding(ECSpacing.md)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: ECRadius.lg))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
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
                    placeholderAvatar
                } else {
                    ProgressView()
                        .tint(ECColors.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: ECRadius.md))
        } else {
            placeholderAvatar
        }
    }

    private var placeholderAvatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: ECRadius.md)
                .fill(ECColors.primary.opacity(0.12))
            Image(systemName: "person.crop.rectangle.fill")
                .font(.title2)
                .foregroundStyle(ECColors.primary)
        }
        .frame(width: 72, height: 72)
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
