import XCTest
import SwiftUI
import SnapshotTesting
import ComposableArchitecture
import ECSharedModels
import CoreImage.CIFilterBuiltins

@testable import GenericPassFeature

/// TEMPORARY visual verification for the Discover gallery (not an App Store asset).
/// Renders the grid + detail into /tmp scratchpad for manual inspection.
final class DiscoverVerifySnapshot: XCTestCase {

    /// Renders only when DISCOVER_VERIFY_DIR is set — skipped in normal test runs.
    private var outputDir: String? {
        ProcessInfo.processInfo.environment["DISCOVER_VERIFY_DIR"]
    }

    private func demoCards() -> [PublicCard] {
        let palettes = [
            ColorPalette.default,
            ColorPalette.colorPalettes[2],
            ColorPalette.colorPalettes[11],
            ColorPalette.colorPalettes[14],
            ColorPalette.colorPalettes[8],
            ColorPalette.colorPalettes[17],
        ]
        let people: [(String, String, String, String)] = [
            ("Flavia", "Bevilacqua", "Flavia Bevilacqua", "Makeup Artist & Beauty Coach"),
            ("James", "Dillon", "Space Eclectic", "Creative Director"),
            ("Gregory", "Fischlenski", "SHARPLIFY", "Founder"),
            ("Dana", "Suranshiyeva", "InterPress Abroad", "Education Consultant"),
            ("Lucas", "Pereira", "Machado", "Sales Manager"),
            ("Valerio", "Puri", "Avv. Valerio Puri", "Lawyer"),
        ]
        return zip(people, palettes).enumerated().map { index, pair in
            let (person, palette) = pair
            var vCard = VCard(
                contact: .init(lastName: person.1, firstName: person.0),
                formattedName: "\(person.0) \(person.1)",
                organization: person.2,
                position: person.3,
                telephones: [.init(type: .work, number: "+351 911 000 00\(index)")],
                emails: [.init(text: "hello\(index)@example.com")],
                website: nil,
                socialMedia: nil
            )
            vCard.imageURLs = []
            return PublicCard(slug: "card-\(index)", vCard: vCard, colorPalette: palette)
        }
    }

    func test_discoverGrid() {
        guard let outputDir else { return }
        var state = Discover.State()
        let cards = demoCards()
        state.cards = .init(uniqueElements: cards)
        state.total = cards.count

        let store = Store<Discover.State, Discover.Action>(initialState: state) {
            EmptyReducer()
        }

        let vc = UIHostingController(rootView: DiscoverView(store: store))
        vc.overrideUserInterfaceStyle = .light

        try! FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        _ = verifySnapshot(
            of: vc,
            as: .image(on: .iPhone13Pro),
            record: true,
            snapshotDirectory: outputDir,
            testName: "discover_grid"
        )
    }

    func test_discoverDetail() {
        guard let outputDir else { return }
        let card = demoCards()[1]
        var detailState = CardDesignReducer.State(
            colorP: card.colorPalette,
            vCard: card.vCard,
            isRealDataView: true
        )
        detailState.qrCodeImage = qrImage(from: card.vCard.vCardRepresentation)

        let store = Store<CardDesignReducer.State, CardDesignReducer.Action>(
            initialState: detailState
        ) {
            EmptyReducer()
        }

        let view = DiscoverCardDetailView(store: store) {}
        let vc = UIHostingController(rootView: view)
        vc.overrideUserInterfaceStyle = .light

        try! FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        _ = verifySnapshot(
            of: vc,
            as: .image(on: .iPhone13Pro),
            record: true,
            snapshotDirectory: outputDir,
            testName: "discover_detail"
        )
    }

    private func qrImage(from string: String) -> Image? {
        guard let data = string.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return Image(uiImage: UIImage(cgImage: cgImage))
    }
}
