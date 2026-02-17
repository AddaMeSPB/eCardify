import Vision
import SwiftUI
import Foundation
import Dependencies
import ComposableArchitecture

enum VNRecognizeError: Error {
    case invalid
    case error(String)
    case fatalError(String)
}

public struct VNRecognizeResponse: Codable, Equatable {

    public enum TextType: String, Codable, Equatable {
        case plain, vcard
    }

    public init(
        string: String? = nil,
        textType: TextType = .plain
    ) {
        self.string = string
        self.textType = textType
    }

    public var string: String?
    public var textType: TextType

    public static var empty: Self = .init()
    public static var mock: Self = .init(string: "https://addame.com", textType: .vcard)
    public static var fullQRString: Self = .init(string: "BEGIN:VCARD\nN:Saroar;Khandoker;\nTEL;TYPE=work,VOICE:+351000000000\nTEL;TYPE=home,VOICE:+79218888888\nEMAIL:fake9@gmail.com\nORG:Addame\nTITLE:IOS Developer\nADR;TYPE=WORK,PREF:;;R. Prof. Bento de Jesus Caraça 52;R/C EQS;1600-605;PORTUGAL\nURL:https://addame.com\nEND:VCARD", textType: .vcard)
}

public struct VNRecognizeClient {
    public typealias RecognizeTextHandler = @Sendable (UIImage) async throws -> VNRecognizeResponse

    public let recognizeTextRequest: RecognizeTextHandler

    public init(recognizeTextRequest: @escaping RecognizeTextHandler) {
        self.recognizeTextRequest = recognizeTextRequest
    }
}

extension VNRecognizeClient {

    public static var live: Self {

        return Self(recognizeTextRequest: { image in
            return try await withCheckedThrowingContinuation { continuation in
                var returnValue: String = ""

                let qrCodeDetectionRequest = VNDetectBarcodesRequest { request, error in
                    guard let observations = request.results as? [VNBarcodeObservation], let qrCode = observations.first else {
                        // QR code not detected, fallback to text recognition
                        let vnRecognizeTextRequest = VNRecognizeTextRequest { request, error in
                            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                                return continuation.resume(throwing: VNRecognizeError.fatalError("Received invalid observations"))
                            }

                            let recognizedTexts = observations
                                .map { $0.topCandidates(1).first }
                                .compactMap { $0?.string }

                            returnValue = recognizedTexts.joined(separator: " ")
                            let vNRecognizeRes = VNRecognizeResponse(string: returnValue)
                            continuation.resume(returning: vNRecognizeRes)
                        }

                        let handler = VNImageRequestHandler(cgImage: image.cgImage!, orientation: .up, options: [:])
                        try? handler.perform([vnRecognizeTextRequest])
                        return
                    }

                    // QR code detected, process the payload
                    returnValue = qrCode.payloadStringValue ?? ""
                    let vNRecognizeRes = VNRecognizeResponse(string: returnValue, textType: .vcard)
                    continuation.resume(returning: vNRecognizeRes)
                }

                let handler = VNImageRequestHandler(cgImage: image.cgImage!, orientation: .up, options: [:])
                try? handler.perform([qrCodeDetectionRequest])
            }
        })
    }


}


extension VNRecognizeClient {
    public static let empty = Self(
        recognizeTextRequest: { _ in .empty }
    )

    public static let mock = Self(
        recognizeTextRequest: { _ in .mock }
    )
}

public enum VNRecognizeClientKey: TestDependencyKey {
    public static let testValue = VNRecognizeClient.mock
}

extension VNRecognizeClientKey: DependencyKey {
    public static let liveValue = VNRecognizeClient.live
}

extension DependencyValues {
    public var vnRecognizeClient: VNRecognizeClient {
        get { self[VNRecognizeClientKey.self] }
        set { self[VNRecognizeClientKey.self] = newValue }
    }
}
