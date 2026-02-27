import SwiftUI
import DesignSystem
import L10nResources
import ECSharedModels
import ComposableArchitecture

struct OrganizationSectionView: View {

    @Bindable var store: StoreOf<GenericPassForm>
    var scrollProxy: ScrollViewProxy
    var geoProxy: GeometryProxy

    public init(
        store: StoreOf<GenericPassForm>,
        _ geoProxy: GeometryProxy,
        _ scrollProxy: ScrollViewProxy
    ) {
        self.store = store
        self.geoProxy = geoProxy
        self.scrollProxy = scrollProxy
    }

    var body: some View {
        HStack {
                VStack {
                    if store.isCustomProduct {
                        if let uiImage = store.cardImage {
                            Button {
                                store.send(.isImagePicker(isPresented: true))
                                store.send(.imageFor(.card))
                            } label: {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .clipShape(RoundedRectangle(cornerRadius: ECRadius.lg))
                                    .overlay(alignment: .bottomTrailing) {
                                        Button {
                                            store.send(.isImagePicker(isPresented: true))
                                            store.send(.imageFor(.card))
                                        } label: {

                                            Image(systemName: "rectangle.badge.checkmark")
                                                .resizable()
                                                .frame(width: 60, height: 60)
                                                .padding()
                                        }
                                        .frame(width: geoProxy.size.width / 2.3,   height: 98)
                                    }
                            }
                            .frame(width: geoProxy.size.width / 2.3,   height: 98)

                        } else {
                            VStack {
                                Button {
                                    store.send(.isImagePicker(isPresented: true))
                                    store.send(.imageFor(.card))
                                } label: {
                                    VStack {
                                        Text(L("Upload old card"))
                                            .font(ECTypography.body(.medium))
                                            .padding(.horizontal, ECSpacing.md)
                                    }
                                }
                                .foregroundStyle(ECColors.textSecondary)
                                .frame(width: geoProxy.size.width / 2.3,   height: 98)
                                .overlay(
                                    RoundedRectangle(cornerRadius: ECRadius.lg)
                                        .stroke(ECColors.separator, style: StrokeStyle(lineWidth: 3, dash: [9]))
                                        .padding(5)
                                )
                                .buttonStyle(.borderless)
                            }
                            .frame(width: geoProxy.size.width / 2.3,   height: 98)
                        }

                    } else {
                        Menu {
                            Text(L("To activate this function,"))
                            Text(L("Please change your product type below."))
                            Button {
                                withAnimation(.easeInOut(duration: 0.9)) {
                                    scrollProxy.scrollTo(store.bottomID, anchor: .bottom)
                                }
                            } label: {
                                Text(L("Change product type"))
                            }
                        } label: {

                            Button {
                                store.send(.isImagePicker(isPresented: true))
                                store.send(.imageFor(.card))
                            } label: {
                                Text(L("Upload old card"))
                                    .font(ECTypography.body(.medium))
                                    .padding(.horizontal, ECSpacing.md)
                            }
                            .disabled(!store.isCustomProduct)
                            .foregroundStyle(store.isCustomProduct ? ECColors.primary : ECColors.textSecondary)
                            .frame(width: geoProxy.size.width / 2.3,   height: 98)
                            .overlay(
                                RoundedRectangle(cornerRadius: ECRadius.lg)
                                    .stroke(ECColors.separator, style: StrokeStyle(lineWidth: 3, dash: [9]))
                                    .padding(5)
                            )
                            .buttonStyle(.borderless)

                        }
                    }

                    Button {
                        store.send(.isImagePicker(isPresented: true))
                        store.send(.imageFor(.logo))
                    } label: {
                        if let logoImage = store.logoImage {
                            Image(uiImage: logoImage)
                                .resizable()
                                .clipShape(RoundedRectangle(cornerRadius: ECRadius.lg))
                                .frame(width: geoProxy.size.width / 2.3,   height: 96)
                        } else {
                            Text(L("Upload Logo"))
                                .font(ECTypography.body(.medium))
                                .padding(.horizontal, ECSpacing.md)
                        }
                    }
                    .frame(width: geoProxy.size.width / 2.3,   height: 98)
                    .overlay(
                        RoundedRectangle(cornerRadius: ECRadius.lg)
                            .stroke(store.logoImage == nil ? ECColors.warning.opacity(0.5) : ECColors.separator, style: StrokeStyle(lineWidth: 3, dash: [9]))
                            .padding(5)
                    )
                    .buttonStyle(.borderless)


                }.frame(width: geoProxy.size.width / 2.3,   height: 200)


                if let uiImage = store.avatarImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .clipShape(RoundedRectangle(cornerRadius: ECRadius.lg))
                        .overlay(alignment: .bottomTrailing) {
                            Button {
                                store.send(.isImagePicker(isPresented: true))
                                store.send(.imageFor(.avatar))
                            } label: {
                                Image(systemName: "rectangle.2.swap")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)
                                    .padding(ECSpacing.md)

                            }
                            .buttonStyle(.borderless)
                        }
                        .frame(width: geoProxy.size.width / 2.3,   height: 200)

                } else {
                    Button {
                        store.send(.isImagePicker(isPresented: true))
                        store.send(.imageFor(.avatar))
                    } label: {
                        VStack {
                            Image(systemName: "person.fill.viewfinder")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .padding()
                                .clipShape(RoundedRectangle(cornerRadius: ECRadius.lg))

                            Text(L("Avatar"))
                                .font(ECTypography.sectionTitle(.medium))
                        }
                    }
                    .frame(width: geoProxy.size.width / 2.3,   height: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: ECRadius.lg)
                            .stroke(store.avatarImage == nil ? ECColors.warning.opacity(0.5) : ECColors.separator, style: StrokeStyle(lineWidth: 3, dash: [9]))
                            .padding(5)
                    )
                    .buttonStyle(.borderless)
                }
        }
    }
}


struct OrganizationSectionView_Previews: PreviewProvider {

    static var state = GenericPassForm.State(
        storeKitState: .demoProductsCustom,
        vCard: .demo
    )

    static var store = Store(initialState: state) {
        GenericPassForm()
    } withDependencies: {
        $0.attachmentS3Client = .happyPath
    }

    static var previews: some View {
        GeometryReader { geoProxy in
            ScrollViewReader { value in
                Form {
                    OrganizationSectionView(store: store, geoProxy, value)
                }
            }
        }
    }
}
