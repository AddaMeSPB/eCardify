import Foundation
import LoggerKit

// Domain name for development — reads from xcconfig in production
private let devDomainName = "192.168.1.204:3030"
public struct AppConfiguration {

    public enum ApiEnvironment: String {
        case development
        case production

        var isTestEnvironment: Bool {
            self != .production
        }

        var shortDescription: String {
            switch self {
            case .development:
                return "Dev"
            case .production:
                return "Prod"
            }
        }
    }

    private enum Keys {
        static let appName = "eCardify_IOS_APP_NAME"
        static let apiEnvironment = "eCardify_IOS_ENVIRONMENT"
        static let productIds = "Product_IDS"
        static let apiURL = "ROOT_URL"
        static let webSocketUrl = "WEB_SOCKET_URL"
        static let neuAuthURL = "NEUAUTH_URL"
        static let neuAuthClientId = "NEUAUTH_CLIENT_ID"
    }

    public let appName: String
    public let apiURL: String
    public let webSocketUrl: String
    public let productIds: String
    public let apiEnvironment: ApiEnvironment
    public let completeAppVersion: String?

    /// NeuAuth server base URL (e.g. "https://neuauth.byalif.app")
    public let neuAuthURL: String

    /// NeuAuth tenant client ID from admin dashboard
    public let neuAuthClientId: String

    public init(
        appName: String,
        apiURL: String,
        webSocketUrl: String,
        productIds: String,
        apiEnvironment: ApiEnvironment,
        completeAppVersion: String?,
        neuAuthURL: String = "https://neuauth.byalif.app",
        neuAuthClientId: String = ""
    ) {
        self.appName = appName
        self.apiURL = apiURL
        self.webSocketUrl = webSocketUrl
        self.productIds = productIds
        self.apiEnvironment = apiEnvironment
        self.completeAppVersion = completeAppVersion
        self.neuAuthURL = neuAuthURL
        self.neuAuthClientId = neuAuthClientId
    }

}

extension AppConfiguration {

    public static func live(bundle: Bundle) -> AppConfiguration {
        AppConfiguration(bundle: bundle)
    }

    public init(bundle: Bundle) {
        guard
            let appName = bundle.object(forInfoDictionaryKey: Keys.appName) as? String,
            let productIds = bundle.object(forInfoDictionaryKey: Keys.productIds) as? String,
            let apiURL = bundle.object(forInfoDictionaryKey: Keys.apiURL) as? String,
            let webSocketURL = bundle.object(forInfoDictionaryKey: Keys.webSocketUrl) as? String,
            let apiEnvironmentKey = bundle.object(forInfoDictionaryKey: Keys.apiEnvironment) as? String,
            let apiEnvironment = ApiEnvironment(rawValue: apiEnvironmentKey)
        else {
            sharedLogger.log(level: .fault,"Couldn't init environment from bundle: \(bundle.infoDictionary ?? [:])")
            fatalError("Couldn't init environment from bundle: \(bundle.infoDictionary ?? [:])")
        }

        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        {
            let appVersionString = "\(version) (\(buildNumber))"
            completeAppVersion = apiEnvironment.isTestEnvironment
            ? appVersionString + " (\(apiEnvironment.shortDescription))"
            : appVersionString
        } else {
            completeAppVersion = nil
        }

        self.appName = appName
        self.apiURL = apiURL
        self.webSocketUrl = webSocketURL
        self.apiEnvironment = apiEnvironment
        self.productIds = productIds

        // NeuAuth config — read from Info.plist or use defaults
        self.neuAuthURL = (bundle.object(forInfoDictionaryKey: Keys.neuAuthURL) as? String)
            ?? "https://neuauth.byalif.app"
        self.neuAuthClientId = (bundle.object(forInfoDictionaryKey: Keys.neuAuthClientId) as? String)
            ?? ""
    }

}

extension AppConfiguration {

    public static func mock() -> AppConfiguration {
        AppConfiguration(
            appName: "eCardify",
            apiURL: "http://10.0.1.4:3030",
            webSocketUrl: "ws://10.10.18.148:3030/v1/chat",
            productIds: "BasicCard_eCardify_testing FlexiCards_eCardify_testing",
            apiEnvironment: .development,
            completeAppVersion: "0.0.1 (1)",
            neuAuthURL: "http://localhost:8080",
            neuAuthClientId: "test-client-id"
        )
    }

}

import Dependencies

private enum AppConfigurationKey: DependencyKey {
    public static let liveValue = AppConfiguration.live(bundle: Bundle.main)
    public static let testValue = AppConfiguration.mock()
}

extension DependencyValues {
    public var appConfiguration: AppConfiguration {
        get { self[AppConfigurationKey.self] }
        set { self[AppConfigurationKey.self] = newValue }
    }
}
