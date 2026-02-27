import os
import UIKit
import Build
import Foundation
import APIClient
import KeychainClient
import ECSharedModels
import ComposableStoreKit
import NotificationHelpers
import UIApplicationClient
import FoundationExtension
import ComposableArchitecture
import ComposableUserNotifications

@Reducer
public struct Settings {

    @ObservableState
    public struct State: Equatable {
        public init(
            currentUser: UserOutput = .withFirstName,
            buildNumber: Build.Number? = nil,
            enableNotifications: Bool = false,
            userNotificationSettings: UserNotificationClient.Notification.Settings? = nil,
            userSettings: UserSettings = UserSettings()
        ) {
            self.currentUser = currentUser
            self.buildNumber = buildNumber
            self.enableNotifications = enableNotifications
            self.userNotificationSettings = userNotificationSettings
            self.userSettings = userSettings
        }


        @Presents public var destination: Destination.State? = nil
        public var userSettings: UserSettings
        public var enableNotifications: Bool

        @Shared(.appStorage("isAuthorized")) public var isAuthorized = false
        @Shared(.appStorage("isUserFirstNameEmpty")) public var isUserFirstNameEmpty = true

        public var currentUser: UserOutput = .withFirstName
        public var buildNumber: Build.Number?
        public var userNotificationSettings: UserNotificationClient.Notification.Settings?

    }

