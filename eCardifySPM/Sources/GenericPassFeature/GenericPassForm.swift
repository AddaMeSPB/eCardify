import BSON
import SwiftUI
import APIClient
import Foundation
import ImagePicker
import ECardifySharedModels
import ComposableArchitecture
import VNRecognizeFeature
import AttachmentS3Client
import UserDefaultsClient
import ComposableStoreKit
import LocalDatabaseClient

extension String: Identifiable {
    public typealias ID = Int
    public var id: Int {
        return hash
    }
}

public struct GenericPassForm: ReducerProtocol {
    public enum ImageFor: String, Equatable {
        case logo, avatar, card
    }

    public struct State: Equatable {
        public init(
            isActivityIndicatorVisible: Bool = false,
            storeKitState: StoreKitReducer.State = .init(),
            isUploadingImage: Bool = false,
            logoImage: UIImage? = nil,
            avartarImage: UIImage? = nil,
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
            self.avartarImage = avartarImage
            self.cardImage = cardImage
            self.imageFor = imageFor
            self.isFormValid = isFormValid
            self.isAuthorized = isAuthorized
            self.user = user
            self.vCard = vCard
            self.telephone = telephone
            self.email = email
        }


        @BindingState public var vCard: VCard
        @BindingState public var telephone: VCard.Telephone
        @BindingState public var email: String
        @BindingState public var storeKitState: StoreKitReducer.State
        @PresentationState public var imagePicker: ImagePickerReducer.State?

        public var pass: Pass = .draff
        public var isActivityIndicatorVisible = false
        public var isUploadingImage: Bool = false
        public var logoImage: UIImage?
        public var avartarImage: UIImage?
        public var cardImage: UIImage?
        public var imageFor: ImageFor = .avatar
        public var isFormValid: Bool = false
        public var isAuthorized: Bool = true
        public var user: UserOutput? = nil
        public var walletPass: WalletPass? = nil
        public var bottomID = 9

        public var isCustomProduct: Bool {
            self.storeKitState.type == .custom
        }

    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case imagePicker(PresentationAction<ImagePickerReducer.Action>)
        case onAppear
        case isUploadingImage
        case isImagePicker(isPresented: Bool)
        case uploadAvatar(_ image: UIImage)
        case createAttachment(_ attachment: AttachmentInOutPut)
        case imageUploadResponse(TaskResult<String>)
        case attacmentResponse(TaskResult<AttachmentInOutPut>)
        case imageFor(ImageFor)
        case recognizeText(VCard?)
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

    public init() {}

    @Dependency(\.build) var build
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.userDefaults) var userDefaults
    @Dependency(\.keychainClient) var keychainClient
    @Dependency(\.vnRecognizeClient) var vnRecognizeClient
    @Dependency(\.attachmentS3Client) var attachmentS3Client
    @Dependency(\.localDatabase) var localDatabase
    @Dependency(\.dismiss) var dismass

    public var body: some ReducerProtocol<State, Action> {

        BindingReducer()

        Scope(state: \.storeKitState, action: /Action.storeKit) {
            StoreKitReducer()
        }

        Reduce(self.core)
            .ifLet(\.$imagePicker, action: /Action.imagePicker) {
                ImagePickerReducer()
            }
    }

