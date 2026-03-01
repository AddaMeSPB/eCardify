import SwiftUI
import DesignSystem
import L10nResources
import SettingsFeature
import ECSharedModels
import ComposableArchitecture

public struct WalletPassView: View {

    @Bindable public var store: StoreOf<WalletPassList>

    public init(store: StoreOf<WalletPassList>) {
        self.store = store
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ECColors.groupedBackground.ignoresSafeArea()

            mainScrollView

            // FAB
            if !store.wPassLocal.isEmpty {
                addButton
            }
        }
    }

    private var mainScrollView: some View {
        scrollContent
            .redacted(reason: store.isLoadingWPL ? .placeholder : .init())
            .navigationTitle(L("Digital Cards"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar { settingsToolbar }
            .onAppear { store.send(.onAppear) }
            .sheet(
                item: $store.scope(
                    state: \.destination?.digitalCard,
                    action: \.destination.digitalCard
                )
            ) { store in
                CardDesignView(store: store)
            }
            .navigationDestination(
                item: $store.scope(
                    state: \.destination?.add,
                    action: \.destination.add
                )
            ) { store in
                GenericPassFormView(store: store)
            }
            .navigationDestination(
                item: $store.scope(
                    state: \.destination?.settings,
                    action: \.destination.settings
                )
            ) { store in
                SettingsView(store: store)
            }
            .sheet(
                item: $store.scope(
                    state: \.destination?.addPass,
                    action: \.destination.addPass
                )
            ) { store in
                AddPassView(store: store)
            }
    }

    private var scrollContent: some View {
        ScrollView {
            if !store.wPassLocal.isEmpty {
                cardListContent
            } else {
                emptyStateContent
            }
        }
    }

    @ToolbarContentBuilder
    private var settingsToolbar: some ToolbarContent {
        if store.isAuthorized {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.send(.navigateSettingsButtonTapped)
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(ECTypography.body())
                        .foregroundStyle(ECColors.primary)
                }
                .accessibilityIdentifier("settings_button")
            }
        }
    }

    // MARK: - Card List

    private var cardListContent: some View {
        LazyVStack(spacing: ECSpacing.sm) {
            ForEach(
                store.scope(
                    state: \.wPassLocal,
                    action: \.wPass
                )
            ) {
                WalletPassDetailsView(store: $0)
            }
        }
        .padding(.horizontal, ECSpacing.md)
        .padding(.top, ECSpacing.sm)
        .padding(.bottom, 80) // Space for FAB
    }

    // MARK: - Empty State

    private var emptyStateContent: some View {
        VStack(spacing: ECSpacing.xxl) {
            Spacer(minLength: ECSpacing.xxxl)

            if store.isAuthorized {
                ECEmptyState(
                    icon: "creditcard.fill",
                    title: L("No Cards Yet"),
                    message: L("Create your first digital business card and share it instantly."),
                    actionTitle: L("Create Card")
                ) {
                    store.send(.createGenericFormButtonTapped)
                }
            } else {
                ECEmptyState(
                    icon: "person.crop.circle.badge.plus",
                    title: L("Welcome to eCardify"),
                    message: L("Login or register to create and manage your digital business cards."),
                    actionTitle: L("Login or Register")
                ) {
                    store.send(.openSheetLogin(true))
                }
            }

            Spacer()
        }
    }

    // MARK: - FAB

    private var addButton: some View {
        Button {
            store.send(.createGenericFormButtonTapped)
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [ECColors.primary, ECColors.primaryDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: ECColors.primary.opacity(0.35), radius: 8, y: 4)
        }
        .padding(ECSpacing.xl)
        .accessibilityIdentifier("add_card_button")
    }
}

// MARK: - Preview

struct WalletPassView_Previews: PreviewProvider {
    static public var demoWPassLocal: IdentifiedArrayOf<WalletPassDetails.State> {
        .init(
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
        NavigationStack {
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
