import SwiftUI
import DesignSystem
import SettingsFeature
import AuthenticationCore
import ECSharedModels
import L10nResources
import ComposableArchitecture

public enum UILoginAccessibility: String {
    case codeChangedTF
    case niceNameTF
    case emailTF
    case sendEmailButtonTapped
}

public struct AuthenticationView: View {

    @Bindable var store: StoreOf<Login>
    @FocusState private var focusedField: Field?

    private enum Field { case email, code }

    public init(store: StoreOf<Login>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            ECColors.groupedBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: ECSpacing.xl) {
                    // Logo & Title
                    headerSection

                    // Input Section
                    if store.isValidationCodeIsSend {
                        codeInputSection
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else {
                        emailInputSection
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }

                    // Terms
                    if !store.isValidationCodeIsSend {
                        termsSection
                    }
                }
                .padding(.horizontal, ECSpacing.xl)
                .padding(.top, ECSpacing.xxxl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            store.send(.onAppear)
            focusedField = .email
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: store.isValidationCodeIsSend)
        .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
        .sheet(
            item: $store.scope(
                state: \.destination?.termsAndPrivacy, action: \.destination.termsAndPrivacy
            )
        ) { store in
            TermsAndPrivacyWebView(store: store)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: ECSpacing.sm) {
            // App icon circle
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ECColors.primary, ECColors.primaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: ECColors.primary.opacity(0.3), radius: 12, y: 4)

                Image(systemName: "person.text.rectangle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, ECSpacing.xs)

            Text(L("eCardify"))
                .font(ECTypography.largeTitle())
                .foregroundStyle(ECColors.textPrimary)

            Text(store.isValidationCodeIsSend
                 ? L("Verification Code")
                 : L("Register Or Login"))
                .font(ECTypography.subheadline())
                .foregroundStyle(ECColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Email Input

    private var emailInputSection: some View {
        VStack(spacing: ECSpacing.md) {
            // Email field
            VStack(alignment: .leading, spacing: ECSpacing.xs) {
                Text(L("Email"))
                    .font(ECTypography.footnote())
                    .foregroundStyle(ECColors.textSecondary)

                TextField(L("your@email.com"), text: $store.email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .email)
                    .font(ECTypography.body())
                    .padding(ECSpacing.md)
                    .background(ECColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: ECRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: ECRadius.md)
                            .stroke(
                                focusedField == .email
                                    ? ECColors.primary
                                    : ECColors.separator,
                                lineWidth: focusedField == .email ? 2 : 1
                            )
                    )
                    .disabled(store.isLoginRequestInFlight && store.isEmailValidated)
                    .accessibilityIdentifier(UILoginAccessibility.emailTF.rawValue)
            }

            // Send button
            Button {
                store.send(.sendEmailButtonTapped)
            } label: {
                if store.isLoginRequestInFlight {
                    ProgressView()
                        .tint(.white)
                } else {
                    HStack(spacing: ECSpacing.xs) {
                        Text(L("Continue"))
                        Image(systemName: "arrow.right")
                    }
                }
            }
            .buttonStyle(.ecPrimary)
            .disabled(!store.isEmailValidated || store.isLoginRequestInFlight)
            .accessibilityIdentifier(UILoginAccessibility.sendEmailButtonTapped.rawValue)
        }
    }

    // MARK: - Code Input

    private var codeInputSection: some View {
        VStack(spacing: ECSpacing.md) {
            VStack(alignment: .leading, spacing: ECSpacing.xs) {
                Text(L("Verification Code"))
                    .font(ECTypography.footnote())
                    .foregroundStyle(ECColors.textSecondary)

                TextField("000000", text: $store.code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.system(size: 32, weight: .semibold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .focused($focusedField, equals: .code)
                    .padding(ECSpacing.md)
                    .background(ECColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: ECRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: ECRadius.md)
                            .stroke(
                                focusedField == .code
                                    ? ECColors.primary
                                    : ECColors.separator,
                                lineWidth: focusedField == .code ? 2 : 1
                            )
                    )
                    .accessibilityIdentifier(UILoginAccessibility.codeChangedTF.rawValue)
                    .onAppear { focusedField = .code }
            }

            // Info text
            Label {
                Text(L("Didn't get email? Please check your mail spam folder!"))
                    .font(ECTypography.caption())
            } icon: {
                Image(systemName: "info.circle")
            }
            .foregroundStyle(ECColors.textSecondary)
            .padding(ECSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ECColors.accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: ECRadius.sm))

            if store.isLoginRequestInFlight {
                ProgressView()
                    .tint(ECColors.primary)
                    .padding(.top, ECSpacing.xs)
            }
        }
    }

    // MARK: - Terms

    private var termsSection: some View {
        VStack(spacing: ECSpacing.sm) {
            Text(L("Check our terms and privacy"))
                .font(ECTypography.caption())
                .foregroundStyle(ECColors.textSecondary)

            HStack(spacing: ECSpacing.md) {
                Button {
                    store.send(.termsPrivacySheet(isPresented: .terms))
                } label: {
                    Text(L("Terms"))
                        .font(ECTypography.subheadline(.medium))
                        .foregroundStyle(ECColors.primary)
                }

                Text(L("&"))
                    .font(ECTypography.caption())
                    .foregroundStyle(ECColors.textSecondary)

                Button {
                    store.send(.termsPrivacySheet(isPresented: .privacy))
                } label: {
                    Text(L("Privacy"))
                        .font(ECTypography.subheadline(.medium))
                        .foregroundStyle(ECColors.primary)
                }
            }
        }
        .padding(.top, ECSpacing.md)
    }
}

#if DEBUG
struct AuthenticationView_Previews: PreviewProvider {
    static var store = Store(
        initialState: Login.State()
    ) {
        Login()
    }

    static var previews: some View {
        AuthenticationView(store: store)
    }
}
#endif
