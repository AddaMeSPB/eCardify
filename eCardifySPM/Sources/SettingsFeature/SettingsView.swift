import Build
import SwiftUI
import SwiftUIExtension
import ECSharedModels
import ComposableArchitecture

public struct SettingsView: View {

    @Environment(\.colorScheme) var colorScheme
    @State var isSharePresented = false
    let store: StoreOf<Settings>

    private var columns: [GridItem] {
        Array(repeating: .init(.adaptive(minimum: 100)), count: 1)
    }

    private let rows = [GridItem(.adaptive(minimum: 80, maximum: 150))]

    public init(store: StoreOf<Settings>) {
        self.store = store
    }

    public var body: some View {
        WithPerceptionTracking {
            ScrollView {
                VStack {
                    Text("Hello, \(store.currentUser.fullName ?? "")")
                        .frame( maxWidth: .infinity, alignment: .leading)
                        .font(Font.system(size: 30, weight: .heavy, design: .rounded))
                        .padding(.vertical, 5)

                    Text("Support our app")
                        .frame( maxWidth: .infinity, alignment: .leading)
                        .font(Font.system(size: 16, weight: .light, design: .rounded))

                }
                .padding(.horizontal)
                .padding(.bottom, 10)

                LazyVGrid(columns: columns, spacing: 10) {
                    Button(action: {
                        store.send(.leaveUsAReviewButtonTapped)
                    }) {
                        VStack(alignment: .center) {
                            HStack { Spacer() }
                            Image(systemName: "hand.thumbsup")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 35, height: 35)
                                .foregroundColor(.white)

                            Text("Review us")
                                .font(.caption)
                                .bold()
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                    }
                    //          .buttonStyle(.plain)
                    .frame(height: 100)
                    .background(Color.red.opacity(0.3))
                    .cornerRadius(20)

                    Button(action: {
                        isSharePresented.toggle()
                    }) {
                        VStack(alignment: .center) {
                            HStack { Spacer() }
                            Image(systemName: "square.and.arrow.up.circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 35, height: 35)
                                .foregroundColor(.blue)

                            Text("Share")
                                .font(.caption)
                                .bold()
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)


                            Spacer()
                        }
                        .padding()
                    }
                    //          .buttonStyle(.plain)
                    .frame(height: 100)
                    .background(Color.yellow.opacity(0.5))
                    .cornerRadius(20)


                    Button(action: {
                        store.send(.restoreButtonTapped)
                    }) {
                        VStack(alignment: .center) {
                            HStack { Spacer() }
                            Image(systemName: "star.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 35, height: 35)
                                .foregroundColor(.red)

                            Text("Restore")
                                .font(.caption)
                                .bold()
                                .frame(maxWidth: .infinity, alignment: .center)

                            Spacer()
                        }
                        .padding()
                    }
                    //          .buttonStyle(.plain)
                    .frame(height: 100)
                    .background(Color.blue.opacity(0.3))
                    .cornerRadius(20)


                }
                .padding()

                Text("Explore our other apps!")
                    .frame( maxWidth: .infinity, alignment: .leading)
                    .font(Font.system(size: 23, weight: .regular, design: .rounded))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)

                ScrollView(.horizontal) {

                    LazyHGrid(rows: rows, spacing: 16) {
                        ForEach(OurApps.allCases, id: \.self) { app in
                            Button(action: { store.send(.ourAppLinkButtonTapped(app.urlLink)) }) {
                                AsyncImage(url: app.logoImageLink) { image in
                                    image.resizable()
                                } placeholder: {
                                    ProgressView()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                        .tint(Color.blue)
                                }
                                .aspectRatio(contentMode: .fill)
                            }
                            //          .buttonStyle(.plain)
                            .frame(height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10) // Create a rounded rectangle overlay
                                    .stroke(Color.blue, lineWidth: 1) // Apply a red border with a line width of 2
                            )

                        }
                    }
                }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)

                Spacer()

                HStack {
                    Spacer()

                    Button(action: { store.send(.logOutButtonTapped) }) {
                        Text("Log out!")
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                    }
                    .padding()
                    .background(Color.red)
                    .clipShape(Capsule())
                }
                .padding(.horizontal)

                VStack(spacing: 6) {
                    if let buildNumber = store.buildNumber {
                        Text("Build \(buildNumber.rawValue)")
                    }
                    Button(action: { store.send(.reportABugButtonTapped) }) {
                        Text("Report a bug")
                            .underline()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .font(.system(size: 12, design: .rounded))
            }
            .onAppear { store.send(.onAppear) }
            .navigationTitle("Settings")
            .navigationDestination(
                store: self.store.scope(
                    state: \.$destination.restore,
                    action: \.destination.restore
                )
            ) { store in
                RestoreNonProductView.init(store: store)
            }
            .sheet(isPresented: self.$isSharePresented) {
                ActivityView(activityItems: [URL(string: "https://apps.apple.com/pt/app/ecardify/id6452084315?l=en-GB")!])
                    .ignoresSafeArea()
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity)
        }
    }

}


struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(store: .init(
            initialState: Settings.State(currentUser: .withFirstName)
        ) {
            Settings()
        })
    }
}

enum OurApps: String, CaseIterable {
    case addame, iInverview, notifyWords

    var urlLink: String {
        switch self {
            case .addame:
                return "https://apps.apple.com/pt/app/walk-nearby-neighbours-friends/id1538487173?l=en-GB"
            case .iInverview:
                return "https://apps.apple.com/pt/app/iintrvwbell/id6457363081?l=en-GB"
//            case .learnPlaygrow:
//                return "https://apps.apple.com/pt/app/ecardify/id6452084315?l=en-GB"
            case .notifyWords:
                return "https://apps.apple.com/pt/app/new-word-learn-word-vocabulary/id1619504857?l=en-GB"
        }
    }

    var logoImageLink: URL {
        switch self {
            case .addame:
                return URL(string: "https://github.com/AddaMeSPB/AddaMeSPB.github.io/assets/8770772/eb00fcf7-65b6-4e64-ab1c-faadfd826944")!

            case .iInverview:
                return URL(string: "https://github.com/AddaMeSPB/AddaMeSPB.github.io/assets/8770772/f832e748-e9f2-4a10-8961-c3f10589ed0c")!

//            case .ecardify:
//                return URL(string: "https://github.com/AddaMeSPB/AddaMeSPB.github.io/assets/8770772/2d1c49e4-f6d6-4dda-ab5b-22d4ed0d7a3b")!

            case .notifyWords:
                return URL(string: "https://github.com/AddaMeSPB/AddaMeSPB.github.io/assets/8770772/85d53768-f9e2-4dbe-aba5-cc9c67ce3258")!

        }
    }

    var bcolor: Color {
        switch self {
            case .addame:
                return Color.blue.opacity(0.3)
            case .iInverview:
                return Color.blue.opacity(0.3)
//            case .ecardify:
//                return Color.orange.opacity(0.5)
            case .notifyWords:
                return Color.red.opacity(0.5)
        }
    }
}
