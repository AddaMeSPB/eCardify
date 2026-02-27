import XCTest
import SwiftUI
import SnapshotTesting
import ComposableArchitecture
import ECSharedModels
import L10nResources

@testable import AppView
@testable import GenericPassFeature
@testable import SettingsFeature
import AuthenticationView
@testable import AuthenticationCore

// MARK: - Screenshot Tests

/// Deterministic App Store screenshot generation using swift-snapshot-testing.
///
/// Env vars are NOT forwarded to the simulator test process, so locale
/// iteration happens inside the test methods themselves.
///
/// Run manually:
///   xcodebuild test \
///     -scheme eCardifySPM-Package \
///     -only-testing ScreenshotTests \
///     -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max'
final class ScreenshotTests: XCTestCase {

    // MARK: - Configuration

    /// Set to `false` to skip screenshot generation in normal test runs.
    /// Env vars can't be forwarded to the simulator, so this is the toggle.
    private var shouldGenerate: Bool { true }

    /// Locales to generate screenshots for.
    /// Set to `[.current]` or a single locale for faster iteration.
    private var locales: [ScreenshotLocaleConfig] {
        ScreenshotLocaleConfig.all
    }

    // MARK: - Output

    /// Resolves to `fastlane/screenshots/{locale}/`
    private func outputDirectory(for locale: ScreenshotLocaleConfig) -> String {
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
    /// and saves it to `fastlane/screenshots/{locale}/{filename}`.
    private func captureAndSave<V: View>(
        _ view: V,
        config: ViewImageConfig,
        filename: String,
        locale: ScreenshotLocaleConfig
    ) {
        // Switch the L10n bundle to the target locale so L() returns
        // translated strings when the view body is evaluated.
        setScreenshotLocale(locale.fastlaneDir)

        let localizedView = view.environment(
            \.locale,
            Locale(identifier: locale.swiftLocale)
        )

        let vc = UIHostingController(rootView: localizedView)
        vc.overrideUserInterfaceStyle = .light

        // Create output directory
        let dir = outputDirectory(for: locale)
        try! FileManager.default.createDirectory(
            atPath: dir,
            withIntermediateDirectories: true
        )

        // Use verifySnapshot in record mode, which writes the PNG file.
        // verifySnapshot names files as "{testName}.1.png", so we strip ".png"
        // from the filename to use as testName, then rename afterward.
        let baseName = filename.replacingOccurrences(of: ".png", with: "")
        let failure = verifySnapshot(
            of: vc,
            as: .image(on: config),
            record: true,
            snapshotDirectory: dir,
            testName: baseName
        )

        if let failure {
            // In record mode, "failure" is expected (it means a new reference was recorded).
            // Only truly fail if it's not a recording message.
            if !failure.contains("record") && !failure.contains("Record") {
                XCTFail(failure)
            }
        }

        // Rename from "{baseName}.1.png" → "{filename}" for fastlane compatibility
        let generatedPath = URL(fileURLWithPath: dir)
            .appendingPathComponent("\(baseName).1.png").path
        let finalPath = URL(fileURLWithPath: dir)
            .appendingPathComponent(filename).path
        try? FileManager.default.removeItem(atPath: finalPath)
        try? FileManager.default.moveItem(atPath: generatedPath, toPath: finalPath)
    }

    /// Snapshots a SwiftUI view on both iPhone 6.9" and iPad Pro 13"
    /// for every locale in `self.locales`.
    private func snapshotAllDevices<V: View>(
        _ view: V,
        screenName: String
    ) {
        for locale in locales {
            // iPhone 6.9" (1320×2868 @3x)
            captureAndSave(
                view,
                config: ScreenshotDevice.iPhone6_9,
                filename: "\(screenName)_iPhone.png",
                locale: locale
            )

            // iPad Pro 13" (2064×2752 @2x)
            captureAndSave(
                view,
                config: ScreenshotDevice.iPadPro13,
                filename: "\(screenName)_iPad.png",
                locale: locale
            )
        }
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

        let store = Store<WalletPassList.State, WalletPassList.Action>(
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

        let store = Store<WalletPassDetails.State, WalletPassDetails.Action>(
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

        let store = Store<GenericPassForm.State, GenericPassForm.Action>(
            initialState: GenericPassForm.State(
                storeKitState: .demoProducts,
                vCard: .demoAlif,
                telephone: .init(type: .work, number: "+8801712345678"),
                email: "alif@ecardify.app"
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

        let store = Store<GenericPassForm.State, GenericPassForm.Action>(
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

        let store = Store<Settings.State, Settings.Action>(
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

        let store = Store<Login.State, Login.Action>(
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

        let store = Store<WalletPassList.State, WalletPassList.Action>(
            initialState: WalletPassList.State()
        ) {
            EmptyReducer()
        }

        let view = WalletPassView(store: store)
        snapshotAllDevices(view, screenName: "08_empty_state")
    }
}
