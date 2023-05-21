import SwiftUI
import ECardifySharedModels
import ComposableArchitecture

//extension Binding where Value == Optional<String> {
//    public var orEmpty: Binding<String> {
//        Binding<String> {
//            wrappedValue ?? ""
//        } set: {
//            wrappedValue = $0
//        }
//    }
//}

//Generic Passes
public struct WallatPassView: View {

    public let store: StoreOf<WallatPassRouter>

    public init(store: StoreOf<WallatPassRouter>) {
        self.store = store
    }

    public var body: some View {
        WithViewStore(store, observe: { $0 } ) { viewStore in
            VStack {
                Text("Business card")
                    .font(.title)
                    .fontWeight(.medium)
                    .padding(30)
                    .foregroundColor(Color.blue)

                HStack {

                    Button {

                    } label: {
                        Text("Logo")
                            .font(.body)
                            .fontWeight(.medium)
                            .padding()
                    }

                    Spacer()


                    TextField(
                        "Logo Text",
                        text: viewStore.binding(\.$pass.logoText)
                    )
                    .font(.body)
                    .fontWeight(.medium)
                    .padding()
                    .frame(maxWidth: .infinity)

                    Spacer()

                    TextField("Header", text: viewStore.binding(\.$pass.organizationName))
                        .font(.body)
                        .fontWeight(.medium)
                        .padding()
                        .background()
                }
                .padding(.bottom, 20)
                .frame(height: 50)

                HStack {

                    VStack(alignment: .leading) {
                        PassContentsView(store:
                            self.store.scope(
                                state: \.passContents,
                                action: WallatPassRouter.Action.passContentsAction
                            )
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 150)
                    .foregroundColor(.black)
                    .background(viewStore.pass.backgroundColor.colorFromRGBString)

                    Spacer()

                    Button {

                    } label: {
                        Image(systemName: "person.fill.viewfinder")
                            .resizable()
                            .frame(width: 100,height: 150)
                            .background(Color(red: 186 / 255, green: 186 / 255, blue: 224 / 255) )
                            .cornerRadius(15)
                    }

                }


                VStack(alignment: .leading) {
                    Text("Secondary fields")
                        .font(.title3)
                        .fontWeight(.medium)
                        .padding(.bottom, 5)

                    Text("POSITION")
                        .font(.body)
                        .fontWeight(.medium)

//                    TextField("IOS Developer", text: $logoText)
//                        .font(.title)
//                        .fontWeight(.medium)

                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.black)
                .background(viewStore.pass.backgroundColor.colorFromRGBString)


                VStack(alignment: .leading) {
//                    if isFakeViewOn {
                        Text("Auxiliary fields")
                            .font(.body)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
//                    }


                    HStack {
                        VStack(alignment: .leading) {
                            Text("MOBILE")
                                .font(.body)
                                .fontWeight(.medium)

//                            TextField("+351911700782", text: $logoText)
//                                .font(.body)
//                                .fontWeight(.medium)
                        }

                        VStack(alignment: .leading) {

                            Text("EMAIL")
                                .font(.body)
                                .fontWeight(.medium)

//                            TextField("saroar9@gmail.com", text: $logoText)
//                                .font(.body)
//                                .fontWeight(.medium)
                        }
                    }
                }
                .padding()
//                .background(viewStore.pass.backgroundColor)

                Text("Rectangle barcode")
                    .font(.body)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(viewStore.pass.backgroundColor.colorFromRGBString)
                    .padding(30)

                HStack {

                    Image(systemName: "paintbrush")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .fontWeight(.medium)
                        .padding()
                        .foregroundColor(.white)
                        .overlay {
//                            ColorPicker("", selection: $bgColor)
//                                .labelsHidden()
//                                .opacity(0.015)
                        }

                    Spacer()

//                    Button {
//                        isFakeViewOn.toggle()
//                        fieldsbBgColor = isFakeViewOn ? Color(red: 186 / 255, green: 186 / 255, blue: 224 / 255) : .clear
//
//                    } label: {
//                        Text("FinalVersion")
//                            .font(.title2)
//                            .fontWeight(.medium)
//                    }
//                    .buttonStyle(.bordered)

                    Spacer()

                    Button {

                    } label: {
                        Text("Create")
                            .font(.title2)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.bordered)

                }
            }
//            .padding()
//            .background(viewStore.pass.backgroundColor)
            .cornerRadius(30)
            .padding()
        }
    }
}

struct WallatPassView_Previews: PreviewProvider {
    static var store = Store(
        initialState: WallatPassRouter.State(passContents: .generic(.init(passContent: .init(primaryFields: [.init()])))),
        reducer: WallatPassRouter()
    )

