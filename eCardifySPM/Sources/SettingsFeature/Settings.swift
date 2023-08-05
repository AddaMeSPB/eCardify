import os
import UIKit
import Build
import Foundation
import KeychainClient
import ECSharedModels
import ComposableStoreKit
import UserDefaultsClient
import NotificationHelpers
import UIApplicationClient
import FoundationExtension
import ComposableArchitecture
import ComposableUserNotifications

public struct Settings: ReducerProtocol {
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


        @PresentationState public var destination: Destination.State? = nil
        @BindingState public var userSettings: UserSettings
        @BindingState public var enableNotifications: Bool

        public var currentUser: UserOutput = .withFirstName
        public var buildNumber: Build.Number?
        public var userNotificationSettings: UserNotificationClient.Notification.Settings?

    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case onAppear
        case didBecomeActive
        case openSettingButtonTapped
        case userNotificationAuthorizationResponse(TaskResult<Bool>)
        case userNotificationSettingsResponse(UserNotificationClient.Notification.Settings)
        case leaveUsAReviewButtonTapped
        case reportABugButtonTapped
        case logOutButtonTapped
        case restoreButtonTapped
    }

  @Dependency(\.build) var build
  @Dependency(\.mainQueue) var mainQueue
  @Dependency(\.continuousClock) var clock
  @Dependency(\.storeKit) var storeKitClient
  @Dependency(\.userDefaults) var userDefaults
  @Dependency(\.keychainClient) var keychainClient
  @Dependency(\.applicationClient) var applicationClient
  @Dependency(\.userNotifications) var userNotifications
  @Dependency(\.remoteNotifications.unregister) var unRegisterForRemoteNotifications

    public init() {}

    public var body: some ReducerProtocol<State, Action> {
        CombineReducers {

            BindingReducer()

            Reduce { state, action in

                switch action {

                case .binding:
                    return .none

                case .binding(\.$enableNotifications):
                    guard
                        state.enableNotifications,
                        let userNotificationSettings = state.userNotificationSettings
                    else {
                        // TODO: API request to opt out of all notifications
                        state.enableNotifications = false
                        return .none
                    }

                    state.userNotificationSettings?.authorizationStatus = state.enableNotifications == true ? .authorized : .denied
                    switch userNotificationSettings.authorizationStatus {
                    case .notDetermined, .provisional:
                        state.enableNotifications = true
                        return .task {
                            await .userNotificationAuthorizationResponse(
                                TaskResult {
                                    try await self.userNotifications.requestAuthorization([.alert, .badge, .sound])
                                }
                            )
                        }
                        .animation()

                    case .denied:
                        state.enableNotifications = false
                        return .none

                    case .authorized:
                        state.enableNotifications = true
                        return .task { .userNotificationAuthorizationResponse(.success(true)) }

                    case .ephemeral:
                        state.enableNotifications = true
                        return .none

                    @unknown default:
                        return .none
                    }

                case .onAppear:
                    state.buildNumber = self.build.number()

                    do {
                        state.currentUser = try keychainClient.readCodable(.user, self.build.identifier(), UserOutput.self)
                    } catch {
                        // fatalError("Do soemthing from SettingsFeature!")
                        logger.error("cant get current user from keychainClient ")
                    }

                    return .merge(
                        .run { send in

                            async let settingsResponse: Void = send(
                                .userNotificationSettingsResponse(
                                    self.userNotifications.getNotificationSettings()
                                ),
                                animation: .default
                            )

                            _ = await settingsResponse
                        },

                        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
                            .map { _ in .didBecomeActive }
                            .eraseToEffect()
                    )

                case .openSettingButtonTapped:
                    return .fireAndForget {
                        guard
                            let url = await URL(string: self.applicationClient.openSettingsURLString())
                        else { return }
                        _ = await self.applicationClient.open(url, [:])
                    }

                case let .userNotificationAuthorizationResponse(.success(granted)):
                    state.enableNotifications = granted
                    return granted
                    ?  .fireAndForget {
                        await self.unRegisterForRemoteNotifications()
                    }// .fireAndForget { await self.registerForRemoteNotifications() }
                    : .none

                case .userNotificationAuthorizationResponse:
                    return .none

                case let .userNotificationSettingsResponse(settings):
                    state.userNotificationSettings = settings
                    state.enableNotifications = settings.authorizationStatus == .authorized
                    return .none

                case .leaveUsAReviewButtonTapped:

                    return .fireAndForget {
                        _ = await self.applicationClient.open(appStoreReviewUrl, [:])
                    }

                case .didBecomeActive:
                    return .task {
                        await .userNotificationSettingsResponse(
                            self.userNotifications.getNotificationSettings()
                        )
                    }

                case .reportABugButtonTapped:
                    return .fireAndForget { [currentUser = state.currentUser] in
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

                        _ = await self.applicationClient.open(components.url!, [:])
                    }
                case .logOutButtonTapped:
                    return .none

                  case .restoreButtonTapped:
                    state.destination = .restore(.init())
                    return .run { send in
                      try await clock.sleep(for: .seconds(1))
                      await send(.destination(.presented(.restore(.restoreButtonTapped))))
                    }
                    
                  case .destination:
                    return .none
                }
            }
            .ifLet(\.$destination, action: /Action.destination) {
              Destination()
            }
        }
    }

    private var appStoreReviewUrl: URL {
      URL(
        string: "https://itunes.apple.com/us/app/apple-store/id1619504857?mt=8&action=write-review"
      )!
    }

  public struct Destination: ReducerProtocol {


    public enum State: Equatable {
      case alert(AlertState<Action.Alert>)
      case restore(StoreKitReducer.State)
      case termsAndPrivacy(TermsAndPrivacy.State)
    }

    public enum Action: Equatable {
      case alert(Alert)
      case termsAndPrivacy(TermsAndPrivacy.Action)
      case restore(StoreKitReducer.Action)

      public enum Alert: Equatable {}
    }

    public var body: some ReducerProtocol<State, Action> {

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

public let logger = Logger(subsystem: "com.eCardify.AddaMeIOS", category: "settins.reducer")
