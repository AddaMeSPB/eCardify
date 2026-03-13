import SwiftUI
import DesignSystem
import L10nResources
import ECSharedModels
import ComposableArchitecture

struct AddressesSectionView: View {

    @Bindable var store: StoreOf<GenericPassForm>
    var scrollProxy: ScrollViewProxy

    public init(
        store: StoreOf<GenericPassForm>,
        _ scrollProxy: ScrollViewProxy
    ) {
        self.store = store
        self.scrollProxy = scrollProxy
    }

    var body: some View {
        Section {
            ForEach($store.vCard.addresses, id: \.id) { $item in

                Picker(L("Address Type"), selection: $item.type) {
                    ForEach(VCard.Address.AType.allCases, id: \.self) { option in
                        Text(LDynamic(option.rawValue.uppercased()))
                            .tag(option)
                    }
                }

                TextField(L("Post Office"), text: $item.postOfficeAddress.orEmpty)
                    .formFieldStyle()
                    .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.postOfficeTextFields.rawValue)

                TextField(L("Extended Address (Optional)"), text: $item.extendedAddress.orEmpty)
                    .formFieldStyle()

                HStack(spacing: ECSpacing.xs) {
                    ECRequiredDot()
                    TextField(L("Street"), text: $item.street)
                        .formFieldStyle()
                        .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.streetTextFields.rawValue)
                }

                HStack(spacing: ECSpacing.xs) {
                    ECRequiredDot()
                    TextField(L("City"), text: $item.locality)
                        .formFieldStyle()
                        .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.cityTextFields.rawValue)
                }

                TextField(L("Region / State"), text: $item.region.orEmpty)
                    .formFieldStyle()
                    .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.regionTextFields.rawValue)

                HStack(spacing: ECSpacing.xs) {
                    ECRequiredDot()
                    TextField(L("Post Code"), text: $item.postalCode)
                        .formFieldStyle()
                        .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.postTextFields.rawValue)
                }

                CountryPickerRow(item: $item)

                if store.vCard.addresses.count > 1 {
                    Button(role: .destructive) {
                        store.send(.removeAddressSection(by: item.id))
                    } label: {
                        Label(L("Remove Address"), systemImage: "trash")
                            .font(ECTypography.subheadline())
                            .foregroundStyle(ECColors.error)
                    }
                }
            }
            .onDelete(perform: deleteAddress)
        } header: {
            HStack {
                Text(L("Address"))
                    .font(ECTypography.headline())

                Spacer()

                if store.isCustomProduct {
                    Button {
                        store.send(.addOneMoreAddressSection)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ECColors.primary)
                    }
                } else {
                    Menu {
                        Text(L("To activate this function,"))
                        Text(L("Please change your product type below."))
                        Button {
                            withAnimation(.easeInOut(duration: 0.9)) {
                                scrollProxy.scrollTo(store.bottomID, anchor: .bottom)
                            }
                        } label: {
                            Text(L("Change product type"))
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ECColors.textSecondary)
                    }
                }
            }
        }
    }

    func deleteAddress(at offsets: IndexSet) {
        if store.vCard.addresses.count > 1 {
            store.vCard.addresses.remove(atOffsets: offsets)
        }
    }
}

// MARK: - Per-row country picker with isolated @State

private struct CountryPickerRow: View {
    @Binding var item: VCard.Address
    @State private var isPickerPresented = false

    var body: some View {
        VStack {
            Button { isPickerPresented = true } label: {
                HStack {
                    HStack(spacing: ECSpacing.xs) {
                        ECRequiredDot()
                        Text(item.country.isEmpty
                             ? L("Select Country")
                             : item.country)
                        .font(ECTypography.body(.medium))
                        .foregroundStyle(
                            item.country.isEmpty
                            ? ECColors.textSecondary
                            : ECColors.textPrimary
                        )
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundStyle(ECColors.textSecondary)
                }
                .padding(.vertical, ECSpacing.xs)
            }
            .sheet(isPresented: $isPickerPresented) {
                NavigationStack {
                    List(Locale.Region.isoRegions, id: \.identifier) { region in
                        Button {
                            item.country = Locale.current.localizedString(
                                forRegionCode: region.identifier
                            ) ?? region.identifier
                            isPickerPresented = false
                        } label: {
                            Text(Locale.current.localizedString(
                                forRegionCode: region.identifier
                            ) ?? region.identifier)
                        }
                    }
                    .navigationTitle(L("Select Country"))
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.countryTextFields.rawValue)
        }
    }
}
