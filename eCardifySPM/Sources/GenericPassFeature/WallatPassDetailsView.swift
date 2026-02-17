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
    }

    @CasePathable
    public enum Action: Equatable {
        case onAppear
//        case sendToEmail
        case addPassToWallet
        case qrCode(Image)
        case viewCardButtonTapped
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce(self.core)
    }

    func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:

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

        }
    }

    private func generateQRCode(from string: String) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            Task {
                let data = string.data(using: .utf8) // Change to .utf8

                if let filter = CIFilter(name: "CIQRCodeGenerator") {
                    filter.setValue(data, forKey: "inputMessage")
                    filter.setValue("H", forKey: "inputCorrectionLevel") // Add this line to set a higher correction level

                    guard let outputImage = filter.outputImage else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let scaleX = 10.0 // scale X by 10 times
                    let scaleY = 10.0 // scale Y by 10 times
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
