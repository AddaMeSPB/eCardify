import SwiftUI
import DesignSystem
import L10nResources
import ECSharedModels
import iPhoneNumberField
import ComposableArchitecture

struct TelephoneSectionView: View {
    @Bindable var store: StoreOf<GenericPassForm>
    let value: ScrollViewProxy
    @State var isEditing: Bool = false
    @State private var isPhoneNumberValid: Bool = false

    public init(
        store: StoreOf<GenericPassForm>,
        _ value: ScrollViewProxy
    ) {
        self.store = store
        self.value = value
    }

    var body: some View {
        Section {

            ForEach(store.vCard.telephones.indices, id: \.self) { index in

                Picker(L("Device Type"), selection: $store.vCard.telephones[index].type) {
                    ForEach(VCard.Telephone.TType.allCases) { option in
                        Text(option.rawValue.uppercased())
                            .font(ECTypography.body(.medium))
                    }
                }

                iPhoneNumberField(
                    "+351 (000) 000-0000",
                    text: $store.vCard.telephones[index].number,
                    isEditing: $isEditing
                )
                .flagHidden(false)
                .prefixHidden(false)
                .font(UIFont(size: 20, weight: .semibold, design: .monospaced))
                .placeholderColor(ECColors.error.opacity(0.3))
                .foregroundColor(isPhoneNumberValid ? .label : UIColor.systemRed.withAlphaComponent(0.5))
                .clearButtonMode(.whileEditing)
                .onClear { _ in isEditing.toggle() }
                .padding(.vertical, ECSpacing.md)

                if !isPhoneNumberValid && isEditing {
                    Text(L("Number is invalid"))
                        .font(ECTypography.caption())
                        .foregroundStyle(ECColors.error)
                }
            }
            .onDelete(perform: deletePhoneNumber)

        } header: {
            HStack {
                Text(L("Telephone"))
                    .font(ECTypography.headline())

                Spacer()

                if store.isCustomProduct {
                    Button {
                        store.send(.addOneMoreTelephoneSection)
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
                                value.scrollTo(store.bottomID, anchor: .bottom)
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

    func deletePhoneNumber(at offsets: IndexSet) {
        if store.vCard.telephones.count > 1 {
            store.vCard.telephones.remove(atOffsets: offsets)
        }
    }
}

struct TelephoneSectionView_Previews: PreviewProvider {
    static var store = Store(initialState: GenericPassForm.State(storeKitState: .demoProducts, vCard: .demo)) {
        GenericPassForm()
    } withDependencies: {
        $0.attachmentS3Client = .happyPath
    }

    static var previews: some View {
        ScrollViewReader { value in
            Form {
                TelephoneSectionView(store: store, value)
            }
        }
    }
}
