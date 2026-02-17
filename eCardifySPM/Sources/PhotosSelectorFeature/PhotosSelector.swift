import SwiftUI
import PhotosUI
import SwiftUIExtension
import ComposableArchitecture

public enum ImageState: Equatable {

    public static func ==(lhs: ImageState, rhs: ImageState) -> Bool {
        switch (lhs, rhs) {
        case (let .loading(lhsString), let .loading(rhsString)):
            return lhsString == rhsString

        case (let .success(id1), let .success(id2)):
            return id1 == id2

        default:
            return false
        }
    }

    case empty
    case loading(Progress)
    case success(Image)
    case failure(Error)
}


struct SwapFormImageView: View {
    public var imageState: ImageState

    var body: some View {
        switch imageState {
        case .success(let image):
            image.resizable()
        case .loading:
            ProgressView()
        case .empty:
            Image(systemName: "person.fill")
                .font(.system(size: 40))
                .foregroundColor(.white)
        case .failure:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.white)
        }
    }
}

public struct SwapFormImage: Identifiable, Equatable {
    public let id = UUID().uuidString
    public var image: UIImage = .init(named: "blank-baby-blue")!
}

extension SwapFormImage: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension PhotosPickerItem: Identifiable {
    public var id: String {
        self.hashValue.description

    }
}

@Reducer
public struct PhotosSelectorReducer {

    @ObservableState
    public struct State: Equatable {
        public init(
            imageSelections: [PhotosPickerItem] = [],
            images: [SwapFormImage] = [],
            imageStates: [String: ImageState] = [:]
        ) {
            self.imageSelections = imageSelections
            self.images = images
        }

        public var imageSelections: [PhotosPickerItem] = []

        public var image: SwapFormImage? {
            images.first
        }

        public var images: [SwapFormImage] = []
        public var maxSelectionCount: Int = 9
        public var phPickerFilter: PHPickerFilter? = .any(of: [.images, .not(.videos)])
        public var isLoading: Bool = false

    }

    @CasePathable
    public enum Action: Equatable {
        case imageSelections(items: [PhotosPickerItem])
        case images([SwapFormImage])
        case remove(at: Int)
        case addImageFailling(String)
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce(self.core)
    }

    func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {

        case .imageSelections(items: let imageSelections):
            state.isLoading = true
            return .run { send in
                do {
                    try await send(.images(loadMultipleSelections(from: imageSelections)))
                } catch {
                    await send(.addImageFailling(error.localizedDescription))
                }
            }
        case .images(let images):
            if state.images.isEmpty {
                state.images = images
            } else {
                state.images.append(contentsOf: images)
            }

            state.isLoading = false
            state.imageSelections = []
            return .none

        case .remove(at: let idx):
            state.images.remove(at: idx)
            return .none

        case .addImageFailling:
            // show some alert
            state.isLoading = false
            return .none
        }
    }

    private func loadMultipleSelections(
            from selections: [PhotosPickerItem]
        ) async throws -> [SwapFormImage] {
            var images: [SwapFormImage] = []
            do {
                for selection in selections {
                    if let image = try await loadSelection(from: selection) {
                        images.append(image)
                    }
                }
            } catch {
                sharedLogger.logError("ImageLoader error: \(error)")
            }

            return images

        }

    private func loadSelection(
            from selection: PhotosPickerItem?
        ) async throws -> SwapFormImage? {
            guard let data = try await selection?.loadTransferable(
                type: Data.self
            ), let uiimage =  UIImage(data: data)

            else { return nil }

            return SwapFormImage(image: uiimage)
        }
}

public struct PhotosSelectorView: View {

    @Perception.Bindable var store: StoreOf<PhotosSelectorReducer>

    public init(store: StoreOf<PhotosSelectorReducer>) {
        self.store = store
    }

    public var body: some View {
        WithPerceptionTracking {
            PhotosPicker(
                selection: viewStore.binding(
                    get: \.imageSelections,
                    send: PhotosSelectorReducer.Action.imageSelections(items:)
                ),
                maxSelectionCount: viewStore.maxSelectionCount,
                matching:  viewStore.phPickerFilter //.any(of: [.images, .not(.videos)])
            ) {

                Image(systemName: "plus")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .cornerRadius(10)
                    .padding()
                    .opacity(viewStore.isLoading ? 0 : 1)
                    .overlay(alignment: .center) {
                        VStack {
                            ProgressView("Loading... please wait!")
                                .font(.customSubheadline)
                                .foregroundColor(.nevyDarkLPG)
                        }
                        .opacity(viewStore.isLoading ? 1 : 0)
                    }

            }

        }
    }
}

struct PhotosSelectorView_Previews: PreviewProvider {
    static var previews: some View {
        PhotosSelectorView(store: .init(
            initialState: PhotosSelectorReducer.State(),
            reducer: PhotosSelectorReducer()
            )
        )
    }
}
