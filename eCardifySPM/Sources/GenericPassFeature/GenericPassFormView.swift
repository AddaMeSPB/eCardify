import BSON
import ImagePicker
import SwiftUI
import Foundation
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
    @Perception.Bindable var store: StoreOf<GenericPassForm>

    public init(store: StoreOf<GenericPassForm>) {
        self.store = store
    }

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    // MARK: - BODY
    public var body: some View {
        WithPerceptionTracking {
            GeometryReader { proxy in
                ScrollViewReader { value in
                    ZStack(alignment: .center) {
                        WithPerceptionTracking {
                            Form {
                                Section {
                                    HStack {
                                        
                                        
                                        TextField(
                                            "",
                                            text: $store.vCard.organization.orEmpty,
                                            prompt: Text("***Org or Company Name")
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
                                    
                                    Text("***Organization/Company/self employee(put your name)")
                                        .foregroundColor(Color.gray)
                                    
                                    TextField(
                                        "",
                                        text: $store.vCard.position,
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
                                        cardImagePicker(proxy, value)
                                        avatarImagePicker(proxy)
                                    }
                                    
                                    Text("By incorporating your photo into a digital business card, your avatar will be displayed on Apple Wallet Pass, enabling others to instantly recognize you.")
                                        .font(.headline)
                                        .fontWeight(.medium)
                                        .foregroundColor(Color.gray)
                                        .padding(.vertical, 5)
                                    
                                } header: {
                                    Text("Upload Images")
                                        .font(.title2)
                                        .fontWeight(.medium)
                                }
                                
                                // MARK: ContactSectionView Body
                                contactSectionView()
                                
                                // MARK: TelephonesSectionView Body
                                telephoneSectionView(value)
                                
                                // MARK: EmailsSectionView Body
                                emailsSectionView(value)
                                
                                // MARK: - AddressesSectionView Body
                                addressesSectionView(value)
                                
                                //MARK: WebSite
                                webSiteSectionView()
                                
                                Group {
                                    Picker("Choice Product Type 👉🏼", selection: $store.storeKitState.type) {
                                        ForEach(StoreKitReducer.State.ProductType.allCases) { option in

                                            Text(option.rawValue.uppercased())
                                                .font(.title2)
                                                .fontWeight(.medium)
                                                .padding(.vertical, 10)

                                        }
                                    }
                                    .animation(.easeIn, value: 190)
                                    
                                }
                                
                                //MARK: Pick Card Design
                                Section {
                                    Button {
                                        // tapped func
                                        store.send(.dcdSheetIsPresentedButtonTapped, animation: .default)
                                    } label: {
                                        
                                        HStack {
                                            Text("Pick or Preview")
                                                .font(.title)
                                                .foregroundColor(store.isCustomProduct ? Color.blue :  Color.gray)
                                                .fontWeight(.heavy)
                                            Text("Your ")
                                                .font(.title2)
                                                .foregroundColor(store.isCustomProduct ? Color.white : Color.gray)
                                                .fontWeight(.bold)
                                            Text("Card Design")
                                                .font(.title)
                                                .foregroundColor(store.isCustomProduct ? Color.pink : Color.gray)
                                                .fontWeight(.heavy)
                                        }
                                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0)
                                        .padding(.horizontal, 10)
                                        
                                        
                                        if !store.isCustomProduct {
                                            Text("To activate this function,")
                                            Text("Please change your product type up☝️.")
                                        }
                                    }
                                    .animation(.easeIn, value: 190)
                                    
                                }
                                .disabled(!store.isCustomProduct)
                                .listRowBackground(store.isCustomProduct ? Color.yellow : Color.gray.opacity(0.3))
                                
                                //MARK: Payment
                                
                                VStack(alignment: .trailing, spacing: 10)  {
                                    
                                    if let product = store.storeKitState.product {

                                            Button {
                                                store.send(.createPass)
                                            } label: {
                                                Text(store.storeKitState.isPurchasing 
                                                     ? "     "
                                                     : "Pay \(cost(product: product)) and Create")
                                                    .font(.title3)
                                                    .fontWeight(.medium)
                                                    .minimumScaleFactor(0.5)
                                                    .padding(10)
                                                    .overlay(
                                                        Group {
                                                            if store.storeKitState.isPurchasing {
                                                                ProgressView().tint(Color.white)
                                                            }
                                                        }
                                                    )
                                            }
                                            .background(store.isFormValid ? Color.blue : Color.red)
                                            .foregroundColor(store.isFormValid ? Color.white : Color.white.opacity(0.3))
                                            .disabled(!store.isFormValid)
                                            .cornerRadius(9)
                                            .buttonStyle(BorderlessButtonStyle())
                                            .accessibility(identifier: "pay_button")
                                            
                                            Text(product.localizedTitle)
                                                .font(.title2)
                                                .fontWeight(.medium)
                                            
                                            Text(product.localizedDescription)
                                                .font(.body)
                                                .frame(maxWidth: .infinity, alignment: .trailing)

                                        
                                    } else {
                                        ProgressView()
                                            .tint(.blue)
                                            .scaleEffect(3)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .padding()
                                    }
                                    
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .id(store.bottomID)
                                
                            }
                            .navigationTitle("Create digital card 🪪!")
                            .redacted(reason: store.isActivityIndicatorVisible ? .placeholder : .init())
                            .allowsHitTesting(!store.isActivityIndicatorVisible)
                            .background(
                                store.isActivityIndicatorVisible == true
                                ? Color.black.opacity(0.9)
                                : Color.white
                            )
                            .onAppear {
                                store.send(.onAppear)
                            }
                            .alert($store.scope(state: \.alert, action: \.alert))
                            .sheet(
                                store: store.scope(state: \.$imagePicker, action: \.imagePicker),
                                content: ImagePickerView.init(store:)
                            )
                            .sheet(
                                store: store.scope(state: \.$digitalCardDesign, action: \.digitalCardDesign),
                                content: CardDesignListView.init(store:)
                            )
                            
                            if store.isActivityIndicatorVisible {
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
    }

    // MARK: - CardImagePicker
    @ViewBuilder
    fileprivate func cardImagePicker(_ proxy: GeometryProxy, _ value: ScrollViewProxy) -> some View {
        WithPerceptionTracking {
            VStack {
                if store.isCustomProduct {
                    if let uiImage = store.cardImage {
                        Button {
                            store.send(.isImagePicker(isPresented: true))
                            store.send(.imageFor(.card))
                        } label: {
                            Image(uiImage: uiImage)
                                .resizable()
                                .cornerRadius(15)
                                .overlay(alignment: .bottomTrailing) {
                                    Button {
                                        store.send(.isImagePicker(isPresented: true))
                                        store.send(.imageFor(.card))
                                    } label: {

                                        Image(systemName: "rectangle.badge.checkmark")
                                            .resizable()
                                            .frame(width: 60, height: 60)
                                            .padding()
                                    }
                                    .frame(width: proxy.size.width / 2.3,   height: 200)
                                }
                        }
                        .frame(width: proxy.size.width / 2.3,   height: 200)
                        //.buttonStyle(BorderlessButtonStyle())

                    } else {
                        VStack {
                            Button {
                                store.send(.isImagePicker(isPresented: true))
                                store.send(.imageFor(.card))
                            } label: {
                                VStack {
                                    Text("Upload old card.")
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 15)
                                }
                            }
                            .foregroundColor(.gray)
                            .frame(width: proxy.size.width / 2.3,   height: 98)
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
                                value.scrollTo(store.bottomID, anchor: .bottom)
                            }
                        } label: {
                            Text("click here to change your product type 👇🏼")
                        }
                    } label: {

                        Button {
                            store.send(.isImagePicker(isPresented: true))
                            store.send(.imageFor(.card))
                        } label: {
                            Text("Upload old card")
                                .font(.title3)
                                .fontWeight(.medium)
                                .padding(.horizontal, 15)
                        }
                        .disabled(!store.isCustomProduct)
                        .foregroundColor(store.isCustomProduct ? Color.blue : Color.gray)
                        .frame(width: proxy.size.width / 2.3,   height: 98)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.gray, style: StrokeStyle(lineWidth: 3, dash: [9]))
                                .padding(5)
                        )
                        .buttonStyle(BorderlessButtonStyle())

                    }
                }

                Button {
                    store.send(.isImagePicker(isPresented: true))
                    store.send(.imageFor(.logo))
                } label: {
                    if let logoImage = store.logoImage {
                        Image(uiImage: logoImage)
                            .resizable()
                            .resizable()
                            .cornerRadius(15)
                            .frame(width: proxy.size.width / 2.3,   height: 96)
                    } else {
                        Text("*Upload logo")
                            .font(.title3)
                            .fontWeight(.medium)
                            .padding(.horizontal, 15)
                    }
                }
                .frame(width: proxy.size.width / 2.3,   height: 98)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.gray, style: StrokeStyle(lineWidth: 3, dash: [9]))
                        .padding(5)
                )
                .buttonStyle(BorderlessButtonStyle())


            }.frame(width: proxy.size.width / 2.3,   height: 200)
        }
    }

    // MARK: - avatarImagePicker func
    @ViewBuilder
    fileprivate func avatarImagePicker(_ proxy: GeometryProxy) -> some View {
        WithPerceptionTracking {
            if let uiImage = store.avatarImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .cornerRadius(15)
                    .overlay(alignment: .bottomTrailing) {
                        Button {
                            store.send(.isImagePicker(isPresented: true))
                            store.send(.imageFor(.avatar))
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
                    store.send(.isImagePicker(isPresented: true))
                    store.send(.imageFor(.avatar))
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
                .frame(width: proxy.size.width / 2.3,   height: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.gray, style: StrokeStyle(lineWidth: 3, dash: [9]))
                        .padding(5)
                )
                .buttonStyle(BorderlessButtonStyle())
            }
        }
    }

    // MARK: - contactSectionView func
    @MainActor
    fileprivate func contactSectionView() -> some View {
        WithPerceptionTracking {
            Section {

                TextField(
                    "",
                    text: $store.vCard.contact.firstName,
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
                    text: $store.vCard.contact.additionalName.orEmpty,
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
                    text: $store.vCard.contact.lastName,
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
    }

    // MARK: telephoneSectionView func
    @ViewBuilder
    fileprivate func telephoneSectionView(_ value: ScrollViewProxy) -> some View {
        WithPerceptionTracking {
            Section {

                ForEach($store.vCard.telephones, id: \.id) { item in

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

                        if store.vCard.telephones.count > 1 {
                            Button {
                                store.send(.removeTelephoneSection(by: item.id))
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

                    if store.isCustomProduct {
                        Button {
                            store.send(.addOneMoreTelephoneSection)
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
                                    value.scrollTo(store.bottomID, anchor: .bottom)
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

    // MARK: EmailsSectionView func
    @ViewBuilder
    fileprivate func emailsSectionView(_ value: ScrollViewProxy) -> some View {
        WithPerceptionTracking {
            Section {
                ForEach($store.vCard.emails, id: \.id) { item in
                    HStack {
                        TextField(
                            "",
                            text: item.text,
                            prompt: Text("*Email")

                        )
                        .font(.title2)
                        .fontWeight(.medium)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .padding(.vertical, 10)
                        .disableAutocorrection(true)
                        .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.emailTextFields.rawValue)

                        if $store.vCard.emails.count > 1 {
                            Button {
                                store.send(.removeEmailSection(by: item.id))
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

                    if store.isCustomProduct {
                        Button {
                            store.send(.addOneMoreEmailSection)
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
                                    value.scrollTo(store.bottomID, anchor: .bottom)
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

    // MARK: URLsSectionView func
    @ViewBuilder
    fileprivate func webSiteSectionView() -> some View {
        WithPerceptionTracking {
            Section {
                HStack {
                    TextField(
                        "",
                        text: $store.vCard.website.orEmpty,
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
    }

    // MARK: AddressesSectionView
    @ViewBuilder
    fileprivate func addressesSectionView(_ value: ScrollViewProxy) -> some View {
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
                    )
                    .keyboardType(.phonePad)
                    .disableAutocorrection(true)
                    .font(.title2)
                    .fontWeight(.medium)
                    .padding(.vertical, 10)
                    .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.postTextFields.rawValue)


                    TextField(
                        "",
                        text: $item.country,
                        prompt: Text("*Country")
                            .font(.title2)
                            .fontWeight(.medium)
                    )
                    .disableAutocorrection(true)
                    .font(.title2)
                    .fontWeight(.medium)
                    .padding(.vertical, 10)
                    .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.countryTextFields.rawValue)


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
                                    value.scrollTo(store.bottomID, anchor: .bottom)
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
}

struct GenericPassFormView_Previews: PreviewProvider {

    static var store = Store(initialState: GenericPassForm.State(storeKitState: .demoProducts, vCard: .demo)) {
        GenericPassForm()
    } withDependencies: {
        $0.attachmentS3Client = .happyPath
    }

//    @Dependency(\.build) var build
//    @Dependency(\.apiClient) var apiClient
//    @Dependency(\.userDefaults) var userDefaults
//    @Dependency(\.keychainClient) var keychainClient
//    @Dependency(\.vnRecognizeClient) var vnRecognizeClient
//    @Dependency(\.attachmentS3Client) var attachmentS3Client
//    @Dependency(\.localDatabase) var localDatabase
//    @Dependency(\.dismiss) var dismass

    static var previews: some View {
        GenericPassFormView(store: store)
    }
}

private func cost(product: StoreKitClient.Product) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = product.priceLocale
    return formatter.string(from: product.price) ?? ""
}

extension StoreKitReducer.State {
    static public var demoProducts: Self = .init(products: [ .basic, .flexiCard])
}

extension StoreKitClient.Product {
  static let basic = Self(
    downloadContentLengths: [],
    downloadContentVersion: "",
    isDownloadable: false,
    localizedDescription: "Basic version of product has fixed design!",
    localizedTitle: "Basic Card!",
    price: 3,
    priceLocale: .init(identifier: "en_US"),
    productIdentifier: "cardify.addame.com.eCardify.BasicCard.testing"
  )
    static let flexiCard = Self(
      downloadContentLengths: [],
      downloadContentVersion: "",
      isDownloadable: false,
      localizedDescription: "Flexibility & Customisation can add muti data",
      localizedTitle: "FlexiCard!",
      price: 6,
      priceLocale: .init(identifier: "en_US"),
      productIdentifier: "cardify.addame.com.eCardify.FlexiCard.testing"
    )
}
//
//extension VCard.Address.AType : AccessibilityRotorContent {
//    
//    public var accessibilityDescription: String {
//        switch self {
//        case .home:
//            return "Home Address"
//        case .work:
//            return "Work Address"
//        case .postal:
//            return "Postal Address"
//        case .dom:
//            return "Domestic Address"
//        case .intl:
//            return "International Address"
//        case .parcel:
//            return "Parcel Address"
//        }
//    }
//}
