import BSON
import SwiftUI
import APIClient
import LoggerKit
import Foundation
import ImagePicker

import ECSharedModels
import SettingsFeature
import VNRecognizeFeature
import AttachmentS3Client
import UserDefaultsClient
import ComposableStoreKit
import LocalDatabaseClient
import FoundationExtension
import ComposableArchitecture

extension String: Identifiable {
    public typealias ID = Int
    public var id: Int {
        return hash
    }
}

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
            isAuthorized: Bool = true,
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
            self.isAuthorized = isAuthorized
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
        public var isAuthorized: Bool = true
        public var user: UserOutput? = nil
        public var walletPass: WalletPass? = nil
        public var bottomID: Int = 9
        public var isCustomProduct: Bool {
            return storeKitState.type == .basic ? false : true
        }

    }

    @CasePathable
    public enum Action: BindableAction, Equatable {
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
        case imageUploadResponse(TaskResult<String>)
        case attachmentResponse(TaskResult<AttachmentInOutPut>)
        case imageFor(ImageFor)
        case recognizeText(VNRecognizeResponse)
        case createPass
        case buildPKPassFrom(url: String)
        case passResponse(TaskResult<WalletPassResponse>)
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

    }

    public enum AlertAction: Equatable {}

    public init() {}

    @Dependency(\.build) var build
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.userDefaults) var userDefaults
    @Dependency(\.keychainClient) var keychainClient
    @Dependency(\.vnRecognizeClient) var vnRecognizeClient
    @Dependency(\.attachmentS3Client) var attachmentS3Client
    @Dependency(\.localDatabase) var localDatabase
    @Dependency(\.dismiss) var dismiss

    public var body: some Reducer<State, Action> {

        BindingReducer()

        Scope(state: \.storeKitState, action: /Action.storeKit) {
            StoreKitReducer()
        }

        Reduce(self.core)
            .ifLet(\.$imagePicker, action: /Action.imagePicker) {
                ImagePickerReducer()
            }
            .ifLet(\.$digitalCardDesign, action: /Action.digitalCardDesign) {
                CardDesignListReducer()
            }
    }

    func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {

        case .binding(\.vCard):

            let emailValidationCheck = state.vCard.emails.count == state.vCard.emails.filter({ $0.text.isEmailValid == true }).count
            let imageMoreThenThree = state.vCard.imageURLs.count >= 1
            state.isFormValid = state.vCard.isVCardValid && emailValidationCheck && imageMoreThenThree

            sharedLogger.logError("isVCardValid: \(state.vCard.isVCardValid) emailValidationCheck:\(emailValidationCheck) imageMoreThenThree:\(imageMoreThenThree)")

            return .none

        case .binding:
            return .none

        case .alert:
            return .none
            // MARK: - .onAppear
        case .onAppear:

            state.isAuthorized = userDefaults.boolForKey(UserDefaultKey.isAuthorized.rawValue)

            do {
                state.user = try self.keychainClient.readCodable(.user, self.build.identifier(), UserOutput.self)
            } catch { }

//            if TARGET_OS_SIMULATOR == 1 {
//                state.vCard.imageURLs = ImageURL.draff
//            }

            return .run { send in
                await send(.storeKit(.fetchProduct))
            }

        case .openSheetLogin:
            return .none

        case .isUploadingImage:
            return .none

        case .isImagePicker(isPresented: let isPresented):
            state.imagePicker = isPresented
            ? ImagePickerReducer.State(showingImagePicker: true, selectType: .single)
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

            return .run { [imageFor = state.imageFor] send in
                    await send(.attachmentResponse(
                        await TaskResult {

//                            if TARGET_OS_SIMULATOR == 1 {
//                                if imageFor == .avatar {
//                                    return AttachmentInOutPut.thumbnail
//                                }
//
//                                if imageFor == .logo {
//                                    return AttachmentInOutPut.logo
//                                }
//                            }

                            return try await apiClient.request(
                                for: .authEngine(.users(.user(id: id, route: .attachments(.create(input: attachment))))),
                                as: AttachmentInOutPut.self,
                                decoder: .iso8601
                            )
                        }
                    )
                    )
            }

        case .imageUploadResponse(.success(let imageURL)):
            switch state.imageFor {
            case .logo:
                state.vCard.imageURLs.append(.init(type: .logo, urlString: imageURL))
                state.vCard.imageURLs.append(.init(type: .icon, urlString: imageURL))
            case .avatar:
                sharedLogger.log(imageURL)
                state.vCard.imageURLs.append(.init(type: .thumbnail, urlString: imageURL))
            case .card:
                sharedLogger.log(imageURL)
            }

            sharedLogger.log(imageURL)

            return .none
            
        case .imageUploadResponse(.failure(let error)):
                state.alert = AlertState { TextState("Unable to upload image please try again!") }
            sharedLogger.logError(error)
            return .none

        case let .imagePicker(.presented(.picked(result: image))):
            state.isUploadingImage = true
            state.imagePicker = nil

            switch state.imageFor {
            case .logo:
                state.logoImage = image
                guard let currentUserID = state.user?.id else {
                    return .none
                }

                return .run { [serialNumber = state.pass.serialNumber] send in
                    await send(.imageUploadResponse(
                        TaskResult {
//                            if TARGET_OS_SIMULATOR == 1 {
//                                return "https://learnplaygrow.ams3.digitaloceanspaces.com/uploads/images/9155F894-E500-453A-A691-6CDE8F722BDF/CECF3925-180E-4373-A15E-E7876760D18F/logo.png"
//
//                            }

                            return try await attachmentS3Client.uploadImageToS3(
                                image, .init(
                                    passId: serialNumber,
                                    compressionQuality: .lowest,
                                    type: .png,
                                    passImagesType: .logo,
                                    userId: currentUserID.hexString
                                )
                            )
                        }
                    ))
                }

            case .avatar:
                state.avatarImage = image
                guard let currentUserID = state.user?.id else {
                    state.alert = AlertState { TextState("Please login 1st!") }
                    return .none
                }

                return .run { [serialNumber = state.pass.serialNumber]  send in
                    await send(.imageUploadResponse(
                        TaskResult {
//                            if TARGET_OS_SIMULATOR == 1 {
//                                return "https://learnplaygrow.ams3.digitaloceanspaces.com/uploads/images/DC6E2827-FF38-4038-A3BB-6F2C40695EC5/CECF3925-180E-4373-A15E-E7876760D18F/thumbnail.png"
//                            }

                            return try await attachmentS3Client.uploadImageToS3(
                                image, .init(
                                    passId: serialNumber,
                                    compressionQuality: .lowest,
                                    type: .png,
                                    passImagesType: .thumbnail,
                                    userId: currentUserID.hexString
                                )
                            )
                        }
                    ))
                }

            case .card:
                state.cardImage = image
                return .run { [imageFor = state.imageFor, cardImage = state.cardImage] send in
                    if imageFor == .card {
                        let vnRecognizeResponse = try await vnRecognizeClient.recognizeTextRequest(cardImage!)
                        await send(.recognizeText(vnRecognizeResponse))
                    }
                }
            }

        // MARK: - .imagePicker
        case .imagePicker:
            return .none

        case .attachmentResponse(.success(let attachmentResponse)):
            state.isUploadingImage = false

            switch state.imageFor {
            case .logo:
                //if let image = attachmentResponse.imageUrlString {
                    // state.imageURLs.insert(image, at: 0)
                //}
                return .none
            case .avatar:
                //if let image = attachmentResponse.imageUrlString {
//                     state.imageURLs.insert(image, at: 0)
                //}
                return .none
            case .card:
                return .none
            }


        case .attachmentResponse(.failure(let error)):
            sharedLogger.logError(error)
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

            do {
                state.user = try self.keychainClient.readCodable(.user, self.build.identifier(), UserOutput.self)
            } catch {
                //state.alert = .init(title: TextState("Missing you id! please login again!"))
                sharedLogger.logError("Missing Current user!")
                return .none
            }

            guard let currentUserID = state.user?.id else {
                sharedLogger.logError("Missing you id! please login again!")
                return .none
            }

            if !state.isFormValid {
                sharedLogger.log("FormValid is not valid")
                return .none
            }

            let walletPass = WalletPass(
                _id: .init(),
                ownerId: currentUserID,
                vCard: state.vCard,
                colorPalette: state.colorPalette
            )

            state.walletPass = walletPass

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
            /// draff cvard make it empty again
            guard let wp = state.walletPass else {
                return .none
            }

            state.isActivityIndicatorVisible = true

            return .run { send in
               await send(.passResponse(
                    await TaskResult {
                        try await apiClient.request(
                            for: .walletPasses(.create(input: wp)),
                            as: WalletPassResponse.self
                        )
                    }
                ))
            }

        case .passResponse(.success(let response)):

            state.isActivityIndicatorVisible = false
            guard
                let wp = state.walletPass
            else {
                return .none
            }

            return .run { send in

                do {
                    try await localDatabase.update(wp: wp)
                } catch {
                    sharedLogger.logError("create localdatabase error:- \(error)")
                }

                await send(.buildPKPassFrom(url: response.urlString))
                await self.dismiss()

            }

        case .passResponse(.failure(let error)):
            state.isActivityIndicatorVisible = false
                sharedLogger.logError("passResponse error:- \(error)")
            return .none

        case .buildPKPassFrom:
            return .none

        case .storeKit:
            return .none

        case .dismissView:

            return .none
        case .update(isAuthorized: let bool):
            state.isAuthorized = bool
            return .none

        case .addOneMoreEmailSection:
            let email = VCard.Email(text: "")
            state.vCard.emails.append(email)

            return .none

        case .removeEmailSection(by: let uuid):
            state.vCard.emails.removeAll(where: { $0.id == uuid })
            return .none

        case .addOneMoreTelephoneSection:
            let telephone = VCard.Telephone.init(type: .cell, number: "")
            state.vCard.telephones.append(telephone)
            return .none
            
        case .removeTelephoneSection(by: let uuid):
            state.vCard.telephones.removeAll(where: { $0.id == uuid })
            return .none

        case .addOneMoreAddressSection:
            state.vCard.addresses.append(.init(type: .parcel, postOfficeAddress: "", extendedAddress: nil, street: "", locality: "", region: nil, postalCode: "", country: ""))

            return .none
        case .removeAddressSection(by: let uuid):
            state.vCard.addresses.removeAll(where: { $0.id == uuid })
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
            postOfficeAddress: "nil",
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

                    case let .date(date):
                        print(date)
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
}
