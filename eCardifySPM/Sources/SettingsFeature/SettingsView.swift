import Build
import SwiftUI
import SwiftUIExtension
import ECSharedModels
import ComposableArchitecture

public struct SettingsView: View {

    @Environment(\.colorScheme) var colorScheme
    @State var isSharePresented = false
    let store: StoreOf<Settings>

    private var items: [GridItem] {
        Array(repeating: .init(.adaptive(minimum: 250)), count: 2)
    }

    public init(store: StoreOf<Settings>) {
        self.store = store
    }

    public var body: some View {
        WithPerceptionTracking {
            VStack {
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

                LazyVGrid(columns: items, spacing: 10) {
                    Button(action: {
                        store.send(.leaveUsAReviewButtonTapped)
                    }) {
                        VStack(alignment: .center, spacing: 5) {
                            HStack { Spacer() }
                            Image(systemName: "hand.thumbsup")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 65, height: 65)
                                .foregroundColor(.white)

                            Text("Leave us review")
                                .font(.title3)
                                .bold()
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                .padding(.vertical, 5)

                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                    }
                    //          .buttonStyle(.plain)
                    .frame(height: 180)
                    .background(Color.red.opacity(0.3))
                    .cornerRadius(20)

                    Button(action: {
                        isSharePresented.toggle()
                    }) {
                        VStack(alignment: .center, spacing: 5) {
                            HStack { Spacer() }
                            Image(systemName: "square.and.arrow.up.circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 65, height: 65)
                                .foregroundColor(.blue)

                            Text("Share with friends")
                                .font(.title3)
                                .bold()
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                .padding(.vertical, 5)

                            Spacer()
                        }
                        .padding()
                    }
                    //          .buttonStyle(.plain)
                    .frame(height: 180)
                    .background(Color.yellow.opacity(0.5))
                    .cornerRadius(20)


                    Button(action: {
                        store.send(.restoreButtonTapped)
                    }) {
                        VStack(alignment: .center, spacing: 5) {
                            HStack { Spacer() }
                            Image(systemName: "star.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 65, height: 65)
                                .foregroundColor(.red)

                            Text("Restore")
                                .font(.title3)
                                .bold()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()

                            Spacer()
                        }
                        .padding()
                    }
                    //          .buttonStyle(.plain)
                    .frame(height: 180)
                    .background(Color.blue.opacity(0.3))
                    .cornerRadius(20)


                }
                .padding()

                Spacer()

                HStack {
                    Spacer()

                    Button(action: { store.send(.logOutButtonTapped) }) {
                        Text("Log out!")
                            .font(.title3).fontWeight(.medium)
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
