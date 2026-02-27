import BSON
import SwiftUI
import ECSharedModels
import GenericPassFeature
import SettingsFeature
import AuthenticationCore
import ComposableArchitecture

// MARK: - Fixed Date

/// Deterministic date for all screenshots (2025-01-15 09:00 UTC)
let screenshotDate = Date(timeIntervalSince1970: 1736935200)

// MARK: - Demo VCards

extension VCard {
    /// Sarah Johnson — Product Manager at TechVentures Inc.
    static let demoSarah = VCard(
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

    /// Marcus Chen — Senior Designer at Creative Studio
    static let demoMarcus = VCard(
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
    // Fixed ObjectIds for deterministic screenshots
    private static let ownerIdFixed = ObjectId("5fabb1ebaa5f5774ccfe48c3")!

    /// Alif's card — default palette
    static let demoAlif = WalletPass(
        _id: ObjectId("aaaaaaaaaaaaaaaaaaaaaaaa")!,
        ownerId: ownerIdFixed,
        vCard: .demo,
        colorPalette: .default,
        isPaid: true,
        isDataSavedOnServer: true,
        createdAt: screenshotDate,
        updatedAt: screenshotDate
    )

    /// Sarah's card — indigo/gold palette (#2)
    static let demoSarah = WalletPass(
        _id: ObjectId("bbbbbbbbbbbbbbbbbbbbbbbb")!,
        ownerId: ownerIdFixed,
        vCard: .demoSarah,
        colorPalette: ColorPalette.colorPalettes[2],
        isPaid: true,
        isDataSavedOnServer: true,
        createdAt: screenshotDate,
        updatedAt: screenshotDate
    )

    /// Marcus's card — purple/gold palette (#4)
    static let demoMarcus = WalletPass(
        _id: ObjectId("cccccccccccccccccccccccc")!,
        ownerId: ownerIdFixed,
        vCard: .demoMarcus,
        colorPalette: ColorPalette.colorPalettes[4],
        isPaid: true,
        isDataSavedOnServer: true,
        createdAt: screenshotDate,
        updatedAt: screenshotDate
    )
}

// MARK: - Demo States

extension WalletPassDetails.State {
    static let demoAlif = WalletPassDetails.State(
        wp: .demoAlif, vCard: .demo
    )
    static let demoSarah = WalletPassDetails.State(
        wp: .demoSarah, vCard: .demoSarah
    )
    static let demoMarcus = WalletPassDetails.State(
        wp: .demoMarcus, vCard: .demoMarcus
    )
}

/// Pre-built list of 3 demo cards for the wallet list screenshot.
let demoWPassLocal: IdentifiedArrayOf<WalletPassDetails.State> = [
    .demoAlif,
    .demoSarah,
    .demoMarcus,
]

// MARK: - Demo User

extension UserOutput {
    /// Deterministic user for settings screenshot
    static let demoScreenshot = UserOutput(
        id: ObjectId("5fabb1ebaa5f5774ccfe48c3")!,
        fullName: "Alif Khandoker",
        email: "alif@ecardify.app",
        role: .basic,
        language: .english,
        url: .home,
        createdAt: screenshotDate,
        updatedAt: screenshotDate
    )
}
