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

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
      self.viewStore.send(.appDelegate(.didRegisterForRemoteNotifications(.success(deviceToken))))
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
      self.viewStore.send(.appDelegate(.didRegisterForRemoteNotifications(.failure(error))))
  }
}

@main
struct eCardifyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
      WindowGroup {
        AppView(store: self.appDelegate.store)
      }
      .onChange(of: self.scenePhase) {
        self.appDelegate.viewStore.send(.didChangeScenePhase($0))
      }
    }
}

//{
//  "formatVersion": 1,
//  "passTypeIdentifier": "pass.ecardify.addame.com",
//  "serialNumber": "8j23fm3",
//  "webServiceURL": "https://example.com/passes/",
//  "authenticationToken": "vxwxd7J8AlNNFPS8k0a0FfUFtq0ewzFdc",
//  "teamIdentifier": "6989658CU5",
//  "locations": [
//    {
//      "longitude": -122.3748889,
//      "latitude": 37.6189722
//    },
//    {
//      "longitude": -122.03118,
//      "latitude": 37.33182
//    }
//  ],
//  "barcode": {
//    "message": "123456789",
//    "format": "PKBarcodeFormatPDF417",
//    "messageEncoding": "iso-8859-1"
//  },
//  "organizationName": "Toy Town",
//  "description": "Toy Town Membership",
//  "logoText": "Toy Town",
//  "foregroundColor": "gb(255, 255, 255)",
//  "backgroundColor": "gb(197, 31, 31)",
//  "generic": {
//    "primaryFields": [
//      {
//        "key": "member",
//        "value": "Johnny Appleseed"
//      }
//    ],
//    "secondaryFields": [
//      {
//        "key": "subtitle",
//        "label": "MEMBER SINCE",
//        "value": "2012"
//      }
//    ],
//    "auxiliaryFields": [
//      {
//        "key": "level",
//        "label": "LEVEL",
//        "value": "Platinum"
//      },
//      {
//        "key": "favorite",
//        "label": "FAVORITE TOY",
//        "value": "Bucky Ball Magnets",
//        "textAlignment": "PKTextAlignmentRight"
//      }
//    ],
//    "backFields": [
//      {
//        "numberStyle": "PKNumberStyleSpellOut",
//        "label": "spelled out",
//        "key": "numberStyle",
//        "value": 200
//      },
//      {
//        "label": "in Reals",
//        "key": "currency",
//        "value": 200,
//        "currencyCode": "BRL"
//      },
//      {
//        "dateStyle": "PKDateStyleFull",
//        "label": "full date",
//        "key": "dateFull",
//        "value": "1980-05-07T10:00-05:00"
//      },
//      {
//        "label": "full time",
//        "key": "timeFull",
//        "value": "1980-05-07T10:00-05:00",
//        "timeStyle": "PKDateStyleFull"
//      },
//      {
//        "dateStyle": "PKDateStyleShort",
//        "label": "short date and time",
//        "key": "dateTime",
//        "value": "1980-05-07T10:00-05:00",
//        "timeStyle": "PKDateStyleShort"
//      },
//      {
//        "dateStyle": "PKDateStyleShort",
//        "label": "relative date",
//        "key": "elStyle",
//        "value": "2013-04-24T10:00-05:00",
//        "isRelative": true
//      }
//    ]
//  }
//}
//
