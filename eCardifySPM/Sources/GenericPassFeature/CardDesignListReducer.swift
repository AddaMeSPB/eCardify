//
//  SwiftUIView.swift
//  
//
//  Created by Saroar Khandoker on 17.07.2023.
//

import SwiftUI
import Foundation
import ECSharedModels
import ComposableArchitecture

extension CardDesignListReducer.State {

    static public var defaultData: CardDesignListReducer.State {

        var cp: IdentifiedArrayOf<CardDesignReducer.State> = []

        for item in ColorPalette.colorPalettes {
            cp.append(.init(colorP: item, vCard: .demo))
        }

        return .init(cardDesigns: cp, vCard: .demo)
    }

}

public struct CardDesignListReducer: Reducer {
    public struct State: Equatable {
        public init(
            cardDesigns: IdentifiedArrayOf<CardDesignReducer.State> = .defaultData.cardDesigns,
            selectedColorPalette: ColorPalette = .default,
            vCard: VCard
        ) {
            self.cardDesigns = cardDesigns
            self.selectedColorPalette = selectedColorPalette
            self.vCard = vCard
        }

        public var cardDesigns: IdentifiedArrayOf<CardDesignReducer.State> = []
        public var selectedColorPalette: ColorPalette
        public var vCard: VCard

    }

    @CasePathable
    public enum Action: Equatable {
        case onAppear
        case cardDesigns(id: CardDesignReducer.State.ID, action: CardDesignReducer.Action)
        case dismiss
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce(self.core)
            .forEach(\.cardDesigns, action: /Action.cardDesigns) {
                CardDesignReducer()
            }
    }

    func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            return .none
        case .cardDesigns(id: _, action: let action):

            if case let .selectedDCard(uuid) = action {

                // Unselect the same card
                if uuid == state.selectedColorPalette.id {
                    state.cardDesigns[id: uuid]!.isTappedCard = state.cardDesigns[id: uuid]?
                        .isTappedCard == true ? false : true

                    // when unselected same card have me make default value again
                    if state.cardDesigns[id: uuid]?.isTappedCard == false {
                        state.selectedColorPalette = ColorPalette.default
                    }
                    return .none
                }

                // Unselect the previous card
                if let previousID = state.cardDesigns[id: state.selectedColorPalette.id]?.id {
                    state.cardDesigns[id: previousID]?.isTappedCard = false
                }

                // Select the new card
                state.cardDesigns[id: uuid]?.isTappedCard = true
                state.selectedColorPalette = state.cardDesigns[id: uuid]?.colorP ?? ColorPalette.default


            }

            return .none
                
        case .dismiss:
            return .run { _ in
                await self.dismiss()
            }
        }
    }
}

public struct CardDesignListView: View {

    public let store: StoreOf<CardDesignListReducer>

    public init(store: StoreOf<CardDesignListReducer>) {
        self.store = store
    }

    let rows = [GridItem(.flexible())]

    public var body: some View {

        WithPerceptionTracking {
            ZStack(alignment: .bottomLeading) {


                VStack {

                    HStack {
                        Text("Select card design")
                            .font(.title)
                            .fontWeight(.heavy)

                        Spacer()

                        Button {
                            store.send(.dismiss)
                        } label: {
                            Text("Close")
                                .font(.title)
                                .fontWeight(.bold)
                                .padding()
                        }
                    }
                    .padding([.vertical, .horizontal], 20)
                    .padding(.bottom, -20)

                    TabView {
                        ForEachStore(
                            self.store.scope(
                                state: \.cardDesigns,
                                action: \.cardDesigns
                            )
                        ) {
                            CardDesignView(store: $0)
                        }
                    }
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                    .tabViewStyle(.page)

                    .onAppear {
                        store.send(.onAppear)
                    }
                    .navigationTitle("Select card design")


                }



            }
        }

    }
}


struct CardDesignListView_Previews: PreviewProvider {
    static var previews: some View {
        CardDesignListView(
            store: .init(
                initialState: CardDesignListReducer.State.defaultData
            ) {
                CardDesignListReducer()
            }
        )
    }
}

@Reducer
public struct CardDesignReducer {

    @ObservableState
    public struct State: Equatable, Identifiable {
        public init(
            colorP: ColorPalette,
            vCard: VCard,
            isTappedCard: Bool = false,
            isRealDataView: Bool = false
        ) {
            self.colorP = colorP
            self.vCard = vCard
            self.isTappedCard = isTappedCard
            self.isRealDataView = isRealDataView
        }

        public var id: UUID {
            self.colorP.id
        }
        public var colorP: ColorPalette
        public var vCard: VCard
        public var qrCodeImage: Image? = nil
        public var isTappedCard: Bool
        public var isRealDataView: Bool
    }

    @CasePathable
    public enum Action: Equatable {
        case onAppear
        case qrCode(Image)
        case selectedDCard(by: UUID)
        case dismiss
    }

    @Dependency(\.dismiss) var dismiss

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

        case .selectedDCard:
            return .none

        case .dismiss:
            return .run { _ in
                await self.dismiss()
            }
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


extension IdentifiedArray where ID == CardDesignReducer.State.ID, Element == CardDesignReducer.State {
    static public var defaultData: CardDesignListReducer.State {

        var cp: IdentifiedArrayOf<CardDesignReducer.State> = []

        for item in ColorPalette.colorPalettes {
            cp.append(.init(colorP: item, vCard: .demo))
        }

        return .init(cardDesigns: cp, vCard: .demo)
    }
    
}

import SwiftUIExtension

public struct CardDesignView: View {

