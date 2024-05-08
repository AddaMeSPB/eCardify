import SwiftUI
import SettingsFeature
import ECSharedModels
import ComposableArchitecture

public struct WalletPassView: View {

    public let store: StoreOf<WalletPassList>

    public init(store: StoreOf<WalletPassList>) {
        self.store = store
    }

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    public var body: some View {
        WithPerceptionTracking {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    Group {
                        if store.wPassLocal.count > 0 {
                            ForEachStore(
                                self.store.scope(
                                    state: \.wPassLocal,
                                    action: \.wPass
                                )
                            ) {
                                WalletPassDetailsView(store: $0)
                            }
                        } else {

                            if store.isAuthorized {
                                Button {
                                    store.send(.createGenericFormButtonTapped)
                                } label: {
                                    Image(systemName: "plus")
                                        .resizable()
                                        .frame(width: 60, height: 60)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 130)
                                        .buttonBorderShape(.capsule)
                                        .foregroundColor(.gray)
                                        .padding()
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 25)
                                                .stroke(Color.gray, style: StrokeStyle(lineWidth: 3, dash: [9]))
                                        )
                                }
                                .padding(20)
                                .accessibility(identifier: "add_card_button")
                            }

                            if !store.isAuthorized {
                                Button {
                                    store.send(.openSheetLogin(true))
                                } label: {
                                    VStack {
                                        Text("Login or Register.")
                                            .font(.title3)
                                        //  .fontWeight(.light)

                                        Image(systemName: "iphone.and.arrow.forward")
                                            .resizable()
                                            .frame(width: 40, height: 60)
                                    }
                                }
                                .padding(32)
                            }

                        }
                    }
                }
                .redacted(reason: store.isLoadingWPL ? .placeholder : .init())
                .navigationBarTitle("Digital Cards")
                .navigationViewStyle(StackNavigationViewStyle())
                .navigationBarTitleDisplayMode(.automatic)
                .toolbar {
                    if store.isAuthorized {
                        ToolbarItem(placement: ToolbarItemPlacement.navigationBarTrailing) {
                            Button {
                                store.send(.navigateSettingsButtonTapped)
                            } label: {
                                Image(systemName: "gear")
                                    .font(.title2)
                                //.foregroundColor(colorScheme == .dark ? .white : Color.yellow)
                            }
                            .accessibility(identifier: "settings_button")
                        }
                    }
                }
                .onAppear {
                    store.send(.onAppear)
                }
                .sheet(
                  store: self.store.scope(
                    state: \.$destination.digitalCard,
                    action: \.destination.digitalCard
                  )
                ) { store in
                    CardDesignView(store: store)
                }
                .navigationDestination(
                    store: self.store.scope(
                        state: \.$destination.add,
                        action: \.destination.add
                    )
                ) { store in
                    GenericPassFormView(store: store)
                }
                .navigationDestination(
                    store: self.store.scope(
                        state: \.$destination.settings,
                        action: \.destination.settings
                    )
                ) { store in
                    SettingsView.init(store: store)

                }
                .sheet(
                    store: self.store.scope(
                        state: \.$destination.addPass,
                        action: \.destination.addPass
                    )
                ) { store in
                    AddPassView(store: store)
                }

                if store.wPassLocal.count > 0 {
                    Button {
                        store.send(.createGenericFormButtonTapped)
                    } label: {
                        Image(systemName: "plus.square.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundStyle(.white, .blue)
                    }
                    .padding(32)
                    .accessibility(identifier: "add_card_button")
                }
            }
        }
    }
}

struct WalletPassView_Previews: PreviewProvider {
    static public var demoWPassLocal: IdentifiedArrayOf<WalletPassDetails.State> {
        return .init(
            uniqueElements: [
                WalletPassDetails.State(wp: .mock, vCard: .demo),
                WalletPassDetails.State(wp: .mock1, vCard: .demo)
            ]
        )
    }

    static var state = WalletPassList.State(wPass: demoWPassLocal)

    static var store = Store(
        initialState: state
    ) {
        WalletPassList()
    }

    static var previews: some View {
        NavigationView {
            WalletPassView(store: store)
        }
    }
}

/// Move to TCA helper extension
extension Binding where Value == Optional<String> {
    public var orEmpty: Binding<String> {
        Binding<String> {
            wrappedValue ?? ""
        } set: {
            wrappedValue = $0
        }
    }
}

extension String {

    // may be prefix which will more speed
    var colorFromRGBString: Color {
        let components = self.replacingOccurrences(of: "rgb(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .split(separator: ",").map { String($0) }

        guard components.count == 3,
              let red = Double(components[0]),
              let green = Double(components[1]),
              let blue = Double(components[2]) else {
            return Color(red: 186 / 255, green: 186 / 255, blue: 224 / 255)
        }

        return Color(red: red / 255.0, green: green / 255.0, blue: blue / 255.0)
    }
}
