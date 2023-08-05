import BSON
import SwiftUI
import Foundation
import ImagePicker
import ECSharedModels
import ComposableStoreKit
import ComposableArchitecture
import SettingsFeature

public enum UITestGPFAccessibilityIdentifier: String {
    case orgText
    case jobTitleText
    case firstNameTextFields
    case middleNameTextFields
    case lastNameTextFields
    case telephoneNumberTextFields
    case emailTextFields
    case postOfficeTextFields
    case streetTextFields
    case cityTextFields
    case regionTextFields
    case postTextFields
    case countryTextFields
}

public struct GenericPassFormView: View {
    let store: StoreOf<GenericPassForm>

    struct ViewState: Equatable {

        @BindingViewState var vCard: VCard
        @BindingViewState var storeKitState: StoreKitReducer.State

        var avartarImage: UIImage?
        var cardImage: UIImage?
        var logoImage: UIImage?
        var isFormValid: Bool
        var isImagePickerPresented: Bool
        var isAuthorized: Bool
        var isActivityIndicatorVisible: Bool
        var isCustomProduct: Bool
        var bottomID: Int

        init(state: BindingViewStore<GenericPassForm.State>) {
            _vCard = state.$vCard
            _storeKitState = state.$storeKitState

            self.logoImage = state.logoImage
            self.avartarImage = state.avartarImage
            self.cardImage = state.cardImage

            self.isImagePickerPresented = state.imagePicker != nil
            self.isFormValid = state.vCard.isVCardValid

            self.isAuthorized = state.isAuthorized
            self.isActivityIndicatorVisible = state.isActivityIndicatorVisible
            self.isCustomProduct = state.storeKitState.type == .custom
            self.bottomID = state.bottomID
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
        WithViewStore(self.store, observe: ViewState.init) { viewStore in
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
                                    .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.orgText.rawValue)
                                }
                                .frame(height: 60)

                                Text("***Organization/company/self employee(put your name)")
                                    .font(.body)
                                    .foregroundColor(Color.gray)

                                TextField(
                                    "",
                                    text: viewStore.$vCard.position,
                                    prompt: Text("*Job title")
                                        .font(.body)
                                        .fontWeight(.medium)
                                )
                                .disableAutocorrection(true)
                                .font(.title2)
                                .fontWeight(.medium)
                                .padding(.vertical, 10)
                                .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.jobTitleText.rawValue)

                                HStack {
                                    cardImagePicker(viewStore, proxy, value)
                                    avatarImagePicker(viewStore, proxy)
                                }

