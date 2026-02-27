// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "eCardifySPM",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "AppView", targets: ["AppView"]),
        .library(name: "APIClient", targets: ["APIClient"]),
        .library(name: "AppFeature", targets: ["AppFeature"]),
        .library(name: "AppConfiguration", targets: ["AppConfiguration"]),
        .library(name: "AuthenticationCore", targets: ["AuthenticationCore"]),
        .library(name: "AuthenticationView", targets: ["AuthenticationView"]),
        .library(name: "AttachmentS3Client", targets: ["AttachmentS3Client"]),
        .library(name: "GenericPassFeature", targets: ["GenericPassFeature"]),
        .library(name: "VNRecognizeFeature", targets: ["VNRecognizeFeature"]),
        .library(name: "LocalDatabaseClient", targets: ["LocalDatabaseClient"]),
        .library(name: "SettingsFeature", targets: ["SettingsFeature"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "L10nResources", targets: ["L10nResources"])
    ],
    dependencies: [
        // TCA - NOTE: Version must be compatible with CommonTCALibraries
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "1.24.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", from: "1.4.0"),

        // Common libraries - using local path for development
        .package(path: "../../../../CommonTCALibraries"),

        // Shared models - use local path for development
        .package(path: "../../../ECSharedModels"),

        // AWS S3
        .package(url: "https://github.com/soto-project/soto.git", from: "6.0.0"),

        // Local database
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),

        // Phone number field
        .package(url: "https://github.com/MojtabaHs/iPhoneNumberField.git", from: "0.10.0"),

        // Snapshot testing for App Store screenshots
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.17.0"),
    ],
    targets: [
        .target(
            name: "DesignSystem",
            resources: [
                .process("Resources")
            ]
        ),

        .target(
            name: "L10nResources",
            resources: [
                .process("Resources")
            ]
        ),

        .target(
            name: "AppFeature",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "CommonTCALibraries", package: "CommonTCALibraries"),
                .product(name: "ECSharedModels", package: "ECSharedModels"),
                "APIClient", "AttachmentS3Client", "GenericPassFeature",
                "AuthenticationCore", "SettingsFeature"
            ]
        ),

        .target(
            name: "AppView",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "CommonTCALibraries", package: "CommonTCALibraries"),
                .product(name: "ECSharedModels", package: "ECSharedModels"),
                "AppFeature", "GenericPassFeature", "AuthenticationView", "SettingsFeature",
                "DesignSystem", "L10nResources"
            ]
        ),

        .target(
            name: "AppConfiguration",
            dependencies: [
                .product(name: "CommonTCALibraries", package: "CommonTCALibraries")
            ]
        ),

        .target(
            name: "APIClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "CommonTCALibraries", package: "CommonTCALibraries"),
                .product(name: "ECSharedModels", package: "ECSharedModels"),
                "AppConfiguration"
            ]
        ),

        .target(
            name: "AttachmentS3Client",
            dependencies: [
                .product(name: "SotoS3", package: "soto"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "ECSharedModels", package: "ECSharedModels"),
                .product(name: "CommonTCALibraries", package: "CommonTCALibraries")
            ]
        ),

        .target(
            name: "ECImagePicker",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "CommonTCALibraries", package: "CommonTCALibraries"),
                "L10nResources"
            ]
        ),

        .target(
            name: "AuthenticationCore",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "ECSharedModels", package: "ECSharedModels"),
                .product(name: "CommonTCALibraries", package: "CommonTCALibraries"),
                "APIClient", "SettingsFeature"
            ]
        ),

        .target(
            name: "AuthenticationView",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "ECSharedModels", package: "ECSharedModels"),
                .product(name: "CommonTCALibraries", package: "CommonTCALibraries"),
                "AuthenticationCore",
                "DesignSystem", "L10nResources"
            ],
            resources: [
                .process("Resources/PhoneNumberMetadata.json")
            ]
        ),

        .target(
            name: "SettingsFeature",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "ECSharedModels", package: "ECSharedModels"),
                .product(name: "CommonTCALibraries", package: "CommonTCALibraries"),
                "AppConfiguration", "APIClient", "DesignSystem", "L10nResources"
            ]
        ),

        .target(
            name: "VNRecognizeFeature",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies")
            ]
        ),

        .target(
            name: "GenericPassFeature",
            dependencies: [
                .product(name: "CommonTCALibraries", package: "CommonTCALibraries"),
                .product(name: "ECSharedModels", package: "ECSharedModels"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "iPhoneNumberField", package: "iPhoneNumberField"),
                "ECImagePicker", "VNRecognizeFeature", "AttachmentS3Client", "APIClient",
                "LocalDatabaseClient", "SettingsFeature", "AppConfiguration", "DesignSystem"
            ]
        ),
        .testTarget(name: "GenericPassFormTests", dependencies: ["GenericPassFeature"]),
        .testTarget(name: "GenericPassFormUITests", dependencies: ["GenericPassFeature"]),

        .testTarget(
            name: "AuthenticationCoreTests",
            dependencies: [
                "AuthenticationCore",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "ECSharedModels", package: "ECSharedModels"),
                .product(name: "CommonTCALibraries", package: "CommonTCALibraries")
            ]
        ),

        .testTarget(
            name: "SettingsFeatureTests",
            dependencies: [
                "SettingsFeature",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "ECSharedModels", package: "ECSharedModels"),
                .product(name: "CommonTCALibraries", package: "CommonTCALibraries")
            ]
        ),

        .testTarget(
            name: "WalletPassListTests",
            dependencies: [
                "GenericPassFeature",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "ECSharedModels", package: "ECSharedModels"),
                .product(name: "CommonTCALibraries", package: "CommonTCALibraries")
            ]
        ),

        .testTarget(
            name: "ScreenshotTests",
            dependencies: [
                "AppView",
                "GenericPassFeature",
                "SettingsFeature",
                "AuthenticationView",
                "AuthenticationCore",
                "DesignSystem",
                "L10nResources",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "ECSharedModels", package: "ECSharedModels"),
                .product(name: "CommonTCALibraries", package: "CommonTCALibraries"),
            ]
        ),

        .target(
            name: "LocalDatabaseClient",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "ECSharedModels", package: "ECSharedModels"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
