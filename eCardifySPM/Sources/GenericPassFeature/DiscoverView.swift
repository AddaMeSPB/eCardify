import SwiftUI
import DesignSystem
import L10nResources
import ECSharedModels
import ComposableArchitecture

public struct DiscoverView: View {

    @Bindable public var store: StoreOf<Discover>

    public init(store: StoreOf<Discover>) {
        self.store = store
    }

    private let columns = [
        GridItem(.flexible(), spacing: ECSpacing.sm),
        GridItem(.flexible(), spacing: ECSpacing.sm)
    ]

    public var body: some View {
        NavigationStack {
            ZStack {
                ECColors.groupedBackground.ignoresSafeArea()
                content
            }
            .navigationTitle(L("Inspiration"))
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $store.searchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: L("Search by name, company, or title")
            )
            .onAppear { store.send(.onAppear) }
            .sheet(
                item: $store.scope(state: \.detail, action: \.detail)
            ) { detailStore in
                DiscoverCardDetailView(store: detailStore) {
                    store.send(.createMyCardTapped)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage = store.loadError, store.cards.isEmpty {
            ECEmptyState(
                icon: "exclamationmark.triangle.fill",
                title: L("Connection Error"),
                message: errorMessage,
                actionTitle: L("Retry")
            ) {
                store.send(.retryButtonTapped)
            }
        } else if store.cards.isEmpty && !store.isLoading {
            ECEmptyState(
                icon: "magnifyingglass",
                title: L("No cards found"),
                message: L("Try a different search term")
            )
        } else {
            cardGrid
        }
    }

    private var cardGrid: some View {
        ScrollView {
            Text(L("Get inspired by real cards from our community"))
                .font(ECTypography.subheadline())
                .foregroundStyle(ECColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, ECSpacing.md)
                .padding(.top, ECSpacing.xs)

            LazyVGrid(columns: columns, spacing: ECSpacing.sm) {
                ForEach(store.cards) { card in
                    Button {
                        store.send(.cardTapped(card.id))
                    } label: {
                        DiscoverCardTile(card: card)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if card.id == store.cards.last?.id {
                            store.send(.loadMore)
                        }
                    }
                }
            }
            .padding(.horizontal, ECSpacing.md)
            .padding(.top, ECSpacing.xs)

            if store.isLoadingMore {
                ProgressView()
                    .padding(.vertical, ECSpacing.lg)
            }

            // Inline pagination error — the full-screen error state only
            // covers the cards-empty case
            if let errorMessage = store.loadError, !store.cards.isEmpty {
                VStack(spacing: ECSpacing.xs) {
                    Text(errorMessage)
                        .font(ECTypography.footnote())
                        .foregroundStyle(ECColors.textSecondary)
                    Button(L("Retry")) {
                        store.send(.inlineRetryTapped)
                    }
                    .font(ECTypography.footnote(.semibold))
                    .foregroundStyle(ECColors.primary)
                }
                .padding(.vertical, ECSpacing.lg)
            }
        }
        .redacted(reason: store.isLoading && store.cards.isEmpty ? .placeholder : .init())
        .refreshable {
            await store.send(.refresh).finish()
        }
    }
}

// MARK: - Card Tile

struct DiscoverCardTile: View {

    let card: PublicCard

    private var imageURL: URL? {
        let urlString = card.vCard.imageURLs.first(where: { $0.type == .avatar })?.urlString
            ?? card.vCard.imageURLs.first(where: { $0.type == .thumbnail })?.urlString
        return urlString.flatMap(URL.init(string:))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ECSpacing.xs) {
            avatar

            VStack(alignment: .leading, spacing: ECSpacing.xxs) {
                Text(card.vCard.contact.fullName)
                    .font(ECTypography.headline(.bold))
                    .foregroundStyle(Color(rgbString: card.colorPalette.foregroundColor))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if let organization = card.vCard.organization, !organization.isEmpty {
                    Text(organization)
                        .font(ECTypography.footnote())
                        .foregroundStyle(Color(rgbString: card.colorPalette.labelColor))
                        .lineLimit(1)
                }

                if !card.vCard.position.isEmpty {
                    Text(card.vCard.position)
                        .font(ECTypography.caption())
                        .foregroundStyle(Color(rgbString: card.colorPalette.labelColor).opacity(0.8))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, ECSpacing.sm)
            .padding(.bottom, ECSpacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(rgbString: card.colorPalette.backgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: ECRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ECRadius.lg)
                .strokeBorder(ECColors.separator.opacity(0.4), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
    }

    private var avatar: some View {
        AsyncImage(url: imageURL) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color(rgbString: card.colorPalette.labelColor).opacity(0.1)
                    Image(systemName: "person.crop.square.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color(rgbString: card.colorPalette.labelColor).opacity(0.4))
                }
            }
        }
        .frame(height: 130)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

// MARK: - Card Detail (community card rendered like a real digital card)

struct DiscoverCardDetailView: View {

    let store: StoreOf<CardDesignReducer>
    let createMyCardAction: () -> Void

    var body: some View {
        CardDesignView(store: store)
            .safeAreaInset(edge: .bottom) {
                Button(action: createMyCardAction) {
                    Text(L("Create My Card"))
                        .font(ECTypography.headline(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ECSpacing.md)
                        .background(
                            LinearGradient(
                                colors: [ECColors.primary, ECColors.primaryDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: ECRadius.lg))
                }
                .padding(.horizontal, ECSpacing.lg)
                .padding(.bottom, ECSpacing.xs)
                .accessibilityIdentifier("discover_create_my_card_button")
            }
    }
}

// MARK: - Preview

struct DiscoverView_Previews: PreviewProvider {
    static var previews: some View {
        DiscoverView(
            store: .init(initialState: Discover.State()) {
                Discover()
            }
        )
    }
}
