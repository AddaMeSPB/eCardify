import SwiftUI
import ECSharedModels
import FoundationExtension
import ComposableArchitecture

struct EmailsSectionView: View {

    @Perception.Bindable var store: StoreOf<GenericPassForm>
    var scrollProxy: ScrollViewProxy

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
                ForEach($store.vCard.emails, id: \.id) { $email in
                    HStack {
                        TextField(
                            "",
                            text: $email.text,
                            prompt: Text("*Email").foregroundColor(.red.opacity(0.5))
                        )
                        .font(.title2)
                        .fontWeight(.medium)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .padding(.vertical, 10)
                        .disableAutocorrection(true)
                        .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.emailTextFields.rawValue)
                        .foregroundColor(
                            email.text.isEmailValid 
                            ? Color.black
                            : Color.red.opacity(0.5)
                        )

                        Image(systemName: "checkmark.circle")
                            .foregroundColor(email.text.isEmailValid ? Color.blue : Color.red)
                            .opacity(email.text.isEmailValid ? 1 : 0)

                    }

                }
                .onDelete(perform: deleteEmails)
            } header: {
                headerView
            }
        }
    }

    private var headerView: some View {
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
                disabledMenu
            }
        }
        .padding(.vertical, 10)
    }

    private var disabledMenu: some View {
        Menu {
            Text("To activate this function,")
            Text("Please change your product type below.")
            Button {
                withAnimation(.easeInOut(duration: 0.9)) {
                    scrollProxy.scrollTo(store.bottomID, anchor: .bottom)
                }
            } label: {
                Text("click here to change your product type 👇🏼")
            }
        } label: {
            Image(systemName: "plus.square.on.square")
                .resizable()
                .frame(width: 30, height: 30)
        }
        .disabled(!store.isCustomProduct)
        .foregroundColor(store.isCustomProduct ? Color.blue : Color.gray)
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
