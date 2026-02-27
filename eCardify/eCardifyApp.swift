import UIKit
import SwiftUI
import AppView
import AppFeature
import ComposableArchitecture

final class AppDelegate: NSObject, UIApplicationDelegate {
    let store = Store(initialState: AppReducer.State()) {
        AppReducer()._printChanges()
    }


  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    self.store.send(.appDelegate(.didFinishLaunching))
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
                    .onOpenURL { url in
                        self.appDelegate.store.send(.deepLink(url))
                    }
                    .onChange(of: self.scenePhase) { _, newPhase in
                        self.appDelegate.store.send(.didChangeScenePhase(newPhase))
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
