import SwiftUI
import ImagePicker
import SettingsFeature
import ECSharedModels
import ComposableArchitecture

public struct WallatPassView: View {

    public let store: StoreOf<WallatPassList>

    struct ViewState: Equatable {
        var wPassLocal: IdentifiedArrayOf<WallatPassDetails.State>
        var isAuthorized: Bool
        var isLoadinWPL: Bool

        init(state: BindingViewStore<WallatPassList.State>) {
            self.wPassLocal = state.wPassLocal
            self.isAuthorized = state.isAuthorized
            self.isLoadinWPL = state.isLoadinWPL
        }
    }

    public init(store: StoreOf<WallatPassList>) {
        self.store = store
    }

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    public var body: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    Group {
                        if viewStore.wPassLocal.count > 0 {
                            ForEachStore(
                                self.store.scope(
                                    state: \.wPassLocal,
                                    action: WallatPassList.Action.wPass(id:action:))
                            ) {
                                WallatPassDetailsView(store: $0)
                            }
                        } else {
                            Button {
                                viewStore.send(.createGenericFormButtonTapped)
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
                    }
                }
                .redacted(reason: viewStore.isLoadinWPL ? .placeholder : .init())
                .navigationBarTitle("Digital Cards")
                .navigationViewStyle(StackNavigationViewStyle())
                .navigationBarTitleDisplayMode(.automatic)
                .toolbar {
                    if viewStore.isAuthorized {
                        ToolbarItem(placement: ToolbarItemPlacement.navigationBarTrailing) {
                            Button {
                                viewStore.send(.navigateSettingsButtonTapped)
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
                    viewStore.send(.onAppear)
                }
                .sheet(
                    store: self.store.scope(
                        state: \.$destination,
                        action: { .destination($0) }
                    ),
                    state: /WallatPassList.Destination.State.digitalCard,
                    action: WallatPassList.Destination.Action.digitalCard

                ) { store in
                    CardDesignView(store: store)
                }
                .navigationDestination(
                    store: self.store.scope(
                        state: \.$destination,
                        action: { .destination($0) }
                    ),
                    state: /WallatPassList.Destination.State.add,
                    action: WallatPassList.Destination.Action.add
                ) { store in
                    GenericPassFormView(store: store)
                }
                .navigationDestination(
                    store: self.store.scope(
                        state: \.$destination,
                        action: { .destination($0) }
                    ),
                    state: /WallatPassList.Destination.State.settings,
                    action: WallatPassList.Destination.Action.settings
                ) { store in
                    SettingsView.init(store: store)
                }


                if viewStore.wPassLocal.count > 0 {
                    Button {
                        viewStore.send(.createGenericFormButtonTapped)
                    } label: {
                        Image(systemName: "plus.square.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                    }
                    .padding(32)
                    .accessibility(identifier: "add_card_button")
                }
            }
            .sheet(
                store: self.store.scope(
                    state: \.$destination,
                    action: { .destination($0) }
                ),
                state: /WallatPassList.Destination.State.addPass,
                action: WallatPassList.Destination.Action.addPass

            ) { store in
                AddPassView(store: store)
            }
        }
    }
}

struct WallatPassView_Previews: PreviewProvider {
    static public var demoWPassLocal: IdentifiedArrayOf<WallatPassDetails.State> {
        return .init(
            uniqueElements: [
                WallatPassDetails.State(wp: .mock, vCard: .demo),
                WallatPassDetails.State(wp: .mock1, vCard: .demo)
            ]
        )
    }

    static var store = Store(
        initialState: WallatPassList.State(wPassLocal: demoWPassLocal),
        reducer: WallatPassList()
    )

    static var previews: some View {
        NavigationView {
            WallatPassView(store: store)
        }
    }
}

/// Move to TCA helper extention
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
