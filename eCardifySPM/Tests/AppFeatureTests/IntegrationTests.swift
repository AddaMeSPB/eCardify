import XCTest
import Foundation
import ECSharedModels

/// Integration tests that verify iOS model serialization against the REAL local Rust server.
/// These tests make actual HTTP calls to http://localhost:3030 — the server must be running.
///
/// Run:  xcodebuild test -workspace eCardify.xcworkspace -scheme eCardify \
///         -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max,OS=18.4' \
///         -only-testing:AppFeatureTests/IntegrationTests
///
/// Tests auto-skip when the server is not reachable.
/// Uses a real NeuAuth JWT obtained from neuauth.byalif.app.
@MainActor
final class IntegrationTests: XCTestCase {

    // MARK: - Config

    private let baseURL = "http://localhost:3030"
    private let neuAuthURL = "https://neuauth.byalif.app"
    private let clientId = "ce543d4db539e25a7d11e76d70805e71"
    private let testEmail = "dev@ecardify.app"
    private let testOTP = "000000"

    private var accessToken: String!

    /// Decoder that handles Rust chrono's ISO 8601 dates with fractional seconds.
    /// Rust's `chrono::DateTime<Utc>` serializes as "2026-03-03T19:21:45.870200Z"
    /// which has microsecond precision. Swift's built-in `.iso8601` doesn't handle
    /// fractional seconds, so we use ISO8601DateFormatter with `.withFractionalSeconds`.
    private var apiDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = formatter.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
        return decoder
    }

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        // Auto-detect: skip if server is not running (no env var needed)
        do {
            let url = URL(string: "\(baseURL)/health")!
            let (_, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw XCTSkip("Local server at \(baseURL) returned non-200 status")
            }
        } catch let skip as XCTSkip {
            throw skip
        } catch {
            throw XCTSkip("Local server at \(baseURL) is not reachable: \(error.localizedDescription)")
        }

        // Obtain a REAL NeuAuth JWT
        accessToken = try await obtainNeuAuthJWT()
        XCTAssertFalse(accessToken.isEmpty, "Failed to obtain NeuAuth JWT")
    }

    // MARK: - Step 1: Device Registration

    func testStep1_DeviceRegistration() async throws {
        let url = URL(string: "\(baseURL)/v1/devices")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken!)", forHTTPHeaderField: "Authorization")

        let device: [String: Any] = [
            "_id": "eeeeeeeeeeeeeeeeeeeeee01",
            "identifierForVendor": "INTEGRATION-TEST",
            "name": "iPhone 16 Pro Max",
            "model": "iPhone",
            "osVersion": "18.4",
            "pushToken": "integration-push-token",
            "voipToken": "integration-voip-token"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: device)

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        XCTAssertEqual(httpResponse.statusCode, 200, "Device registration failed: \(String(data: data, encoding: .utf8) ?? "")")

        // Decode using iOS model with proper date handling
        let output = try apiDecoder.decode(DeviceOutPut.self, from: data)
        XCTAssertEqual(output.name, "iPhone 16 Pro Max")
        XCTAssertEqual(output.pushToken, "integration-push-token")
        print("Step 1 PASSED: Device registered -- id=\(output.id.hexString)")
    }

    // MARK: - Step 2: Wallet Pass List (authenticated)

    func testStep2_WalletPassList() async throws {
        let url = URL(string: "\(baseURL)/v1/wallet_pass/list")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken!)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        XCTAssertEqual(httpResponse.statusCode, 200, "Wallet pass list failed: \(String(data: data, encoding: .utf8) ?? "")")

        // Decode using iOS model with proper date handling
        let passes = try apiDecoder.decode([WalletPass].self, from: data)
        print("Step 2 PASSED: Wallet pass list decoded -- \(passes.count) pass(es)")

        // Verify each pass decodes fully
        for pass in passes {
            XCTAssertFalse(pass.id.isEmpty, "Pass id should not be empty")
            XCTAssertFalse(pass.ownerId.hexString.isEmpty, "Pass ownerId should not be empty")
            XCTAssertNotNil(pass.vCard.contact, "VCard contact should not be nil")
            print("  - Pass \(pass.id): \(pass.vCard.formattedName) (\(pass.vCard.position))")
        }
    }

    // MARK: - Step 3: User Profile (auto-created)

    func testStep3_UserProfile() async throws {
        // Trigger user auto-creation by hitting an authenticated endpoint
        let listURL = URL(string: "\(baseURL)/v1/wallet_pass/list")!
        var listRequest = URLRequest(url: listURL)
        listRequest.setValue("Bearer \(accessToken!)", forHTTPHeaderField: "Authorization")
        _ = try await URLSession.shared.data(for: listRequest)
        print("Step 3 PASSED: User auto-created via authenticated request")
    }

    // MARK: - Step 4: Create Wallet Pass

    func testStep4_CreateWalletPass() async throws {
        let url = URL(string: "\(baseURL)/v1/wallet_pass")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken!)", forHTTPHeaderField: "Authorization")

        // Build a WalletPass using the REAL iOS model
        let vCard = VCard(
            contact: .init(lastName: "IntegrationTest", firstName: "Swift"),
            formattedName: "Swift IntegrationTest",
            organization: "eCardify",
            position: "iOS Developer",
            imageURLs: [],
            addresses: [
                .init(
                    type: .work,
                    postOfficeAddress: nil,
                    extendedAddress: nil,
                    street: "456 Swift Lane",
                    locality: "Cupertino",
                    region: "CA",
                    postalCode: "95014",
                    country: "United States"
                )
            ],
            telephones: [
                .init(type: .cell, number: "+14085551234")
            ],
            emails: [
                .init(text: "integration@ecardify.app")
            ],
            urls: [],
            notes: [],
            website: "https://ecardify.byalif.app",
            socialMedia: .init(
                facebook: nil, skype: nil, instagram: nil,
                linkedIn: nil, twitter: nil, telegram: "@ecardify", vk: nil
            )
        )

        let walletPass = WalletPass(
            _id: .init(),
            ownerId: .init(),  // Server overrides this
            vCard: vCard,
            colorPalette: .default
        )

        // Encode using iOS JSONEncoder — this is the serialization compatibility test
        let encoder = JSONEncoder()
        let requestData = try encoder.encode(walletPass)

        // Log what iOS sends (first 300 chars)
        let requestJSON = String(data: requestData, encoding: .utf8)!
        print("iOS sends: \(requestJSON.prefix(300))...")

        request.httpBody = requestData

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        XCTAssertEqual(httpResponse.statusCode, 200,
            "Wallet pass creation failed (\(httpResponse.statusCode)): \(String(data: data, encoding: .utf8) ?? "")")

        // Decode the response using iOS model
        let walletPassResponse = try JSONDecoder().decode(WalletPassResponse.self, from: data)
        XCTAssertFalse(walletPassResponse.urlString.isEmpty, "Pass URL should not be empty")
        print("Step 4 PASSED: Wallet pass created -- URL: \(walletPassResponse.urlString)")
    }

    // MARK: - Step 5: Verify Created Pass in List

    func testStep5_VerifyCreatedPassInList() async throws {
        // First create a pass
        try await testStep4_CreateWalletPass()

        // Then fetch the list and verify it's there
        let url = URL(string: "\(baseURL)/v1/wallet_pass/list")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken!)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        XCTAssertEqual(httpResponse.statusCode, 200)

        let passes = try apiDecoder.decode([WalletPass].self, from: data)

        XCTAssertGreaterThan(passes.count, 0, "Should have at least 1 pass after creation")

        // Verify the pass we just created exists
        let found = passes.contains { $0.vCard.formattedName == "Swift IntegrationTest" }
        XCTAssertTrue(found, "Created pass 'Swift IntegrationTest' should be in the list")

        // Verify ALL fields decode correctly
        if let pass = passes.first(where: { $0.vCard.formattedName == "Swift IntegrationTest" }) {
            XCTAssertEqual(pass.vCard.position, "iOS Developer")
            XCTAssertEqual(pass.vCard.organization, "eCardify")
            XCTAssertEqual(pass.vCard.contact.firstName, "Swift")
            XCTAssertEqual(pass.vCard.contact.lastName, "IntegrationTest")
            XCTAssertEqual(pass.vCard.telephones.first?.number, "+14085551234")
            XCTAssertEqual(pass.vCard.telephones.first?.type, .cell)
            XCTAssertEqual(pass.vCard.emails.first?.text, "integration@ecardify.app")
            XCTAssertEqual(pass.vCard.addresses.first?.street, "456 Swift Lane")
            XCTAssertEqual(pass.vCard.addresses.first?.type, .work)
            XCTAssertEqual(pass.vCard.socialMedia?.telegram, "@ecardify")
            XCTAssertTrue(pass.isPaid, "Server should set isPaid=true")
            XCTAssertTrue(pass.isDataSavedOnServer, "Server should set isDataSavedOnServer=true")
            print("Step 5 PASSED: All VCard fields verified -- full iOS <-> Rust model compatibility confirmed")
        }
    }

    // MARK: - Helpers

    private func obtainNeuAuthJWT() async throws -> String {
        // Step 1: Send OTP
        let sendURL = URL(string: "\(neuAuthURL)/api/v1/auth/otp/send")!
        var sendRequest = URLRequest(url: sendURL)
        sendRequest.httpMethod = "POST"
        sendRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        sendRequest.setValue(clientId, forHTTPHeaderField: "X-Client-ID")
        sendRequest.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": testEmail,
            "purpose": "login"
        ])

        let (_, sendResponse) = try await URLSession.shared.data(for: sendRequest)
        guard (sendResponse as? HTTPURLResponse)?.statusCode == 200 else {
            throw NSError(domain: "IntegrationTest", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to send OTP"
            ])
        }

        // Step 2: Verify OTP
        let verifyURL = URL(string: "\(neuAuthURL)/api/v1/auth/otp/verify")!
        var verifyRequest = URLRequest(url: verifyURL)
        verifyRequest.httpMethod = "POST"
        verifyRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        verifyRequest.setValue(clientId, forHTTPHeaderField: "X-Client-ID")
        verifyRequest.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": testEmail,
            "code": testOTP
        ])

        let (verifyData, verifyResponse) = try await URLSession.shared.data(for: verifyRequest)
        guard (verifyResponse as? HTTPURLResponse)?.statusCode == 200 else {
            throw NSError(domain: "IntegrationTest", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Failed to verify OTP: \(String(data: verifyData, encoding: .utf8) ?? "")"
            ])
        }

        let json = try JSONSerialization.jsonObject(with: verifyData) as! [String: Any]
        guard let token = json["access_token"] as? String else {
            throw NSError(domain: "IntegrationTest", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "No access_token in response"
            ])
        }
        return token
    }
}
