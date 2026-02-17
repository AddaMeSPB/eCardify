import BSON
import ImagePicker
import SwiftUI
import Foundation
import ECSharedModels
import SettingsFeature
import iPhoneNumberKit
import ComposableStoreKit
import ComposableArchitecture

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
                                            prompt: Text("***Org or Company Name").foregroundColor(.red.opacity(0.5))
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
                                        prompt: Text("*Job title").foregroundColor(.red.opacity(0.5))
                                            .font(.body)
                                            .fontWeight(.medium)
                                    )
                                    .disableAutocorrection(true)
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .padding(.vertical, 10)
                                    .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.jobTitleText.rawValue)
                                    
                                    OrganizationSectionView(store: store, proxy, value)

                                    Text("By incorporating your photo into a digital business card, your avatar will be displayed on Apple Wallet Pass, enabling others to instantly recognize you.")
                                        .font(.headline)
                                        .fontWeight(.medium)
                                        .foregroundColor(Color.gray)
                                        .padding(.vertical, 5)
                                    
                                } header: {
                                    Text("Organisation & Upload Images!")
                                        .font(.title3)
                                        .fontWeight(.medium)
                                }

                                // MARK: ContactSectionView Body
                                ContactSectionView(contact: $store.vCard.contact)
//
                                // MARK: TelephonesSectionView Body
                                TelephoneSectionView(store: store, value)

                                // MARK: EmailsSectionView Body
                                EmailsSectionView(store: store, value)

                                // MARK: - AddressesSectionView Body
                                AddressesSectionView(store: store, value)

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

}

struct GenericPassFormView_Previews: PreviewProvider {

    static var store = Store(initialState: GenericPassForm.State(storeKitState: .demoProducts, vCard: .demo)) {
        GenericPassForm()
    } withDependencies: {
        $0.attachmentS3Client = .happyPath
    }

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
    static public var demoProducts: Self = .init(products: [.basic, .flexiCard])
    static public var demoProductsCustom: Self = .init(products: [.basic, .flexiCard], type: .custom)
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
