import XCTest
import ComposableArchitecture
import ECSharedModels

@testable import GenericPassFeature

@MainActor
final class DiscoverTests: XCTestCase {

    static let palette = ColorPalette(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    )

    static func card(slug: String) -> PublicCard {
        // PublicCard identity is vCard.id — each test card needs its own,
        // otherwise cards sharing VCard.demo's single id collapse to one tile
        var vCard = VCard.demo
        vCard.id = UUID(
            uuidString: "00000000-0000-0000-0000-" + String(format: "%012x", abs(slug.hashValue) % 0xFFFF_FFFF)
        )!
        return PublicCard(slug: slug, vCard: vCard, colorPalette: palette)
    }

    static func list(_ cards: [PublicCard], total: Int, page: Int) -> PublicCardList {
        PublicCardList(items: cards, total: total, page: page, perPage: Discover.perPage)
    }

    // MARK: - Initial load

    func testOnAppear_loadsFirstPage() async {
        let cards = [Self.card(slug: "a"), Self.card(slug: "b")]

        let store = TestStore(initialState: Discover.State()) {
            Discover()
        } withDependencies: {
            $0.publicCardsClient.fetch = { page, _, search in
                XCTAssertEqual(page, 1)
                XCTAssertNil(search)
                return Self.list(cards, total: 2, page: 1)
            }
            $0.analyticsClient.track = { _ in }
            $0.continuousClock = ImmediateClock()
        }

        await store.send(.onAppear) {
            $0.isLoading = true
        }

        await store.receive(\.cardsResponse) {
            $0.isLoading = false
            $0.total = 2
            $0.page = 1
            $0.cards = .init(uniqueElements: cards)
        }
    }

    func testOnAppear_skipsWhenAlreadyLoaded() async {
        var state = Discover.State()
        state.cards = .init(uniqueElements: [Self.card(slug: "a")])

        let store = TestStore(initialState: state) {
            Discover()
        }

        await store.send(.onAppear)
    }

    func testLoadFailure_setsError() async {
        let store = TestStore(initialState: Discover.State()) {
            Discover()
        } withDependencies: {
            $0.publicCardsClient.fetch = { _, _, _ in throw URLError(.badServerResponse) }
            $0.analyticsClient.track = { _ in }
            $0.continuousClock = ImmediateClock()
        }

        await store.send(.onAppear) {
            $0.isLoading = true
        }

        await store.receive(\.cardsResponse) {
            $0.isLoading = false
            $0.loadError = "Unable to load cards. Please try again."
        }
    }

    // MARK: - Pagination

    func testLoadMore_appendsNextPage() async {
        let firstPage = [Self.card(slug: "a")]
        let secondPage = [Self.card(slug: "b")]

        var state = Discover.State()
        state.cards = .init(uniqueElements: firstPage)
        state.total = 2
        state.page = 1

        let store = TestStore(initialState: state) {
            Discover()
        } withDependencies: {
            $0.publicCardsClient.fetch = { page, _, _ in
                XCTAssertEqual(page, 2)
                return Self.list(secondPage, total: 2, page: 2)
            }
        }

        await store.send(.loadMore) {
            $0.isLoadingMore = true
        }

        await store.receive(\.cardsResponse) {
            $0.isLoadingMore = false
            $0.page = 2
            $0.cards = .init(uniqueElements: firstPage + secondPage)
        }
    }

    func testLoadMore_noopWhenAllLoaded() async {
        var state = Discover.State()
        state.cards = .init(uniqueElements: [Self.card(slug: "a")])
        state.total = 1

        let store = TestStore(initialState: state) {
            Discover()
        }

        await store.send(.loadMore)
    }

    // MARK: - Search

    func testSearch_debouncesAndReplacesResults() async {
        let results = [Self.card(slug: "match")]
        let clock = TestClock()

        var state = Discover.State()
        state.cards = .init(uniqueElements: [Self.card(slug: "old")])
        state.total = 1

        let store = TestStore(initialState: state) {
            Discover()
        } withDependencies: {
            $0.publicCardsClient.fetch = { page, _, search in
                XCTAssertEqual(page, 1)
                XCTAssertEqual(search, "flavia")
                return Self.list(results, total: 1, page: 1)
            }
            $0.continuousClock = clock
        }

        await store.send(.binding(.set(\.searchQuery, "flavia"))) {
            $0.searchQuery = "flavia"
        }

        await clock.advance(by: .milliseconds(300))

        await store.receive(\.searchDebounced) {
            $0.isLoading = true
            $0.page = 1
        }

        await store.receive(\.cardsResponse) {
            $0.isLoading = false
            $0.total = 1
            $0.cards = .init(uniqueElements: results)
        }
    }

