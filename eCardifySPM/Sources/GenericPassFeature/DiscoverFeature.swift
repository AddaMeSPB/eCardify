import Foundation
import LoggerKit
import L10nResources
import AppConfiguration
import AnalyticsClient
import ECSharedModels
import ComposableArchitecture

// MARK: - Models

/// A public card from the community directory (same payload the
/// https://ecardify.byalif.app/wallets page renders).
public struct PublicCard: Codable, Equatable, Identifiable {
    /// Identity is the vCard's stable id — re-saved records can appear under
    /// multiple slugs and must collapse to one tile.
    public var id: UUID { vCard.id }
    public let slug: String
    public let vCard: VCard
    public let colorPalette: ColorPalette

    public init(slug: String, vCard: VCard, colorPalette: ColorPalette) {
        self.slug = slug
        self.vCard = vCard
        self.colorPalette = colorPalette
    }
}

public struct PublicCardList: Codable, Equatable {
    public let items: [PublicCard]
    public let total: Int
    public let page: Int
    public let perPage: Int

    public init(items: [PublicCard], total: Int, page: Int, perPage: Int) {
        self.items = items
        self.total = total
        self.page = page
        self.perPage = perPage
    }
}

// MARK: - Client

public struct PublicCardsClient {
    public var fetch: @Sendable (_ page: Int, _ perPage: Int, _ search: String?) async throws -> PublicCardList

    public init(
        fetch: @escaping @Sendable (_ page: Int, _ perPage: Int, _ search: String?) async throws -> PublicCardList
    ) {
        self.fetch = fetch
    }
}

extension PublicCardsClient: DependencyKey {

    public static var liveValue: PublicCardsClient {
        @Dependency(\.appConfiguration) var appConfiguration

        return PublicCardsClient { page, perPage, search in
            guard var components = URLComponents(string: appConfiguration.apiURL) else {
                throw URLError(.badURL)
            }
            components.path = "/cards"
            var queryItems = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "per_page", value: String(perPage))
            ]
            if let search, !search.isEmpty {
                queryItems.append(URLQueryItem(name: "search", value: search))
            }
            components.queryItems = queryItems

            guard let url = components.url else { throw URLError(.badURL) }

            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode)
            else {
                throw URLError(.badServerResponse)
            }

            return try JSONDecoder().decode(PublicCardList.self, from: data)
        }
    }

    public static let testValue = PublicCardsClient(
        fetch: { _, _, _ in PublicCardList(items: [], total: 0, page: 1, perPage: 24) }
    )
}

extension DependencyValues {
    public var publicCardsClient: PublicCardsClient {
        get { self[PublicCardsClient.self] }
        set { self[PublicCardsClient.self] = newValue }
    }
}

// MARK: - Reducer

@Reducer
public struct Discover {

    static let perPage = 24

    @ObservableState
    public struct State: Equatable {
        public init() {}

        public var cards: IdentifiedArrayOf<PublicCard> = []
        public var total = 0
        public var page = 1
        public var isLoading = false
        public var isLoadingMore = false
        public var searchQuery = ""
        public var loadError: String? = nil
        /// Whether the request that set `loadError` was a load-more (append)
        /// fetch — decides what the inline Retry re-issues.
        public var retryIsLoadMore = false
        @Presents public var detail: CardDesignReducer.State?

        public var canLoadMore: Bool { cards.count < total }
    }

    @CasePathable
    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case refresh
        case searchDebounced
        case loadMore
        case cardsResponse(Result<PublicCardList, Error>, replacing: Bool)
        case cardTapped(PublicCard.ID)
        case detail(PresentationAction<CardDesignReducer.Action>)
        case createMyCardTapped
        case retryButtonTapped
        case inlineRetryTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case createCard
        }
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.publicCardsClient) var publicCardsClient
    @Dependency(\.analyticsClient) var analytics

    private enum CancelID { case search, fetch }

    public init() {}

    public var body: some Reducer<State, Action> {

        BindingReducer()

        Reduce(self.core)
            .ifLet(\.$detail, action: \.detail) {
                CardDesignReducer()
            }
    }

    func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {

        case .binding(\.searchQuery):
            // Debounce typing before hitting the API
            return .run { send in
                try await clock.sleep(for: .milliseconds(300))
                await send(.searchDebounced)
            }
            .cancellable(id: CancelID.search, cancelInFlight: true)

        case .binding:
            return .none

        case .onAppear:
            guard state.cards.isEmpty else { return .none }
            state.isLoading = true
            state.loadError = nil
            return .merge(
                .run { _ in await analytics.track(.screenViewed(name: "discover")) },
                fetchEffect(page: 1, search: state.searchQuery, replacing: true)
            )

        case .refresh, .searchDebounced, .retryButtonTapped:
            state.isLoading = true
            // A cancelled in-flight loadMore can never reset this flag itself
            state.isLoadingMore = false
            state.loadError = nil
            state.page = 1
            return fetchEffect(page: 1, search: state.searchQuery, replacing: true)

        case .loadMore:
            guard state.canLoadMore, !state.isLoadingMore, !state.isLoading else { return .none }
            state.isLoadingMore = true
            state.loadError = nil
            return fetchEffect(page: state.page + 1, search: state.searchQuery, replacing: false)

        case let .cardsResponse(.success(list), replacing):
            state.isLoading = false
            state.isLoadingMore = false
            state.loadError = nil
            state.total = list.total
            state.page = list.page
            // Manual dedupe by id in both paths — `init(uniqueElements:)`
            // traps if the API ever returns two records for one vCard
            if replacing {
                state.cards = []
            }
            for item in list.items where state.cards[id: item.id] == nil {
                state.cards.append(item)
            }
            return .none

        case let .cardsResponse(.failure(error), replacing):
            state.isLoading = false
            state.isLoadingMore = false
            state.retryIsLoadMore = !replacing
            sharedLogger.logError("Discover cards fetch failed: \(error.localizedDescription)")
            if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
                state.loadError = L("No internet connection.")
            } else {
                state.loadError = L("Unable to load cards. Please try again.")
            }
            return .none

        case let .cardTapped(id):
            guard let card = state.cards[id: id] else { return .none }
            state.detail = .init(
                colorP: card.colorPalette,
                vCard: card.vCard,
                isRealDataView: true
            )
            return .run { _ in
                await analytics.track(.screenViewed(name: "discover_card_detail"))
            }

        case .detail:
            return .none

        case .inlineRetryTapped:
            // Re-issue exactly what failed: appending fetch vs replacing page-1
            // fetch — a .loadMore here after a failed search would mix results
            // from two different queries.
            return .send(state.retryIsLoadMore ? .loadMore : .retryButtonTapped)

        case .createMyCardTapped:
            state.detail = nil
            return .send(.delegate(.createCard))

        case .delegate:
            return .none
        }
    }

    private func fetchEffect(page: Int, search: String, replacing: Bool) -> Effect<Action> {
        .run { send in
            let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
            do {
                let list = try await publicCardsClient.fetch(page, Self.perPage, query.isEmpty ? nil : query)
                await send(.cardsResponse(.success(list), replacing: replacing))
            } catch is CancellationError {
                // Superseded by a newer fetch — never surface as an error
            } catch let error as URLError where error.code == .cancelled {
                // Same: URLSession's flavor of cancellation
            } catch {
                await send(.cardsResponse(.failure(error), replacing: replacing))
            }
        }
        .cancellable(id: CancelID.fetch, cancelInFlight: true)
    }
}
