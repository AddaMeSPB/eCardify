import SwiftUI
import ECSharedModels
import iPhoneNumberKit
import ComposableArchitecture

struct OrganizationSectionView: View {

    @Perception.Bindable var store: StoreOf<GenericPassForm>
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
        WithPerceptionTracking {

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
                                    .cornerRadius(15)
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
                            //.buttonStyle(BorderlessButtonStyle())

                        } else {
                            VStack {
                                Button {
                                    store.send(.isImagePicker(isPresented: true))
                                    store.send(.imageFor(.card))
                                } label: {
                                    VStack {
                                        Text("Upload old card.")
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 15)
                                    }
                                }
                                .foregroundColor(.gray)
                                .frame(width: geoProxy.size.width / 2.3,   height: 98)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.gray, style: StrokeStyle(lineWidth: 3, dash: [9]))
                                        .padding(5)
                                )
                                .buttonStyle(BorderlessButtonStyle())
                            }
                            .frame(width: geoProxy.size.width / 2.3,   height: 98)
                        }

                    } else {
                        Menu {
                            Text("To activate this function,")
                            Text("Please change your product type below.")
                            Button {
                                withAnimation(.easeInOut(duration: 90)) {
                                    scrollProxy.scrollTo(store.bottomID, anchor: .bottom)
                                }
                            } label: {
                                Text("click here to change your product type 👇🏼")
                            }
                        } label: {

                            Button {
                                store.send(.isImagePicker(isPresented: true))
                                store.send(.imageFor(.card))
                            } label: {
                                Text("Upload old card")
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 15)
                            }
                            .disabled(!store.isCustomProduct)
                            .foregroundColor(store.isCustomProduct ? Color.blue : Color.gray)
                            .frame(width: geoProxy.size.width / 2.3,   height: 98)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.gray, style: StrokeStyle(lineWidth: 3, dash: [9]))
                                    .padding(5)
                            )
                            .buttonStyle(BorderlessButtonStyle())

                        }
                    }

                    Button {
                        store.send(.isImagePicker(isPresented: true))
                        store.send(.imageFor(.logo))
                    } label: {
                        if let logoImage = store.logoImage {
                            Image(uiImage: logoImage)
                                .resizable()
                                .resizable()
                                .cornerRadius(15)
                                .frame(width: geoProxy.size.width / 2.3,   height: 96)
                        } else {
                            Text("*Upload logo")
                                .font(.title3)
                                .fontWeight(.medium)
                                .padding(.horizontal, 15)
                        }
                    }
                    .frame(width: geoProxy.size.width / 2.3,   height: 98)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(store.logoImage == nil ? Color.yellow.opacity(0.5) : Color.gray, style: StrokeStyle(lineWidth: 3, dash: [9]))
                            .padding(5)
                    )
                    .buttonStyle(BorderlessButtonStyle())


                }.frame(width: geoProxy.size.width / 2.3,   height: 200)


                if let uiImage = store.avatarImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .cornerRadius(15)
                        .overlay(alignment: .bottomTrailing) {
                            Button {
                                store.send(.isImagePicker(isPresented: true))
                                store.send(.imageFor(.avatar))
                            } label: {
                                Image(systemName: "rectangle.2.swap")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)
                                    .padding(15)

                            }
                            .buttonStyle(BorderlessButtonStyle())
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
                                .cornerRadius(15)

                            Text("*Avatar")
                                .font(.title2)
                                .fontWeight(.medium)
                        }
                    }
                    .frame(width: geoProxy.size.width / 2.3,   height: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(store.avatarImage == nil ? Color.yellow.opacity(0.5) : Color.gray, style: StrokeStyle(lineWidth: 3, dash: [9]))
                            .padding(5)
                    )
                    .buttonStyle(BorderlessButtonStyle())
                }
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
