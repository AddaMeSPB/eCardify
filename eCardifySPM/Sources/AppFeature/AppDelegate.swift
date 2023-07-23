import os
import BSON
import UIKit
import APIClient
import Foundation
import NotificationHelpers
import ECSharedModels
import ComposableArchitecture
import RemoteNotificationsClient
import ComposableUserNotifications

public struct AppDelegateReducer: ReducerProtocol {
  public typealias State = UserSettings

  public enum Action: Equatable {
    case didFinishLaunching
    case didRegisterForRemoteNotifications(TaskResult<Data>)
    case userNotifications(UserNotificationClient.DelegateEvent)
    case userSettingsLoaded(TaskResult<UserSettings>)
    case deviceResponse(TaskResult<DeviceOutPut>)
    case getNotificationSettings
    case createOrUpdate(deviceToken: Data)
  }

  @Dependency(\.apiClient) var apiClient
  @Dependency(\.build.number) var buildNumber
  @Dependency(\.remoteNotifications) var remoteNotifications
//  @Dependency(\.applicationClient.setUserInterfaceStyle) var setUserInterfaceStyle
  @Dependency(\.userNotifications) var userNotifications

  public init() {}

  public func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .didFinishLaunching:
      return .run { send in
        await withThrowingTaskGroup(of: Void.self) { group in
          group.addTask {
            for await event in self.userNotifications.delegate() {
              await send(.userNotifications(event))
            }
          }

          group.addTask {
            let settings = await self.userNotifications.getNotificationSettings()
            switch settings.authorizationStatus {
            case .authorized:
              guard
                try await self.userNotifications.requestAuthorization([.alert, .badge, .sound])
              else { return }
            case .notDetermined, .provisional:
              guard try await self.userNotifications.requestAuthorization(.provisional)
              else { return }
            default:
              return
            }
          }

            group.addTask {
                await registerForRemoteNotificationsAsync(
                    remoteNotifications: self.remoteNotifications,
                    userNotifications: self.userNotifications
                )
            }
        }
      }

    case let .didRegisterForRemoteNotifications(.success(data)):
        return .run { send in
            await send(.getNotificationSettings)
            await send(.createOrUpdate(deviceToken: data))
        }

    case .didRegisterForRemoteNotifications(.failure):
      return .none

    case .getNotificationSettings:

        logger.info("\(#line) run getNotificationSettings")
        return .run { _ in
           _ = await self.userNotifications.getNotificationSettings()
        }

    case let .createOrUpdate(deviceToken: data):

        // check if have owner id send it
        let identifierForVendor = UIDevice.current.identifierForVendor?.uuidString
        let token = data.toHexString

        let device = DeviceModel(
            _id: .init(),
            ownerId: nil,
            identifierForVendor: identifierForVendor,
            name: UIDevice.current.name,
            model: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion,
            pushToken: token,
            voipToken: ""
        )

        return .task {
            .deviceResponse(
                await TaskResult {
                    try await apiClient.request(
                        for: .authEngine(.devices(.createOrUpdate(input: device))),
                        as: DeviceOutPut.self,
                        decoder: .iso8601
                    )
                }
            )
        }

    case let .userNotifications(.willPresentNotification(_, completionHandler)):
        
      return .fireAndForget { completionHandler(.banner) }

    case .userNotifications:
      return .none

    case let .userSettingsLoaded(result):
      state = (try? result.value) ?? state
        return .fireAndForget { 
//            async let setUI: Void =
//            await self.setUserInterfaceStyle(state.colorScheme.userInterfaceStyle)
//            _ = await setUI

        }

    case .deviceResponse(.success):
        logger.info("\(#line) deviceResponse success")
        return .none

    case .deviceResponse(.failure(let error)):
        logger.error("\(#line) deviceResponse error \(error.localizedDescription)")
        return .none
    }
  }
}

public let logger = Logger(subsystem: "baby.learnplaygrow.learnplaygrowIOS", category: "appDelegate.reducer")
