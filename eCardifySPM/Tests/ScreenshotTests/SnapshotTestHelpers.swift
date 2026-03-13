import UIKit
import SnapshotTesting

// MARK: - Device Configurations

/// Apple-required pixel dimensions for App Store screenshots.
/// Only need iPhone 6.9" + iPad 13" — Apple auto-scales to other device sizes.
enum ScreenshotDevice {

    /// iPhone 16 Pro Max (6.9") — renders at 1320×2868px @3x
    static let iPhone6_9 = ViewImageConfig(
        safeArea: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
        size: CGSize(width: 440, height: 956),
        traits: UITraitCollection(traitsFrom: [
            .init(userInterfaceIdiom: .phone),
            .init(displayScale: 3.0),
            .init(horizontalSizeClass: .compact),
            .init(verticalSizeClass: .regular),
            .init(layoutDirection: .leftToRight),
            .init(preferredContentSizeCategory: .medium),
        ])
    )

    /// iPad Pro 13" — renders at 2064×2752px @2x
    static let iPadPro13 = ViewImageConfig(
        safeArea: UIEdgeInsets(top: 24, left: 0, bottom: 20, right: 0),
        size: CGSize(width: 1032, height: 1376),
        traits: UITraitCollection(traitsFrom: [
            .init(userInterfaceIdiom: .pad),
            .init(displayScale: 2.0),
            .init(horizontalSizeClass: .regular),
            .init(verticalSizeClass: .regular),
            .init(layoutDirection: .leftToRight),
            .init(preferredContentSizeCategory: .medium),
        ])
    )
}

// MARK: - Expected Pixel Dimensions

extension ViewImageConfig {
    /// The exact pixel dimensions Apple requires for this device class.
    /// Returns `nil` if no post-processing is needed (e.g. iPhone configs
    /// render at the correct @3x scale on iPhone simulators).
    var expectedPixelSize: CGSize? {
        // iPad Pro 13" must be 2064×2752 @2x but renders at @3x on iPhone sims
        if self.size == CGSize(width: 1032, height: 1376) {
            return CGSize(width: 2064, height: 2752)
        }
        return nil
    }
}

// MARK: - Locale Configuration

/// Maps fastlane locale directory names to Swift Locale identifiers.
struct ScreenshotLocaleConfig: Sendable {
    let fastlaneDir: String   // e.g. "en-US"
    let swiftLocale: String   // e.g. "en_US"

    static let all: [ScreenshotLocaleConfig] = [
        .init(fastlaneDir: "en-US", swiftLocale: "en_US"),
        .init(fastlaneDir: "de-DE", swiftLocale: "de_DE"),
        .init(fastlaneDir: "es-MX", swiftLocale: "es_MX"),
        .init(fastlaneDir: "fr-FR", swiftLocale: "fr_FR"),
        .init(fastlaneDir: "it", swiftLocale: "it_IT"),
        .init(fastlaneDir: "ja", swiftLocale: "ja_JP"),
        .init(fastlaneDir: "ko", swiftLocale: "ko_KR"),
        .init(fastlaneDir: "pt-BR", swiftLocale: "pt_BR"),
        .init(fastlaneDir: "zh-Hans", swiftLocale: "zh_Hans"),
        .init(fastlaneDir: "ru", swiftLocale: "ru_RU"),
    ]

    /// Current locale from environment variable (set by generate_screenshots.sh)
    static var current: ScreenshotLocaleConfig {
        let env = ProcessInfo.processInfo.environment["SCREENSHOT_LOCALE"] ?? "en-US"
        return all.first { $0.fastlaneDir == env } ?? all[0]
    }
}