                                Text("By incorporating your photo into a digital business card, your avatar will be displayed on Apple Wallet Pass, enabling others to instantly recognize you.")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(Color.gray)
                                .padding(.vertical, 5)

                            } header: {
                                Text("Uplod Images")
                                    .font(.title2)
                                    .fontWeight(.medium)
                            }

                            // MARK: ContactSectionView Body
                            contactSectionView(viewStore)

                            // MARK: TelephonesSectionView Body
                            telephoneSectionView(viewStore, value)

                            // MARK: EmailsSectionView Body
                            emailsSectionView(viewStore, value)

                            // MARK: - AddressesSectionView Body
                            addressesSectionView(viewStore, value)

                            //MARK: WebSite
                            webSiteSectionView(viewStore)

                            Group {
                                Picker("Choice Product Type 👉🏼", selection: viewStore.$storeKitState.type) {
                                    ForEach(StoreKitReducer.State.ProductType.allCases) { option in
                                        Text(option.rawValue.uppercased())
                                            .font(.title2)
                                            .fontWeight(.medium)
                                            .padding(.vertical, 10)
                                    }
                                }
                                .animation(.easeIn, value: 190)

                            }

                            //MARK: Pick card desgin
                            Section {
                                Button {
                                    // tapped func
                                    viewStore.send(.dcdSheetIsPresentedButtonTapped, animation: .default)
                                } label: {

                                    HStack {
                                        Text("Pick or Preview")
                                            .font(.title)
                                            .foregroundColor(viewStore.isCustomProduct ? Color.blue :  Color.gray)
                                            .fontWeight(.heavy)
                                        Text("Your ")
                                            .font(.title2)
                                            .foregroundColor(viewStore.isCustomProduct ? Color.white : Color.gray)
                                            .fontWeight(.bold)
                                        Text("Card Design")
                                            .font(.title)
                                            .foregroundColor(viewStore.isCustomProduct ? Color.pink : Color.gray)
                                            .fontWeight(.heavy)
                                    }
                                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0)
                                    .padding(.horizontal, 10)


                                    if !viewStore.isCustomProduct {
                                        Text("To activate this function,")
                                        Text("Please change your product type up☝️.")
                                    }
                                }
                                .animation(.easeIn, value: 190)

                            }
                            .disabled(!viewStore.isCustomProduct)
                            .listRowBackground(viewStore.isCustomProduct ? Color.yellow : Color.gray.opacity(0.3))

                            //MARK: Payment
                            
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
                                    .buttonStyle(BorderlessButtonStyle())
                                    .accessibility(identifier: "pay_button")

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
                        .sheet(
                            store: store.scope(
                                state: \.$digitalCardDesign,
                                action: GenericPassForm.Action.digitalCardDesign
                            ),
                            content: CardDesignListView.init(store:)
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

    // MARK: - logoImagePicker func
    fileprivate func logoImagePicker(_ viewStore: ViewStore<ViewState, GenericPassForm.Action>, _ proxy: GeometryProxy) -> some View {
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
        .buttonStyle(BorderlessButtonStyle())
    }

    // MARK: - cardImagePicker func
    @ViewBuilder
    fileprivate func cardImagePicker(_ viewStore: ViewStore<ViewState, GenericPassForm.Action>, _ proxy: GeometryProxy, _ value: ScrollViewProxy) -> some View {

        if viewStore.isCustomProduct {
            if let uiImage = viewStore.cardImage {
                Button {
                    viewStore.send(.isImagePicker(isPresented: true))
                    viewStore.send(.imageFor(.card))
                } label: {
                    Image(uiImage: uiImage)
                        .resizable()
                        .cornerRadius(15)
                        .overlay(alignment: .bottomTrailing) {
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
                        .frame(width: proxy.size.width / 2.3,   height: 200)
                }
                .buttonStyle(BorderlessButtonStyle())

            } else {
                VStack {
                    Button {
                        viewStore.send(.isImagePicker(isPresented: true))
                        viewStore.send(.imageFor(.card))
                    } label: {
                        VStack {
                            Image(systemName: "arrow.up.doc.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .padding()

                            Text("Upload visiting old card.")
                                .font(.body)
                                .fontWeight(.medium)
                                .padding(.horizontal, 15)
                        }
                    }

                    .foregroundColor(.gray)
                    .frame(width: proxy.size.width / 2.3,   height: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.gray, style: StrokeStyle(lineWidth: 3, dash: [9]))
                            .padding(5)
                    )
                    .buttonStyle(BorderlessButtonStyle())
                }
                .frame(width: proxy.size.width / 2.3,   height: 200)
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

                VStack {
                    Button {
                        viewStore.send(.isImagePicker(isPresented: true))
                        viewStore.send(.imageFor(.card))
                    } label: {
                        VStack {
                            Image(systemName: "arrow.up.doc.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .padding()

                            Text("Upload visiting old card.")
                                .font(.title2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 15)
                        }
                    }
                    .disabled(!viewStore.isCustomProduct)
                    .foregroundColor(viewStore.isCustomProduct ? Color.blue : Color.gray)
                    .frame(width: proxy.size.width / 2.3,   height: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.gray, style: StrokeStyle(lineWidth: 3, dash: [9]))
                            .padding(5)
                    )
                    .buttonStyle(BorderlessButtonStyle())
                }
                .frame(width: proxy.size.width / 2.3,   height: 200)



            }
        }
    }

    // MARK: - avatarImagePicker func
    @ViewBuilder
    fileprivate func avatarImagePicker(_ viewStore: ViewStore<ViewState, GenericPassForm.Action>, _ proxy: GeometryProxy) -> some View {
        if let uiImage = viewStore.avartarImage {
            Image(uiImage: uiImage)
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
                    .buttonStyle(BorderlessButtonStyle())
                }
                .frame(width: proxy.size.width / 2.3,   height: 200)

        } else {
            Button {
                viewStore.send(.isImagePicker(isPresented: true))
                viewStore.send(.imageFor(.avatar))
            } label: {
                VStack {
                    Image(systemName: "person.fill.viewfinder")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .padding()
                        .cornerRadius(15)

                    Text("*Avatar")
                        .font(.title2)
                        .fontWeight(.medium)
                }
            }
            .foregroundColor(.gray)
            .frame(width: proxy.size.width / 2.3,   height: 200)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.gray, style: StrokeStyle(lineWidth: 3, dash: [9]))
                    .padding(5)
            )
            .buttonStyle(BorderlessButtonStyle())
        }
    }

    // MARK: - contactSectionView func
    @MainActor
    fileprivate func contactSectionView(_ viewStore: ViewStore<ViewState, GenericPassForm.Action>) -> some View {

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
            .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.firstNameTextFields.rawValue)



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
            .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.middleNameTextFields.rawValue)

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
            .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.lastNameTextFields.rawValue)

        } header: {
            Text("Contact")
                .font(.title2)
                .fontWeight(.medium)
        }

    }


    // MARK: telephoneSectionView func
    fileprivate func telephoneSectionView(_ viewStore: ViewStore<ViewState, GenericPassForm.Action>, _ value: ScrollViewProxy) -> some View {
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
                        prompt: Text("*Telephone Number (+70000000000)")
                            .font(.title2)
                            .fontWeight(.medium)
                    )
                    .keyboardType(.phonePad)
                    .disableAutocorrection(true)
                    .font(.title2)
                    .fontWeight(.medium)
                    .padding(.vertical, 10)
                    .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.telephoneNumberTextFields.rawValue)


                    Spacer()

                    if viewStore.vCard.telephones.count > 1 {
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

    // MARK: EmailsSectionView func
    fileprivate func emailsSectionView(_ viewStore: ViewStore<ViewState, GenericPassForm.Action>, _ value: ScrollViewProxy) -> some View {
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
                    .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.emailTextFields.rawValue)

                    if viewStore.$vCard.emails.count > 1 {
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

    // MARK: URLsSectionView func
    fileprivate func webSiteSectionView(_ viewStore: ViewStore<ViewState, GenericPassForm.Action>) -> some View {
        Section {
            HStack {
                TextField(
                    "",
                    text: viewStore.$vCard.website.orEmpty,
                    prompt: Text("WebSite")
                        .font(.title2)
                        .fontWeight(.medium)
                )
                .keyboardType(.URL)
                .textContentType(.URL)
                .disableAutocorrection(true)
                .font(.title2)
                .fontWeight(.medium)
                .padding(.vertical, 10)

            }

        } header: {
            HStack {
                Text("Web site ?OPTIONAL")
                    .font(.title2)
                    .fontWeight(.medium)
            }
            .padding(.vertical, 10)
        }
    }

    // MARK: AddressesSectionView
    fileprivate func addressesSectionView(_ viewStore: ViewStore<ViewState, GenericPassForm.Action>, _ value: ScrollViewProxy) -> some View {
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
                    text: item.postOfficeAddress.orEmpty,
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
                .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.streetTextFields.rawValue)


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
                .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.cityTextFields.rawValue)



                TextField(
                    "",
                    text: item.region.orEmpty,
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
                .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.postTextFields.rawValue)


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
                .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.countryTextFields.rawValue)


                if viewStore.$vCard.addresses.count > 1 {
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

private func cost(product: StoreKitClient.Product) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = product.priceLocale
    return formatter.string(from: product.price) ?? ""
}
