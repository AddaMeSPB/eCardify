// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "eCardifySPM",
    platforms: [
       .iOS(.v16),
       .macOS(.v12)
    ],
    products: [
        .library(name: "APIClient", targets: ["APIClient"]),
        .library(name: "AppConfiguration", targets: ["AppConfiguration"]),
        .library(name: "AppFeature", targets: ["AppFeature"]),
        .library(name: "AppView", targets: ["AppView"]),
        .library(name: "eCardifySPM", targets: ["eCardifySPM"]),
        .library(name: "GenericPassFeature", targets: ["GenericPassFeature"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "0.53.1"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "0.1.0"),
        .package(url: "https://github.com/AddaMeSPB/CommonTCALibraries.git", branch: "main"),
//        .package(url: "https://github.com/AddaMeSPB/ECardifySharedModels.git", branch: "main"),
        .package(path: "/Users/alif/Developer/Swift/MySideProjects/VertualBusinessCard/ECardifySharedModels"),
        .package(url: "https://github.com/soto-project/soto.git", from: "5.13.1"),
    ],
    targets: [
        .target(
            name: "AppFeature",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "CommonTCALibraries", package: "CommonTCALibraries"),
                .product(name: "RemoteNotificationsClient", package: "CommonTCALibraries"),
                "APIClient", "AttachmentS3Client",
            ]
        ),

        .target(
            name: "AppView",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "CommonTCALibraries", package: "CommonTCALibraries"),
                .product(name: "RemoteNotificationsClient", package: "CommonTCALibraries"),
                "AppFeature", "GenericPassFeature"
            ]
        ),

        .target(
            name: "AppConfiguration",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "ECardifySharedModels", package: "ECardifySharedModels"),
                .product(name: "CommonTCALibraries", package: "CommonTCALibraries")
            ]
        ),

        .target(
            name: "APIClient",
            dependencies: [
                .product(name: "ECardifySharedModels", package: "ECardifySharedModels"),
                .product(name: "CommonTCALibraries", package: "CommonTCALibraries"),
                "AppConfiguration"
            ]
        ),

        .target(
            name: "AttachmentS3Client",
            dependencies: [
                .product(name: "SotoS3", package: "soto"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "ECardifySharedModels", package: "ECardifySharedModels"),
                .product(name: "CommonTCALibraries", package: "CommonTCALibraries"),
                .product(name: "ECardifySharedModels", package: "ECardifySharedModels"),
            ]
        ),
        .target(
            name: "eCardifySPM",
            dependencies: [
                .product(name: "ECardifySharedModels", package: "ECardifySharedModels"),
            ]
        ),

        .target(
            name: "ImagePicker",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),


        .testTarget(
            name: "eCardifySPMTests",
            dependencies: ["eCardifySPM"]),

        .target(
            name: "GenericPassFeature",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "ECardifySharedModels", package: "ECardifySharedModels"),
            ]
        )
    ]
)

