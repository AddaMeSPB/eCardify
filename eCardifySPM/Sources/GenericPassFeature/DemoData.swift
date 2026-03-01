#if DEBUG
import BSON
import SwiftUI
import ECSharedModels
import ComposableArchitecture

// MARK: - Demo Mode Support
//
// Launch the app with `-DEMO_MODE` argument in Xcode to skip auth
// and load 3 prebuilt business cards for manual testing.
//
// Xcode → Product → Scheme → Edit Scheme → Run → Arguments → add "-DEMO_MODE"

/// Fixed date for deterministic demo data (2025-01-15 09:00 UTC)
private let demoDate = Date(timeIntervalSince1970: 1736935200)

// MARK: - Demo VCards

extension VCard {
    /// Alif Khandoker — CEO & IOS Developer
    public static let demoAlif = VCard(
        contact: .init(lastName: "Khandoker", firstName: "Alif"),
        formattedName: "Alif Khandoker",
        organization: "IT Company Adda.",
        position: "CEO & IOS Developer",
        addresses: [
            .init(
                type: .work,
                postOfficeAddress: nil,
                extendedAddress: nil,
                street: "123 Main Street",
                locality: "Dhaka",
                region: "Dhaka",
                postalCode: "1205",
                country: "Bangladesh"
            )
        ],
        telephones: [.init(type: .work, number: "+8801712345678")],
        emails: [.init(text: "alif@ecardify.app")],
        urls: [URL(string: "https://addame.com")!],
        notes: [""],
        website: "https://addame.com",
        socialMedia: .init(
            facebook: nil, skype: nil, instagram: nil,
            linkedIn: "alifkhandoker", twitter: nil,
            telegram: "alifkhandoker", vk: nil
        )
    )

    /// Sarah Johnson — Product Manager
    public static let demoSarah = VCard(
        contact: .init(lastName: "Johnson", firstName: "Sarah"),
        formattedName: "Sarah Johnson",
        organization: "TechVentures Inc.",
        position: "Product Manager",
        addresses: [
            .init(
                type: .work,
                postOfficeAddress: nil,
                extendedAddress: nil,
                street: "350 Fifth Avenue",
                locality: "New York",
                region: "NY",
                postalCode: "10118",
                country: "United States"
            )
        ],
        telephones: [.init(type: .work, number: "+12125551234")],
        emails: [.init(text: "sarah.johnson@techventures.io")],
        urls: [URL(string: "https://techventures.io")!],
        notes: [""],
        website: "https://techventures.io",
        socialMedia: .init(
            facebook: nil, skype: nil, instagram: nil,
            linkedIn: "sarah-johnson-pm", twitter: nil,
            telegram: nil, vk: nil
        )
    )

    /// Marcus Chen — Senior Designer
    public static let demoMarcus = VCard(
        contact: .init(lastName: "Chen", firstName: "Marcus"),
        formattedName: "Marcus Chen",
        organization: "Creative Studio",
        position: "Senior Designer",
        addresses: [
            .init(
                type: .work,
                postOfficeAddress: nil,
                extendedAddress: nil,
                street: "88 Colin P Kelly Jr St",
                locality: "San Francisco",
                region: "CA",
                postalCode: "94107",
                country: "United States"
            )
        ],
        telephones: [.init(type: .cell, number: "+14155559876")],
        emails: [.init(text: "marcus@creativestudio.design")],
        urls: [URL(string: "https://creativestudio.design")!],
        notes: [""],
        website: "https://creativestudio.design",
        socialMedia: .init(
            facebook: nil, skype: nil, instagram: "@marcus.designs",
            linkedIn: nil, twitter: nil, telegram: nil, vk: nil
        )
    )
}

// MARK: - Demo WalletPasses

extension WalletPass {
    private static let demoOwnerId = ObjectId("5fabb1ebaa5f5774ccfe48c3")!

    public static let demoAlif = WalletPass(
        _id: ObjectId("aaaaaaaaaaaaaaaaaaaaaaaa")!,
        ownerId: demoOwnerId,
        vCard: .demoAlif,
        colorPalette: .default,
        isPaid: true,
        isDataSavedOnServer: true,
        createdAt: demoDate,
        updatedAt: demoDate
    )

    public static let demoSarah = WalletPass(
        _id: ObjectId("bbbbbbbbbbbbbbbbbbbbbbbb")!,
        ownerId: demoOwnerId,
        vCard: .demoSarah,
        colorPalette: ColorPalette.colorPalettes[2],
        isPaid: true,
        isDataSavedOnServer: true,
        createdAt: demoDate,
        updatedAt: demoDate
    )

    public static let demoMarcus = WalletPass(
        _id: ObjectId("cccccccccccccccccccccccc")!,
        ownerId: demoOwnerId,
        vCard: .demoMarcus,
        colorPalette: ColorPalette.colorPalettes[4],
        isPaid: true,
        isDataSavedOnServer: true,
        createdAt: demoDate,
        updatedAt: demoDate
    )
}

// MARK: - Demo User

extension UserOutput {
    public static let demoUser = UserOutput(
        id: ObjectId("5fabb1ebaa5f5774ccfe48c3")!,
        fullName: "Alif Khandoker",
        email: "alif@ecardify.app",
        role: .basic,
        language: .english,
        url: .home,
        createdAt: demoDate,
        updatedAt: demoDate
    )
}

// MARK: - Demo State Builder

extension WalletPassList.State {
    /// Returns a fully-populated demo state with 3 cards.
    /// Used when `-DEMO_MODE` launch argument is present.
    public static var demoMode: Self {
        var state = Self()
        state.wPassLocal = [
            .init(wp: .demoAlif, vCard: .demoAlif),
            .init(wp: .demoSarah, vCard: .demoSarah),
            .init(wp: .demoMarcus, vCard: .demoMarcus),
        ]
        state.$isAuthorized.withLock { $0 = true }
        state.user = .demoUser
        return state
    }
}

/// Returns `true` when `-DEMO_MODE` was passed as a launch argument.
public var isDemoMode: Bool {
    ProcessInfo.processInfo.arguments.contains("-DEMO_MODE")
}
#endif
