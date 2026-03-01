import WebKit
import SwiftUI
import SwiftUIExtension
import ComposableArchitecture

public class WebViewModel: ObservableObject {
    @Published public var link: Link
    @Published public var didFinishLoading: Bool = true

    public enum Link: String {
        case terms, privacy

        var urlString: String {
            switch self {
                case .terms:
                    return "https://ecardify.byalif.app/terms"
                case .privacy:
                    return "https://ecardify.byalif.app/privacy"
            }
        }
    }

    public init (link: Link) {
        self.link = link
    }
}

extension WebViewModel: Equatable {
    public static func == (lhs: WebViewModel, rhs: WebViewModel) -> Bool {
        return lhs.link == rhs.link && lhs.didFinishLoading == rhs.didFinishLoading
    }
}

public struct WebView: UIViewRepresentable {
    public func updateUIView(_ uiView: UIView, context: Context) {}

    @ObservedObject var viewModel: WebViewModel
    let webView = WKWebView()

    public func makeCoordinator() -> Coordinator {
        Coordinator(self.viewModel)
    }

    public class Coordinator: NSObject, WKNavigationDelegate {
        private var viewModel: WebViewModel

        init(_ viewModel: WebViewModel) {
            self.viewModel = viewModel
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            self.viewModel.didFinishLoading = webView.isLoading
        }
    }

    public func makeUIView(context: Context) -> UIView {
        self.webView.navigationDelegate = context.coordinator

        if let url = URL(string: self.viewModel.link.urlString) {
            self.webView.load(URLRequest(url: url))
        }

        return self.webView
    }
}

@Reducer
public struct TermsAndPrivacy {

    @ObservableState
    public struct State: Equatable {

        public var wbModel: WebViewModel

        public init(wbModel: WebViewModel) {
            self.wbModel = wbModel
        }
    }

    @CasePathable
    public enum Action: Equatable, BindableAction {
      case binding(BindingAction<State>)
      case leaveCurrentPageButtonClick
      case terms
      case privacy
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .leaveCurrentPageButtonClick:
                return .none
            case .terms, .privacy:
                return .none
            }
        }
    }

}

public struct TermsAndPrivacyWebView: View {

    let store: StoreOf<TermsAndPrivacy>

    public init(store: StoreOf<TermsAndPrivacy>) {
        self.store = store
    }

    public var body: some View {
        WebView(viewModel: store.wbModel)
            .overlay(
                Button(
                    action: {
                        store.send(.leaveCurrentPageButtonClick)
                    },
                    label: {
                        Image(systemName: "xmark.circle").font(.title)
                    }
                )
                .padding(.bottom, 10)
                .padding(),

                alignment: .bottomTrailing
            )
            .overlay(
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.blue))
                    .font(.largeTitle)
                    .opacity(store.wbModel.didFinishLoading ? 1 : 0),

                alignment: .center
            )
    }
}
