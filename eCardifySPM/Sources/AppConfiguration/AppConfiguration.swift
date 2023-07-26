import Foundation
import LoggerKit

private let devDomainName = "10.0.1.4:3030" //"172.20.10.10:3030" //"192.168.1.28:3030" //"10.0.1.4:3030"

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
    }

    public let appName: String
    public let apiURL: String
    public let webSocketUrl: String
    public let productIds: String
    public let apiEnvironment: ApiEnvironment
    public let completeAppVersion: String?

    public init(
        appName: String,
        apiURL: String,
        webSocketUrl: String,
        productIds: String,
        apiEnvironment: ApiEnvironment,
        completeAppVersion: String?
    ) {
        self.appName = appName
        self.apiURL = apiURL
        self.webSocketUrl = webSocketUrl
        self.productIds = productIds
        self.apiEnvironment = apiEnvironment
        self.completeAppVersion = completeAppVersion
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
            completeAppVersion: "0.0.1 (1)"
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
