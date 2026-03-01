import SwiftUI
import DesignSystem
import L10nResources
import ECSharedModels
import iPhoneNumberField
import ComposableArchitecture

struct TelephoneSectionView: View {
    @Bindable var store: StoreOf<GenericPassForm>
    let value: ScrollViewProxy

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
                TelephoneRowView(
                    type: $store.vCard.telephones[index].type,
                    number: $store.vCard.telephones[index].number
                )
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

// MARK: - Per-row view with isolated @State

private struct TelephoneRowView: View {
    @Binding var type: VCard.Telephone.TType
    @Binding var number: String
    @State private var isEditing: Bool = false
    @State private var isPhoneNumberValid: Bool = false

    var body: some View {
        Picker(L("Device Type"), selection: $type) {
            ForEach(VCard.Telephone.TType.allCases) { option in
                Text(LDynamic(option.rawValue.uppercased()))
                    .font(ECTypography.body(.medium))
            }
        }

        iPhoneNumberField(
            "+351 (000) 000-0000",
            text: $number,
            isEditing: $isEditing
        )
        .flagHidden(false)
        .prefixHidden(false)
        .font(UIFont(size: 20, weight: .semibold, design: .monospaced))
        .placeholderColor(ECColors.error.opacity(0.3))
        .foregroundColor(isPhoneNumberValid ? .label : UIColor.systemRed.withAlphaComponent(0.5))
        .clearButtonMode(.whileEditing)
        .onClear { _ in isEditing.toggle() }
        .onNumberChange { phoneNumber in
            isPhoneNumberValid = phoneNumber != nil
        }
        .padding(.vertical, ECSpacing.md)

        if !isPhoneNumberValid && isEditing {
            Text(L("Number is invalid"))
                .font(ECTypography.caption())
                .foregroundStyle(ECColors.error)
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
