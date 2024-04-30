import BSON
import UIKit
import APIClient
import Foundation
import NotificationHelpers
import ECSharedModels
import ComposableArchitecture
import RemoteNotificationsClient
import ComposableUserNotifications

public struct AppDelegateReducer: Reducer {
  public typealias State = UserSettings

  public enum Action: Equatable {
    case didFinishLaunching
  }

  @Dependency(\.apiClient) var apiClient
  @Dependency(\.build.number) var buildNumber

  public init() {}

  public func reduce(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .didFinishLaunching:
      return .none
    }
  }
}
