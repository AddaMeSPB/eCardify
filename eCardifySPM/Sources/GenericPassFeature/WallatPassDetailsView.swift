import CoreNFC
import PassKit
import SwiftUI
import Foundation
import ECSharedModels
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

            return .run { send in
                if let image = await generateQRCode(from: vCardRepresentation) {
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
                    let url = URL(string: "https://apps.apple.com/app/ecardify/id6452084315")!
                    try await nfcClient.writeURL(url)
                    await send(.nfcWriteResult(.success(true)))
                } catch {
                    await send(.nfcWriteResult(.failure(NFCWriteError(error))))
                }
            }

        case .nfcWriteResult(.success):
            state.nfcWriteStatus = .success
            return .none

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

    private func generateQRCode(from string: String) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            Task {
                let data = string.data(using: .utf8)

                if let filter = CIFilter(name: "CIQRCodeGenerator") {
                    filter.setValue(data, forKey: "inputMessage")
                    filter.setValue("H", forKey: "inputCorrectionLevel")

                    guard let outputImage = filter.outputImage else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let scaleX = 10.0
                    let scaleY = 10.0
                    let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

                    let context = CIContext()
                    if let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) {
                        continuation.resume(returning: UIImage(cgImage: cgImage))
                    } else {
                        continuation.resume(returning: nil)
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

import SwiftUIExtension

public struct WalletPassDetailsView: View {

    @State var isShareViewPresented = false
    @Perception.Bindable public var store: StoreOf<WalletPassDetails>

    public init(store: StoreOf<WalletPassDetails>) {
        self.store = store
    }

    public var body: some View {
        WithPerceptionTracking {
            Menu {

                Button {
                    self.isShareViewPresented.toggle()
                } label: {
                    Text("🪪 Share card")
                        .foregroundColor(Color.black)
                }

                if store.isNFCAvailable {
                    Button {
                        store.send(.writeNFCVCard)
                    } label: {
                        Label("Write to NFC Tag", systemImage: "wave.3.right")
                            .foregroundColor(Color.black)
                    }

                    Button {
                        store.send(.writeNFCURL)
                    } label: {
                        Label("Write App Link to NFC", systemImage: "link.badge.plus")
                            .foregroundColor(Color.black)
                    }
                }

                Button {
                    store.send(.viewCardButtonTapped)
                } label: {
                    Text("Show card 🪪")
                        .foregroundColor(Color.black)
                }

                Button {
                    store.send(.addPassToWallet)
                } label: {
                    Image("PassbookWallet_logo_Icon")
                    Text("Add to Apple Wallet")
                        .foregroundColor(Color.black)
                }

            } label: {

                VStack(alignment: .leading) {
                    HStack {

                        if let imageUrl = store.vCard.imageURLs.first(where: { $0.type == .thumbnail }) {

                            AsyncImage(url: URL(string: imageUrl.urlString)) { phase in
                                if let image = phase.image {
                                    image.resizable()
                                } else if phase.error != nil {
                                    Color.red
                                } else {
                                    ProgressView()
                                        .tint(Color.blue)
                                }
                            }
                            .frame(width: 100, height: 100)
                        }

                        HStack {

                            VStack(alignment: .leading) {
                                if let imageUrl = store.vCard.imageURLs.first(where: { $0.type == .icon }) {
                                    AsyncImage(url: URL(string: imageUrl.urlString)) { phase in
                                        if let image = phase.image {
                                            image.resizable()
                                        } else if phase.error != nil {
                                            Color.red
                                        } else {
                                            ProgressView()
                                                .tint(Color.blue)
                                            }
                                    }
                                    .frame(width: 30, height: 30)
                                }

                                Spacer()

                                VStack(alignment: .leading) {
                                    Text(store.vCard.contact.firstName)
                                    Text(store.vCard.position)
                                    Text(store.vCard.organization ?? "")
                                }
                                .lineLimit(1)
                                .layoutPriority(1)
                            }


                            Spacer()

                            if let image = store.qrCodeImage {
                                image
                                    .resizable()
                                    .interpolation(.none)
                                    .frame(width: 50, height: 100)
                                    .padding(.trailing, -16)
                            }
                        }
                        .padding(.vertical, 14)

                        Spacer()

                    }
                    .padding()
                }
                .frame(height: 130)
                .onAppear {
                    store.send(.onAppear)
                }
                .background(Color.white)
                .cornerRadius(10)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .sheet(isPresented: self.$isShareViewPresented) {
                  ActivityView(activityItems: [URL(string: "https://apps.apple.com/pt/app/ecardify/id6452084315?l=en-GB")!])
                    .ignoresSafeArea()
                }
                .overlay {
                    nfcStatusOverlay
                }
            }
        }
    }

    @ViewBuilder
    private var nfcStatusOverlay: some View {
        switch store.nfcWriteStatus {
        case .idle:
            EmptyView()
        case .writing:
            HStack(spacing: 8) {
                ProgressView()
                    .tint(.white)
                Text("Hold near NFC tag...")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.blue.cornerRadius(8))
        case .success:
            Label("Written!", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.green.cornerRadius(8))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        store.send(.dismissNFCStatus)
                    }
                }
        case .failed(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.red.cornerRadius(8))
                .onTapGesture {
                    store.send(.dismissNFCStatus)
                }
        }
    }
}

struct WalletPassDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        WalletPassDetailsView(
            store: .init(
                initialState: WalletPassDetails.State.init(wp: .mock, vCard: .demo)
            ) {
                WalletPassDetails()
            }
        )
        .background(Color(red: 243/255, green: 243/255, blue: 243/255))
    }
}