    /// After a failed refresh/search (replacing fetch), the inline Retry must
    /// re-issue the replacing page-1 request — a .loadMore here would mix
    /// results from two different queries.
    func testInlineRetry_afterFailedRefresh_reissuesReplacingFetch() async {
        let cards = [Self.card(slug: "a")]
        var state = Discover.State()
        state.cards = .init(uniqueElements: [Self.card(slug: "old")])
        state.total = 2
        state.loadError = "Unable to load cards. Please try again."
        state.retryIsLoadMore = false

        let store = TestStore(initialState: state) {
            Discover()
        } withDependencies: {
            $0.publicCardsClient.fetch = { page, _, _ in
                XCTAssertEqual(page, 1)
                return Self.list(cards, total: 1, page: 1)
            }
        }

        await store.send(.inlineRetryTapped)

        await store.receive(\.retryButtonTapped) {
            $0.isLoading = true
            $0.loadError = nil
            $0.page = 1
        }

        await store.receive(\.cardsResponse) {
            $0.isLoading = false
            $0.total = 1
            $0.cards = .init(uniqueElements: cards)
        }
    }

    /// After a failed load-more (appending fetch), the inline Retry re-issues
    /// the append for the next page.
    func testInlineRetry_afterFailedLoadMore_reissuesAppendingFetch() async {
        let firstPage = [Self.card(slug: "a")]
        let secondPage = [Self.card(slug: "b")]
        var state = Discover.State()
        state.cards = .init(uniqueElements: firstPage)
        state.total = 2
        state.page = 1
        state.loadError = "Unable to load cards. Please try again."
        state.retryIsLoadMore = true

        let store = TestStore(initialState: state) {
            Discover()
        } withDependencies: {
            $0.publicCardsClient.fetch = { page, _, _ in
                XCTAssertEqual(page, 2)
                return Self.list(secondPage, total: 2, page: 2)
            }
        }

        await store.send(.inlineRetryTapped)

        await store.receive(\.loadMore) {
            $0.isLoadingMore = true
            $0.loadError = nil
        }

        await store.receive(\.cardsResponse) {
            $0.isLoadingMore = false
            $0.page = 2
            $0.cards = .init(uniqueElements: firstPage + secondPage)
        }
    }

    // MARK: - Detail + CTA

    func testCardTapped_presentsDetail() async {
        let card = Self.card(slug: "a")
        var state = Discover.State()
        state.cards = .init(uniqueElements: [card])
        state.total = 1

        let store = TestStore(initialState: state) {
            Discover()
        } withDependencies: {
            $0.analyticsClient.track = { _ in }
        }

        await store.send(.cardTapped(card.id)) {
            $0.detail = .init(
                colorP: card.colorPalette,
                vCard: card.vCard,
                isRealDataView: true
            )
        }
    }

    // MARK: - WalletPassList integration

    /// Regression guard: the discover delegate case in WalletPassList's switch
    /// must sit ABOVE the catch-all `case .destination:` or it silently no-ops.
    func testDiscoverDelegate_createCard_closesGalleryAndOpensForm() async {
        let clock = TestClock()
        var state = WalletPassList.State()
        state.$isAuthorized.withLock { $0 = true }
        state.destination = .discover(.init())
        // `VCard.empty` is computed (fresh id per access) — reuse the reducer's draft
        let draft = state.vCard ?? .empty

        let store = TestStore(initialState: state) {
            WalletPassList()
        } withDependencies: {
            $0.continuousClock = clock
        }

        await store.send(.destination(.presented(.discover(.delegate(.createCard))))) {
            $0.destination = nil
        }

        await clock.advance(by: .milliseconds(400))

        await store.receive(\.createGenericFormButtonTapped) {
            $0.destination = .add(.init(user: nil, vCard: draft))
        }
    }

    func testCreateMyCard_dismissesDetailAndDelegates() async {
        let card = Self.card(slug: "a")
        var state = Discover.State()
        state.cards = .init(uniqueElements: [card])
        state.total = 1
        state.detail = .init(colorP: card.colorPalette, vCard: card.vCard, isRealDataView: true)

        let store = TestStore(initialState: state) {
            Discover()
        }

        await store.send(.createMyCardTapped) {
            $0.detail = nil
        }

        await store.receive(\.delegate.createCard)
    }
}
