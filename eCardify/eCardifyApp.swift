import UIKit
import SwiftUI
import AppView
import AppFeature
import ComposableArchitecture

final class AppDelegate: NSObject, UIApplicationDelegate {
  let store = Store(
    initialState: AppReducer.State(),
    reducer: AppReducer()
        ._printChanges()
        .transformDependency(\.self) { _ in }
  )

  var viewStore: ViewStore<Void, AppReducer.Action> {
    ViewStore(self.store.stateless)
  }

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    self.viewStore.send(.appDelegate(.didFinishLaunching))
    return true
  }
}

@main
struct eCardifyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            if _XCTIsTesting || ProcessInfo.processInfo.environment["UITesting"] == "true" {
                UITestingView()
            } else {

                AppView(store: self.appDelegate.store)
                    .onChange(of: self.scenePhase) {
                        self.appDelegate.viewStore.send(.didChangeScenePhase($0))
                    }
            }
        }
    }
}


struct UITestingView: View {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some View {
      AppView(store: self.appDelegate.store)
  }
}
