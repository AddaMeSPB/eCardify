// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "eCardifySPM",
    platforms: [
        .iOS(.v16)
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
        .library(name: "SettingsFeature", targets: ["SettingsFeature"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "0.56.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "0.1.0"),
        .package(url: "https://github.com/AddaMeSPB/CommonTCALibraries.git", branch: "main"),
        .package(url: "https://github.com/AddaMeSPB/ECSharedModels.git", from: "1.1.1"),
//      .package(path: "/Users/alif/Developer/Swift/MySideProjects/VertualBusinessCard/ECSharedModels"),

        .package(url: "https://github.com/soto-project/soto.git", from: "6.0.0"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "0.2.0"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.16.0")
        
    ],
    targets: [
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
                "AppFeature", "GenericPassFeature", "AuthenticationView", "SettingsFeature"
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
            name: "ImagePicker",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "CommonTCALibraries", package: "CommonTCALibraries"),
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
                "AuthenticationCore"
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
                "AppConfiguration"
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
                "ImagePicker", "VNRecognizeFeature", "AttachmentS3Client", "APIClient",
                "LocalDatabaseClient", "SettingsFeature", "AppConfiguration"
            ]
        ),
        .testTarget(name: "GenericPassFormTests", dependencies: ["GenericPassFeature"]),
        .testTarget(name: "GenericPassFormUITests", dependencies: ["GenericPassFeature"]),

        .target(
            name: "LocalDatabaseClient",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "ECSharedModels", package: "ECSharedModels"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        )
    ]
)

