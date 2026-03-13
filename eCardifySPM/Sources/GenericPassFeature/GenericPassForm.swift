import BSON
import SwiftUI
import StoreKit
import APIClient
import LoggerKit
import Foundation
import ImagePicker
import L10nResources
import ECSharedModels
import SettingsFeature
import VNRecognizeFeature
import AttachmentS3Client
import ComposableStoreKit
import LocalDatabaseClient
import FoundationExtension
import ComposableArchitecture
#if os(iOS)
import UIKit
#endif

@Reducer
public struct GenericPassForm {

    public enum ImageFor: String, Equatable {
        case logo, avatar, card
    }

    @ObservableState
    public struct State: Equatable {
        public init(
            isActivityIndicatorVisible: Bool = false,
            storeKitState: StoreKitReducer.State = .init(),
            isUploadingImage: Bool = false,
            logoImage: UIImage? = nil,
            avatarImage: UIImage? = nil,
            cardImage: UIImage? = nil,
            imageFor: ImageFor = .avatar,
            imageURLS: [ImageURL] = [],
            isFormValid: Bool = false,
            user: UserOutput? = nil,
            vCard: VCard,
            telephone: VCard.Telephone = .empty,
            email: String = ""
        ) {
            self.isActivityIndicatorVisible = isActivityIndicatorVisible
            self.storeKitState = storeKitState
            self.isUploadingImage = isUploadingImage
            self.logoImage = logoImage
            self.avatarImage = avatarImage
            self.cardImage = cardImage
            self.imageFor = imageFor
            self.isFormValid = isFormValid
            self.user = user
            self.vCard = vCard
            self.telephone = telephone
            self.email = email
        }

        public var vCard: VCard
        public var telephone: VCard.Telephone
        public var email: String
        public var storeKitState: StoreKitReducer.State
        @Presents public var imagePicker: ImagePickerReducer.State?
        @Presents public var digitalCardDesign: CardDesignListReducer.State?
        @Presents var alert: AlertState<AlertAction>?

        public var pass: Pass = .draff
        public var colorPalette: ColorPalette = .default
        public var isActivityIndicatorVisible = false
        public var isUploadingImage: Bool = false
        public var logoImage: UIImage?
        public var avatarImage: UIImage?
        public var cardImage: UIImage?
        public var imageFor: ImageFor = .avatar
        public var isFormValid: Bool = false
        @Shared(.appStorage("isAuthorized")) public var isAuthorized = false
        @Shared(.appStorage("hasUsedFreeCard")) public var hasUsedFreeCard = false
        public var isEligibleForFreeCard: Bool { !hasUsedFreeCard }
        public var user: UserOutput? = nil
        public var walletPass: WalletPass? = nil
        public var bottomID: Int = 9
        public var isCustomProduct: Bool {
            return storeKitState.type == .basic ? false : true
        }
        public var isEmailValid: Bool = false
        /// Set to true when saveToServer fails with 401/403.
        /// After re-login succeeds, auto-retries the save.
        public var pendingSave: Bool = false

    }

    @CasePathable
    public enum Action: BindableAction {
        case alert(PresentationAction<AlertAction>)
        case binding(BindingAction<State>)
        case imagePicker(PresentationAction<ImagePickerReducer.Action>)
        case digitalCardDesign(PresentationAction<CardDesignListReducer.Action>)
        case dcdSheetIsPresentedButtonTapped
        case onAppear
        case isUploadingImage
        case isImagePicker(isPresented: Bool)
        case uploadAvatar(_ image: UIImage)
        case createAttachment(_ attachment: AttachmentInOutPut)
        case imageUploadSuccess(String)
        case imageUploadFailed
        case attachmentResponse(AttachmentInOutPut)
        case attachmentFailed
        case imageFor(ImageFor)
        case recognizeText(VNRecognizeResponse)
        case createPass
        case buildPKPassFrom(url: String)
        case passResponse(WalletPassResponse)
        case passResponseFailed(reason: String = "")
        case openSheetLogin(Bool)
        case storeKit(StoreKitReducer.Action)
        case buyProduct
        case saveToServer
        case dismissView
        case update(isAuthorized: Bool)
        case addOneMoreEmailSection
        case removeEmailSection(by: UUID)
        case addOneMoreTelephoneSection
        case removeTelephoneSection(by: UUID)
        case addOneMoreAddressSection
        case removeAddressSection(by: UUID)
        case resetFreeCardFlag

    }

