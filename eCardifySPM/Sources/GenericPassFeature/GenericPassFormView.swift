import BSON
import SwiftUI
import Foundation
import ImagePicker
import ECardifySharedModels
import ComposableArchitecture
import ComposableStoreKit

public struct GenericPassFormView: View {
    let store: StoreOf<GenericPassForm>

    struct ViewState: Equatable {

        @BindingViewState var vCard: VCard
        var avartarImage: UIImage?
        var cardImage: UIImage?
        var logoImage: UIImage?
        var isFormValid: Bool
        var isImagePickerPresented: Bool
        var isAuthorized: Bool
        var isActivityIndicatorVisible: Bool
        var storeKitState: StoreKitReducer.State

        init(state: BindingViewStore<GenericPassForm.State>) {

            _vCard = state.$vCard

            self.logoImage = state.logoImage
            self.avartarImage = state.avartarImage
            self.cardImage = state.cardImage

            self.isImagePickerPresented = state.imagePicker != nil
            self.isFormValid = state.vCard.imageURLs.count >= 3

            self.isAuthorized = state.isAuthorized
            self.isActivityIndicatorVisible = state.isActivityIndicatorVisible
            self.storeKitState = state.storeKitState

        }

    }

    public init(store: StoreOf<GenericPassForm>) {
        self.store = store
    }

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    // MARK: - BODY
    public var body: some View {
        WithViewStore(self.store) { viewStore in
            GeometryReader { proxy in
                ScrollViewReader { value in
                    ZStack(alignment: .center) {
                        Form {

                            Section {
                                HStack {
                                    logoImagePicker(viewStore, proxy)

                                    TextField(
                                        "",
                                        text: viewStore.$vCard.organization.orEmpty,
                                        prompt: Text("***Org/Company Name")
                                            .font(.body)
                                            .fontWeight(.medium)

                                    )
                                    .disableAutocorrection(true)
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .padding(.vertical, 10)
                                }
                                .frame(height: 60)
                                Text("***Organization/company/self employee(put your name)")
                                    .font(.body)
                                    .foregroundColor(Color.gray)

                                HStack {
                                    cardImagePicker(viewStore, proxy)

                                    avatarImagePicker(viewStore, proxy)
                                }

                            } header: {
                                Text("Uplod Images")
                                    .font(.title2)
                                    .fontWeight(.medium)
                            }

                            contactSectionView(viewStore)

                            telephonesSectionView(viewStore, value)

                            emailsSectionView(viewStore, value)

                            addressesSectionView(viewStore, value)

                            Group {
                                Picker("Choice Product Type 👉🏼", selection: viewStore.$storeKitState.type) {
                                    ForEach(StoreKitReducer.State.ProductType.allCases) { option in
                                        Text(option.rawValue.uppercased())
                                            .font(.title2)
                                            .fontWeight(.medium)
                                            .padding(.vertical, 10)
                                    }
                                }

                            }

                            HStack {

                                if let product = viewStore.storeKitState.product {
                                    VStack(alignment: .leading) {
                                        Text(product.localizedTitle)
                                            .font(.title2)
                                            .fontWeight(.medium)

                                        Text(product.localizedDescription)
                                            .font(.body)

                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)


                                    Spacer()

                                    Button {
                                        viewStore.send(.createPass)
                                    } label: {
                                        Text("Pay \(cost(product: product)) and Create")
                                            .font(.title2)
                                            .fontWeight(.medium)
                                            .padding(10)
                                    }
                                    .background(viewStore.isFormValid ? Color.blue : Color.red)
                                    .foregroundColor(viewStore.isFormValid ? Color.white : Color.white.opacity(0.3))
                                    .disabled(!viewStore.isFormValid)
                                    .cornerRadius(9)

                                } else {
                                    ProgressView()
                                        .tint(.blue)
                                        .scaleEffect(3)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }

                            }
                            .padding(.vertical, 20)
                            .id(viewStore.bottomID)

                        }
                        .navigationTitle("Create digital card 🪪!")
                        .redacted(reason: viewStore.isActivityIndicatorVisible ? .placeholder : .init())
                        .allowsHitTesting(!viewStore.isActivityIndicatorVisible)
                        .background(
                            viewStore.isActivityIndicatorVisible == true
                            ? Color.black.opacity(0.9)
                            : Color.white
                        )
                        .onAppear {
                            viewStore.send(.onAppear)
                        }
                        .sheet(
                            store: store.scope(
                                state: \.$imagePicker,
                                action: GenericPassForm.Action.imagePicker
                            ),
                            content: ImagePickerView.init(store:)
                        )

                        if viewStore.isActivityIndicatorVisible {
                            VStack {
                                ProgressView()
                                    .tint(.blue)
                                    .scaleEffect(4)
                                    .padding()
                                    .foregroundColor(Color.white)
                                Text("Generating your Digital card! Please wait")
                                    .font(.system(size: 23, weight: .bold, design: .rounded))
                                    .padding()
                                    .foregroundColor(Color.white)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - logoImagePicker
    fileprivate func logoImagePicker(_ viewStore: ViewStore<GenericPassForm.State, GenericPassForm.Action>, _ proxy: GeometryProxy) -> some View {
        Button {
            viewStore.send(.isImagePicker(isPresented: true))
            viewStore.send(.imageFor(.logo))
        } label: {
            if let logoImage = viewStore.logoImage {
                Image(uiImage: logoImage)
                    .resizable()
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .padding()
            } else {

                Image(
                    uiImage: (UIImage(named: "logo.jpg")
                              ?? UIImage(systemName: "infinity.circle"))!
                )
                .resizable()
                .frame(width: 60, height: 60)
                .padding(.vertical, 40)

            }
        }
    }

    // MARK: - cardImagePicker
    @ViewBuilder
    fileprivate func cardImagePicker(_ viewStore: ViewStore<GenericPassForm.State, GenericPassForm.Action>, _ proxy: GeometryProxy ) -> some View {
        if viewStore.cardImage == nil {
            VStack {
                Button {
                    viewStore.send(.isImagePicker(isPresented: true))
                    viewStore.send(.imageFor(.card))
                } label: {
                    Image(systemName: "arrow.up.doc.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .padding()

                    Text("Upload visiting old card.")
                        .font(.body)
                        .fontWeight(.medium)
                        .padding(.horizontal, 15)
                }
                .foregroundColor(.gray)
                .frame(width: proxy.size.width / 2.3,   height: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.gray, style: StrokeStyle(lineWidth: 3, dash: [9]))
                        .padding(5)
                )

            }
            .frame(width: proxy.size.width / 2.3,   height: 200)

        } else {

            Button {
                viewStore.send(.isImagePicker(isPresented: true))
                viewStore.send(.imageFor(.card))
            } label: {

                Image(systemName: "rectangle.badge.checkmark")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .padding()
            }
            .frame(width: proxy.size.width / 2.3,   height: 200)
        }

    }

    // MARK: - avatarImagePicker
    @ViewBuilder
    fileprivate func avatarImagePicker(_ viewStore: ViewStore<GenericPassForm.State, GenericPassForm.Action>, _ proxy: GeometryProxy) -> some View {
        if let uiimage = viewStore.avartarImage {
            Image(uiImage: uiimage)
                .resizable()
                .cornerRadius(15)
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        viewStore.send(.isImagePicker(isPresented: true))
                        viewStore.send(.imageFor(.avatar))
                    } label: {
                        Image(systemName: "rectangle.2.swap")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .padding(15)

                    }
                }
                .frame(width: proxy.size.width / 2.3,   height: 200)

        } else {
            Button {
                viewStore.send(.isImagePicker(isPresented: true))
                viewStore.send(.imageFor(.avatar))
            } label: {
                Image(systemName: "person.fill.viewfinder")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .padding()
                    .cornerRadius(15)

                Text("*Avatar")
                    .font(.title2)
                    .fontWeight(.medium)
            }
            .foregroundColor(.gray)
            .frame(width: proxy.size.width / 2.3,   height: 200)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.gray, style: StrokeStyle(lineWidth: 3, dash: [9]))
                    .padding(5)
            )
        }
    }

    // MARK: - contactSectionView
    @MainActor
    fileprivate func contactSectionView(_ viewStore: ViewStore<GenericPassForm.State, GenericPassForm.Action>) -> some View {

        Section {

            TextField(
                "",
                text: viewStore.$vCard.contact.firstName,
                prompt: Text("*First Name")
                    .font(.title2)
                    .fontWeight(.medium)
            )
            .disableAutocorrection(true)
            .font(.title2)
            .fontWeight(.medium)
            .padding(.vertical, 10)


            TextField(
                "",
                text: viewStore.$vCard.contact.additionalName.orEmpty,
                prompt: Text("Middle Name")
                    .font(.title2)
                    .fontWeight(.medium)
            )
            .disableAutocorrection(true)
            .font(.title2)
            .fontWeight(.medium)
            .padding(.vertical, 10)

            TextField(
                "",
                text: viewStore.$vCard.contact.lastName,
                prompt: Text("*Last Name")
                    .font(.title2)
                    .fontWeight(.medium)
            )
            .disableAutocorrection(true)
            .font(.title2)
            .fontWeight(.medium)
            .padding(.vertical, 10)

        } header: {
            Text("Contact")
                .font(.title2)
                .fontWeight(.medium)
        }

    }

    // MARK: - telephonesSectionView
    @MainActor
    fileprivate func telephonesSectionView(_ viewStore: ViewStore<GenericPassForm.State, GenericPassForm.Action>, _ value: ScrollViewProxy) -> some View {
        Section {

            ForEach(viewStore.$vCard.telephones, id: \.id) { item in

                Picker("Device Type", selection: item.type) {

                    ForEach(VCard.Telephone.TType.allCases) { option in
                        Text(option.rawValue.uppercased())
                            .font(.title2)
                            .fontWeight(.medium)
                            .padding(.vertical, 10)

                    }
                }

                HStack {

                    TextField(
                        "",
                        text: item.number,
                        prompt: Text("*Telephone Number")
                            .font(.title2)
                            .fontWeight(.medium)
                    )
                    .keyboardType(.phonePad)
                    .disableAutocorrection(true)
                    .font(.title2)
                    .fontWeight(.medium)
                    .padding(.vertical, 10)

                    Spacer()

                    Button {
                        viewStore.send(.removeTelephoneSection(by: item.id))
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

        } header: {
            HStack {
                Text("Telephone")
                    .font(.title2)
                    .fontWeight(.medium)

                Spacer()

                if viewStore.isCustomProduct {
                    Button {
                        viewStore.send(.addOneMoreTelephoneSection)
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
                                value.scrollTo(viewStore.bottomID, anchor: .bottom)
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
                        .disabled(!viewStore.isCustomProduct)
                        .foregroundColor(viewStore.isCustomProduct ? Color.blue : Color.gray)
                    }
                }

            }
            .padding(.vertical, 10)
        }
    }

    // MARK: - emailsSectionView
    @MainActor
    fileprivate func emailsSectionView(_ viewStore: ViewStore<GenericPassForm.State, GenericPassForm.Action>, _ value: ScrollViewProxy) -> some View {
        Section {
            ForEach(viewStore.$vCard.emails, id: \.id) { item in
                HStack {
                    TextField(
                        "",
                        text: item.text,
                        prompt: Text("*Email")
                            .font(.title2)
                            .fontWeight(.medium)
                    )
                    .keyboardType(.emailAddress)
                    .disableAutocorrection(true)
                    .font(.title2)
                    .fontWeight(.medium)
                    .padding(.vertical, 10)

                    Button {
                        viewStore.send(.removeEmailSection(by: item.id))
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
        } header: {
            HStack {
                Text("Email")
                    .font(.title2)
                    .fontWeight(.medium)

                Spacer()

                if viewStore.isCustomProduct {
                    Button {
                        viewStore.send(.addOneMoreEmailSection)
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
                                value.scrollTo(viewStore.bottomID, anchor: .bottom)
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
                        .disabled(!viewStore.isCustomProduct)
                        .foregroundColor(viewStore.isCustomProduct ? Color.blue : Color.gray)
                    }
                }
            }
            .padding(.vertical, 10)
        }
    }

    // MARK: - addressesSectionView
    @MainActor
    fileprivate func addressesSectionView(_ viewStore: ViewStore<GenericPassForm.State, GenericPassForm.Action>, _ value: ScrollViewProxy) -> some View {
        Section {
            ForEach(viewStore.$vCard.addresses, id: \.id) { item in

                Picker("Address Type", selection: item.type) {
                    ForEach(VCard.Address.AType.allCases) { option in
                        Text(option.rawValue.uppercased())
                            .font(.title2)
                            .fontWeight(.medium)
                            .padding(.vertical, 10)
                    }
                }

                TextField(
                    "",
                    text: item.postOfficeAddress,
                    prompt: Text("*PostOffice")
                        .font(.title2)
                        .fontWeight(.medium)
                )
                .disableAutocorrection(true)
                .font(.title2)
                .fontWeight(.medium)
                .padding(.vertical, 10)

                TextField(
                    "",
                    text: item.extendedAddress.orEmpty,
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
                    text: item.street,
                    prompt: Text("*Street")
                        .font(.title2)
                        .fontWeight(.medium)
                )
                .disableAutocorrection(true)
                .font(.title2)
                .fontWeight(.medium)
                .padding(.vertical, 10)

                TextField(
                    "",
                    text: item.locality,
                    prompt: Text("*City")
                        .font(.title2)
                        .fontWeight(.medium)
                )
                .disableAutocorrection(true)
                .font(.title2)
                .fontWeight(.medium)
                .padding(.vertical, 10)


                TextField(
                    "",
                    text: item.region.orEmpty,
                    prompt: Text("*Region/State")
                        .font(.title2)
                        .fontWeight(.medium)
                )
                .disableAutocorrection(true)
                .font(.title2)
                .fontWeight(.medium)
                .padding(.vertical, 10)

                TextField(
                    "",
                    text: item.postalCode,
                    prompt: Text("*Post Code")
                        .font(.title2)
                        .fontWeight(.medium)
                )
                .keyboardType(.phonePad)
                .disableAutocorrection(true)
                .font(.title2)
                .fontWeight(.medium)
                .padding(.vertical, 10)

                TextField(
                    "",
                    text: item.country,
                    prompt: Text("*Country")
                        .font(.title2)
                        .fontWeight(.medium)
                )
                .disableAutocorrection(true)
                .font(.title2)
                .fontWeight(.medium)
                .padding(.vertical, 10)

                HStack {

                    Spacer()

                    Text("Remove this address")
                        .font(.title2)
                        .fontWeight(.medium)
                        .padding()


                    Button {
                        viewStore.send(.removeAddressSection(by: item.id))
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
        } header: {
            HStack {
                Text("Address")
                    .font(.title2)
                    .fontWeight(.medium)

                Spacer()

                if viewStore.isCustomProduct {
                    Button {
                        viewStore.send(.addOneMoreAddressSection)
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
                                value.scrollTo(viewStore.bottomID, anchor: .bottom)
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
                        .disabled(!viewStore.isCustomProduct)
                        .foregroundColor(viewStore.isCustomProduct ? Color.blue : Color.gray)
                    }
                }
            }
            .padding(.vertical, 10)
        }
    }
}

#if DEBUG
struct GenericPassFormView_Previews: PreviewProvider {
    static var previews: some View {
        GenericPassFormView(store: StoreOf<GenericPassForm>(
            initialState: GenericPassForm.State(storeKitState: .init(), vCard: VCard.empty),
            reducer: GenericPassForm()
        ))
    }
}
#endif


import ComposableStoreKit

private func cost(product: StoreKitClient.Product) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = product.priceLocale
    return formatter.string(from: product.price) ?? ""
}

