//
//  SwiftUIView.swift
//  
//
//  Created by Saroar Khandoker on 17.07.2023.
//

import SwiftUI
import Foundation
import ECardifySharedModels
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

public struct CardDesignListReducer: ReducerProtocol {
    public struct State: Equatable {
        public init(
            cardDesigns: IdentifiedArrayOf<CardDesignReducer.State> = .defaultData.cardDesigns,
            selectedColorPalattle: ColorPalette = .default,
            vCard: VCard
        ) {
            self.cardDesigns = cardDesigns
            self.selectedColorPalattle = selectedColorPalattle
            self.vCard = vCard
        }

        public var cardDesigns: IdentifiedArrayOf<CardDesignReducer.State> = []
        public var selectedColorPalattle: ColorPalette
        public var vCard: VCard

    }

    public enum Action: Equatable {
        case onAppear
        case cardDesigns(id: CardDesignReducer.State.ID, action: CardDesignReducer.Action)
        case dismiss
    }

    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some ReducerProtocol<State, Action> {
        Reduce(self.core)
            .forEach(\.cardDesigns, action: /Action.cardDesigns) {
                CardDesignReducer()
            }
    }

    func core(state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .onAppear:
            return .none
        case .cardDesigns(id: _, action: let action):

            if case let .selectedDCard(uuid) = action {

                // Unselect the same card
                if uuid == state.selectedColorPalattle.id {
                    state.cardDesigns[id: uuid]!.isTappedCard = state.cardDesigns[id: uuid]?
                        .isTappedCard == true ? false : true

                    // when unseleted same card have me make default value again
                    if state.cardDesigns[id: uuid]?.isTappedCard == false {
                        state.selectedColorPalattle = ColorPalette.default
                    }
                    return .none
                }

                // Unselect the previous card
                if let previousID = state.cardDesigns[id: state.selectedColorPalattle.id]?.id {
                    state.cardDesigns[id: previousID]?.isTappedCard = false
                }

                // Select the new card
                state.cardDesigns[id: uuid]?.isTappedCard = true
                state.selectedColorPalattle = state.cardDesigns[id: uuid]?.colorP ?? ColorPalette.default

            }

            return .none
        case .dismiss:
            return .fireAndForget {
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

        WithViewStore(store) { viewStore in
            ZStack(alignment: .bottomLeading) {


                VStack {

                    HStack {
                        Text("Select card design")
                            .font(.title)
                            .fontWeight(.heavy)

                        Spacer()

                        Button {
                            viewStore.send(.dismiss)
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
                                action: CardDesignListReducer.Action.cardDesigns(id:action:))
                        ) {
                            CardDesignView(store: $0)
                        }
                    }
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                    .tabViewStyle(.page)

                    .onAppear {
                        viewStore.send(.onAppear)
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
                initialState: CardDesignListReducer.State.defaultData,
                reducer: CardDesignListReducer()
            )
        )
    }
}

public struct CardDesignReducer: ReducerProtocol {

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

    public enum Action: Equatable {
        case onAppear
        case qrCode(Image)
        case selectedDCard(by: UUID)
        case dismiss
    }

    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some ReducerProtocol<State, Action> {
        Reduce(self.core)
    }

    func core(state: inout State, action: Action) -> EffectTask<Action> {
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
            return .fireAndForget {
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

    struct ViewState: Equatable {
        var colorP: ColorPalette
        var vCard: VCard
        var qrCodeImage: Image?
        var isTappedCard: Bool
        var isRealDataView: Bool

        init(state: CardDesignReducer.State) {
            self.colorP = state.colorP
            self.vCard = state.vCard
            self.qrCodeImage = state.qrCodeImage
            self.isTappedCard = state.isTappedCard
            self.isRealDataView = state.isRealDataView
        }
    }

    public init(store: StoreOf<CardDesignReducer>) {
        self.store = store
    }

    public var body: some View {
        WithViewStore(store) { viewStore in
            ScrollView {
                VStack(alignment: .leading) {
                    HStack {

                        if let imageUrl = viewStore.vCard.imageURLs.first(where: { $0.type == .icon }) {
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

                        Text(viewStore.vCard.organization ?? viewStore.vCard.contact.fullName)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(Color(rgbString: viewStore.colorP.foregroundColor))

                        Spacer()

                    }

                    HStack(alignment: .top) {
                        VStack(alignment: .leading) {
                            Text("NAME")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(Color(rgbString: viewStore.colorP.labelColor))

                            Text(viewStore.vCard.contact.fullName.replacingOccurrences(of: " ", with: "\n").uppercased())
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(Color(rgbString: viewStore.colorP.foregroundColor))

                        }

                        Spacer()

                        if let imageUrl = viewStore.vCard.imageURLs.first(where: { $0.type == .thumbnail }) {
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
                            .foregroundColor(Color(rgbString: viewStore.colorP.labelColor))

                        Text(viewStore.vCard.position)
                            .font(.title2)
                            .fontWeight(.light)
                            .foregroundColor(Color(rgbString: viewStore.colorP.foregroundColor))
                    }
                    .padding(.top, 0)

                    HStack {
                        VStack(alignment: .leading) {

                            Text("EMAIL")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(Color(rgbString: viewStore.colorP.labelColor))

                            Text(viewStore.vCard.emails.first?.text ?? "demo@mail.com")
                                .minimumScaleFactor(0.4)
                                .lineLimit(1)
                                .layoutPriority(1)
                                .font(.title2)
                                .fontWeight(.light)
                                .accentColor(Color(rgbString: viewStore.colorP.foregroundColor))
                            Spacer()
                        }

                        Spacer()

                        VStack(alignment: .leading) {
                            Text("MOBILE")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(Color(rgbString: viewStore.colorP.labelColor))

                            Text(viewStore.vCard.telephones.first?.number ?? "+7921000000")
                                .minimumScaleFactor(0.4)
                                .lineLimit(1)
                                .font(.title2)
                                .fontWeight(.light)
                                .foregroundColor(Color(rgbString: viewStore.colorP.foregroundColor))
                            Spacer()
                        }

                    }
                    .padding(.top, 10)


                    HStack(alignment: .bottom) {
                        Spacer()
                        if let image = viewStore.qrCodeImage {
                            image
                                .resizable()
                                .interpolation(.none)
                                .frame(width: 250, height: 250)
                                .padding(.trailing, -16)
                        } else {
                            Image("qr")
                                .resizable()
                                .frame(width: 250, height: 250)
                        }
                        Spacer()
                    }
                    
                    HStack(alignment: .bottom) {

                        Button {
                            self.isShareViewPresented.toggle()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .resizable()
                                .frame(width: 40, height: 40)
                        }
                        .foregroundColor(viewStore.isRealDataView ? Color(rgbString: viewStore.colorP.foregroundColor) : Color.gray)
                        .allowsHitTesting(viewStore.isRealDataView)

                        Spacer()

                        if !viewStore.isRealDataView {
                            Button {
                                viewStore.send(.selectedDCard(by: viewStore.id), animation: .easeIn(duration: 1))
                            } label: {
                                Image(
                                    systemName: viewStore.isTappedCard == true
                                    ? "heart.circle"
                                    : "circle"
                                )
                                .resizable()
                                .foregroundColor(viewStore.isTappedCard == true ? Color(rgbString: viewStore.colorP.foregroundColor) : Color.gray)
                                .frame(width: 40, height: 40)
                            }
                        } else {
                            Button {
                                viewStore.send(.dismiss)
                            } label: {
                                Text("Close")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(Color(rgbString: viewStore.colorP.foregroundColor))
                        }

                    }
                    .padding([.top, .bottom], 10)

                }
                .onAppear {
                    viewStore.send(.onAppear)
                }
                .padding(25)
                .background(Color(rgbString: viewStore.colorP.backgroundColor))
                .cornerRadius(30)
                .sheet(isPresented: self.$isShareViewPresented) {
                  ActivityView(activityItems: [URL(string: "https://apps.apple.com/ru/app/new-word-learn-word-vocabulary/id1619504857?l=en")!])
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
                ),
                reducer: CardDesignReducer()
            )
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
