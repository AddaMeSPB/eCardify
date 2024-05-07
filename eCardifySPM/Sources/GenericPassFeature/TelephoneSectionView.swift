import SwiftUI
import ECSharedModels
import iPhoneNumberKit
import ComposableArchitecture

struct TelephoneSectionView: View {
    @Perception.Bindable var store: StoreOf<GenericPassForm>
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
        WithPerceptionTracking {
            Section {

                ForEach($store.vCard.telephones, id: \.id) { item in

                    WithPerceptionTracking {
                        Picker("Device Type", selection: item.type) {
                            ForEach(VCard.Telephone.TType.allCases) { option in
                                Text(option.rawValue.uppercased())
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 6)

                            }
                        }
                    }

                    iPhoneNumberField(
                        "+351 (000) 000-0000",
                        text: item.number,
                        isEditing: $isEditing,
                        isPhoneNumberValid: $isPhoneNumberValid
                    )
                    .flagHidden(false)
                    .prefixHidden(false)
                    .font(UIFont(size: 20, weight: .semibold, design: .monospaced))
                    .placeholderColor(Color.red.opacity(0.3))
                    .foregroundColor(isPhoneNumberValid ? Color.black : Color.red.opacity(0.5))
                    .clearButtonMode(.whileEditing)
                    .onClear { _ in isEditing.toggle() }
                    .padding(.vertical, 16)
                    if !isPhoneNumberValid && isEditing {
                        Text("Number is invalid!.")
                            .font(.caption2)
                            .foregroundColor(isPhoneNumberValid ? Color.blue : Color.red)

                    }

                }
                .onDelete(perform: deletePhoneNumber)

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



//.phoneTextField.isValidNumber
