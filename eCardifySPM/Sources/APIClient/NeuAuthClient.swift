import Foundation
import LoggerKit
import Dependencies
import ECSharedModels
import AppConfiguration

// MARK: - NeuAuth API Client

/// Dedicated client for NeuAuth authentication server.
/// Uses plain URLSession with X-Client-ID header for multi-tenancy.
public struct NeuAuthClient: Sendable {

    public var sendOtp: @Sendable (NeuAuthOtpRequest) async throws -> NeuAuthOtpResponse
    public var verifyOtp: @Sendable (NeuAuthOtpVerifyRequest) async throws -> NeuAuthResponse
    public var refreshToken: @Sendable (NeuAuthRefreshRequest) async throws -> NeuAuthResponse
    public var logout: @Sendable (NeuAuthRefreshRequest) async throws -> Void

    public init(
        sendOtp: @escaping @Sendable (NeuAuthOtpRequest) async throws -> NeuAuthOtpResponse,
        verifyOtp: @escaping @Sendable (NeuAuthOtpVerifyRequest) async throws -> NeuAuthResponse,
        refreshToken: @escaping @Sendable (NeuAuthRefreshRequest) async throws -> NeuAuthResponse,
        logout: @escaping @Sendable (NeuAuthRefreshRequest) async throws -> Void
    ) {
        self.sendOtp = sendOtp
        self.verifyOtp = verifyOtp
        self.refreshToken = refreshToken
        self.logout = logout
    }
}

// MARK: - Live Implementation

extension NeuAuthClient {
    /// Create a live NeuAuth client configured with base URL and client ID
    public static func live(baseURL: String, clientId: String) -> NeuAuthClient {
        let decoder = JSONDecoder()

        return NeuAuthClient(
            sendOtp: { request in
                let data = try await performRequest(
                    baseURL: baseURL,
                    path: "/api/v1/auth/otp/send",
                    body: request,
                    clientId: clientId
                )
                return try decoder.decode(NeuAuthOtpResponse.self, from: data)
            },
            verifyOtp: { request in
                let data = try await performRequest(
                    baseURL: baseURL,
                    path: "/api/v1/auth/otp/verify",
                    body: request,
                    clientId: clientId
                )
                return try decoder.decode(NeuAuthResponse.self, from: data)
            },
            refreshToken: { request in
                let data = try await performRequest(
                    baseURL: baseURL,
                    path: "/api/v1/auth/refresh",
                    body: request,
                    clientId: clientId
                )
                return try decoder.decode(NeuAuthResponse.self, from: data)
            },
            logout: { request in
                _ = try await performRequest(
                    baseURL: baseURL,
                    path: "/api/v1/auth/logout",
                    body: request,
                    clientId: clientId
                )
            }
        )
    }
}

// MARK: - Network Helpers

private func performRequest<T: Encodable>(
    baseURL: String,
    path: String,
    body: T,
    clientId: String,
    accessToken: String? = nil
) async throws -> Data {
    guard let url = URL(string: baseURL + path) else {
        throw NeuAuthError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(clientId, forHTTPHeaderField: "X-Client-ID")

    if let token = accessToken {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    let encoder = JSONEncoder()
    request.httpBody = try encoder.encode(body)

    let (data, response) = try await URLSession.shared.data(for: request)

    #if DEBUG
    sharedLogger.log("NeuAuth \(path): \(String(data: data, encoding: .utf8) ?? "")")
    #endif

    guard let httpResponse = response as? HTTPURLResponse else {
        throw NeuAuthError.unknown
    }

    switch httpResponse.statusCode {
    case 200..<300:
        return data
    case 401:
        let errorBody = try? JSONDecoder().decode(NeuAuthErrorResponse.self, from: data)
        throw NeuAuthError.unauthorized(errorBody?.error ?? "Unauthorized")
    case 429:
        throw NeuAuthError.rateLimited
    default:
        let errorBody = try? JSONDecoder().decode(NeuAuthErrorResponse.self, from: data)
        throw NeuAuthError.serverError(
            statusCode: httpResponse.statusCode,
            message: errorBody?.error ?? "Unknown error"
        )
    }
}

// MARK: - Error Types

public enum NeuAuthError: Error, Equatable {
    case invalidURL
    case unauthorized(String)
    case rateLimited
    case serverError(statusCode: Int, message: String)
    case unknown
}

private struct NeuAuthErrorResponse: Codable {
    let error: String
}

// MARK: - TCA Dependency

private enum NeuAuthClientKey: TestDependencyKey {
    public static let testValue = NeuAuthClient(
        sendOtp: { _ in
            NeuAuthOtpResponse(message: "Verification code sent", expiresIn: 900)
        },
        verifyOtp: { _ in
            NeuAuthResponse(
                accessToken: "test-access-token",
                refreshToken: "test-refresh-token",
                user: NeuAuthUser(
                    id: UUID(),
                    email: "test@example.com",
                    emailVerified: true,
                    roles: ["user"],
                    tenantId: UUID()
                )
            )
        },
        refreshToken: { _ in
            NeuAuthResponse(
                accessToken: "refreshed-access-token",
                refreshToken: "refreshed-refresh-token",
                user: NeuAuthUser(
                    id: UUID(),
                    email: "test@example.com",
                    emailVerified: true,
                    roles: ["user"],
                    tenantId: UUID()
                )
            )
        },
        logout: { _ in }
    )
}

extension NeuAuthClientKey: DependencyKey {
    public static let liveValue: NeuAuthClient = {
        let config = DependencyValues._current.appConfiguration
        return NeuAuthClient.live(
            baseURL: config.neuAuthURL,
            clientId: config.neuAuthClientId
        )
    }()
}

extension DependencyValues {
    public var neuAuthClient: NeuAuthClient {
        get { self[NeuAuthClientKey.self] }
        set { self[NeuAuthClientKey.self] = newValue }
    }
}
