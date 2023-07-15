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

//passContentState: PassContentReducer.State? = .init(
//    passContent: .init(
//        primaryFields: [.init(key: "NAME")],
//        secondaryFields: [.init(key: "POSITION")],
//        auxiliaryFields: [.init(key: "MOBILE"), .init(key: "EMAIL")]
//    )
//),

public struct GenericPassForm: ReducerProtocol {
    public enum ImageFor: String, Equatable {
        case logo, avatar, card
    }

    public struct State: Equatable {
        public init(
            pass: Pass = .draff,
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
            vCard: VCard = .empty,
            telephone: VCard.Telephone = .empty,
            email: String = "",
            isFormPresented: Bool = false
        ) {
            self.pass = pass
            self.isActivityIndicatorVisible = isActivityIndicatorVisible
            self.storeKitState = storeKitState
            self.isUploadingImage = isUploadingImage
            self.logoImage = logoImage
            self.avartarImage = avartarImage
            self.cardImage = cardImage
            self.imageFor = imageFor
            self.imageURLS = imageURLS
            self.isFormValid = isFormValid
            self.isAuthorized = isAuthorized
            self.user = user
            self.vCard = vCard
            self.telephone = telephone
            self.email = email
            self.isFormPresented = isFormPresented
        }

        @BindingState public var pass: Pass
        @BindingState public var vCard: VCard
        @BindingState public var telephone: VCard.Telephone
        @BindingState public var email: String
        @BindingState public var storeKitState: StoreKitReducer.State
        @PresentationState public var imagePicker: ImagePickerReducer.State?

        public var isActivityIndicatorVisible = false
        public var isUploadingImage: Bool = false
        public var logoImage: UIImage?
        public var avartarImage: UIImage?
        public var cardImage: UIImage?
        public var imageFor: ImageFor = .avatar
        public var imageURLS: [ImageURL] = []
        public var isFormValid: Bool = false
        public var isAuthorized: Bool = true
        public var user: UserOutput? = nil
        public var isFormPresented: Bool  = false
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
        case removeEmailSection(at: Int)
        case addOneMoreTelephoneSection
        case removeTelephoneSection(at: Int)
        case addOneMoreAddressSection
        case removeAddressSection(at: Int)
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
            state.imageURLS.count >= 3

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
                state.imageURLS = ImageURL.draff
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
                state.imageURLS.append(.init(type: .logo, urlString: imageURL))
                state.imageURLS.append(.init(type: .icon, urlString: imageURL))
            case .avatar:
                print(#line, imageURL)
                state.imageURLS.append(.init(type: .thumbnail, urlString: imageURL))
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


//            if state.passContentState != nil {
//                for field in state.passContentState!.fields {
//                    switch field.fieldType {
//                    case .header:
//                        for idx in 0...state.passContentState!.passContent.headerFields!.count {
//                            state.passContentState!.passContent.headerFields![idx].value = field.field.value
//                        }
//
//                    case .primary:
//
//                        if let memberIdx = state.passContentState?.passContent
//                            .primaryFields
//                            .firstIndex(where: { $0.key == "member"})
//                        {
//                            //state.vCard.fullName = field.field.value
//                            state.passContentState!.passContent.primaryFields[memberIdx].value = field.field.value
//                        }
//
//                    case .secondary:
//
//                        if let positionIdx = state.passContentState?.passContent
//                            .secondaryFields?
//                            .firstIndex(where: { $0.key == "position"})
//                        {
//                            state.vCard.position = field.field.value
//                            state.passContentState!.passContent.secondaryFields![positionIdx].value = field.field.value
//                        }
//
//                    case .auxiliary:
//
//                        if let mobile = state.passContentState?
//                            .passContent
//                            .auxiliaryFields?
//                            .firstIndex(where: { $0.key == "mobile" && field.field.key == "mobile"})
//                        {
//                            //state.vCard.cellPhone = field.field.value
//                            state.passContentState!.passContent.auxiliaryFields![mobile].value = field.field.value
//                        }
//
//                        if let emailIdx = state.passContentState?
//                            .passContent
//                            .auxiliaryFields?
//                            .firstIndex(where: { $0.key == "email" && field.field.key == "email" })
//                        {
//                            //state.vCard.workEmail = field.field.value
//                            state.passContentState!.passContent.auxiliaryFields![emailIdx].value = field.field.value
//                        }
//
//                    case .back:
//                        for idx in 0..<state.passContentState!.passContent.backFields!.count {
//                            state.passContentState!.passContent.backFields![idx].value = field.field.value
//                        }
//                    }
//                }
//            }
//
//            state.pass.generic = state.passContentState?.passContent
//            _ = state.pass.generic?.primaryFields[0].value.replacingOccurrences(of: " ", with: "\n")

            /// have to debug why after scan code was not showing image
            //            if let imageURL = state.imageURLS.first(where: { $0.type == .thumbnail })?.urlString {
            //                state.vCard.imageURL = imageURL
            //            }

//            state.pass.barcodes = [
//                .init(message: state.vCard.vCardRepresentation, format: .qr)
//            ]
//
//            let walletPass = WalletPass(
//                _id: .init(),
//                ownerId: currentUserID,
//                pass: state.pass,
//                imageURLs: state.imageURLS
//            )
//
//            state.walletPass = walletPass

            // create Pass here

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

            return .run { send in
                do {
                    try await localDatabase.create(wp: wp)
                    await send(.saveToServer)
                } catch {
                    print("\(#line) create localdatabase error:- \(error.localizedDescription)")
                }
            }

        case .saveToServer:

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
        case .removeEmailSection(at: let index):
            state.vCard.emails.remove(at: index)
            return .none

        case .addOneMoreTelephoneSection:
            let telephone = VCard.Telephone.init(type: .cell, number: "")
            state.vCard.telephones.append(telephone)
            return .none
            
        case .removeTelephoneSection(at: let index):
            state.vCard.telephones.remove(at: index)
            return .none

        case .addOneMoreAddressSection:
            state.vCard.addresses.append(.init(type: .parcel, postOfficeAddress: "", extendedAddress: nil, street: "", locality: "", region: nil, postalCode: "", country: ""))

            return .none
        case .removeAddressSection:
//            state.vCard.addresses.remove(at: index)
            return .none
        }
    }
}