    @CasePathable
    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case onAppear
        case didBecomeActive
        case openSettingButtonTapped
        case userNotificationAuthorizationResponse(Bool)
        case userNotificationSettingsResponse(UserNotificationClient.Notification.Settings)
        case leaveUsAReviewButtonTapped
        case reportABugButtonTapped
        case logOutButtonTapped
        case restoreButtonTapped
        case ourAppLinkButtonTapped(String)
    }

    @Dependency(\.build) var build
    @Dependency(\.mainQueue) var mainQueue
    @Dependency(\.continuousClock) var clock
    @Dependency(\.storeKit) var storeKitClient
    @Dependency(\.keychainClient) var keychainClient
    @Dependency(\.neuAuthClient) var neuAuthClient
    @Dependency(\.applicationClient) var applicationClient
    @Dependency(\.userNotifications) var userNotifications
    @Dependency(\.remoteNotifications.unregister) var unRegisterForRemoteNotifications

    public init() {}

    public var body: some Reducer<State, Action> {
        CombineReducers {

            BindingReducer()

            Reduce { state, action in

                switch action {

                    case .binding(\.enableNotifications):
                        guard
                            state.enableNotifications,
                            let userNotificationSettings = state.userNotificationSettings
                        else {
                            // TODO: API request to opt out of all notifications
                            state.enableNotifications = false
                            return .none
                        }

                        let newStatus: UNAuthorizationStatus = state.enableNotifications ? .authorized : .denied
                        state.userNotificationSettings?.authorizationStatus = newStatus
                        switch userNotificationSettings.authorizationStatus {
                            case .notDetermined, .provisional:
                                state.enableNotifications = true
                                return .run { send in
                                    do {
                                        let granted = try await self.userNotifications.requestAuthorization([.alert, .badge, .sound])
                                        await send(.userNotificationAuthorizationResponse(granted))
                                    } catch {
                                        await send(.userNotificationAuthorizationResponse(false))
                                    }
                                }
                                .animation()

                            case .denied:
                                state.enableNotifications = false
                                return .none

                            case .authorized:
                                state.enableNotifications = true
                                return .run { send in
                                    await send(.userNotificationAuthorizationResponse(true))
                                }

                            case .ephemeral:
                                state.enableNotifications = true
                                return .none

                            @unknown default:
                                return .none
                        }

                    case .binding:
                        return .none

                    case .onAppear:
                        state.buildNumber = self.build.number()

                        do {
                            state.currentUser = try keychainClient.readCodable(.user, self.build.identifier(), UserOutput.self)
                        } catch {
                            // fatalError("Do soemthing from SettingsFeature!")
                            settingsLogger.error("cant get current user from keychainClient ")
                        }

                        return .none

                    case .openSettingButtonTapped:
                        return .run { send in
                            guard
                                let url = await URL(string: self.applicationClient.openSettingsURLString())
                            else { return }
                            _ = await self.applicationClient.open(url, [:])
                        }

                    case let .userNotificationAuthorizationResponse(granted):
                        state.enableNotifications = granted
                        return granted
                        ? .none
                        : .run { _ in
                            await self.unRegisterForRemoteNotifications()
                        }

                    case let .userNotificationSettingsResponse(settings):
                        state.userNotificationSettings = settings
                        state.enableNotifications = settings.authorizationStatus == .authorized
                        return .none

                    case .leaveUsAReviewButtonTapped:

                        return .run { _ in
                            _ = await self.applicationClient.open(appStoreReviewUrl, [:])
                        }

                    case .didBecomeActive:
                        return .run { send in
                            await send(.userNotificationSettingsResponse(
                                self.userNotifications.getNotificationSettings()
                            ))
                        }

                    case .reportABugButtonTapped:
                        return .run { [currentUser = state.currentUser] _ in
                            let currentUser = currentUser
                            var components = URLComponents()
                            components.scheme = "mailto"
                            components.path = "saroar9@gmail.com"
                            components.queryItems = [
                                URLQueryItem(name: "subject", value: "I found a bug in eCardify IOS App"),
                                URLQueryItem(
                                    name: "body",
                                    value: """


                          ---
                          Build: \(self.build.number()) (\(self.build.gitSha()))
                          \(currentUser.id.hexString)
                          """
                                )
                            ]

                            guard let mailURL = components.url else { return }
                            _ = await self.applicationClient.open(mailURL, [:])
                        }
                    case .logOutButtonTapped:
                        state.$isAuthorized.withLock { $0 = false }
                        state.$isUserFirstNameEmpty.withLock { $0 = true }

                        return .run { _ in
                            // Revoke server session (fire-and-forget)
                            do {
                                let tokens = try keychainClient.readCodable(
                                    .token, build.identifier(), RefreshTokenResponse.self
                                )
                                try await neuAuthClient.logout(
                                    NeuAuthRefreshRequest(refreshToken: tokens.refreshToken)
                                )
                            } catch {
                                settingsLogger.error("Server logout failed: \(error.localizedDescription)")
                            }

                            // Clear all keychain data
                            do {
                                try await keychainClient.logout()
                            } catch {
                                settingsLogger.error("Keychain clear failed: \(error.localizedDescription)")
                            }
                        }

                    case .restoreButtonTapped:
                        state.destination = .restore(.init())
                        return .run { send in
                            try await clock.sleep(for: .seconds(1))
                            await send(.destination(.presented(.restore(.restoreButtonTapped))))
                        }

                    case .destination:
                        return .none


                    case .ourAppLinkButtonTapped(let link):

                        guard let linkURLFromString = URL(string: link) else { return .none }

                        return .run { _ in
                            _ = await self.applicationClient.open(linkURLFromString, [:])
                        }

                }
            }
            .ifLet(\.$destination, action: \.destination) {
                Destination()
            }
        }
    }

    private var appStoreReviewUrl: URL {
        URL(
            string: "https://itunes.apple.com/us/app/apple-store/id1619504857?mt=8&action=write-review"
        )!
    }

    @Reducer
    public struct Destination {

        @ObservableState
        public enum State: Equatable {
            case alert(AlertState<Action.Alert>)
            case restore(StoreKitReducer.State)
            case termsAndPrivacy(TermsAndPrivacy.State)
        }

        @CasePathable
        public enum Action {
            case alert(Alert)
            case termsAndPrivacy(TermsAndPrivacy.Action)
            case restore(StoreKitReducer.Action)

            public enum Alert: Equatable {}
        }

        public var body: some Reducer<State, Action> {

            Scope(state: /State.alert, action: /Action.alert) {}

            Scope(state: /State.termsAndPrivacy, action: /Action.termsAndPrivacy) {
                TermsAndPrivacy()
            }

            Scope(state: /State.restore, action: /Action.restore) {
                StoreKitReducer()
            }

        }
    }

}

let settingsLogger = Logger(subsystem: "com.eCardify.AddaMeIOS", category: "settings.reducer")
