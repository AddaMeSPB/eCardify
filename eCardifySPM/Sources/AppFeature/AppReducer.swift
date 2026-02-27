
import Build
import SwiftUI
import APIClient
import KeychainClient
import SettingsFeature
import GenericPassFeature
import AuthenticationCore
import NotificationHelpers
import ECSharedModels
import ComposableArchitecture

@Reducer
public struct AppReducer {

    @Reducer(state: .equatable)
    public enum Path {
        case genericForm(GenericPassForm)
        case settings(Settings)
    }

    @ObservableState
    public struct State: Equatable {
        public init(
            path: StackState<Path.State> = StackState<Path.State>(),
            walletState: WalletPassList.State = WalletPassList.State(),
            authState: Login.State? = nil
        ) {
            self.path = path
            self.walletState = walletState
            self.authState = authState
        }

        public var path = StackState<Path.State>()
        public var walletState: WalletPassList.State
        @Presents public var authState: Login.State? = nil
        public var isSheetLoginPresented: Bool { authState != nil }
    }

    public enum Action {
        case path(StackActionOf<Path>)
        case onAppear
        case appDelegate(AppDelegateReducer.Action)
        case didChangeScenePhase(ScenePhase)
        case walletAction(WalletPassList.Action)
        case auth(PresentationAction<Login.Action>)
        case isSheetLogin(isPresented: Bool)
        case deepLink(URL)
        case tokenRefreshFailed
    }

    @Dependency(\.userNotifications) var userNotifications
    @Dependency(\.remoteNotifications) var remoteNotifications
    @Dependency(\.mainRunLoop) var mainRunLoop
    @Dependency(\.keychainClient) var keychainClient
    @Dependency(\.neuAuthClient) var neuAuthClient
    @Dependency(\.build) var build
    @Dependency(\.continuousClock) var clock

    private enum CancelID { case tokenRefresh }

    public init() {}

    public var body: some ReducerOf<Self> {

//      Scope(state: \.walletState.$destination.wrappedValue, action: /Action.appDelegate) {
//          AppDelegateReducer()
//      }

        Scope(state: \.walletState, action: /Action.walletAction) {
            WalletPassList()
        }

        Reduce(self.core)
            .forEach(\.path, action: \.path) 
            .ifLet(\.$authState, action: /AppReducer.Action.auth) {
                Login()
            }
    }

    func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-UI_TESTING") {
                state.walletState.$isAuthorized.withLock { $0 = true }
            }
            #endif
            return .none

        case .appDelegate:
            return .none

        case .didChangeScenePhase(.active):
            return .run { send in
                // Read current tokens from keychain
                guard let tokens = try? keychainClient.readCodable(
                    .token, build.identifier(), RefreshTokenResponse.self
                ) else { return }

                // Check if access token is expired or near expiry (within 60s)
                guard isAccessTokenExpired(tokens.accessToken) else { return }

                // Attempt token refresh
                do {
                    let response = try await neuAuthClient.refreshToken(
                        NeuAuthRefreshRequest(refreshToken: tokens.refreshToken)
                    )
                    let loginRes = response.toSuccessfulLoginResponse()
                    guard let newTokens = loginRes.access,
                          let newUser = loginRes.user else { return }
                    try await keychainClient.saveOrUpdateCodable(
                        newTokens, .token, build.identifier()
                    )
                    try await keychainClient.saveOrUpdateCodable(
                        newUser, .user, build.identifier()
                    )
                } catch {
                    // Refresh failed — session expired or revoked, force re-login
                    await send(.tokenRefreshFailed)
                }
            }
            .cancellable(id: CancelID.tokenRefresh, cancelInFlight: true)

        case .didChangeScenePhase(.background):
            return .none

        case .didChangeScenePhase:
            return .none

        case .walletAction(.destination(.presented(.add(.openSheetLogin(let bool))))):
            return .run { send in
                await send(.isSheetLogin(isPresented: bool))
            }


        case .walletAction(.openSheetLogin(let bool)):
            return .run { send in
                await send(.isSheetLogin(isPresented: bool))
            }

        case .walletAction:
            return .none

        case .auth(.presented(.verificationSuccess)):
            // isAuthorized is @Shared — automatically synced via AppStorage.
            // The .update(isAuthorized:) action below is redundant for the value itself
            // but signals GenericPassForm that auth completed (e.g., to proceed with pass creation).
            return .run { send in
                try await clock.sleep(for: .seconds(1))
                await send(.walletAction(.destination(.presented(.add(.update(isAuthorized: true))))))
                await send(.isSheetLogin(isPresented: false))
            }

        case .auth:
            return .none

        case .isSheetLogin(isPresented: let isPresented):
            state.authState = isPresented ? .init() : nil

            return .none

        case let .deepLink(url):
            // Handle auth callback URL: cardify.addame.com.eCardify://auth/callback
            // Currently OTP-based login doesn't use URL callbacks.
            // This prepares for future OAuth2/PKCE flows.
            #if DEBUG
            print("[DeepLink] Received: \(url.absoluteString)")
            #endif
            return .none

        case .tokenRefreshFailed:
            state.walletState.$isAuthorized.withLock { $0 = false }
            state.authState = .init()  // open login sheet on session expiry
            return .none

        case .path:
            return .none
        }
    }

}

// MARK: - JWT Helpers

/// Decode a JWT access token's `exp` claim to check if it's expired or near expiry.
/// Returns `true` if the token is expired or will expire within 60 seconds.
private func isAccessTokenExpired(_ token: String) -> Bool {
    let parts = token.split(separator: ".")
    guard parts.count == 3 else { return true }

    // Base64URL → standard Base64
    var base64 = String(parts[1])
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")

    // Pad to multiple of 4
    let remainder = base64.count % 4
    if remainder > 0 {
        base64 += String(repeating: "=", count: 4 - remainder)
    }

    guard
        let data = Data(base64Encoded: base64),
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let exp = json["exp"] as? TimeInterval
    else { return true }

    // Expired if current time >= (exp - 60s buffer)
    return Date().timeIntervalSince1970 >= (exp - 60)
}
