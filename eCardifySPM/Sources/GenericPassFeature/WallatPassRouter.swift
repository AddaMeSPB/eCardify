import BSON
import PassKit
import SwiftUI
import LoggerKit
import APIClient
import Foundation
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
        case binding(BindingAction<State>)
        case onAppear
        case wPass(IdentifiedActionOf<WalletPassDetails>)
        case wpResponse([WalletPass])
        case wpResponseFailed(String)
        case wpLocalDataResponse([WalletPass])
        case wpLocalDataFailed
        case getWP
        case retryButtonTapped
        case sendPass(PKPass)
        case openSheetLogin(Bool)
        case destination(PresentationAction<Destination.Action>)
        case createGenericFormButtonTapped
        case dismissAddGenericFormButtonTapped
        case navigateSettingsButtonTapped

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
            .forEach(\.wPassLocal, action: \.wPass) {
                WalletPassDetails()
            }
    }

    func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {

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

        case .destination(.presented(.add(.buildPKPassFrom(url: let passUrl)))):

            return .run { send in
                guard let url = URL(string: passUrl) else {
                    sharedLogger.logError("Invalid pass URL: \(passUrl)")
                    return
                }

                let urlRequest = URLRequest(url: url)
                let (data, response) = try await URLSession.shared.data(for: urlRequest)

                guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                    let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                    sharedLogger.logError("Pass download failed with status \(status)")
                    return
                }

                let canAddPassResult = await PKAddPassesViewController.canAddPasses()

                if canAddPassResult {
                    await send(.sendPass(try PKPass(data: data)))
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
            state.destination = .add(.init(user: state.user, vCard: state.vCard ?? .empty))
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
            
        }
    }

    @Reducer
    public struct Destination {

        public enum State: Equatable {
            case addPass(AddPass.State)
            case digitalCard(CardDesignReducer.State)
            case add(GenericPassForm.State)
            case settings(Settings.State)
        }

        @CasePathable
        public enum Action {
            case addPass(AddPass.Action)
            case digitalCard(CardDesignReducer.Action)
            case add(GenericPassForm.Action)
            case settings(Settings.Action)
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

