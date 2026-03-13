import Build
import SwiftUI
import AppPromo
import DesignSystem
import L10nResources
import ECSharedModels
import SwiftUIExtension
import ComposableArchitecture

public struct SettingsView: View {

    @Bindable var store: StoreOf<Settings>
    @State private var isSharePresented = false

    public init(store: StoreOf<Settings>) {
        self.store = store
    }

    public var body: some View {
        List {
            // MARK: - Account
            accountSection

            // MARK: - General
            actionsSection

            // MARK: - Our Apps
            ourAppsSection

            // MARK: - About
            aboutSection

            // MARK: - Danger Zone
            dangerSection
        }
        .listStyle(.insetGrouped)
        .onAppear { store.send(.onAppear) }
        .navigationTitle(L("Settings"))
        .navigationDestination(
            item: $store.scope(
                state: \.destination?.restore,
                action: \.destination.restore
            )
        ) { store in
            RestoreNonProductView(store: store)
        }
        .sheet(isPresented: $isSharePresented) {
            ActivityView(
                activityItems: [
                    URL(string: "https://apps.apple.com/pt/app/ecardify/id6452084315?l=en-GB")!
                ]
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        Section {
            HStack(spacing: ECSpacing.md) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [ECColors.primary, ECColors.primaryDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    Text(initials(from: store.currentUser.fullName))
                        .font(ECTypography.sectionTitle(.bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: ECSpacing.xxs) {
                    Text(store.currentUser.fullName ?? L("User"))
                        .font(ECTypography.headline())
                        .foregroundStyle(ECColors.textPrimary)

                    if let email = store.currentUser.email {
                        Text(email)
                            .font(ECTypography.caption())
                            .foregroundStyle(ECColors.textSecondary)
                    }
                }

                Spacer()
            }
            .padding(.vertical, ECSpacing.xs)
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        Section {
            Button {
                store.send(.leaveUsAReviewButtonTapped)
            } label: {
                settingsRow(
                    icon: "star.fill",
                    iconColor: .orange,
                    title: L("Leave a Review")
                )
            }

            Button {
                isSharePresented.toggle()
            } label: {
                settingsRow(
                    icon: "square.and.arrow.up",
                    iconColor: ECColors.primary,
                    title: L("Share App")
                )
            }

            Button {
                store.send(.restoreButtonTapped)
            } label: {
                settingsRow(
                    icon: "arrow.clockwise.circle",
                    iconColor: .purple,
                    title: L("Restore Purchases")
                )
            }
        } header: {
            Text(L("General"))
        }
    }

    // MARK: - Our Apps Section

    private var ourAppsSection: some View {
        MoreAppsSection(excludingBundleID: "cardify.addame.com.eCardify")
    }

    // MARK: - About Section

    @ViewBuilder
    private var aboutSection: some View {
        Section {
            Button {
                store.send(.termsOfUseTapped)
            } label: {
                settingsRow(
                    icon: "doc.text",
                    iconColor: .blue,
                    title: L("Terms of Use")
                )
            }

            Button {
                store.send(.privacyPolicyTapped)
            } label: {
                settingsRow(
                    icon: "hand.raised.fill",
                    iconColor: .blue,
                    title: L("Privacy Policy")
                )
            }

            Button {
                store.send(.reportABugButtonTapped)
            } label: {
                settingsRow(
                    icon: "ladybug.fill",
                    iconColor: .green,
                    title: L("Report a Bug")
                )
            }

            versionRow
        } header: {
            Text(L("About"))
        }
    }

    @ViewBuilder
    private var versionRow: some View {
        if let buildNumber = store.buildNumber {
            HStack {
                settingsRow(
                    icon: "hammer.fill",
                    iconColor: ECColors.textSecondary,
                    title: L("Version")
                )
                Spacer()
                Text("\(buildNumber.rawValue)")
                    .font(ECTypography.footnote())
                    .foregroundStyle(ECColors.textSecondary)
            }
        }
    }

    // MARK: - Danger Zone

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                store.send(.logOutButtonTapped)
            } label: {
                HStack {
                    Spacer()
                    Label {
                        Text(L("Log Out"))
                            .font(ECTypography.headline())
                    } icon: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                    .foregroundStyle(ECColors.error)
                    Spacer()
                }
                .padding(.vertical, ECSpacing.xs)
            }

            Button(role: .destructive) {
                store.send(.deleteAccountButtonTapped)
            } label: {
                HStack {
                    Spacer()
                    Label {
                        Text(L("Delete Account"))
                            .font(ECTypography.headline())
                    } icon: {
                        Image(systemName: "trash.fill")
                    }
                    .foregroundStyle(ECColors.error)
                    Spacer()
                }
                .padding(.vertical, ECSpacing.xs)
            }
        }
        .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
    }

    // MARK: - Helpers

    private func settingsRow(
        icon: String,
        iconColor: Color,
        title: String
    ) -> some View {
        HStack(spacing: ECSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(iconColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(title)
                .font(ECTypography.body())
                .foregroundStyle(ECColors.textPrimary)
        }
    }

    private func initials(from name: String?) -> String {
        guard let name, !name.isEmpty else { return "?" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Preview

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SettingsView(store: .init(
                initialState: Settings.State(currentUser: .withFirstName)
            ) {
                Settings()
            })
        }
    }
}
#endif

