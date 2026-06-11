import SwiftUI
import StoreKitClient
import DesignSystem
import L10nResources
import ComposableArchitecture

public struct PaywallView: View {
    @Bindable var store: StoreOf<PaywallFeature>

    public init(store: StoreOf<PaywallFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: ECSpacing.lg) {
                headerSection
                productCardsSection
                purchaseSection
                benefitsSection
                restoreSection
            }
            .padding(.horizontal, ECSpacing.md)
            .padding(.bottom, ECSpacing.xxl)
        }
        .background(ECColors.groupedBackground)
        .navigationTitle(L("Upgrade"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L("Close")) { store.send(.closeTapped) }
            }
        }
        .onAppear { store.send(.onAppear) }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: ECSpacing.sm) {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [ECColors.primary, ECColors.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top, ECSpacing.lg)

            Text(L("Unlock Premium Cards"))
                .font(ECTypography.sectionTitle(.bold))
                .foregroundStyle(ECColors.textPrimary)
                .multilineTextAlignment(.center)

            Text(L("Create beautiful, customizable digital business cards that make a lasting impression."))
                .font(ECTypography.subheadline())
                .foregroundStyle(ECColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ECSpacing.md)
        }
    }

    // MARK: - Product Cards

    @ViewBuilder
    private var productCardsSection: some View {
        if store.isLoadingProducts {
            ProgressView()
                .padding(ECSpacing.xxl)
        } else if let error = store.loadError {
            VStack(spacing: ECSpacing.sm) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(ECColors.warning)

                Text(error)
                    .font(ECTypography.caption())
                    .foregroundStyle(ECColors.textSecondary)
                    .multilineTextAlignment(.center)

                Button(L("Try Again")) {
                    store.send(.retryLoadProducts)
                }
                .buttonStyle(.ecSecondary)
                .frame(width: 160)
            }
            .padding(ECSpacing.lg)
        } else {
            VStack(spacing: ECSpacing.sm) {
                ForEach(store.products) { product in
                    ProductCard(
                        product: product,
                        isSelected: store.selectedProductID == product.id,
                        isEntitled: store.entitledProductIDs.contains(product.id)
                    ) {
                        store.send(.selectProduct(product.id))
                    }
                }
            }
        }
    }

    // MARK: - Purchase Button

    private var purchaseSection: some View {
        VStack(spacing: ECSpacing.xs) {
            if !store.products.isEmpty {
                let selectedProduct = store.products.first { $0.id == store.selectedProductID }
                let alreadyOwned = store.entitledProductIDs.contains(store.selectedProductID ?? "")

                Button {
                    store.send(.purchaseTapped)
                } label: {
                    if store.isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else if alreadyOwned {
                        Text(L("Already Purchased"))
                    } else if let product = selectedProduct {
                        Text(L("Buy") + " — " + product.displayPrice)
                    } else {
                        Text(L("Select a Product"))
                    }
                }
                .buttonStyle(.ecPrimary)
                .disabled(store.isPurchasing || store.selectedProductID == nil || alreadyOwned)

                Text(L("One-time purchase. No subscription."))
                    .font(ECTypography.caption())
                    .foregroundStyle(ECColors.textSecondary)
            }
        }
    }

    // MARK: - Benefits

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: ECSpacing.sm) {
            Text(L("What you get"))
                .font(ECTypography.headline())
                .foregroundStyle(ECColors.textPrimary)
                .padding(.bottom, ECSpacing.xxs)

            BenefitRow(icon: "paintbrush.fill", text: L("Custom card designs with flexible layouts"))
            BenefitRow(icon: "wallet.bifold.fill", text: L("Add cards directly to Apple Wallet"))
            BenefitRow(icon: "qrcode", text: L("Share your card via QR code"))
            BenefitRow(icon: "globe", text: L("Support for 10+ languages"))
            BenefitRow(icon: "lock.shield.fill", text: L("Your data stays private and secure"))
        }
        .padding(ECSpacing.md)
        .background(ECColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: ECRadius.md))
    }

    // MARK: - Restore

    private var restoreSection: some View {
        Button {
            store.send(.restorePurchasesTapped)
        } label: {
            if store.isRestoring {
                ProgressView()
                    .tint(ECColors.primary)
            } else {
                Text(L("Restore Purchases"))
                    .font(ECTypography.footnote())
                    .foregroundStyle(ECColors.primary)
            }
        }
        .disabled(store.isRestoring)
        .padding(.top, ECSpacing.xs)
    }
}

// MARK: - Product Card

private struct ProductCard: View {
    let product: ECProduct
    let isSelected: Bool
    let isEntitled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ECSpacing.sm) {
                // Selection indicator
                Image(systemName: isEntitled ? "checkmark.circle.fill" : (isSelected ? "largecircle.fill.circle" : "circle"))
                    .font(.title3)
                    .foregroundStyle(isEntitled ? ECColors.success : ECColors.primary)

                VStack(alignment: .leading, spacing: ECSpacing.xxs) {
                    Text(product.displayName)
                        .font(ECTypography.headline())
                        .foregroundStyle(ECColors.textPrimary)

                    if isEntitled {
                        Text(L("Purchased"))
                            .font(ECTypography.caption())
                            .foregroundStyle(ECColors.success)
                    }
                }

                Spacer()

                Text(product.displayPrice)
                    .font(ECTypography.sectionTitle(.bold))
                    .foregroundStyle(ECColors.textPrimary)
            }
            .padding(ECSpacing.md)
            .background(ECColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: ECRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: ECRadius.md)
                    .stroke(
                        isSelected ? ECColors.primary : ECColors.separator,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Benefit Row

private struct BenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: ECSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(ECColors.primary)
                .frame(width: 24, height: 24)

            Text(text)
                .font(ECTypography.subheadline())
                .foregroundStyle(ECColors.textPrimary)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        PaywallView(store: Store(initialState: PaywallFeature.State()) {
            PaywallFeature()
        })
    }
}
#endif
