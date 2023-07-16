import BSON
import PassKit
import SwiftUI
import APIClient
import Foundation
import SettingsFeature
import ECardifySharedModels
import ComposableArchitecture
import VNRecognizeFeature
import UserDefaultsClient

public extension Bundle {
    @Sendable func decode<T: Decodable>(
        _ type: T.Type,
        from file: String,
        dateDecodingStategy: JSONDecoder.DateDecodingStrategy = .deferredToDate,
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys
    ) throws -> T {
        guard let url = self.url(forResource: file, withExtension: nil) else {
            fatalError("Error: Failed to locate \(file) in bundle.")
        }

        guard let data = try? Data(contentsOf: url) else {
            fatalError("Error: Failed to load \(file) from bundle.")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = keyDecodingStrategy

        do {
            let loaded = try decoder.decode(T.self, from: data)
            return loaded
        } catch {
            fatalError("Error: Failed to decode \(file) from bundle. \(error)")
        }

    }
}

public struct WallatPassList: ReducerProtocol {

    public struct State: Equatable {
        public init(
            pass: Pass = .draff,
            wPass: IdentifiedArrayOf<WallatPassDetails.State> = [],
            isActivityIndicatorVisible: Bool = false
        ) {
            self.pass = pass
            self.wPass = wPass
            self.isActivityIndicatorVisible = isActivityIndicatorVisible

        }

        @BindingState public var pass: Pass?
        @PresentationState public var destination: Destination.State?

        public var vCard: VCard? = .empty
        public var wPass: IdentifiedArrayOf<WallatPassDetails.State> = []
        public var wPassLocal: IdentifiedArrayOf<WallatPassDetails.State> = []
        public var isActivityIndicatorVisible = false
        public var isLoadinWPL: Bool = false
        public var isAuthorized: Bool = true
        public var user: UserOutput? = nil
        
    }

    public enum Action: BindableAction, Equatable {
        public static func == (lhs: WallatPassList.Action, rhs: WallatPassList.Action) -> Bool {
            return true
        }

        case binding(BindingAction<State>)
        case onAppear
        case wPass(id: WallatPassDetails.State.ID, action: WallatPassDetails.Action)
        case wpResponse(TaskResult<[WalletPass]>)
        case wpLocalDataResponse(TaskResult<[WalletPass]>)
        case getWP
        case sendPass(PKPass)
        case passResponse(TaskResult<WalletPassResponse>)
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
    @Dependency(\.userDefaults) var userDefaults
    @Dependency(\.localDatabase) var localDatabase
    @Dependency(\.keychainClient) var keychainClient
    @Dependency(\.vnRecognizeClient) var vnRecognizeClient
    @Dependency(\.attachmentS3Client) var attachmentS3Client

    public var body: some ReducerProtocol<State, Action> {

        BindingReducer()

        Reduce(self.core)
            .ifLet(\.$destination, action: /Action.destination) {
                Destination()
            }
            .forEach(\.wPassLocal, action: /Action.wPass(id:action:)) {
                WallatPassDetails()
            }
    }

    func core(state: inout State, action: Action) -> EffectTask<Action> {
        switch action {

        case .binding:
            return .none

        case .onAppear:

            state.isAuthorized = userDefaults.boolForKey(UserDefaultKey.isAuthorized.rawValue)

            do {
                state.user = try self.keychainClient.readCodable(.user, self.build.identifier(), UserOutput.self)
            } catch {
                //state.alert = .init(title: TextState("Missing you id! please login again!"))
                return .none
            }

            state.isLoadinWPL = true
            return .run { send in
                await send(.getWP)
                do {
                    let wpl = try await localDatabase.find()
                    await send(.wpLocalDataResponse(.success(wpl)))
                } catch {
                    await send(.wpLocalDataResponse(.failure(error)))
                    print("\(#line) cant find any data error:- \(error.localizedDescription)")
                }
            }


        case .getWP:

            return .task {
                .wpResponse(
                    await TaskResult {
                        try await apiClient.request(
                            for: .walletPasses(.list),
                            as: [WalletPass].self,
                            decoder: .iso8601
                        )
                    }
                )
            }

        case .openSheetLogin:
            return .none

        case .sendPass(let pass):
            state.destination = .addPass(.init(pass: pass))
            return .none

        case .wPass(id: let id, action: let wpaction):
            if wpaction == .addPassToWallet {
                if let pass = state.wPassLocal.filter({ $0.id == id }).first {
                    let url =  "https://learnplaygrow.ams3.cdn.digitaloceanspaces.com/ecardify/uploads/pass/\(pass.wp.ownerId.hexString)/\(pass.id).pkpass"
                    return .run { send in
                        await send(.destination(.presented(.add(.buildPKPassFrom(url: url)))))
                    }
                }
            }
            return .none

        case .wpResponse(.success(let wp)):

            if wp.count < 0 {
                //state.genericPassForm = .init()
                // add something onbording video
            }

            let wPassResponse = wp.map { WallatPassDetails.State(wp: $0) }
            state.wPass = .init(uniqueElements: wPassResponse)
            return .none

        case .wpResponse(.failure(let error)):
            return .none

        case .wpLocalDataResponse(.success(let wpl)):

            let wPassLocalResponse = wpl
                .filter { $0.isPaid == true }
                .map { WallatPassDetails.State(wp: $0) }
            
            state.wPassLocal = .init(uniqueElements: wPassLocalResponse)

            state.isLoadinWPL = false
            return .none

        case .wpLocalDataResponse(.failure(let error)):
            state.isLoadinWPL = false
            return .none

        case .passResponse(_):
            return .none

        case .destination(.presented(.add(.buildPKPassFrom(url: let passUrl)))):

            return .run { send in
                guard let url = URL(string: passUrl)
                else {
                    fatalError("Missing URL")
                }

                let urlRequest = URLRequest(url: url)
                let (data, response) = try await URLSession.shared.data(for: urlRequest)

                guard (response as? HTTPURLResponse)?.statusCode == 200
                else {
                    fatalError("Error while fetching data")
                }

                let canAddPassResult = await PKAddPassesViewController.canAddPasses ()

                if (canAddPassResult) {
                    await send(.sendPass(try PKPass.init (data: data)))
                }
            }

        case .destination(.dismiss):
            switch state.destination {
            case .some(.add(let addState)):
                state.vCard = addState.vCard
                return .none
            case .some(.addPass):
                return .none
            case .some(.settings):
                return .none
            case .none:
                return .none
            }
       
        case .destination:
          return .none

        case .createGenericFormButtonTapped:
            state.destination = .add(.init(vCard: state.vCard ?? .empty))
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

    public struct Destination: ReducerProtocol {
        public enum State: Equatable {
            case addPass(AddPass.State)
            case add(GenericPassForm.State)
            case settings(Settings.State)
        }

        public enum Action: Equatable {
            case addPass(AddPass.Action)
            case add(GenericPassForm.Action)
            case settings(Settings.Action)
        }

        public init() {}

        public var body: some ReducerProtocol<State, Action> {

            Scope(state: /State.addPass, action: /Action.addPass) {
                AddPass()
            }

            Scope(state: /State.add, action: /Action.add) {
                GenericPassForm()
            }

            Scope(state: /State.settings, action: /Action.settings) {
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
        print(error)
    }

    return results


//    // Define the regular expression pattern for email addresses
//    let emailRegexk = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
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
        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue)

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
        let pattern = #"[(]\d{3}[)]\s\d{3}[-]\d{4}"#
        var result: [String] = []

        let phoneNumberRegex = try! NSRegularExpression(pattern: "\\+?\\d[\\d -]{8,12}\\d")
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

