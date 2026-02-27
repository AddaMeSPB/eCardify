import XCTest
import SwiftUI
import SnapshotTesting
import ComposableArchitecture
import ECSharedModels

@testable import AppView
import GenericPassFeature
import SettingsFeature
import AuthenticationView
import AuthenticationCore

// MARK: - Screenshot Tests

/// Deterministic App Store screenshot generation using swift-snapshot-testing.
///
/// Gated by `GENERATE_SCREENSHOTS=1` env var — skipped in normal test runs.
/// Locale driven by `SCREENSHOT_LOCALE` env var (default: en-US).
///
/// Run manually:
///   GENERATE_SCREENSHOTS=1 xcodebuild test \
///     -scheme eCardify \
///     -only-testing ScreenshotTests \
///     -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max'
final class ScreenshotTests: XCTestCase {

    // MARK: - Gating

    private var shouldGenerate: Bool {
        ProcessInfo.processInfo.environment["GENERATE_SCREENSHOTS"] == "1"
    }

    // MARK: - Output

    /// Resolves to `fastlane/screenshots/{locale}/`
    private var outputDirectory: String {
        let locale = ScreenshotLocaleConfig.current
        let testFile = URL(fileURLWithPath: #filePath)
        // Tests/ScreenshotTests/ScreenshotTests.swift → eCardifySPM/
        let spmRoot = testFile
            .deletingLastPathComponent() // ScreenshotTests/
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // eCardifySPM/
        let eCardifyRoot = spmRoot.deletingLastPathComponent() // eCardify/
        return eCardifyRoot
            .appendingPathComponent("fastlane")
            .appendingPathComponent("screenshots")
            .appendingPathComponent(locale.fastlaneDir)
            .path
    }

    // MARK: - Helpers

    /// Captures a screenshot of a SwiftUI view at the given device config
    /// and writes it directly to `outputDirectory/{filename}.png`.
    ///
    /// Bypasses swift-snapshot-testing's directory/naming conventions
    /// so filenames match what the landing page PhoneCarousel expects.
    private func captureAndSave<V: View>(
        _ view: V,
        config: ViewImageConfig,
        filename: String
    ) {
        let localeConfig = ScreenshotLocaleConfig.current
        let localizedView = view.environment(
            \.locale,
            Locale(identifier: localeConfig.swiftLocale)
        )

        let vc = UIHostingController(rootView: localizedView)
        vc.overrideUserInterfaceStyle = .light

        let strategy: Snapshotting<UIViewController, UIImage> = .image(on: config)
        let exp = expectation(description: filename)

        strategy.snapshot.run(vc) { image in
            let dir = self.outputDirectory
            try! FileManager.default.createDirectory(
                atPath: dir,
                withIntermediateDirectories: true
            )
            let path = URL(fileURLWithPath: dir)
                .appendingPathComponent(filename)
            try! image.pngData()!.write(to: path)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 30)
    }

    /// Snapshots a SwiftUI view on both iPhone 6.9" and iPad Pro 13".
    private func snapshotAllDevices<V: View>(
        _ view: V,
        screenName: String
    ) {
        // iPhone 6.9" (1320×2868 @3x)
        captureAndSave(
            view,
            config: ScreenshotDevice.iPhone6_9,
            filename: "\(screenName)_iPhone.png"
        )

        // iPad Pro 13" (2064×2752 @2x)
        captureAndSave(
            view,
            config: ScreenshotDevice.iPadPro13,
            filename: "\(screenName)_iPad.png"
        )
    }

    // MARK: - 01 Onboarding Welcome

    func test_01_OnboardingWelcome() {
        guard shouldGenerate else { return }

        let view = OnboardingView()
        snapshotAllDevices(view, screenName: "01_onboarding")
    }

    // MARK: - 02 Card List (populated)

    func test_02_CardList() {
        guard shouldGenerate else { return }

        let store = Store(
            initialState: WalletPassList.State(
                wPassLocal: demoWPassLocal
            )
        ) {
            EmptyReducer()
        }

        let view = WalletPassView(store: store)
        snapshotAllDevices(view, screenName: "02_card_list")
    }

    // MARK: - 03 Card Detail

    func test_03_CardDetail() {
        guard shouldGenerate else { return }

        let store = Store(
            initialState: WalletPassDetails.State.demoAlif
        ) {
            EmptyReducer()
        }

        let view = WalletPassDetailsView(store: store)
        snapshotAllDevices(view, screenName: "03_card_detail")
    }

    // MARK: - 04 Create Card Form

    func test_04_CreateCardForm() {
        guard shouldGenerate else { return }

        let store = Store(
            initialState: GenericPassForm.State(
                storeKitState: .demoProducts,
                vCard: .demo,
                telephone: .demo,
                email: "demogood@mail.com"
            )
        ) {
            EmptyReducer()
        }

        let view = GenericPassFormView(store: store)
        snapshotAllDevices(view, screenName: "04_create_card")
    }

    // MARK: - 05 Create Card Form (Custom)

    func test_05_CreateCardFormCustom() {
        guard shouldGenerate else { return }

        let store = Store(
            initialState: GenericPassForm.State(
                storeKitState: .demoProductsCustom,
                vCard: .demoSarah,
                telephone: .init(type: .work, number: "+12125551234"),
                email: "sarah.johnson@techventures.io"
            )
        ) {
            EmptyReducer()
        }

        let view = GenericPassFormView(store: store)
        snapshotAllDevices(view, screenName: "05_create_card_custom")
    }

    // MARK: - 06 Settings

    func test_06_Settings() {
        guard shouldGenerate else { return }

        let store = Store(
            initialState: Settings.State(
                currentUser: .demoScreenshot
            )
        ) {
            EmptyReducer()
        }

        let view = NavigationStack {
            SettingsView(store: store)
        }
        snapshotAllDevices(view, screenName: "06_settings")
    }

    // MARK: - 07 Login

    func test_07_Login() {
        guard shouldGenerate else { return }

        let store = Store(
            initialState: Login.State()
        ) {
            EmptyReducer()
        }

        let view = AuthenticationView(store: store)
        snapshotAllDevices(view, screenName: "07_login")
    }

    // MARK: - 08 Card List Empty State

    func test_08_EmptyState() {
        guard shouldGenerate else { return }

        let store = Store(
            initialState: WalletPassList.State()
        ) {
            EmptyReducer()
        }

        let view = WalletPassView(store: store)
        snapshotAllDevices(view, screenName: "08_empty_state")
    }
}