public struct GenericPassFormView: View {
    let store: StoreOf<GenericPassForm>

    struct ViewState: Equatable {

        @BindingViewState var pass: Pass
        @BindingViewState var vCard: VCard
        var avartarImage: UIImage?
        var cardImage: UIImage?
        var logoImage: UIImage?
        var isFormValid: Bool
        var isImagePickerPresented: Bool
        var isAuthorized: Bool
        var isActivityIndicatorVisible: Bool
        var storeKitState: StoreKitReducer.State
        var isFormPresented: Bool

        init(state: BindingViewStore<GenericPassForm.State>) {

            _pass = state.$pass
            _vCard = state.$vCard

            self.logoImage = state.logoImage
            self.avartarImage = state.avartarImage
            self.cardImage = state.cardImage

            self.isImagePickerPresented = state.imagePicker != nil
            self.isFormValid = state.imageURLS.count >= 3

            self.isAuthorized = state.isAuthorized
            self.isActivityIndicatorVisible = state.isActivityIndicatorVisible
            self.storeKitState = state.storeKitState
            self.isFormPresented = state.isFormPresented

        }

    }

    public init(store: StoreOf<GenericPassForm>) {
        self.store = store
    }

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    // MARK: - BODY
    public var body: some View {
        WithViewStore(self.store) { viewStore in
            GeometryReader { proxy in
                ScrollViewReader { value in
                    ZStack(alignment: .center) {
                        Form {

                            Section {
                                HStack {

                                    logoImagePicker(viewStore, proxy)

                                    TextField(
                                        "",
                                        text: viewStore.$pass.organizationName,
                                        prompt: Text("Organization Name")
                                            .font(.title2)
                                            .fontWeight(.medium)
                                    )
                                    .disableAutocorrection(true)
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .padding(.vertical, 10)
                                }
                                .frame(height: 50)

                                HStack {
                                    cardImagePicker(viewStore, proxy)

                                    avatarImagePicker(viewStore, proxy)
                                }

                            } header: {
                                Text("Uplod Images")
                                    .font(.title2)
                                    .fontWeight(.medium)
                            }

                            contactSectionView(viewStore)

                            telephonesSectionView(viewStore, value)

                            emailsSectionView(viewStore)

                            addressesSectionView(viewStore)

                            Group {
                                Picker("Choice product type 👉🏼", selection: viewStore.$storeKitState.type) {
                                    ForEach(StoreKitReducer.State.ProductType.allCases) { option in
                                        Text(option.rawValue.uppercased())
                                            .font(.title2)
                                            .fontWeight(.medium)
                                            .padding(.vertical, 10)
                                    }
                                }

                            }

                            HStack {

                                if let product = viewStore.storeKitState.product {
                                    VStack(alignment: .leading) {
                                        Text(product.localizedTitle)
                                            .font(.title2)
                                            .fontWeight(.medium)

                                        Text(product.localizedDescription)
                                            .font(.body)

                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)


                                    Spacer()

                                    Button {
                                        viewStore.send(.createPass)
                                    } label: {
                                        Text("Pay \(cost(product: product)) and Create")
                                            .font(.title2)
                                            .fontWeight(.medium)
                                            .padding(10)
                                    }
                                    .background(viewStore.isFormValid ? Color.blue : Color.red)
                                    .foregroundColor(viewStore.isFormValid ? Color.white : Color.white.opacity(0.3))
                                    .disabled(!viewStore.isFormValid)
                                    .cornerRadius(9)

                                } else {
                                    ProgressView()
                                        .tint(.blue)
                                        .scaleEffect(3)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }

                            }
                            .padding(.vertical, 20)
                            .id(viewStore.bottomID)

                        }
                        .navigationTitle("Create digital card 🪪!")
                        .redacted(reason: viewStore.isActivityIndicatorVisible ? .placeholder : .init())
                        .allowsHitTesting(!viewStore.isActivityIndicatorVisible)
                        .background(
                            viewStore.isActivityIndicatorVisible == true
                            ? Color.black.opacity(0.9)
                            : Color.white
                        )
                        .onAppear {
                            viewStore.send(.onAppear)
                        }
                        .sheet(
                            store: store.scope(
                                state: \.$imagePicker,
                                action: GenericPassForm.Action.imagePicker
                            ),
                            content: ImagePickerView.init(store:)
                        )

                        if viewStore.isActivityIndicatorVisible {
                            VStack {
                                ProgressView()
                                    .tint(.blue)
                                    .scaleEffect(4)
                                    .padding()
                                    .foregroundColor(Color.white)
                                Text("Generating your Digital card! Please wait")
                                    .font(.system(size: 23, weight: .bold, design: .rounded))
                                    .padding()
                                    .foregroundColor(Color.white)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - logoImagePicker
    fileprivate func logoImagePicker(_ viewStore: ViewStore<GenericPassForm.State, GenericPassForm.Action>, _ proxy: GeometryProxy) -> some View {
        Button {
            viewStore.send(.isImagePicker(isPresented: true))
            viewStore.send(.imageFor(.logo))
        } label: {
            if let logoImage = viewStore.logoImage {
                Image(uiImage: logoImage)
                    .resizable()
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .padding()
            } else {

                Image(
                    uiImage: (UIImage(named: "logo.jpg")
                              ?? UIImage(systemName: "infinity.circle"))!
                )
                .resizable()
                .frame(width: 60, height: 60)
                .padding(.vertical, 40)

            }
        }
    }

    // MARK: - cardImagePicker
    @ViewBuilder
    fileprivate func cardImagePicker(_ viewStore: ViewStore<GenericPassForm.State, GenericPassForm.Action>, _ proxy: GeometryProxy ) -> some View {
        if viewStore.cardImage == nil {
            VStack {
                Button {
                    viewStore.send(.isImagePicker(isPresented: true))
                    viewStore.send(.imageFor(.card))
                } label: {
                    Image(systemName: "arrow.up.doc.fill")
                        .resizable()
                        .frame(width: 90, height: 90)
                        .padding()

                    Text("Upload visiting old card.")
                        .font(.title2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 5)
                }
                .cornerRadius(15)

            }
            .frame(width: proxy.size.width / 2.3,   height: 200)

        } else {

            Button {
                viewStore.send(.isImagePicker(isPresented: true))
                viewStore.send(.imageFor(.card))
            } label: {

                Image(systemName: "rectangle.badge.checkmark")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .padding()
            }
            .frame(width: proxy.size.width / 2.3,   height: 200)
            .cornerRadius(15)

        }

    }

    // MARK: - avatarImagePicker
    @ViewBuilder
    fileprivate func avatarImagePicker(_ viewStore: ViewStore<GenericPassForm.State, GenericPassForm.Action>, _ proxy: GeometryProxy) -> some View {
        if let uiimage = viewStore.avartarImage {
            Image(uiImage: uiimage)
                .resizable()
                .cornerRadius(15)
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        viewStore.send(.isImagePicker(isPresented: true))
                        viewStore.send(.imageFor(.avatar))
                    } label: {
                        Image(systemName: "rectangle.2.swap")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .padding(15)

                    }
                }
                .frame(width: proxy.size.width / 2.3,   height: 200)

        } else {
            Button {
                viewStore.send(.isImagePicker(isPresented: true))
                viewStore.send(.imageFor(.avatar))
            } label: {
                Image(systemName: "person.fill.viewfinder")
                    .resizable()
                    .padding()
                //                    .background(Color(red: 186 / 255, green: 186 / 255, blue: 224 / 255) )
                    .cornerRadius(15)

                Text("*Avatar")
                    .font(.title2)
                    .fontWeight(.medium)
            }
            .frame(width: proxy.size.width / 2.3, height: 200)
        }
    }

    // MARK: - contactSectionView
    @MainActor
    fileprivate func contactSectionView(_ viewStore: ViewStore<GenericPassForm.State, GenericPassForm.Action>) -> some View {

        Section {

            TextField(
                "",
                text: viewStore.$vCard.contact.firstName,
                //                            format: .name(style: .medium),
                prompt: Text("*First Name")
                    .font(.title2)
                    .fontWeight(.medium)
            )
            .disableAutocorrection(true)
            .font(.title2)
            .fontWeight(.medium)
            .padding(.vertical, 10)


            TextField(
                "",
                text: viewStore.$vCard.contact.additionalName.orEmpty,
                prompt: Text("Middle Name")
                    .font(.title2)
                    .fontWeight(.medium)
            )
            .disableAutocorrection(true)
            .font(.title2)
            .fontWeight(.medium)
            .padding(.vertical, 10)

            TextField(
                "",
                text: viewStore.$vCard.contact.lastName,
                prompt: Text("*Last Name")
                    .font(.title2)
                    .fontWeight(.medium)
            )
            .disableAutocorrection(true)
            .font(.title2)
            .fontWeight(.medium)
            .padding(.vertical, 10)

        } header: {
            Text("Contact")
                .font(.title2)
                .fontWeight(.medium)
        }

    }

    // MARK: - telephonesSectionView
    @MainActor
    fileprivate func telephonesSectionView(_ viewStore: ViewStore<GenericPassForm.State, GenericPassForm.Action>, _ value: ScrollViewProxy) -> some View {
        Section {

            ForEach(viewStore.$vCard.telephones.indices, id: \.self) { index in

                Picker("Device Type", selection: viewStore.$vCard.telephones[index].type) {
                    ForEach(VCard.Telephone.TType.allCases) { option in
                        Text(option.rawValue.uppercased())
                            .font(.title2)
                            .fontWeight(.medium)
                            .padding(.vertical, 10)

                    }
                }

                HStack {

                    TextField(
                        "",
                        text: viewStore.$vCard.telephones[index].number,
                        prompt: Text("*Telephone Number")
                            .font(.title2)
                            .fontWeight(.medium)
                    )
                    .keyboardType(.phonePad)
                    .disableAutocorrection(true)
                    .font(.title2)
                    .fontWeight(.medium)
                    .padding(.vertical, 10)

                    Spacer()

                    Button {
                        viewStore.send(.removeEmailSection(at: index))
                    } label: {
                        Image(systemName: "trash.circle")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .tint(Color.red)
                    }
                }
            }

        } header: {
            HStack {
                Text("Telephone")
                    .font(.title2)
                    .fontWeight(.medium)

                Spacer()

                if viewStore.isCustomProduct {
                    Button {
                        viewStore.send(.addOneMoreTelephoneSection)
                    } label: {
                        Image(systemName: "plus.square.on.square")
                            .resizable()
                            .frame(width: 30, height: 30)
                    }
                } else {
                    Menu {
                        Text("To activate this function,")
                        Text("Please change your product type below.")
                        Button {
                            withAnimation(.easeInOut(duration: 90)) {
                                value.scrollTo(viewStore.bottomID, anchor: .bottom)
                            }
                        } label: {
                            Text("click here to change your product type 👇🏼")
                        }
                    } label: {
                        Button {} label: {
                            Image(systemName: "plus.square.on.square")
                                .resizable()
                                .frame(width: 30, height: 30)
                        }
                        .disabled(!viewStore.isCustomProduct)
                        .foregroundColor(viewStore.isCustomProduct ? Color.blue : Color.gray)
                    }
                }

            }
            .padding(.vertical, 10)
        }
    }

    // MARK: - emailsSectionView
    @MainActor
    fileprivate func emailsSectionView(_ viewStore: ViewStore<GenericPassForm.State, GenericPassForm.Action>) -> some View {
        Section {
            ForEach(viewStore.$vCard.emails.indices, id: \.self) { index in
                HStack {
                    TextField(
                        "",
                        text: viewStore.$vCard.emails[index].text,
                        prompt: Text("*Email")
                            .font(.title2)
                            .fontWeight(.medium)
                    )
                    .keyboardType(.emailAddress)
                    .disableAutocorrection(true)
                    .font(.title2)
                    .fontWeight(.medium)
                    .padding(.vertical, 10)


                    Button {
                        viewStore.send(.removeEmailSection(at: index))
                    } label: {
                        Image(systemName: "trash.circle")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .tint(Color.red)
                    }
                }
            }
        } header: {
            HStack {
                Text("Email")
                    .font(.title2)
                    .fontWeight(.medium)

                Spacer()

                if viewStore.isCustomProduct {
                    Button {
                        viewStore.send(.addOneMoreEmailSection)
                    } label: {
                        Image(systemName: "plus.square.on.square")
                            .resizable()
                            .frame(width: 30, height: 30)
                    }
                } else {
                    Menu {
                        Text("Activate function, change product type below.")
                    } label: {
                        Button {} label: {
                            Image(systemName: "plus.square.on.square")
                                .resizable()
                                .frame(width: 30, height: 30)
                        }
                        .disabled(!viewStore.isCustomProduct)
                        .foregroundColor(viewStore.isCustomProduct ? Color.blue : Color.gray)
                    }
                }
            }
            .padding(.vertical, 10)
        }
    }

    // MARK: - addressesSectionView
    @MainActor
    fileprivate func addressesSectionView(_ viewStore: ViewStore<GenericPassForm.State, GenericPassForm.Action>) -> some View {
        Section {
            ForEach(viewStore.$vCard.addresses.indices, id: \.self) { index in

                Picker("Address Type", selection: viewStore.$vCard.addresses[index].type) {
                    ForEach(VCard.Address.AType.allCases) { option in
                        Text(option.rawValue.uppercased())
                            .font(.title2)
                            .fontWeight(.medium)
                            .padding(.vertical, 10)
                    }
                }

                TextField(
                    "",
                    text: viewStore.$vCard.addresses[index].postOfficeAddress,
                    prompt: Text("*PostOffice")
                        .font(.title2)
                        .fontWeight(.medium)
                )
                .disableAutocorrection(true)
                .font(.title2)
                .fontWeight(.medium)
                .padding(.vertical, 10)

                TextField(
                    "",
                    text: viewStore.$vCard.addresses[index].extendedAddress.orEmpty,
                    prompt: Text("Extended address - OPTIONAL")
                        .font(.title2)
                        .fontWeight(.medium)
                )
                .disableAutocorrection(true)
                .font(.title2)
                .fontWeight(.medium)
                .padding(.vertical, 10)

                TextField(
                    "",
                    text: viewStore.$vCard.addresses[index].street,
                    prompt: Text("*Street")
                        .font(.title2)
                        .fontWeight(.medium)
                )
                .disableAutocorrection(true)
                .font(.title2)
                .fontWeight(.medium)
                .padding(.vertical, 10)

                TextField(
                    "",
                    text: viewStore.$vCard.addresses[index].locality,
                    prompt: Text("*City")
                        .font(.title2)
                        .fontWeight(.medium)
                )
                .disableAutocorrection(true)
                .font(.title2)
                .fontWeight(.medium)
                .padding(.vertical, 10)


                TextField(
                    "",
                    text: viewStore.$vCard.addresses[index].region.orEmpty,
                    prompt: Text("*Region/State")
                        .font(.title2)
                        .fontWeight(.medium)
                )
                .disableAutocorrection(true)
                .font(.title2)
                .fontWeight(.medium)
                .padding(.vertical, 10)

                TextField(
                    "",
                    text: viewStore.$vCard.addresses[index].postalCode,
                    prompt: Text("*Post Code")
                        .font(.title2)
                        .fontWeight(.medium)
                )
                .keyboardType(.phonePad)
                .disableAutocorrection(true)
                .font(.title2)
                .fontWeight(.medium)
                .padding(.vertical, 10)

                TextField(
                    "",
                    text: viewStore.$vCard.addresses[index].country,
                    prompt: Text("*Country")
                        .font(.title2)
                        .fontWeight(.medium)
                )
                .disableAutocorrection(true)
                .font(.title2)
                .fontWeight(.medium)
                .padding(.vertical, 10)

                HStack {

                    Spacer()

                    Text("Remove this address")
                        .font(.title2)
                        .fontWeight(.medium)
                        .padding()

                    Button {
                        viewStore.send(.removeAddressSection(at: index))
                    } label: {
                        Image(systemName: "trash.circle")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .tint(Color.red)
                    }
                    
                }
            }
        } header: {
            HStack {
                Text("Address")
                    .font(.title2)
                    .fontWeight(.medium)

                Spacer()

                if viewStore.isCustomProduct {
                    Button {
                        viewStore.send(.addOneMoreAddressSection)
                    } label: {
                        Image(systemName: "plus.square.on.square")
                            .resizable()
                            .frame(width: 30, height: 30)
                    }
                } else {
                    Menu {
                        Text("To activate this function,")
                        Text("Please change your product type below.")
                    } label: {
                        Button {} label: {
                            Image(systemName: "plus.square.on.square")
                                .resizable()
                                .frame(width: 30, height: 30)
                        }
                        .disabled(!viewStore.isCustomProduct)
                        .foregroundColor(viewStore.isCustomProduct ? Color.blue : Color.gray)
                    }
                }
            }
            .padding(.vertical, 10)
        }
    }
}

#if DEBUG
struct GenericPassFormView_Previews: PreviewProvider {
    static var previews: some View {
        GenericPassFormView(store: StoreOf<GenericPassForm>(
            initialState: GenericPassForm.State(storeKitState: .init()),
            reducer: GenericPassForm()
        ))
    }
}
#endif


import ComposableStoreKit

private func cost(product: StoreKitClient.Product) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = product.priceLocale
    return formatter.string(from: product.price) ?? ""
}
