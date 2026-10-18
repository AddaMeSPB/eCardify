import BSON
import PassKit
import SwiftUI
import LoggerKit
import APIClient
import Foundation
import L10nResources
import SettingsFeature
import VNRecognizeFeature
import ECSharedModels
import ComposableArchitecture

@Reducer
public struct WalletPassList {

    @ObservableState
    public struct State: Equatable {
        public init(
            wPass: IdentifiedArrayOf<WalletPassDetails.State> = [],
            wPassLocal: IdentifiedArrayOf<WalletPassDetails.State> = [],
            isActivityIndicatorVisible: Bool = false
        ) {
            self.wPass = wPass
            self.wPassLocal = wPassLocal
            self.isActivityIndicatorVisible = isActivityIndicatorVisible
        }

        @Presents public var destination: Destination.State?
        @Presents public var alert: AlertState<Alert>?

        public var vCard: VCard? = .empty
        public var wPass: IdentifiedArrayOf<WalletPassDetails.State> = []
        public var wPassLocal: IdentifiedArrayOf<WalletPassDetails.State> = []
        public var isActivityIndicatorVisible = false
        public var isLoadingWPL: Bool = false
        public var loadError: String? = nil
        @Shared(.appStorage("isAuthorized")) public var isAuthorized = false
        public var user: UserOutput? = nil
        
    }


    @CasePathable
    public enum Action: BindableAction {
        case alert(PresentationAction<Alert>)
        case addPassFailed(AddPassFailure)
        case binding(BindingAction<State>)
        case onAppear
        case wPass(IdentifiedActionOf<WalletPassDetails>)
        case wpResponse([WalletPass])
        case wpResponseFailed(String)
        case wpLocalDataResponse([WalletPass])
        case wpLocalDataFailed
        case wpDeleteResponse(id: String)
        case wpDeleteFailed
        case getWP
        case retryButtonTapped
        case sendPass(PKPass)
        case openSheetLogin(Bool)
        case destination(PresentationAction<Destination.Action>)
        case createGenericFormButtonTapped
        case dismissAddGenericFormButtonTapped
        case navigateSettingsButtonTapped
        case scanCardButtonTapped
        case discoverButtonTapped

    }

    public enum Alert: Equatable {
        /// User confirmed deleting the card with this (hex) id.
        case confirmDelete(id: String)
    }

    /// Why a pass couldn't reach Apple Wallet. Each case maps to a
    /// user-facing alert in `addPassFailed` — never fail silently.
    public enum AddPassFailure: Equatable {
        case downloadFailed
        case deviceCannotAddPasses
        case invalidPassFile
    }

    public init() {}

