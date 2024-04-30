//
//  AuthenticationView.swift
//
//
//  Created by Saroar Khandoker on 07.04.2021.
//

import SwiftUI
import SwiftUIHelpers
import SettingsFeature
import SwiftUIExtension
import AuthenticationCore
import ECSharedModels
import ComposableArchitecture

public enum UILoginAccessibility: String {
    case codeChangedTF
    case niceNameTF
    case emailTF
    case sendEmailButtonTapped
}

public struct AuthenticationView: View {

    @Perception.Bindable var store: StoreOf<Login>

    public init(store: StoreOf<Login>) {
        self.store = store
    }

    public var body: some View {

        WithPerceptionTracking {
            ZStack(alignment: .top) {

                VStack {

                    Text("eCardify")
                        .font(Font.system(size: 60, weight: .heavy, design: .serif))
                        .foregroundColor(.red)
                        .padding(.top, 30)

                    if !store.isValidationCodeIsSend {
                        Text("Register Or Login")
                            .font(Font.system(size: 33, weight: .heavy, design: .rounded))
                            .foregroundColor(.green)
                    }

                    if store.isValidationCodeIsSend {
                        Text("Verification Code")
                            .font(Font.system(size: 33, weight: .heavy, design: .rounded))
                            .foregroundColor(.blue)
                    }

                    ZStack {
                        if !store.isValidationCodeIsSend {
                            inputEmailTextView().disabled(store.isLoginRequestInFlight)
                        }

                        if store.isValidationCodeIsSend {
                            HStack {
                                TextField("000000", text: $store.code)
                                .keyboardType(.numberPad)
                                .font(.largeTitle)
                                .multilineTextAlignment(.center)
                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 60)
                                .keyboardType(.phonePad)
                                .padding(.leading)
                                .accessibilityIdentifier(UILoginAccessibility.codeChangedTF.rawValue)

                            }.cornerRadius(25)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(Color.black.opacity(0.2), lineWidth: 0.6)
                                        .foregroundColor(
                                            Color(
                                                #colorLiteral(
                                                    red: 0.8039215803, green: 0.8039215803, blue: 0.8039215803, alpha: 0.06563035103))
                                        )
                                )
                        }
                    }
                    .padding(EdgeInsets(top: 10, leading: 10, bottom: 20, trailing: 10))

                    if !store.isValidationCodeIsSend  {
                        Button(
                            action: {
                                store.send(.sendEmailButtonTapped)
                            },
                            label: {
                                HStack {
                                    if !store.isLoginRequestInFlight {
                                        Image(systemName: "arrow.right")
                                            .font(.largeTitle)
                                            .frame(maxWidth:.infinity)
                                            .padding()
                                    } else {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: Color.hex(0x5E00CF)))
                                            .padding()
                                        // color have to be black
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                        )
                        .accessibilityIdentifier(UILoginAccessibility.sendEmailButtonTapped.rawValue)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 60, maxHeight: 60)
                        .disabled(
                            (!store.isEmailValidated
                             || store.isLoginRequestInFlight)
                            && self.store.niceName.isEmpty
                        )
                        .foregroundColor(
                            self.store.isEmailValidated
                            && !self.store.niceName.isEmpty ? Color.red : Color.white
                        )
                        .background(
                            self.store.isEmailValidated
                            && !self.store.niceName.isEmpty ? Color.yellow : Color.gray
                        )
                        .buttonStyle(.plain)
                        .cornerRadius(10)
                        .padding(.horizontal, 10)

                    }

                    if store.isValidationCodeIsSend {
                        Text("*** Didn't get email? Please check your mail spam folder!")
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .font(Font.system(size: 16, weight: .medium, design: .rounded))
                            .padding(.horizontal, 20)
                            .foregroundColor(.red)
                    }

                    if !store.isValidationCodeIsSend {
                        termsAndPrivacyView()
                    }

                    Spacer()
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
            .onTapGesture {
                hideKeyboard()
            }
            .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
            .sheet(
              store: self.store.scope(
                state: \.$destination.termsAndPrivacy, action: \.destination.termsAndPrivacy
              )
            ) { store in
                TermsAndPrivacyWebView(store: store)
            }

        }
    }

    private func inputEmailTextView() -> some View {
        VStack {
            TextField(
                "* Your nice Name goes here",
                text: $store.niceName
            )
            .keyboardType(.default)
            .autocorrectionDisabled()
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 60, maxHeight: 60)
            .textCase(.uppercase)
            .autocapitalization(.none)
            .padding(.leading, 30)
            .padding(.bottom, -10)
            .disabled(store.isLoginRequestInFlight)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .accessibilityIdentifier(UILoginAccessibility.niceNameTF.rawValue)

            Divider()

            TextField(
                "* Email",
                text: $store.email
            )
            .keyboardType(.emailAddress)
            .autocorrectionDisabled()
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 60, maxHeight: 60)
            .textCase(.lowercase)
            .autocapitalization(.none)
            .padding(.leading, 30)
            .padding(.top, -10)
            .disabled(store.isLoginRequestInFlight && store.isEmailValidated)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .accessibilityIdentifier(UILoginAccessibility.emailTF.rawValue)

        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.black.opacity(0.3), lineWidth: 0.6)
                .foregroundColor(
                    Color(
                        #colorLiteral(
                            red: 0.8039215803,
                            green: 0.8039215803,
                            blue: 0.8039215803,
                            alpha: 0.06563035103
                        )
                    )
                )
        )
    }

    private func inputCodeTextView() -> some View {
        VStack {
            HStack {
                TextField(
                    "000000",
                    text: $store.code
                )
                .keyboardType(.numberPad)
                .font(.largeTitle)
                .multilineTextAlignment(.center)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 60)
                .keyboardType(.phonePad)
                .padding(.leading)
                .accessibilityIdentifier(UILoginAccessibility.codeChangedTF.rawValue)

            }.cornerRadius(25)
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.black.opacity(0.2), lineWidth: 0.6)
                        .foregroundColor(
                            Color(
                                #colorLiteral(
                                    red: 0.8039215803, green: 0.8039215803, blue: 0.8039215803, alpha: 0.06563035103))
                        )
                )

            Text("*** Didn't Get My Email? PLease Check Your mail Spam Folder!")
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .font(Font.system(size: 16, weight: .medium, design: .rounded))
                .padding()
                .foregroundColor(.red)

        }
//        .frame(maxWidth: UIScreen.main.bounds.width * 0.8)

    }

    private func termsAndPrivacyView() -> some View {
        VStack {
            Text("Check our terms and privacy")
                .font(.body)
                .bold()
                .foregroundColor(.green)
                .padding()

            HStack {
                Button(
                    action: {
                        store.send(.termsPrivacySheet(isPresented: .terms))
                    },
                    label: {
                        Text("Terms")
                            .font(.title3)
                            .bold()
                            .foregroundColor(.green)
                    }
                )

                Text("&")
                    .font(.title3)
                    .bold()
                    .padding([.leading, .trailing], 10)
                    .foregroundColor(.red)

                Button(
                    action: {
                        store.send(.termsPrivacySheet(isPresented: .privacy))
                    },
                    label: {
                        Text("Privacy")
                            .font(.title3)
                            .bold()
                            .foregroundColor(.green)
                    }
                )

            }
        }
    }
}

//#if DEBUG
struct AuthenticationView_Previews: PreviewProvider {
    static var store = Store(
        initialState: Login.State()
    ) {
        Login()
    }

    static var previews: some View {
//        Preview {
            AuthenticationView(store: store)
//        }
    }
}
//#endif