    func core(state: inout State, action: Action) -> EffectTask<Action> {
        switch action {

        case .binding(\.$vCard):

            state.isFormValid = state.vCard.isVCardValid &&
            state.vCard.emails.count ==  state.vCard.emails.filter({ $0.text.isEmailValid == true }).count &&
            state.vCard.imageURLs.count >= 3

            return .none

        case .binding:
            return .none

            // MARK: - .onAppear
        case .onAppear:

            state.isAuthorized = userDefaults.boolForKey(UserDefaultKey.isAuthorized.rawValue)

            do {
                state.user = try self.keychainClient.readCodable(.user, self.build.identifier(), UserOutput.self)
            } catch { }

            if TARGET_OS_SIMULATOR == 1 {
                state.vCard.imageURLs = ImageURL.draff
                state.isFormValid = true
            }

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

            return .task { [imageFor = state.imageFor] in
                    .attacmentResponse(
                        await TaskResult {

                            if TARGET_OS_SIMULATOR == 1 {
                                if imageFor == .avatar {
                                    return AttachmentInOutPut.thumbnail
                                }

                                if imageFor == .logo {
                                    return AttachmentInOutPut.logo
                                }
                            }

                            return try await apiClient.request(
                                for: .authEngine(.users(.user(id: id, route: .attachments(.create(input: attachment))))),
                                as: AttachmentInOutPut.self,
                                decoder: .iso8601
                            )
                        }
                    )
            }

        case .imageUploadResponse(.success(let imageURL)):
            switch state.imageFor {
            case .logo:
                print(#line, imageURL)
                state.vCard.imageURLs.append(.init(type: .logo, urlString: imageURL))
                state.vCard.imageURLs.append(.init(type: .icon, urlString: imageURL))
            case .avatar:
                print(#line, imageURL)
                state.vCard.imageURLs.append(.init(type: .thumbnail, urlString: imageURL))
            case .card:
                print(#line, imageURL)
            }

            return .none
            
        case .imageUploadResponse(.failure(let error)):
            print(#line, error.localizedDescription)
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

                return .task { [serialNumber = state.pass.serialNumber] in
                    await .imageUploadResponse(
                        TaskResult {
                            if TARGET_OS_SIMULATOR == 1 {
                                return "https://learnplaygrow.ams3.digitaloceanspaces.com/uploads/images/9155F894-E500-453A-A691-6CDE8F722BDF/CECF3925-180E-4373-A15E-E7876760D18F/logo.png"

                            }

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
                    )
                }

            case .avatar:
                state.avartarImage = image
                guard let currentUserID = state.user?.id else {
                    return .none
                }

                return .task { [serialNumber = state.pass.serialNumber] in
                    await .imageUploadResponse(
                        TaskResult {
                            if TARGET_OS_SIMULATOR == 1 {
                                return "https://learnplaygrow.ams3.digitaloceanspaces.com/uploads/images/DC6E2827-FF38-4038-A3BB-6F2C40695EC5/CECF3925-180E-4373-A15E-E7876760D18F/thumbnail.png"
                            }

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
                    )
                }

            case .card:
                state.cardImage = image
                return .run { [imageFor = state.imageFor, cardImage = state.cardImage] send in
                    if imageFor == .card {
                        let text = try await vnRecognizeClient.recognizeTextRequest(cardImage!)
                        await send(.recognizeText(text))
                    }
                }
            }

            // MARK: - .imagePicker
        case .imagePicker:
            return .none

        case .attacmentResponse(.success(let attachmentResponse)):
            state.isUploadingImage = false

            switch state.imageFor {
            case .logo:
                if let image = attachmentResponse.imageUrlString {
                    // state.imageURLs.insert(image, at: 0)
                }
                return .none
            case .avatar:
                if let image = attachmentResponse.imageUrlString {
                    // state.imageURLs.insert(image, at: 0)
                }
                return .none
            case .card:
                return .none
            }


        case .attacmentResponse(.failure(let error)):
            return .none

        case .imageFor(let type):
            state.imageFor = type
            return .none

        case .recognizeText(let vcard):

            //            if let vcard = vcard {
            //
            //                if let indexName = state.passContentState!.fields
            //                    .firstIndex(where: {$0.fieldType == .primary && $0.field.key == "member" } )  {
            //                    state.passContentState!.fields[indexName].field.value = vcard.contact.fullName
            //                }
            //
            //                if let indexPosition = state.passContentState!.fields
            //                    .firstIndex(where: {$0.fieldType == .secondary && $0.field.key == "position" } )  {
            //                    state.passContentState!.fields[indexPosition].field.value = vcard.position ?? ""
            //                }
            //
            //            }
            //
            //            if let string = vcard?.vCardRepresentation {
            //
            //                if let indexMobiles = state.passContentState!.fields
            //                    .firstIndex(where: {$0.fieldType == .auxiliary && $0.field.key == "mobile" } ),
            //
            //                    let indexEmails = state.passContentState!.fields
            //                    .firstIndex(where: {$0.fieldType == .auxiliary && $0.field.key == "email" } )
            //                {
            //                    let emailAddress = extractEmailAddrIn(text: string)
            //                    if let mobiles = try? string.findContactsNumber() {
            //                        state.passContentState!.fields[indexMobiles].field.value = mobiles.joined(separator: ", \n")
            //                    }
            //                    state.passContentState!.fields[indexEmails].field.value = emailAddress.joined(separator: ",")
            //                }
            //
            //            }

            return .none
        case .createPass:

            if !state.isAuthorized {
                return .run { send in
                    await send(.openSheetLogin(true))
                }
            }

            do {
                state.user = try self.keychainClient.readCodable(.user, self.build.identifier(), UserOutput.self)
            } catch {
                //state.alert = .init(title: TextState("Missing you id! please login again!"))
                return .none
            }

            guard let currentUserID = state.user?.id else {
                return .none
            }

            if !state.isFormValid {
                return .none
            }


            let primaryFieldName = state.vCard.contact.fullName.replacingOccurrences(of: " ", with: "\n").uppercased()
            let organizationName = state.vCard.organization == nil ? primaryFieldName : (state.vCard.organization ?? "")
            let secondaryFieldPosition = state.vCard.position

            var auxiliaryFields: [Field] = []
            for telephone in state.vCard.telephones {
                let item = Field.init(
                    label: telephone.type.rawValue.uppercased(),
                    key: telephone.type.rawValue.lowercased(),
                    value: telephone.number
                )
                auxiliaryFields.append(item)
            }

            for email in state.vCard.emails {
                let item = Field.init(
                    label: "EMAIL",
                    key: "email",
                    value: email.text
                )
                auxiliaryFields.append(item)
            }

            state.pass.organizationName = organizationName
            state.pass.description = organizationName
            state.pass.logoText = organizationName
            state.pass.generic = .init(
                primaryFields: [
                    .init(label: "NAME", key: "member", value: primaryFieldName)
                ],
                secondaryFields: [
                    .init(label: "POSITION", key: "position", value: secondaryFieldPosition)
                ],
                auxiliaryFields: auxiliaryFields,
                backFields: [
                    .init(label: "Spelled out", key: "numberStyle", value: "200")
                ]
            )

            let walletPass = WalletPass(
                _id: .init(),
                ownerId: currentUserID,
                pass: state.pass,
                imageURLs: state.vCard.imageURLs
            )

            state.walletPass = walletPass

            return .run { send in
                await send(.buyProduct)
            }

        case .buyProduct:

            let product: StoreKitClient.Product

            switch state.storeKitState.type {
            case .basic:
                guard let basicProduct = state.storeKitState.products.first
                else {
                    return .none
                }
                product = basicProduct
            case .custom:
                guard let customProduct = state.storeKitState.products.last
                else {
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
                    print("\(#line) create localdatabase error:- \(error.localizedDescription)")
                }
            }

        case .saveToServer:
            /// draff cvard make it empty again
            guard let wp = state.walletPass else {
                return .none
            }

            state.isActivityIndicatorVisible = true

            return .task {
                .passResponse(
                    await TaskResult {
                        try await apiClient.request(
                            for: .walletPasses(.create(input: wp)),
                            as: WalletPassResponse.self
                        )
                    }
                )
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
                    print("\(#line) create localdatabase error:- \(error.localizedDescription)")
                }

                await send(.buildPKPassFrom(url: response.urlString))
                await self.dismass()

            }

        case .passResponse(.failure):
            state.isActivityIndicatorVisible = false
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
        }
    }
}