    @Dependency(\.build) var build
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.localDatabase) var localDatabase
    @Dependency(\.keychainClient) var keychainClient
    @Dependency(\.vnRecognizeClient) var vnRecognizeClient
    @Dependency(\.attachmentS3Client) var attachmentS3Client

    public var body: some Reducer<State, Action> {

        BindingReducer()

        Reduce(self.core)
            .ifLet(\.$destination, action: \.destination) {
                Destination()
            }
            .ifLet(\.$alert, action: \.alert)
            .forEach(\.wPassLocal, action: \.wPass) {
                WalletPassDetails()
            }
    }

    func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {

        case .alert(.presented(.confirmDelete(let id))):
            guard let objectId = ObjectId(id) else {
                sharedLogger.logError("Delete failed — pass id is not a valid ObjectId: \(id)")
                return .send(.wpDeleteFailed)
            }
            return .run { send in
                do {
                    _ = try await apiClient.request(
                        for: .walletPasses(.delete(id: objectId)),
                        as: WalletPassDeleteResponse.self
                    )
                } catch APIError.serviceError(let statusCode, _) where statusCode == 404 {
                    // Already gone server-side — finish the local cleanup.
                    sharedLogger.log("Delete: pass \(id) already absent on server — cleaning up locally")
                } catch {
                    sharedLogger.logError("Delete failed for pass \(id): \(error.localizedDescription)")
                    await send(.wpDeleteFailed)
                    return
                }
                do {
                    try await localDatabase.deleteBy(id: id)
                } catch {
                    // The server row is gone — that's the source of truth, so
                    // this still reports success. Retry the cache cleanup once;
                    // if it fails again, the stale row only resurfaces OFFLINE
                    // on a later launch (the remote refresh replaces the
                    // in-memory list, not the cache). Accepted: deleteBy only
                    // throws on catastrophic DB errors, and pruning the cache
                    // against the remote list could drop unsynced local cards.
                    sharedLogger.logError("Delete: local cache cleanup failed for \(id), retrying: \(error.localizedDescription)")
                    do {
                        try await localDatabase.deleteBy(id: id)
                    } catch {
                        sharedLogger.logError("Delete: local cache cleanup failed twice for \(id) — leaving stale row: \(error.localizedDescription)")
                    }
                }
                await send(.wpDeleteResponse(id: id))
            }

        case .alert:
            return .none

        case .wpDeleteResponse(let id):
            state.wPassLocal.remove(id: id)
            state.wPass.remove(id: id)
            return .none

        case .wpDeleteFailed:
            state.alert = AlertState {
                TextState(L("Error"))
            } message: {
                TextState(L("Unable to delete the card. Please try again."))
            }
            return .none

        case .addPassFailed(let failure):
            // A presented sheet blocks alerts from the root view — dismiss it,
            // let the dismissal settle, then re-enter to show the alert.
            // Pushed destinations (.add, .settings) are kept: popping them
            // would skip the .destination(.dismiss) vCard sync and throw away
            // the user's navigation. If one is covering the root when the
            // failure lands (only possible if the user navigated during the
            // download), the binding-driven alert presents once the root
            // reappears — deferred, not lost. The failure is logged either way.
            switch state.destination {
            case .addPass, .cardCreated, .digitalCard, .discover:
                state.destination = nil
                return .run { send in
                    try await clock.sleep(for: .milliseconds(550))
                    await send(.addPassFailed(failure))
                }
            case .add, .settings, .none:
                break
            }
            switch failure {
            case .downloadFailed:
                state.alert = AlertState {
                    TextState(L("Download Failed"))
                } message: {
                    TextState(L("The pass could not be downloaded. Please check your connection and try again."))
                }
            case .deviceCannotAddPasses:
                state.alert = AlertState {
                    TextState(L("Wallet Unavailable"))
                } message: {
                    TextState(L("This device can't add passes to Apple Wallet."))
                }
            case .invalidPassFile:
                state.alert = AlertState {
                    TextState(L("Invalid Pass"))
                } message: {
                    TextState(L("This pass can't be added to Apple Wallet. Please contact support."))
                }
            }
            return .none

        case .binding:
            return .none

        case .onAppear:

            #if DEBUG
            // Demo mode: data is already injected by AppReducer — skip API/DB fetch
            if ProcessInfo.processInfo.arguments.contains("-DEMO_MODE") {
                return .none
            }
            #endif

            sharedLogger.log("onAppear get success before login")
            // @Shared(.appStorage) auto-syncs — no manual read needed

            do {
                state.user = try self.keychainClient.readCodable(.user, self.build.identifier(), UserOutput.self)
            } catch {
                // Keychain user missing — if was authorized, force re-login
                if state.isAuthorized {
                    sharedLogger.logError("Keychain user missing but isAuthorized=true — forcing re-login")
                    state.$isAuthorized.withLock { $0 = false }
                    return .send(.openSheetLogin(true))
                }
                return .none
            }

            // Skip if already loading (prevents duplicate fetches on rapid nav back)
            guard !state.isLoadingWPL else {
                return .none
            }

            state.isLoadingWPL = true
            state.loadError = nil
            sharedLogger.log("onAppear get success after login")

            // 1. Show cached local data immediately, then refresh from remote
            return .run { send in
                // Show local cache first (fast)
                do {
                    let wpl = try await localDatabase.find()
                    await send(.wpLocalDataResponse(wpl))
                } catch {
                    sharedLogger.logError("\(#line) cant find any data error:- \(error.localizedDescription)")
                    await send(.wpLocalDataFailed)
                }
                // Then fetch remote update (slower, overwrites local)
                await send(.getWP)
            }


        case .getWP:
            return .run { send in
                do {
                    let wp = try await apiClient.request(
                        for: .walletPasses(.list),
                        as: [WalletPass].self,
                        decoder: .iso8601
                    )
                    await send(.wpResponse(wp))
                } catch {
                    sharedLogger.logError(error)
                    let message: String
                    if let urlError = error as? URLError {
                        message = urlError.code == .notConnectedToInternet
                            ? "No internet connection."
                            : "Unable to reach the server. Please try again."
                    } else {
                        message = "Unable to load cards. Please try again."
                    }
                    await send(.wpResponseFailed(message))
                }
            }

        case .retryButtonTapped:
            state.loadError = nil
            state.isLoadingWPL = true
            return .run { send in
                await send(.getWP)
            }
            
        case .openSheetLogin:
            return .none

        case .sendPass(let pass):
            state.destination = .addPass(.init(pass: pass))
            return .none

        case .wPass(.element(id: let id, action: let wpaction)):
            if wpaction == .addPassToWallet {
                if let pass = state.wPassLocal[id: id] {
                    let url =  "https://ecardify.ams3.cdn.digitaloceanspaces.com/ecardify/uploads/pass/\(pass.wp.ownerId.hexString)/\(pass.id).pkpass"
                    return .run { send in
                        await send(.destination(.presented(.add(.buildPKPassFrom(url: url)))))
                    }
                }
            }

            if wpaction == .viewCardButtonTapped {
                if let pass = state.wPassLocal[id: id] {
                    state.destination = .digitalCard(
                        .init(
                            colorP: pass.wp.colorPalette,
                            vCard: pass.wp.vCard,
                            isRealDataView: true
                        )
                    )
                }
            }

            if wpaction == .deleteCardButtonTapped, state.wPassLocal[id: id] != nil {
                state.alert = AlertState {
                    TextState(L("Delete Card"))
                } actions: {
                    ButtonState(role: .destructive, action: .confirmDelete(id: id)) {
                        TextState(L("Delete"))
                    }
                    ButtonState(role: .cancel) {
                        TextState(L("Cancel"))
                    }
                } message: {
                    // Honest scope: we remove the card, its public page and the
                    // Add-to-Wallet link — a pass already added to the phone's
                    // Wallet stays until the user removes it there.
                    TextState(L("This will permanently delete this card, its public page, and its Add to Wallet link. This action cannot be undone."))
                }
            }

            return .none

        case .wpResponse(let wp):
            state.loadError = nil
            let wPassResponse = wp.map { WalletPassDetails.State(wp: $0, vCard: $0.vCard) }
            state.wPass = .init(uniqueElements: wPassResponse)
            return .run { send in
                await send(.wpLocalDataResponse(wp))
            }

        case .wpResponseFailed(let message):
            state.isLoadingWPL = false
            state.loadError = message
            return .none

        case .wpLocalDataResponse(let wpl):
            let wPassLocalResponse = wpl
                .filter { $0.isPaid == true }
                .map { WalletPassDetails.State(wp: $0, vCard: $0.vCard) }
            state.wPassLocal = .init(uniqueElements: wPassLocalResponse)
            state.isLoadingWPL = false
            return .none

        case .wpLocalDataFailed:
            state.isLoadingWPL = false
            return .none

        // Show CardCreated screen after successful card creation
        case .destination(.presented(.add(.showCardCreated(let wp)))):
            state.destination = .cardCreated(.init(walletPass: wp))
            return .none

        // CardCreated actions
        case .destination(.presented(.cardCreated(.addToWallet))):
            // Delegate to the existing PKPass download flow
            if case let .cardCreated(cardState) = state.destination {
                let pass = cardState.walletPass
                let url = "https://ecardify.ams3.cdn.digitaloceanspaces.com/ecardify/uploads/pass/\(pass.ownerId.hexString)/\(pass.id).pkpass"
                return .run { send in
                    await send(.destination(.presented(.add(.buildPKPassFrom(url: url)))))
                }
            }
            return .none

        case .destination(.presented(.cardCreated(.done))):
            state.destination = nil
            return .run { send in
                await send(.getWP)
            }

        case .destination(.presented(.cardCreated(.shareCard))):
            // Handled by the view (UIActivityViewController)
            return .none

        case .destination(.presented(.cardCreated)):
            return .none

        // Discover CTA: close the gallery, then run the normal create flow
        // (auth-gated inside createGenericFormButtonTapped).
        // Must stay ABOVE the catch-all `case .destination:` or it never matches.
        case .destination(.presented(.discover(.delegate(.createCard)))):
            state.destination = nil
            return .run { send in
                // Let the sheet dismiss settle before presenting the form
                try await clock.sleep(for: .milliseconds(400))
                await send(.createGenericFormButtonTapped)
            }

        case .destination(.presented(.add(.buildPKPassFrom(url: let passUrl)))):

            return .run { send in
                guard let url = URL(string: passUrl) else {
                    sharedLogger.logError("Invalid pass URL: \(passUrl)")
                    await send(.addPassFailed(.invalidPassFile))
                    return
                }

                let data: Data
                do {
                    let urlRequest = URLRequest(url: url)
                    let (body, response) = try await URLSession.shared.data(for: urlRequest)

                    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                        sharedLogger.logError("Pass download failed with status \(status) url: \(passUrl)")
                        await send(.addPassFailed(.downloadFailed))
                        return
                    }
                    data = body
                } catch {
                    sharedLogger.logError("Pass download failed url: \(passUrl) error: \(error.localizedDescription)")
                    await send(.addPassFailed(.downloadFailed))
                    return
                }

                guard await PKAddPassesViewController.canAddPasses() else {
                    sharedLogger.logError("PKAddPassesViewController.canAddPasses() == false — device can't add passes")
                    await send(.addPassFailed(.deviceCannotAddPasses))
                    return
                }

                do {
                    let pass = try PKPass(data: data)
                    await send(.sendPass(pass))
                } catch {
                    // Corrupt or badly signed .pkpass (e.g. expired signing cert)
                    sharedLogger.logError("PKPass(data:) failed url: \(passUrl) error: \(error.localizedDescription)")
                    await send(.addPassFailed(.invalidPassFile))
                }
            }

        case .destination(.dismiss):

            if case let .add(addState) = state.destination {
                state.vCard = addState.vCard
            }

            return .none

        case .destination:
          return .none

        case .createGenericFormButtonTapped:
            // Gate: must be logged in before entering the form
            guard state.isAuthorized else {
                return .send(.openSheetLogin(true))
            }
            state.destination = .add(
                .init(
                    user: state.user,
                    vCard: state.vCard ?? .empty,
                    existingCards: state.wPassLocal.map(\.wp)
                )
            )
            return .none

        case .dismissAddGenericFormButtonTapped:
            state.destination = nil
            return .none

        case .navigateSettingsButtonTapped:
            guard let currentUser = state.user else {
                return .none
            }

            state.destination = .settings(.init(currentUser: currentUser))
            return .none

        case .discoverButtonTapped:
            state.destination = .discover(.init())
            return .none

        case .scanCardButtonTapped:
            // Open the card creation form — the form already has scanner
            // built-in via the camera button (VNRecognize). Navigate to form
            // so user can scan a paper card and auto-populate fields.
            guard state.isAuthorized else {
                return .send(.openSheetLogin(true))
            }
            state.destination = .add(
                .init(
                    user: state.user,
                    vCard: state.vCard ?? .empty,
                    existingCards: state.wPassLocal.map(\.wp)
                )
            )
            return .none

        }
    }

    @Reducer
    public struct Destination {

        public enum State: Equatable {
            case addPass(AddPass.State)
            case digitalCard(CardDesignReducer.State)
            case add(GenericPassForm.State)
            case settings(Settings.State)
            case cardCreated(CardCreated.State)
            case discover(Discover.State)
        }

        @CasePathable
        public enum Action {
            case addPass(AddPass.Action)
            case digitalCard(CardDesignReducer.Action)
            case add(GenericPassForm.Action)
            case settings(Settings.Action)
            case cardCreated(CardCreated.Action)
            case discover(Discover.Action)
        }

        public init() {}

        public var body: some Reducer<State, Action> {

            Scope(state: \.addPass, action: \.addPass) {
                AddPass()
            }

            Scope(state: \.digitalCard, action: \.digitalCard) {
                CardDesignReducer()
            }

            Scope(state: \.add, action: \.add) {
                GenericPassForm()
            }

            Scope(state: \.settings, action: \.settings) {
                Settings()
            }

            Scope(state: \.cardCreated, action: \.cardCreated) {
                CardCreated()
            }

            Scope(state: \.discover, action: \.discover) {
                Discover()
            }
        }
    }
}


