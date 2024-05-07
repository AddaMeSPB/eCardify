import SwiftUI
import ECSharedModels

struct ContactSectionView: View {
    @Binding var contact: VCard.Contact

    var body: some View {
        Section(header: Text("Contact").font(.title2).fontWeight(.medium)) {
            TextField(
                "",
                text: $contact.firstName,
                prompt: Text("*First Name")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.red.opacity(0.5))
            )
            .standardTextFieldStyle()
            .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.firstNameTextFields.rawValue)

            TextField(
                "",
                text: $contact.additionalName.orEmpty,
                prompt: Text("Middle Name").font(.title2).fontWeight(.medium)
            )
            .standardTextFieldStyle()
            .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.middleNameTextFields.rawValue)

            TextField(
                "",
                text: $contact.lastName,
                prompt: Text("*Last Name")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.red.opacity(0.5))
            )
            .standardTextFieldStyle()
            .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.lastNameTextFields.rawValue)
        }
    }
}

extension View {
    func standardTextFieldStyle() -> some View {
        self.disableAutocorrection(true)
            .font(.title2)
            .fontWeight(.medium)
            .padding(.vertical, 10)
    }
}

struct ContactSectionView_Previews: PreviewProvider {
    @State static var contact = VCard.Contact(lastName: "John", firstName: "Heli")

    static var previews: some View {
        Form {
            ContactSectionView(contact: $contact)
                .padding()
        }
        .previewLayout(.sizeThatFits)
    }
}