    public enum AlertAction: Equatable {
        case retrySave
        case loginAndRetry
    }

    public init() {}

    @Dependency(\.build) var build
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.keychainClient) var keychainClient
    @Dependency(\.neuAuthClient) var neuAuthClient
    @Dependency(\.vnRecognizeClient) var vnRecognizeClient
    @Dependency(\.attachmentS3Client) var attachmentS3Client
    @Dependency(\.localDatabase) var localDatabase
    @Dependency(\.dismiss) var dismiss

    public var body: some Reducer<State, Action> {

        BindingReducer()

        Scope(state: \.storeKitState, action: \.storeKit) {
            StoreKitReducer()
        }

        Reduce(self.core)
            .ifLet(\.$alert, action: \.alert)
            .ifLet(\.$imagePicker, action: \.imagePicker) {
                ImagePickerReducer()
            }
            .ifLet(\.$digitalCardDesign, action: \.digitalCardDesign) {
                CardDesignListReducer()
            }
    }

    func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {

        case .binding(\.vCard):

            state.isEmailValid = state.vCard.emails.contains { $0.text.isEmailValid }

            let emailValidationCheck = state.vCard.emails.allSatisfy { $0.text.isEmailValid }
            state.isFormValid = state.vCard.isVCardValid && emailValidationCheck

            return .none

        case .binding:
            return .none

        case .alert(.presented(.retrySave)):
            return .run { send in
                await send(.saveToServer)
            }

        case .alert(.presented(.loginAndRetry)):
            // User's token was rejected (401/403) — re-login then auto-retry
            state.pendingSave = true
            state.$isAuthorized.withLock { $0 = false }
            return .run { send in
                await send(.openSheetLogin(true))
            }

        case .alert:
            return .none

        case .resetFreeCardFlag:
            sharedLogger.log("Recovery: resetting burned hasUsedFreeCard flag (no paid cards exist)")
            state.$hasUsedFreeCard.withLock { $0 = false }
            return .none

            // MARK: - .onAppear
        case .onAppear:
            // @Shared(.appStorage) auto-syncs — no manual read needed
            // Refresh user from keychain if available (parent already set state.user)
            if let freshUser = try? self.keychainClient.readCodable(.user, self.build.identifier(), UserOutput.self) {
                state.user = freshUser
            }

            return .run { [hasUsedFreeCard = state.hasUsedFreeCard] send in
                // Recovery: if hasUsedFreeCard was burned by old bug but
                // no paid cards actually exist, reset the flag so the user
                // gets their rightful free card.
                if hasUsedFreeCard {
                    let existingCards = (try? await localDatabase.find()) ?? []
                    let paidCards = existingCards.filter { $0.isPaid == true }
                    if paidCards.isEmpty {
                        await send(.resetFreeCardFlag)
                    }
                }

                await send(.storeKit(.fetchProduct))
            }

        case .openSheetLogin:
            return .none

        case .isUploadingImage:
            return .none

        case .isImagePicker(isPresented: let isPresented):
            state.imagePicker = isPresented
            ? ImagePickerReducer.State(showingImagePicker: true)
            : nil

            return .none

        case .uploadAvatar:
            state.isUploadingImage = true
            return .none

        // MARK: - .createAttachment
        case .createAttachment(let attachment):
            guard let id = state.user?.id else {
                return .none
            }

            return .run { send in
                do {
                    let result = try await apiClient.request(
                        for: .authEngine(.users(.user(id: id, route: .attachments(.create(input: attachment))))),
                        as: AttachmentInOutPut.self,
                        decoder: .iso8601
                    )
                    await send(.attachmentResponse(result))
                } catch {
                    sharedLogger.logError(error)
                    await send(.attachmentFailed)
                }
            }

        case .imageUploadSuccess(let imageURL):
            state.isUploadingImage = false
            switch state.imageFor {
            case .logo:
                state.vCard.imageURLs.removeAll { $0.type == .logo || $0.type == .icon }
                state.vCard.imageURLs.append(.init(type: .logo, urlString: imageURL))
                state.vCard.imageURLs.append(.init(type: .icon, urlString: imageURL))
            case .avatar:
                state.vCard.imageURLs.removeAll { $0.type == .thumbnail }
                state.vCard.imageURLs.append(.init(type: .thumbnail, urlString: imageURL))
            case .card:
                break
            }
            sharedLogger.log(imageURL)
            return .none

        case .imageUploadFailed:
            state.isUploadingImage = false
            state.alert = AlertState { TextState(L("Error")) } message: { TextState(L("Unable to upload image please try again!")) }
            return .none

        case let .imagePicker(.presented(.imagePicked(image: rawImage))):
            state.isUploadingImage = true
            state.imagePicker = nil

            // Downsample to max 1024px to reduce memory pressure
            let image = Self.downsample(rawImage, maxDimension: 1024)

            switch state.imageFor {
            case .logo:
                state.logoImage = image
                guard let currentUserID = state.user?.id else {
                    state.isUploadingImage = false
                    state.alert = AlertState { TextState(L("Error")) } message: { TextState(L("Please login 1st!")) }
                    return .none
                }

                return .run { [serialNumber = state.pass.serialNumber] send in
                    do {
                        let url = try await attachmentS3Client.uploadImageToS3(
                            image, .init(
                                passId: serialNumber,
                                compressionQuality: .lowest,
                                type: .png,
                                passImagesType: .logo,
                                userId: currentUserID.hexString
                            )
                        )
                        await send(.imageUploadSuccess(url))
                    } catch {
                        sharedLogger.logError(error)
                        await send(.imageUploadFailed)
                    }
                }

            case .avatar:
                state.avatarImage = image
                guard let currentUserID = state.user?.id else {
                    state.isUploadingImage = false
                    state.alert = AlertState { TextState(L("Error")) } message: { TextState(L("Please login 1st!")) }
                    return .none
                }

                return .run { [serialNumber = state.pass.serialNumber] send in
                    do {
                        let url = try await attachmentS3Client.uploadImageToS3(
                            image, .init(
                                passId: serialNumber,
                                compressionQuality: .lowest,
                                type: .png,
                                passImagesType: .thumbnail,
                                userId: currentUserID.hexString
                            )
                        )
                        await send(.imageUploadSuccess(url))
                    } catch {
                        sharedLogger.logError(error)
                        await send(.imageUploadFailed)
                    }
                }

            case .card:
                state.cardImage = image
                return .run { [imageFor = state.imageFor, cardImage = state.cardImage] send in
                    guard imageFor == .card, let cardImage else { return }
                    let vnRecognizeResponse = try await vnRecognizeClient.recognizeTextRequest(cardImage)
                    await send(.recognizeText(vnRecognizeResponse))
                }
            }

        // MARK: - .imagePicker
        case .imagePicker(.dismiss):
            state.imagePicker = nil
            return .none

        case .imagePicker(.presented(.picked(result: .failure))):
            // User cancelled or image load failed — dismiss picker
            state.imagePicker = nil
            return .none

        case .imagePicker:
            return .none

        case .attachmentResponse:
            state.isUploadingImage = false
            return .none

        case .attachmentFailed:
            state.isUploadingImage = false
            return .none

        case .imageFor(let type):
            state.imageFor = type
            return .none

        case .recognizeText(let response):

            switch response.textType {
            case .plain:
                let vCard = textToVcard(from: response)
                state.vCard = vCard
            case .vcard:
                let vCard = textToVcard(from: response)
                state.vCard = vCard
            }

            return .none

        // MARK: - CreatePass
        case .createPass:
            sharedLogger.log("create pass tapped")

            if !state.isAuthorized {
                return .run { send in
                    await send(.openSheetLogin(true))
                }
            }

            // Refresh user from keychain if available, but don't abort
            // — state.user is already set by the parent (WalletPassList)
            if let freshUser = try? self.keychainClient.readCodable(.user, self.build.identifier(), UserOutput.self) {
                state.user = freshUser
            }

            guard let currentUserID = state.user?.id else {
                state.alert = AlertState { TextState(L("Error")) } message: { TextState(L("Please log in to create a card.")) }
                return .none
            }

            if !state.isFormValid {
                sharedLogger.log("FormValid is not valid")
                return .none
            }

            // Prevent double-tap: disable button immediately
            state.isActivityIndicatorVisible = true

            // Use default images only when no URL was uploaded
            if !state.vCard.imageURLs.contains(where: { $0.type == .logo }) {
                state.vCard.imageURLs.append(.init(type: .logo, urlString: "https://ecardify.ams3.cdn.digitaloceanspaces.com/default/logo_d.png"))
                state.vCard.imageURLs.append(.init(type: .icon, urlString: "https://ecardify.ams3.cdn.digitaloceanspaces.com/default/logo_d.png"))
            }

            if !state.vCard.imageURLs.contains(where: { $0.type == .thumbnail }) {
                state.vCard.imageURLs.append(.init(type: .thumbnail, urlString: "https://ecardify.ams3.cdn.digitaloceanspaces.com/default/avatar_d.png"))
            }

            let walletPass = WalletPass(
                _id: .init(),
                ownerId: currentUserID,
                vCard: state.vCard,
                colorPalette: state.colorPalette
            )

            state.walletPass = walletPass

            // Free Tier: first card with basic templates is free
            // Note: hasUsedFreeCard is set in .passResponse AFTER server confirms,
            // so the UI keeps showing "Create Your Free Card" with a spinner
            // instead of flipping to the payment button prematurely.
            if state.isEligibleForFreeCard && state.storeKitState.type == .basic {
                state.walletPass?.isPaid = true
                guard let wp = state.walletPass else { return .none }
                return .run { send in
                    do {
                        try await localDatabase.create(wp: wp)
                        await send(.saveToServer)
                    } catch {
                        sharedLogger.logError("create localdatabase error:- \(error.localizedDescription)")
                        await send(.passResponseFailed(reason: "Failed to save card locally. Please try again."))
                    }
                }
            }

            return .run { send in
                await send(.buyProduct)
            }

        case .buyProduct:

            let product: StoreKitClient.Product

            switch state.storeKitState.type {
            case .basic:
                guard let basicProduct = state.storeKitState.products.first else {
                    return .none
                }
                product = basicProduct
            case .custom:
                guard let customProduct = state.storeKitState.products.last else {
                    return .none
                }
                product = customProduct
            }

            return .run { send in
                await send(.storeKit(.tappedProduct(product)))
            }

        case .storeKit(.buySuccess):

            state.walletPass?.isPaid = true
            guard let wp = state.walletPass
            else {
                return .none
            }
            /// draff cvard make it empty again
            return .run { send in
                do {
                    try await localDatabase.create(wp: wp)
                    await send(.saveToServer)
                } catch {
                    sharedLogger.logError("create localdatabase error:- \(error.localizedDescription)")
                }
            }

        case .saveToServer:
            guard let wp = state.walletPass else {
                return .none
            }

            state.isActivityIndicatorVisible = true

            return .run { send in
                // Attempt 1: make API call
                do {
                    let response = try await apiClient.request(
                        for: .walletPasses(.create(input: wp)),
                        as: WalletPassResponse.self
                    )
                    await send(.passResponse(response))
                    return
                } catch let firstError {
                    // Only retry on 401 (unauthorized/expired token).
                    // 403 can mean permission denied (e.g., ownerId mismatch) — not an auth error.
                    guard case APIError.serviceError(let code, _) = firstError,
                          code == 401 else {
                        sharedLogger.logError("passResponse error:- \(firstError)")
                        let reason: String
                        if let urlError = firstError as? URLError {
                            switch urlError.code {
                            case .notConnectedToInternet, .networkConnectionLost:
                                reason = "No internet connection."
                            case .cannotConnectToHost:
                                reason = "Cannot connect to server."
                            case .timedOut:
                                reason = "Request timed out."
                            default:
                                reason = "Network error."
                            }
                        } else if case APIError.serviceError(let serverCode, _) = firstError {
                            reason = "Server error (\(serverCode))."
                        } else {
                            reason = "Server error."
                        }
                        await send(.passResponseFailed(reason: reason))
                        return
                    }

                    // Auth error (401) — try silent token refresh
                    sharedLogger.log("Auth error (\(code)) — attempting silent token refresh")

                    guard let tokens = try? keychainClient.readCodable(
                        .token, build.identifier(), RefreshTokenResponse.self
                    ) else {
                        sharedLogger.logError("No refresh token available — need login")
                        await send(.passResponseFailed(reason: "AUTH_ERROR"))
                        return
                    }

                    do {
                        let refreshResponse = try await neuAuthClient.refreshToken(
                            NeuAuthRefreshRequest(refreshToken: tokens.refreshToken)
                        )
                        let loginRes = refreshResponse.toSuccessfulLoginResponse()
                        guard let newTokens = loginRes.access,
                              let newUser = loginRes.user else {
                            await send(.passResponseFailed(reason: "AUTH_ERROR"))
                            return
                        }
                        // Save fresh tokens to keychain
                        try await keychainClient.saveOrUpdateCodable(
                            newTokens, .token, build.identifier()
                        )
                        try await keychainClient.saveOrUpdateCodable(
                            newUser, .user, build.identifier()
                        )
                        sharedLogger.log("Token refreshed silently — retrying save")

                        // Attempt 2: retry with fresh token
                        do {
                            let retryResponse = try await apiClient.request(
                                for: .walletPasses(.create(input: wp)),
                                as: WalletPassResponse.self
                            )
                            await send(.passResponse(retryResponse))
                        } catch {
                            // Retry failed — report the actual server error, not "AUTH_ERROR"
                            sharedLogger.logError("Retry after refresh failed: \(error)")
                            await send(.passResponseFailed(reason: "Server error after retry."))
                        }
                    } catch {
                        // Token refresh itself failed — session is truly dead
                        sharedLogger.logError("Token refresh failed: \(error)")
                        await send(.passResponseFailed(reason: "AUTH_ERROR"))
                    }
                }
            }

        case .passResponse(let response):

            state.isActivityIndicatorVisible = false

            // Mark free card as used only AFTER server confirms success.
            // This prevents the UI from flipping to the payment button
            // while the API call is still in progress.
            if state.isEligibleForFreeCard {
                state.$hasUsedFreeCard.withLock { $0 = true }
            }

            guard
                let wp = state.walletPass
            else {
                return .none
            }

            return .run { [localDatabase] send in

                do {
                    try await localDatabase.update(wp: wp)
                } catch {
                    sharedLogger.logError("create local database error:- \(error)")
                }

                // Review prompt: trigger on 2nd card created
                #if os(iOS)
                if let cards = try? await localDatabase.find(), cards.count == 2 {
                    await MainActor.run {
                        if let scene = UIApplication.shared.connectedScenes
                            .compactMap({ $0 as? UIWindowScene })
                            .first(where: { $0.activationState == .foregroundActive }) {
                            SKStoreReviewController.requestReview(in: scene)
                        }
                    }
                }
                #endif

                await send(.buildPKPassFrom(url: response.urlString))
                await self.dismiss()

            }

        case .passResponseFailed(let reason):
            state.isActivityIndicatorVisible = false

            // Auth error (401/403): token expired or missing — need re-login
            if reason == "AUTH_ERROR" {
                state.alert = AlertState {
                    TextState(L("Session Expired"))
                } actions: {
                    ButtonState(role: .cancel) {
                        TextState(L("OK"))
                    }
                    ButtonState(action: .loginAndRetry) {
                        TextState(L("Login & Retry"))
                    }
                } message: {
                    TextState(L("Your session has expired. Please login again to save your card. Your card is saved locally and will not be lost."))
                }
                return .none
            }

            // Other errors: network, server, etc.
            let message = reason.isEmpty
                ? L("Failed to save your card. Please try again.")
                : L("Failed to save your card.") + " " + reason
            state.alert = AlertState {
                TextState(L("Error"))
            } actions: {
                ButtonState(role: .cancel) {
                    TextState(L("OK"))
                }
                ButtonState(action: .retrySave) {
                    TextState(L("Retry"))
                }
            } message: {
                TextState(message)
            }
            return .none

        case .buildPKPassFrom:
            return .none

        case .storeKit:
            return .none

        case .dismissView:

            return .none
        case .update(isAuthorized: let bool):
            state.$isAuthorized.withLock { $0 = bool }

            // Auto-retry server save after re-login (e.g. after 401/403 during save)
            if bool && state.pendingSave {
                state.pendingSave = false
                // Refresh user from keychain after fresh login
                if let freshUser = try? self.keychainClient.readCodable(.user, self.build.identifier(), UserOutput.self) {
                    state.user = freshUser
                }
                return .run { send in
                    await send(.saveToServer)
                }
            }

            return .none

        case .addOneMoreEmailSection:
            let email = VCard.Email(text: "")
            state.vCard.emails.append(email)

            return .none

        case .removeEmailSection(by: let uuid):

            guard let index = state.vCard.emails.firstIndex(where: { $0.id == uuid }) else { return .none }
            state.vCard.emails.remove(at: index)
            return .none

        case .addOneMoreTelephoneSection:
            let telephone = VCard.Telephone.init(type: .cell, number: "")
            state.vCard.telephones.append(telephone)
            return .none
            
        case .removeTelephoneSection(by: let uuid):
            guard let index = state.vCard.telephones.firstIndex(where: { $0.id == uuid }) else { return .none }
            state.vCard.telephones.remove(at: index)
            return .none

        case .addOneMoreAddressSection:
            state.vCard.addresses.append(.init(type: .parcel, postOfficeAddress: "", extendedAddress: nil, street: "", locality: "", region: nil, postalCode: "", country: ""))

            return .none
        case .removeAddressSection(by: let uuid):
            guard let index = state.vCard.addresses.firstIndex(where: { $0.id == uuid }) else { return .none }
            state.vCard.addresses.remove(at: index)
            return .none

        // MARK: - DigitalCardDesign
        case .digitalCardDesign(.dismiss):

            state.colorPalette = state.digitalCardDesign?.selectedColorPalette ?? .default

            return .none

        case .digitalCardDesign:
            return .none

        case .dcdSheetIsPresentedButtonTapped:
            state.digitalCardDesign = .init(vCard: state.vCard)
            return .none

        }
    }

    func textToVcard(from vnRecognizeResponse: VNRecognizeResponse) -> VCard {
        var vCard = VCard(
            contact: VCard.Contact.empty,
            formattedName: "",
            organization: nil,
            position: "",
            website: "",
            socialMedia: .empty
        )
        var vCardAddress = VCard.Address(
            type: .work,
            postOfficeAddress: nil,
            extendedAddress: nil,
            street: "",
            locality: "",
            region: nil,
            postalCode: "",
            country: ""
        )

        switch vnRecognizeResponse.textType {

        case .plain:

            if let stringValue = vnRecognizeResponse.string {


                let detector = NSDataDetector(types: .all)

                detector.enumerateMatches(in: stringValue) { result, matchingFlags, bool  in

                    switch result?.type {
                    case let .url(url):

                        if !vCard.urls.contains(url) {
                            vCard.urls.append(url)
                            vCard.website = url.absoluteString
                        }

                        vCard.website = url.absoluteString


                    case let .email(email: emails, url: _):

                        let components = emails.split(separator: ":", maxSplits: 1)

                        if components.count == 1 {
                            let propertyValue = String(components[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                            vCard.emails.append(.init(text: propertyValue))

                        } else {
                            _ = emails.components(separatedBy: " ").map {
                                vCard.emails.append(.init(text: $0))
                            }
                        }


                    case let .phoneNumber(number):

                        let cleanedNumber = number.replacingOccurrences(of: " ", with: "")
                            .replacingOccurrences(of: "(", with: "")
                            .replacingOccurrences(of: ")", with: "")


                        vCard.telephones.append(.init(type: .work, number: cleanedNumber))
                    case let .address(components: addressComponents):

                        if let street = addressComponents[.street] {
                            vCardAddress.street = street
                        }

                        if let postalCode = addressComponents[.zip] {
                            vCardAddress.postalCode = postalCode
                        }

                        if let state = addressComponents[.state] {
                            vCardAddress.region = state
                        }

                        if let city = addressComponents[.city] {
                            vCardAddress.locality = city
                        }

                        if let country = addressComponents[.country] {
                            vCardAddress.country = country
                        }

                        vCard.addresses.append(vCardAddress)

                    case .date:
                        break
                    case .none:
                        sharedLogger.log("NONE")
                    }
                }
            }

        case .vcard:
            if let stringValue = vnRecognizeResponse.string,
               let vCardRes = VCard.create(from: stringValue)
            {
                vCard = vCardRes

            }
        }

        return vCard
    }

    /// Downsamples a UIImage so its longest edge is at most `maxDimension` points.
    /// Prevents retaining multi-megabyte originals from the photo library.
    private static func downsample(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard max(size.width, size.height) > maxDimension else { return image }
        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