    static var previews: some View {
        WallatPassView(store: store)
    }
}


extension Binding where Value == Optional<String> {
    public var orEmpty: Binding<String> {
        Binding<String> {
            wrappedValue ?? ""
        } set: {
            wrappedValue = $0
        }
    }
}

//struct PassFormView_Previews: PreviewProvider {
//    static var previews: some View {
//        PassFormView()
//    }
//}

extension String {

    // may be prefix which will more speed
    var colorFromRGBString: Color {
        let components = self.replacingOccurrences(of: "rgb(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .split(separator: ",").map { String($0) }

        guard components.count == 3,
            let red = Double(components[0]),
            let green = Double(components[1]),
            let blue = Double(components[2]) else {
                return Color(red: 186 / 255, green: 186 / 255, blue: 224 / 255)
        }

        return Color(red: red / 255.0, green: green / 255.0, blue: blue / 255.0)
    }
}


//struct PassContentView: View {
//    let content: PassContent
//
//    var body: some View {
//        Section(header: Text("Primary Fields")) {
//            ForEach(content.primaryFields, id: \.self) { field in
//                FieldView(field: field)
//            }
//        }
//
//        if let secondaryFields = content.secondaryFields {
//            Section(header: Text("Secondary Fields")) {
////                ForEach(secondaryFields) { field in
////                    FieldView(field: field)
////                }
//            }
//        }
//
//        if let auxiliaryFields = content.auxiliaryFields {
//            Section(header: Text("Auxiliary Fields")) {
////                ForEach(auxiliaryFields) { field in
////                    FieldView(field: field)
////                }
//            }
//        }
//
//        if let headerFields = content.headerFields {
//            Section(header: Text("Header Fields")) {
////                ForEach(headerFields) { field in
////                    FieldView(field: field)
////                }
//            }
//        }
//
//        if let backFields = content.backFields {
//            Section(header: Text("Back Fields")) {
////                ForEach(backFields) { field in
////                    FieldView(field: field)
////                }
//            }
//        }
//    }
//}

struct PassContentTransitView: View {
    let content: PassContentTransit

    var body: some View {
//        PassContentView(content: content)

        Section(header: Text("Transit Information")) {
            Text("Transit Type: \(content.transitType.rawValue)")
        }
    }
}


extension Pass {
    public static var mock: Pass = .init(
        formatVersion: 1,
        passTypeIdentifier: "pass.ecardify.addame.com",
        serialNumber: UUID().uuidString,
        teamIdentifier: "6989658CU5",
        organizationName: "Addame",
        description: "IT Consultant",
        logoText: "Alif",
        foregroundColor: .rgb(r: 255, g: 255, b: 255),
        backgroundColor: .rgb(r: 197, g: 208, b: 197),
        labelColor: .rgb(r: 147, g: 108, b: 137),
        passContents: .generic(
            .init(
                primaryFields: [
                    .init(label: "NAME", key: "member", value: "SAROAR \nKKHANDOKER")
                ],
                secondaryFields: [
                    .init(label: "POSITION", key: "subtitle", value: "IOS Developer")
                ],
                auxiliaryFields: [
                    .init(label: "PHONE", key: "mobile", value: "+351911700782"),
                    .init(label: "EMAIL", key: "email", value: "saroar9@gmail.com")

                ],
                backFields: [
                    .init(label: "Spelled out", key: "numberStyle", value: "200")
                ]
            )
        )
    )
}

