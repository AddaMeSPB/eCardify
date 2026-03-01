import BSON
import ImagePicker
import SwiftUI
import Foundation
import DesignSystem
import L10nResources
import ECSharedModels
import SettingsFeature
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

    @Bindable var store: StoreOf<GenericPassForm>

    public init(store: StoreOf<GenericPassForm>) {
        self.store = store
    }

    // MARK: - BODY
    public var body: some View {
        GeometryReader { proxy in
            ScrollViewReader { value in
                ZStack(alignment: .center) {
                    formContent(proxy: proxy, scrollProxy: value)

                    if store.isActivityIndicatorVisible {
                        ECLoadingOverlay(L("Generating your card..."))
                    }
                }
            }
        }
    }

    // MARK: - Form Content

    @ViewBuilder
    private func formContent(proxy: GeometryProxy, scrollProxy: ScrollViewProxy) -> some View {
        Form {
            organizationSection(proxy: proxy, scrollProxy: scrollProxy)

            ContactSectionView(contact: $store.vCard.contact)

            TelephoneSectionView(store: store, scrollProxy)

            EmailsSectionView(store: store, scrollProxy)

            AddressesSectionView(store: store, scrollProxy)

            websiteSection

            productTypeSection

            cardDesignSection

            paymentSection
        }
        .navigationTitle(L("Create Digital Card"))
        .redacted(reason: store.isActivityIndicatorVisible ? .placeholder : .init())
        .allowsHitTesting(!store.isActivityIndicatorVisible)
        .onAppear { store.send(.onAppear) }
        .alert($store.scope(state: \.alert, action: \.alert))
        .sheet(
            item: $store.scope(state: \.imagePicker, action: \.imagePicker),
            content: ImagePickerView.init(store:)
        )
        .sheet(
            item: $store.scope(state: \.digitalCardDesign, action: \.digitalCardDesign),
            content: CardDesignListView.init(store:)
        )
    }

    // MARK: - Organization Section

    @ViewBuilder
    private func organizationSection(proxy: GeometryProxy, scrollProxy: ScrollViewProxy) -> some View {
        Section {
            HStack(spacing: ECSpacing.xs) {
                ECRequiredDot()
                TextField(
                    L("Organization or Company"),
                    text: $store.vCard.organization.orEmpty
                )
                .autocorrectionDisabled()
                .font(ECTypography.body(.medium))
                .padding(.vertical, ECSpacing.xs)
                .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.orgText.rawValue)
            }

            Text(L("Organization, company, or self-employed name"))
                .font(ECTypography.caption())
                .foregroundStyle(ECColors.textSecondary)

            HStack(spacing: ECSpacing.xs) {
                ECRequiredDot()
                TextField(
                    L("Job Title"),
                    text: $store.vCard.position
                )
                .autocorrectionDisabled()
                .font(ECTypography.body(.medium))
                .padding(.vertical, ECSpacing.xs)
                .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.jobTitleText.rawValue)
            }

            OrganizationSectionView(store: store, proxy, scrollProxy)

            Text(L("Your photo will appear on the Apple Wallet pass, helping others recognize you instantly."))
                .font(ECTypography.caption())
                .foregroundStyle(ECColors.textSecondary)
                .padding(.vertical, ECSpacing.xxs)

        } header: {
            Text(L("Organization & Images"))
                .font(ECTypography.headline())
        }
    }

    // MARK: - Website Section

    private var websiteSection: some View {
        Section {
            TextField(
                L("https://example.com"),
                text: $store.vCard.website.orEmpty
            )
            .keyboardType(.URL)
            .textContentType(.URL)
            .autocorrectionDisabled()
            .font(ECTypography.body(.medium))
            .padding(.vertical, ECSpacing.xs)
        } header: {
            HStack {
                Text(L("Website"))
                    .font(ECTypography.headline())
                Text(L("Optional"))
                    .font(ECTypography.caption())
                    .foregroundStyle(ECColors.textSecondary)
            }
        }
    }

    // MARK: - Product Type Section

    private var productTypeSection: some View {
        Section {
            if store.isEligibleForFreeCard {
                HStack {
                    Text(L("Product Type"))
                    Spacer()
                    Text(L("BASIC"))
                        .foregroundStyle(ECColors.textSecondary)
                }
                Text(L("Your first card is free with basic templates!"))
                    .font(ECTypography.caption())
                    .foregroundStyle(ECColors.primary)
            } else {
                Picker(L("Product Type"), selection: $store.storeKitState.type) {
                    ForEach(StoreKitReducer.State.ProductType.allCases) { option in
                        Text(LDynamic(option.rawValue.uppercased()))
                            .font(ECTypography.body(.medium))
                    }
                }
            }
        }
    }

    // MARK: - Card Design Section

    private var cardDesignSection: some View {
        Section {
            Button {
                store.send(.dcdSheetIsPresentedButtonTapped, animation: .default)
            } label: {
                HStack {
                    Label {
                        Text(L("Pick Card Design"))
                            .font(ECTypography.headline())
                    } icon: {
                        Image(systemName: "paintpalette.fill")
                    }
                    .foregroundStyle(store.isCustomProduct ? ECColors.primary : ECColors.textSecondary)

                    Spacer()

                    if store.isCustomProduct {
                        Image(systemName: "chevron.right")
                            .font(ECTypography.caption())
                            .foregroundStyle(ECColors.textSecondary)
                    }
                }
            }
            .disabled(!store.isCustomProduct || store.isEligibleForFreeCard)

            if store.isEligibleForFreeCard {
                Text(L("Custom card design is available with paid cards."))
                    .font(ECTypography.caption())
                    .foregroundStyle(ECColors.textSecondary)
            } else if !store.isCustomProduct {
                Text(L("Change product type to Custom to unlock card design."))
                    .font(ECTypography.caption())
                    .foregroundStyle(ECColors.textSecondary)
            }
        }
    }

    // MARK: - Payment Section

    private var paymentSection: some View {
        VStack(alignment: .trailing, spacing: ECSpacing.sm) {
            if store.isEligibleForFreeCard {
                freeCardButton

                Text(L("Free Card"))
                    .font(ECTypography.headline())
                    .foregroundStyle(ECColors.textPrimary)

                Text(L("Your first digital business card is free with basic templates."))
                    .font(ECTypography.caption())
                    .foregroundStyle(ECColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                legalLinks
            } else if let product = store.storeKitState.product {
                payButton(product: product)

                Text(product.localizedTitle)
                    .font(ECTypography.headline())
                    .foregroundStyle(ECColors.textPrimary)

                Text(product.localizedDescription)
                    .font(ECTypography.caption())
                    .foregroundStyle(ECColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                // Legal links — Apple 3.1.2 requirement
                legalLinks
            } else {
                ProgressView()
                    .tint(ECColors.primary)
                    .scaleEffect(2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ECSpacing.sm)
        .id(store.bottomID)
    }

    // MARK: - Legal Links

    @Environment(\.openURL) private var openURL

    private var legalLinks: some View {
        HStack(spacing: ECSpacing.md) {
            Spacer()
            Button {
                if let url = URL(string: "https://ecardify.byalif.app/privacy") {
                    openURL(url)
                }
            } label: {
                Text(L("Privacy Policy"))
                    .font(ECTypography.caption())
                    .foregroundStyle(ECColors.primary)
            }
            .buttonStyle(.plain)
            Text("·")
                .font(ECTypography.caption())
                .foregroundStyle(ECColors.textSecondary)
            Button {
                if let url = URL(string: "https://ecardify.byalif.app/terms") {
                    openURL(url)
                }
            } label: {
                Text(L("Terms of Use"))
                    .font(ECTypography.caption())
                    .foregroundStyle(ECColors.primary)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.top, ECSpacing.xxs)
    }

    // MARK: - Free Card Button

    private var freeCardButton: some View {
        Button {
            store.send(.createPass)
        } label: {
            if store.isActivityIndicatorVisible {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(ECSpacing.sm)
            } else {
                Text(L("Create Your Free Card"))
                    .font(ECTypography.headline())
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity)
                    .padding(ECSpacing.sm)
            }
        }
        .foregroundStyle(.white)
        .background(store.isFormValid ? ECColors.primary : ECColors.textSecondary)
        .clipShape(RoundedRectangle(cornerRadius: ECRadius.md))
        .disabled(!store.isFormValid || store.isActivityIndicatorVisible)
        .buttonStyle(.borderless)
        .accessibilityIdentifier("free_card_button")
    }

    @ViewBuilder
    private func payButton(product: StoreKitClient.Product) -> some View {
        Button {
            store.send(.createPass)
        } label: {
            if store.storeKitState.isPurchasing {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(ECSpacing.sm)
            } else {
                Text(L("Pay \(cost(product: product)) and Create"))
                    .font(ECTypography.headline())
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity)
                    .padding(ECSpacing.sm)
            }
        }
        .foregroundStyle(.white)
        .background(store.isFormValid ? ECColors.primary : ECColors.textSecondary)
        .clipShape(RoundedRectangle(cornerRadius: ECRadius.md))
        .disabled(!store.isFormValid || store.storeKitState.isPurchasing || store.isActivityIndicatorVisible)
        .buttonStyle(.borderless)
        .accessibilityIdentifier("pay_button")
    }
}

// MARK: - Preview

struct GenericPassFormView_Previews: PreviewProvider {

    static var store = Store(
        initialState: GenericPassForm.State(storeKitState: .demoProducts, vCard: .demo)
    ) {
        GenericPassForm()
    } withDependencies: {
        $0.attachmentS3Client = .happyPath
    }

    static var previews: some View {
        NavigationStack {
            GenericPassFormView(store: store)
        }
    }
}

private func cost(product: StoreKitClient.Product) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = product.priceLocale
    return formatter.string(from: product.price) ?? "$\(product.price)"
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
        localizedDescription: "Basic digital business card with a fixed design.",
        localizedTitle: "Basic Card",
        price: 1.99,
        priceLocale: .init(identifier: "en_US"),
        productIdentifier: "cardify.addame.com.eCardify.BasicCard.testing"
    )
    static let flexiCard = Self(
        downloadContentLengths: [],
        downloadContentVersion: "",
        isDownloadable: false,
        localizedDescription: "Custom card design with flexible data fields.",
        localizedTitle: "FlexiCard",
        price: 4.99,
        priceLocale: .init(identifier: "en_US"),
        productIdentifier: "cardify.addame.com.eCardify.FlexiCard.testing"
    )
}
