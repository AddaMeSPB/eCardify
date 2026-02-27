import SwiftUI
import DesignSystem
import L10nResources
import ECSharedModels

struct ContactSectionView: View {
    @Binding var contact: VCard.Contact

    var body: some View {
        Section {
            HStack(spacing: ECSpacing.xs) {
                ECRequiredDot()
                TextField(L("First Name"), text: $contact.firstName)
                    .formFieldStyle()
                    .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.firstNameTextFields.rawValue)
            }

            TextField(L("Middle Name"), text: $contact.additionalName.orEmpty)
                .formFieldStyle()
                .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.middleNameTextFields.rawValue)

            HStack(spacing: ECSpacing.xs) {
                ECRequiredDot()
                TextField(L("Last Name"), text: $contact.lastName)
                    .formFieldStyle()
                    .accessibilityIdentifier(UITestGPFAccessibilityIdentifier.lastNameTextFields.rawValue)
            }
        } header: {
            Text(L("Contact"))
                .font(ECTypography.headline())
        }
    }
}

extension View {
    func formFieldStyle() -> some View {
        self.autocorrectionDisabled()
            .font(ECTypography.body(.medium))
            .padding(.vertical, ECSpacing.xs)
    }
}

struct ContactSectionView_Previews: PreviewProvider {
    @State static var contact = VCard.Contact(lastName: "John", firstName: "Heli")

    static var previews: some View {
        Form {
            ContactSectionView(contact: $contact)
        }
    }
}
