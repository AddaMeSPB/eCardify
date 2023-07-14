//
//  SwiftUIView.swift
//  
//
//  Created by Saroar Khandoker on 03.07.2023.
//

import SwiftUI
import Foundation
import ComposableArchitecture
import ECardifySharedModels
import Foundation
import PassKit

public struct WallatPassDetails: ReducerProtocol {

    public struct State: Equatable, Identifiable {
        public var id: String { wp.id }
        public var wp: WalletPass
        public var vCard: VCard = .empty
        public var qrCodeImage: Image? = nil
    }

    public enum Action: Equatable {
        case onAppear
//        case sendToEmail
        case addPassToWallet
        case qrCode(Image)

    }

    public init() {}

    public var body: some ReducerProtocol<State, Action> {
        Reduce(self.core)
    }

    func core(state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .onAppear:

            let vCardString = state.wp.pass.barcodes.first?.message ?? "ecardify.addame.com"
            if let vCardString = state.wp.pass.barcodes.first?.message {
                state.vCard = VCard.create(from: vCardString) ?? .empty
                print(#line, state.vCard)
            }

            return .run { send in
                if let image = await generateQRCode(from: vCardString) {
                    let swiftuiImage = Image(uiImage: image)
                    await send(.qrCode(swiftuiImage))
                }
            }

        case .qrCode(let image):
            state.qrCodeImage = image
            return .none

        case .addPassToWallet:
            return .none
        }
    }

    private func generateQRCode(from string: String) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            Task {
                let data = string.data(using: .ascii)

                if let filter = CIFilter(name: "CIQRCodeGenerator") {
                    filter.setValue(data, forKey: "inputMessage")

                    guard let outputImage = filter.outputImage else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let context = CIContext()

                    if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
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


public struct WallatPassDetailsView: View {

    public let store: StoreOf<WallatPassDetails>

    public init(store: StoreOf<WallatPassDetails>) {
        self.store = store
    }

    public var body: some View {
        WithViewStore(self.store) { viewStore in
            Menu {
                Button {
                    viewStore.send(.addPassToWallet)
                } label: {
                    Image("PassbookWallet_logo_Icon")
                    Text("Add to Apple Wallet")
                        .foregroundColor(Color.black)
                }

//                AddPassToWalletButton() {
//                    viewStore.send(.addPassToWallet)
//                }

            } label: {

                VStack(alignment: .leading) {
                    HStack {

                        if let imageUrl = viewStore.wp.imageURLs.first(where: { $0.type == .thumbnail }) {

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
                                if let imageUrl = viewStore.wp.imageURLs.first(where: { $0.type == .icon }) {

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
                                    .frame(width: 50, height: 50)
                                }

                                Spacer()

                                VStack(alignment: .leading) {
                                    Text(viewStore.vCard.contact.fullName)
                                    Text(viewStore.vCard.organization ?? "")
                                    
                                }
                                .padding(.vertical, 8)
                            }

                            Spacer()

                            if let image = viewStore.qrCodeImage {
                                image
                                    .resizable()
                                    .interpolation(.none)
                                    .frame(width: 100, height: 100)
                                    .padding(.trailing, -16)
                            }
                        }

                        Spacer()

                    }
                    .padding()
                }
                .frame(height:130)
                .onAppear {
                    viewStore.send(.onAppear)
                }
                .background(Color.white)
                .cornerRadius(10)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
            }
        }
    }
}

struct WallatPassDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        WallatPassDetailsView(
            store: .init(
                initialState: WallatPassDetails.State.init(wp: .mock),
                reducer: WallatPassDetails()
            )
        )
        .background(Color(red: 243/255, green: 243/255, blue: 243/255))
    }
}
