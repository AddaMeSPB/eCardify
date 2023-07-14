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

public struct GenericPassForm: ReducerProtocol {
    public enum ImageFor: String, Equatable {
        case logo, avatar, card
    }

    public struct State: Equatable {
        public init(
            pass: Pass = .draff,
            isActivityIndicatorVisible: Bool = false,
            passContentState: PassContentReducer.State? = .init(
                passContent: .init(
                    primaryFields: [.init(key: "NAME")],
                    secondaryFields: [.init(key: "POSITION")],
                    auxiliaryFields: [.init(key: "MOBILE"), .init(key: "EMAIL")]
                )
            ),
            imagePickerState: ImagePickerReducer.State? = nil,
            storeKitState: StoreKitReducer.State = .init(),
            isUploadingImage: Bool = false,
            isImagePickerPresented: Bool = false,
            logoImage: UIImage? = nil,
            avartarImage: UIImage? = nil,
            cardImage: UIImage? = nil,
            imageFor: ImageFor = .avatar,
            imageURLS: [ImageURL] = [],
            isFormValid: Bool = false,
            isAuthorized: Bool = true,
            user: UserOutput? = nil,
            vCard: VCard = .empty,
            isFormPresented: Bool = false
        ) {
            self.pass = pass
            self.isActivityIndicatorVisible = isActivityIndicatorVisible
            self.passContentState = passContentState
            self.imagePickerState = imagePickerState
            self.storeKitState = storeKitState
            self.isUploadingImage = isUploadingImage
            self.isImagePickerPresented = isImagePickerPresented
            self.logoImage = logoImage
            self.avartarImage = avartarImage
            self.cardImage = cardImage
            self.imageFor = imageFor
            self.imageURLS = imageURLS
            self.isFormValid = isFormValid
            self.isAuthorized = isAuthorized
            self.user = user
            self.vCard = vCard
            self.isFormPresented = isFormPresented
        }

        @BindingState public var pass: Pass
        public var isActivityIndicatorVisible = false
        public var passContentState: PassContentReducer.State?
        public var imagePickerState: ImagePickerReducer.State?
        public var storeKitState: StoreKitReducer.State
        public var isUploadingImage: Bool = false
        public var isImagePickerPresented: Bool  = false
        public var logoImage: UIImage?
        public var avartarImage: UIImage?
        public var cardImage: UIImage?
        public var imageFor: ImageFor = .avatar
        public var imageURLS: [ImageURL] = []
        public var isFormValid: Bool = false
        public var isAuthorized: Bool = true
        public var user: UserOutput? = nil
        public var vCard: VCard = .empty
        public var isFormPresented: Bool  = false
        public var walletPass: WalletPass? = nil
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case passContentAction(PassContentReducer.Action)
        case isUploadingImage
        case isImagePicker(isPresented: Bool)
        case uploadAvatar(_ image: UIImage)
        case createAttachment(_ attachment: AttachmentInOutPut)
        case imageUploadResponse(TaskResult<String>)
        case imagePicker(action: ImagePickerReducer.Action)
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
            .ifLet(\.passContentState, action: /Action.passContentAction) {
                PassContentReducer()
            }
            .ifLet(\.imagePickerState, action: /Action.imagePicker) {
                ImagePickerReducer()
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
            } catch { }

            if TARGET_OS_SIMULATOR == 1 {
                state.imageURLS = ImageURL.draff
                state.isFormValid = true
            }

            if let generic = state.pass.generic {
                state.passContentState = .init(passContent: generic)
            } else {
                state.passContentState = nil
            }

            return .run { send in
                await send(.storeKit(.fetchProduct))
            }

        case .openSheetLogin:
            return .none

        case .passContentAction(let psca):

            return .none

        case .isUploadingImage:
            return .none

        case .isImagePicker(isPresented: let isPresented):
            state.imagePickerState = isPresented
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