    public let store: StoreOf<CardDesignReducer>
    @State var isShareViewPresented = false

    public init(store: StoreOf<CardDesignReducer>) {
        self.store = store
    }

    public var body: some View {
        WithPerceptionTracking {
            ScrollView {
                VStack(alignment: .leading) {
                    HStack {

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
                        } else {
                            Image("icon")
                                .resizable()
                                .frame(width: 30, height: 30)
                        }

                        Text(store.vCard.organization ?? store.vCard.contact.fullName)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(Color(rgbString: store.colorP.foregroundColor))

                        Spacer()

                    }

                    HStack(alignment: .top) {
                        VStack(alignment: .leading) {
                            Text("NAME")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(Color(rgbString: store.colorP.labelColor))

                            Text(store.vCard.contact.fullName.replacingOccurrences(of: " ", with: "\n").uppercased())
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(Color(rgbString: store.colorP.foregroundColor))

                        }

                        Spacer()

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
                            .frame(width: 120, height: 120)
                        } else {
                            Image("thumbnail")
                                .resizable()
                                .frame(width: 120, height: 120)
                        }

                    }
                    .padding(.top, 10)

                    VStack(alignment: .leading) {
                        Text("POSITION")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(Color(rgbString: store.colorP.labelColor))

                        Text(store.vCard.position)
                            .font(.title2)
                            .fontWeight(.light)
                            .foregroundColor(Color(rgbString: store.colorP.foregroundColor))
                    }
                    .padding(.top, 0)

                    HStack {
                        VStack(alignment: .leading) {

                            Text("EMAIL")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(Color(rgbString: store.colorP.labelColor))

                            Text(store.vCard.emails.first?.text ?? "demo@mail.com")
                                .minimumScaleFactor(0.4)
                                .lineLimit(1)
                                .layoutPriority(1)
                                .font(.title2)
                                .fontWeight(.light)
                                .accentColor(Color(rgbString: store.colorP.foregroundColor))
                            Spacer()
                        }

                        Spacer()

                        VStack(alignment: .leading) {
                            Text("MOBILE")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(Color(rgbString: store.colorP.labelColor))

                            Text(store.vCard.telephones.first?.number ?? "+7921000000")
                                .minimumScaleFactor(0.4)
                                .lineLimit(1)
                                .font(.title2)
                                .fontWeight(.light)
                                .foregroundColor(Color(rgbString: store.colorP.foregroundColor))
                            Spacer()
                        }

                    }
                    .padding(.top, 6)


                    HStack(alignment: .bottom) {
                        Spacer()
                        if let image = store.qrCodeImage {
                            image
                                .resizable()
                                .interpolation(.none)
                                .frame(
                                    width: store.isRealDataView ? 250 : 100,
                                    height: store.isRealDataView ? 250 : 100
                                )
                                .padding(.trailing, -16)
                        } else {
                            Image("qr")
                                .resizable()
                                .interpolation(.none)
                                .frame(
                                    width: store.isRealDataView ? 250 : 100,
                                    height: store.isRealDataView ? 250 : 100
                                )
                        }

                        Spacer()
                    }
                    
                    HStack(alignment: .bottom) {

                        Button {
                            self.isShareViewPresented.toggle()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30)
                        }
                        .foregroundColor(store.isRealDataView ? Color(rgbString: store.colorP.foregroundColor) : Color.gray)
                        .allowsHitTesting(store.isRealDataView)

                        Spacer()

                        if !store.isRealDataView {
                            Button {
                                store.send(.selectedDCard(by: store.id), animation: .easeIn(duration: 1))
                            } label: {
                                Image(
                                    systemName: store.isTappedCard == true
                                    ? "heart.circle"
                                    : "circle"
                                )
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(store.isTappedCard == true ? Color(rgbString: store.colorP.foregroundColor) : Color.gray)
                                .frame(width: 30)
                            }
                        } else {
                            Button {
                                store.send(.dismiss)
                            } label: {
                                Text("Close")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(Color(rgbString: store.colorP.foregroundColor))
                        }

                    }
                    .padding([.top, .bottom], 5)

                }
                .onAppear {
                    store.send(.onAppear)
                }
                .padding(25)
                .background(Color(rgbString: store.colorP.backgroundColor))
                .cornerRadius(30)
                .sheet(isPresented: self.$isShareViewPresented) {
                  ActivityView(activityItems: [URL(string: "https://apps.apple.com/pt/app/ecardify/id6452084315?l=en-GB")!])
                    .ignoresSafeArea()
                }

            }
            .padding(20)
        }
    }
}

struct CardDesignView_Previews: PreviewProvider {
    static var previews: some View {
        CardDesignView(
            store: .init(
                initialState: .init(
                    colorP: ColorPalette.colorPalettes[14],
                    vCard: .demo
                )
            ) {
                CardDesignReducer()
            }
        )
    }
}

extension Color {
    init(rgbString: String) {
        let components = rgbString.replacingOccurrences(of: "rgb(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .components(separatedBy: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }

        guard components.count == 3 else {
            fatalError("cant convert color from string")
        }

        let red = Double(components[0]) / 255.0
        let green = Double(components[1]) / 255.0
        let blue = Double(components[2]) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}
