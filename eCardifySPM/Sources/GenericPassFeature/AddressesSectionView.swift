import SwiftUI
import ECSharedModels
import iPhoneNumberKit
import ComposableArchitecture

struct AddressesSectionView: View {

    @Perception.Bindable var store: StoreOf<GenericPassForm>
    var scrollProxy: ScrollViewProxy

    @State private var isPickerPresented = false

    public init(
        store: StoreOf<GenericPassForm>,
        _ scrollProxy: ScrollViewProxy
    ) {
        self.store = store
        self.scrollProxy = scrollProxy
    }

    var body: some View {
        WithPerceptionTracking {
            Section {
                ForEach($store.vCard.addresses, id: \.id) { $item in

                    Picker("Address Type", selection: $item.type) {
                        ForEach(VCard.Address.AType.allCases, id: \.self) { option in
                            Text(option.rawValue.uppercased())
                                .tag(option)
                        }
                    }

                    TextField(
                        "",
                        text: $item.postOfficeAddress.orEmpty,
                        prompt: Text("PostOffice")
                            .font(.title2)
                            .fontWeight(.medium)
                    )
                    .disableAutocorrection(true)
                    .font(.title2)
                    .fontWeight(.medium)
                    .padding(.vertical, 10)
                    .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.postOfficeTextFields.rawValue)


                    TextField(
                        "",
                        text: $item.extendedAddress.orEmpty,
                        prompt: Text("Extended address - OPTIONAL")
                            .font(.title2)
                            .fontWeight(.medium)
                    )
                    .disableAutocorrection(true)
                    .font(.title2)
                    .fontWeight(.medium)
                    .padding(.vertical, 10)

                    TextField(
                        "",
                        text: $item.street,
                        prompt: Text("*Street")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.red.opacity(0.5))
                    )
                    .disableAutocorrection(true)
                    .font(.title2)
                    .fontWeight(.medium)
                    .padding(.vertical, 10)
                    .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.streetTextFields.rawValue)


                    TextField(
                        "",
                        text: $item.locality,
                        prompt: Text("*City")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.red.opacity(0.5))
                    )
                    .disableAutocorrection(true)
                    .font(.title2)
                    .fontWeight(.medium)
                    .padding(.vertical, 10)
                    .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.cityTextFields.rawValue)

                    TextField(
                        "",
                        text: $item.region.orEmpty,
                        prompt: Text("Region/State")
                            .font(.title2)
                            .fontWeight(.medium)
                    )
                    .disableAutocorrection(true)
                    .font(.title2)
                    .fontWeight(.medium)
                    .padding(.vertical, 10)
                    .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.regionTextFields.rawValue)


                    TextField(
                        "",
                        text: $item.postalCode,
                        prompt: Text("*Post Code")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.red.opacity(0.5))
                    )
                    .disableAutocorrection(true)
                    .font(.title2)
                    .fontWeight(.medium)
                    .padding(.vertical, 10)
                    .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.postTextFields.rawValue)

                    VStack {
                        Button(action: { isPickerPresented = true }) {
                            HStack {
                                Text(item.country.isEmpty ? "* Select Country" : "\(item.country)")
                                    .foregroundColor(item.country.isEmpty ? .red.opacity(0.5) : .black)
                                    .font(.title2)
                                    .fontWeight(.medium)

                                Spacer()
                                Image(systemName: "chevron.down") // Adds a downward chevron icon
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 16)
                        }
                        .sheet(isPresented: $isPickerPresented) {
                            iCountryField(selectedCountry: $item.country, isPresented: $isPickerPresented)
                        }
                        .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.countryTextFields.rawValue)
                    }
                    .navigationTitle("Country Picker")
                    .navigationBarTitleDisplayMode(.inline)


                    if store.vCard.addresses.count > 1 {
                        HStack {

                            Spacer()

                            Text("Remove this address")
                                .font(.title2)
                                .fontWeight(.medium)
                                .padding()


                            Button {
                                store.send(.removeAddressSection(by: item.id))
                            } label: {
                                Image(systemName: "trash")
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .tint(Color.red)
                            }
                            .frame(width: 50, height: 50)
                            .padding(.trailing, -10)
                        }
                    }
                }
                .onDelete(perform: deleteAddress)
            } header: {
                HStack {
                    Text("Address")
                        .font(.title2)
                        .fontWeight(.medium)

                    Spacer()

                    if store.isCustomProduct {
                        Button {
                            store.send(.addOneMoreAddressSection)
                        } label: {
                            Image(systemName: "plus.square.on.square")
                                .resizable()
                                .frame(width: 30, height: 30)
                        }
                    } else {
                        Menu {
                            Text("To activate this function,")
                            Text("Please change your product type below.")
                            Button {
                                withAnimation(.easeInOut(duration: 90)) {
                                    scrollProxy.scrollTo(store.bottomID, anchor: .bottom)
                                }
                            } label: {
                                Text("click here to change your product type 👇🏼")
                            }
                        } label: {
                            Button {} label: {
                                Image(systemName: "plus.square.on.square")
                                    .resizable()
                                    .frame(width: 30, height: 30)
                            }
                            .disabled(!store.isCustomProduct)
                            .foregroundColor(store.isCustomProduct ? Color.blue : Color.gray)
                        }
                    }
                }
                .padding(.vertical, 10)
            }
        }
    }

    func deleteAddress(at offsets: IndexSet) {
        if store.vCard.addresses.count > 1 {
            store.vCard.addresses.remove(atOffsets: offsets)
        }
    }
}