            return .task {
                .attacmentResponse(
                    await TaskResult {
                        try await apiClient.request(
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

            state.isFormValid = state.imageURLS.count >= 2

            return .none
            
        case .imageUploadResponse(.failure(let error)):
            print(#line, error.localizedDescription)
            return .none

        case let .imagePicker(.picked(result: .success(image))):
            state.isUploadingImage = true
            state.imagePickerState = nil

            switch state.imageFor {
            case .logo:
                state.logoImage = image
                return .task { [serialNumber = state.pass.serialNumber] in
                    await .imageUploadResponse(
                        TaskResult {
                            try await attachmentS3Client.uploadImageToS3(
                                image, .init(
                                    passId: serialNumber,
                                    compressionQuality: .lowest,
                                    type: .png,
                                    passImagesType: .logo,
                                    userId: UUID().uuidString
                                )
                            )
                        }
                    )
                }

            case .avatar:
                state.avartarImage = image
                return .task { [serialNumber = state.pass.serialNumber] in
                    await .imageUploadResponse(
                        TaskResult {
                            try await attachmentS3Client.uploadImageToS3(
                                image, .init(
                                    passId: serialNumber,
                                    compressionQuality: .lowest,
                                    type: .png,
                                    passImagesType: .thumbnail,
                                    userId: UUID().uuidString
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
//                    state.imageURLs.insert(image, at: 0)
                }
                return .none
            case .avatar:
                if let image = attachmentResponse.imageUrlString {
//                    state.imageURLs.insert(image, at: 0)
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

            if let vcard = vcard {

                if let indexName = state.passContentState!.fields
                    .firstIndex(where: {$0.fieldType == .primary && $0.field.key == "member" } )  {
                    state.passContentState!.fields[indexName].field.value = vcard.contact.fullName
                }

                if let indexPosition = state.passContentState!.fields
                    .firstIndex(where: {$0.fieldType == .secondary && $0.field.key == "position" } )  {
                    state.passContentState!.fields[indexPosition].field.value = vcard.position ?? ""
                }

            }

            if let string = vcard?.vCardRepresentation {

                if let indexMobiles = state.passContentState!.fields
                    .firstIndex(where: {$0.fieldType == .auxiliary && $0.field.key == "mobile" } ),

                    let indexEmails = state.passContentState!.fields
                    .firstIndex(where: {$0.fieldType == .auxiliary && $0.field.key == "email" } )
                {
                    let emailAddress = extractEmailAddrIn(text: string)
                    if let mobiles = try? string.findContactsNumber() {
                        state.passContentState!.fields[indexMobiles].field.value = mobiles.joined(separator: ", \n")
                    }
                    state.passContentState!.fields[indexEmails].field.value = emailAddress.joined(separator: ",")
                }

            }

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


            if state.passContentState != nil {
                for field in state.passContentState!.fields {
                    switch field.fieldType {
                    case .header:
                        for idx in 0...state.passContentState!.passContent.headerFields!.count {
                            state.passContentState!.passContent.headerFields![idx].value = field.field.value
                        }

                    case .primary:

                        if let memberIdx = state.passContentState?.passContent
                            .primaryFields
                            .firstIndex(where: { $0.key == "member"})
                        {
                            //state.vCard.fullName = field.field.value
                            state.passContentState!.passContent.primaryFields[memberIdx].value = field.field.value
                        }

                    case .secondary:

                        if let positionIdx = state.passContentState?.passContent
                            .secondaryFields?
                            .firstIndex(where: { $0.key == "position"})
                        {
                            state.vCard.position = field.field.value
                            state.passContentState!.passContent.secondaryFields![positionIdx].value = field.field.value
                        }

                    case .auxiliary:

                        if let mobile = state.passContentState?
                            .passContent
                            .auxiliaryFields?
                            .firstIndex(where: { $0.key == "mobile" && field.field.key == "mobile"})
                        {
                            //state.vCard.cellPhone = field.field.value
                            state.passContentState!.passContent.auxiliaryFields![mobile].value = field.field.value
                        }

                        if let emailIdx = state.passContentState?
                            .passContent
                            .auxiliaryFields?
                            .firstIndex(where: { $0.key == "email" && field.field.key == "email" })
                        {
                            //state.vCard.workEmail = field.field.value
                            state.passContentState!.passContent.auxiliaryFields![emailIdx].value = field.field.value
                        }

                    case .back:
                        for idx in 0..<state.passContentState!.passContent.backFields!.count {
                            state.passContentState!.passContent.backFields![idx].value = field.field.value
                        }
                    }
                }
            }

            state.pass.generic = state.passContentState?.passContent
            _ = state.pass.generic?.primaryFields[0].value.replacingOccurrences(of: " ", with: "\n")

            /// have to debug why after scan code was not showing image
//            if let imageURL = state.imageURLS.first(where: { $0.type == .thumbnail })?.urlString {
//                state.vCard.imageURL = imageURL
//            }

            state.pass.barcodes = [
                .init(message: state.vCard.vCardRepresentation, format: .qr)
            ]

            let walletPass = WalletPass(
                _id: .init(),
                ownerId: currentUserID,
                pass: state.pass,
                imageURLs: state.imageURLS
            )

            state.walletPass = walletPass

            return .run { send in
                await send(.buyProduct)
            }

        case .buyProduct:

            guard
                let product = state.storeKitState.basicCardProduct
            else {
                return .none
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
        }
    }
}

import SwiftUI

public struct GenericPassFormView: View {
    let store: StoreOf<GenericPassForm>

    struct ViewState: Equatable {

        @BindingViewState var pass: Pass
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
            self.logoImage = state.logoImage
            _pass = state.$pass

            self.avartarImage = state.avartarImage
            self.cardImage = state.cardImage

            self.isImagePickerPresented = state.imagePickerState != nil
            self.isFormValid = state.imageURLS.count >= 3

            if state.passContentState != nil {
                self.isFormValid =
                state.passContentState!.fields.filter { !$0.field.value.isEmpty }.count >= 4
   
            }

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

    public var body: some View {
        WithViewStore(self.store) { viewStore in
            GeometryReader { proxy in
                ZStack(alignment: .center) {

                    ScrollView {

                        VStack {

                            HStack {
                                Button {
                                    viewStore.send(.isImagePicker(isPresented: true))
                                    viewStore.send(.imageFor(.logo))
                                } label: {
                                    if let logoImage = viewStore.logoImage {
                                        Image(uiImage: logoImage)
                                            .resizable()
                                            .frame(width: 30, height: 30)
                                            .clipShape(Circle())
                                            .padding()
                                    } else {
                                        Image(
                                            uiImage: (UIImage(named: "logo.jpg")
                                                      ?? UIImage(systemName: "infinity.circle"))!
                                        )
                                        .resizable()
                                        .frame(width: 30, height: 30)
                                        .padding()
                                    }
                                }

                                TextField(
                                    "",
                                    text: viewStore.$pass.logoText,
                                    prompt: Text("Logo Text")
                                )
                                .font(.body)
                                .fontWeight(.medium)
                                .padding()

                                TextField(
                                    "",
                                    text: viewStore.$pass.organizationName,
                                    prompt: Text("Header")
                                )
                                .disableAutocorrection(true)
                                .font(.body)
                                .fontWeight(.medium)
                                .padding()

                            }
                            .frame(height: 50)
                            .background(viewStore.pass.backgroundColor.colorFromRGBString)

                            HStack {

                                if viewStore.cardImage == nil {
                                    Button {
                                        viewStore.send(.isImagePicker(isPresented: true))
                                        viewStore.send(.imageFor(.card))
                                    } label: {
                                        Image(systemName: "arrow.up.doc.fill")
                                            .resizable()
                                            .frame(width: 90, height: 90)
                                            .padding()
                                    }
                                    .frame(width: proxy.size.width / 2.3,   height: 200)
                                    .overlay(alignment: .bottom) {
                                        Text("Upload visiting card!")
                                            .padding(.bottom, 15)
                                    }
                                    .background(Color(red: 186 / 255, green: 186 / 255, blue: 224 / 255) )
                                    .cornerRadius(15)
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
                                    .background(Color(red: 186 / 255, green: 186 / 255, blue: 224 / 255) )
                                    .cornerRadius(15)

                                }

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
                                            .padding(40)
                                            .background(Color(red: 186 / 255, green: 186 / 255, blue: 224 / 255) )
                                            .cornerRadius(15)
                                    }
                                    .frame(width: proxy.size.width / 2.3, height: 200)

                                }

                            }

                            HStack {

                                VStack(alignment: .leading) {

                                    IfLetStore(
                                        self.store.scope(
                                            state: \.passContentState,
                                            action: GenericPassForm.Action.passContentAction
                                        ),
                                        then: { store in
                                            PassContentView(store: store)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical)
                                        },
                                        else: {
                                            Text("View is empty")
                                        }
                                    )
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundColor(.black)
                                .background(viewStore.pass.backgroundColor.colorFromRGBString)

                            }

                            HStack {

                                if let basicCardProduct = viewStore.storeKitState.basicCardProduct {
                                    VStack {
                                        Text(basicCardProduct.localizedTitle)
                                            .font(.title2)
                                            .fontWeight(.medium)

                                        Text(basicCardProduct.localizedDescription)
                                            .font(.body)
                                    }

                                    Spacer()

                                    Button {
                                        viewStore.send(.createPass)
                                    } label: {
                                        Text("Pay \(cost(product: basicCardProduct)) and Create")
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
                                }

                            }
                            .padding(20)
                        }
                        .redacted(reason: viewStore.isActivityIndicatorVisible ? .placeholder : .init())
                        .allowsHitTesting(!viewStore.isActivityIndicatorVisible)
                        .background(
                            viewStore.isActivityIndicatorVisible == true
                            ? Color.black.opacity(0.9)
                            : viewStore.pass.backgroundColor.colorFromRGBString.opacity(0.3)
                        )
                        .cornerRadius(30)
                        .padding(.horizontal)
                        .onAppear {
                            viewStore.send(.onAppear)
                        }
                        .sheet(
                            isPresented: viewStore.binding(
                                get: \.isImagePickerPresented,
                                send: { .isImagePicker(isPresented: $0) }
                            )
                        ) {
                            IfLetStore(
                                self.store.scope(
                                    state: \.imagePickerState,
                                    action: GenericPassForm.Action.imagePicker
                                )
                            ) {
                                ImagePickerView.init(store: $0)
                            } else: {
                                ProgressView()
                            }
                        }

                    }
                    .navigationTitle("Create digital Cards 🪪!")

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

//struct WallatPassView_Previews: PreviewProvider {
//    static var store = Store(
//        initialState: WallatPassList.State(
//            pass: .mock,
//            wPass: .init(uniqueElements: [WallatPassO.State.init(wp: .mock), WallatPassO.State.init(wp: .mock1)]),
//            passContentState: .init(
//                passContent: .init(primaryFields: [.init(key: "NAME")])
//            ),
//            storeKitState: .init(),
//            isFormPresented: false
//        ),
//        reducer: WallatPassList()
//    )
//
//    static var previews: some View {
//        WallatPassView(store: store)
//    }
//}

import ComposableStoreKit

private func cost(product: StoreKitClient.Product) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = product.priceLocale
    return formatter.string(from: product.price) ?? ""
}
