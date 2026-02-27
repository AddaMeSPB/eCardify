import SwiftUI
import DesignSystem
import L10nResources
import ECSharedModels
import FoundationExtension
import ComposableArchitecture

struct EmailsSectionView: View {

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
            ForEach($store.vCard.emails, id: \.id) { $email in
                HStack {
                    ECRequiredDot()

                    TextField(L("Email"), text: $email.text)
                        .font(ECTypography.body(.medium))
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .padding(.vertical, ECSpacing.xs)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.emailTextFields.rawValue)
                        .foregroundStyle(
                            email.text.isEmailValid
                            ? ECColors.textPrimary
                            : ECColors.error.opacity(0.7)
                        )

                    if email.text.isEmailValid {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ECColors.success)
                    }
                }
            }
            .onDelete(perform: deleteEmails)
        } header: {
            headerView
        }
    }

    private var headerView: some View {
        HStack {
            Text(L("Email"))
                .font(ECTypography.headline())

            Spacer()

            if store.isCustomProduct {
                Button {
                    store.send(.addOneMoreEmailSection)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(ECColors.primary)
                }
            } else {
                disabledMenu
            }
        }
    }

    private var disabledMenu: some View {
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

    func deleteEmails(at offsets: IndexSet) {
        if store.vCard.emails.count > 1 {
            store.vCard.emails.remove(atOffsets: offsets)
        }
    }
}

import ComposableStoreKit

struct EmailsSectionView_Previews: PreviewProvider {

    static var state = GenericPassForm.State(
        storeKitState: .demoProductsCustom,
        vCard: .demo
    )

    static var store = Store(initialState: state) {
        GenericPassForm()
    } withDependencies: {
        $0.attachmentS3Client = .happyPath
    }

    static var previews: some View {
        ScrollViewReader { value in
            Form {
                EmailsSectionView(store: store, value)
            }
        }
    }
}