func extractEmailAddrIn(text: String) -> [String] {
    var results = [String]()

    let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    let nsText = text as NSString
    do {
        let regExp = try NSRegularExpression(pattern: emailRegex, options: .caseInsensitive)
        let range = NSMakeRange(0, text.count)
        let matches = regExp.matches(in: text, options: .reportProgress, range: range)

        for match in matches {
            let matchRange = match.range
            results.append(nsText.substring(with: matchRange))
        }
    } catch (let error) {
        sharedLogger.logError(error)
    }

    return results


//    // Define the regular expression pattern for email addresses
//    let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
//
//    // Create a regular expression object
//    guard let regex = try? NSRegularExpression(pattern: emailRegex, options: []) else {
//        return // The regular expression pattern is invalid
//    }
//
//    // Search for matches in the input string
//    let inputString = "Hello, my email address is john.doe@example.com"
//    let range = NSRange(location: 0, length: inputString.utf16.count)
//    let matches = regex.matches(in: inputString, options: [], range: range)
//
//    // Extract the email addresses from the matches
//    let emailAddresses = matches.map {
//        (inputString as NSString).substring(with: $0.range)
//    }
}

enum PhoneNumberDetectionError: Error {
    case nothingDetected
    case noNumberFound
}

extension String {
    func findContactNumber() throws -> String {
        let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue)

        guard let detected = detector.firstMatch(
            in: self, options: [],
            range: NSRange(location: 0, length: self.utf16.count)
        ) else {
            throw PhoneNumberDetectionError.nothingDetected
        }

        guard let number = detected.phoneNumber else {
            throw PhoneNumberDetectionError.noNumberFound
        }

        let noWhiteSpaces = number.filter { !$0.isWhitespace }

        return noWhiteSpaces
    }

    func findContactsNumber() throws -> [String] {
        _ = #"[(]\d{3}[)]\s\d{3}[-]\d{4}"#
        var result: [String] = []

        let phoneNumberRegex = try NSRegularExpression(pattern: "\\+?\\d[\\d -]{8,12}\\d")
        let numbers = phoneNumberRegex.matches(in: self, range: NSRange(self.startIndex..., in: self)).map {
            String(self[Range($0.range, in: self)!])
        }

        for number in numbers {
            do {
                let phone = try number.findContactNumber()
                result.append(phone)
            } catch {
                throw PhoneNumberDetectionError.noNumberFound
            }
        }

        return result

    }

}

