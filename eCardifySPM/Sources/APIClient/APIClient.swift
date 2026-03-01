import Build
import LoggerKit
import InfoPlist
import Foundation
import URLRouting
import Dependencies
import KeychainClient
import AppConfiguration
import FoundationExtension
import ECSharedModels

public typealias APIClient = URLRoutingClient<SiteRoute>

public enum APIClientKey: TestDependencyKey {
    public static let testValue = APIClient.failing
}

extension APIClientKey: DependencyKey {
    public static let baseURL = DependencyValues._current.appConfiguration.apiURL
    public static let liveValue: APIClient = APIClient.live(
        router: SiteRouter().baseURL(APIClientKey.baseURL)
    )
}

extension DependencyValues {
    public var apiClient: APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}

public enum APIError: Error {
    case serviceError(statusCode: Int, APIErrorPayload)
    case unknown

    init(error: Error) {
        if let apiError = error as? APIError {
            self = apiError
        } else {
            self = .unknown
        }
    }
}

extension APIError: Equatable {}

public struct APIErrorPayload: Codable, Equatable {
    let reason: String?
}

extension APIClient {

    @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
    public func request<Value: Decodable>(
        for route: Route,
        as type: Value.Type = Value.self,
        decoder: JSONDecoder = .init()
    ) async throws -> Value {
        guard var request = try? SiteRouter().baseURL(APIClientKey.baseURL).request(for: route)
        else { throw URLError(.badURL) }
        request.setHeaders()

        let (data, response) = try await URLSession.shared.data(for: request)

        #if DEBUG
        sharedLogger.log(String(data: data, encoding: .utf8) ?? "<non-UTF8 data>")
        #endif


        if let statusCode = (response as? HTTPURLResponse)?.statusCode {
            switch statusCode {
            case 200 ..< 300:
                return try decoder.decode(Value.self, from: data)

            case 400 ..< 500:
                if let payload = try? decoder.decode(APIErrorPayload.self, from: data) {
                    throw APIError.serviceError(statusCode: statusCode, payload)
                }
                // Server returned non-JSON error (e.g. plain text "Missing authorization bearer header")
                let reason = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIError.serviceError(statusCode: statusCode, APIErrorPayload(reason: reason))

            default:
                sharedLogger.log("unknown")
                throw APIError.unknown
            }
        } else {
            sharedLogger.log("unknown")
            throw APIError.unknown
        }
    }
}
