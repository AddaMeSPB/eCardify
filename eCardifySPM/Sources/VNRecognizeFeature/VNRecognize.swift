import SwiftUI
import Vision
import Foundation
import Dependencies
import ComposableArchitecture
import ECardifySharedModels

enum VNRecognizeError: Error {
    case invalid
    case error(String)
    case fatalError(String)
}

public struct VNRecognizeClient {
    public typealias RecognizeTextHandler = @Sendable (UIImage) async throws -> VCard?

    public let recognizeTextRequest: RecognizeTextHandler

    public init(recognizeTextRequest: @escaping RecognizeTextHandler) {
        self.recognizeTextRequest = recognizeTextRequest
    }
}

extension VNRecognizeClient {

    public static var live: Self = .init { image in

        return try await withCheckedThrowingContinuation { continuation in
            var returnValue: String = ""
            var isQrCodeDetection = true

            var vnRecognizeTextRequest: VNRecognizeTextRequest {
                let request = VNRecognizeTextRequest { request, error in
                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        return continuation.resume(throwing: VNRecognizeError.fatalError("Received invalid observations"))
                    }

                    let recognizedTexts = observations
                        .map { $0.topCandidates(1).first }
                        .compactMap { $0?.string }

                    returnValue = recognizedTexts.joined(separator: " ")
//                    continuation.resume(
//                        returning: VirtualCard(vnRecognizeString: returnValue)
//                    )

                }

                return request

            }

            var qrCodeDetectionRequest : VNDetectBarcodesRequest {
                let request = VNDetectBarcodesRequest { (request, error) in
                    if let error = error as NSError? {
                        continuation.resume(throwing: VNRecognizeError.error(error.localizedDescription))
                    }

                    guard let observations = request.results as? [VNBarcodeObservation] else {
                        return continuation.resume(throwing: VNRecognizeError.error("request results empry: []"))
                    }

                    print("Observations are \(observations)")

                    let qrCodes = observations.map { $0.payloadStringValue }.compactMap { $0 }

                    if qrCodes.count == 0 {
                        isQrCodeDetection = false
                        runTextRequest(image: image, continuation, tRequests: [vnRecognizeTextRequest], qrVNDetectBarcodesRequest: nil)
                    } else {
                        returnValue = qrCodes.joined(separator: " ")
                        let vCard = parseVCard(returnValue)
//                        continuation.resume(
//                            returning: VCard(vcard: vCard)
//                        )
                    }
                }

                request.revision = VNDetectBarcodesRequestRevision1
                return request
            }

            func runTextRequest(
                image: UIImage,
                _ continuation: CheckedContinuation<VCard?, Error>,
                tRequests: [VNRecognizeTextRequest]?,
                qrVNDetectBarcodesRequest: [VNDetectBarcodesRequest]?
            ) {
                DispatchQueue.global(qos: .userInitiated).async {
                    guard let img = image.cgImage else {
                        return continuation.resume(throwing: VNRecognizeError.error("Missing image to scan"))
                    }

                    let handler = VNImageRequestHandler(cgImage: img, options: [:])

                    do {
                        if tRequests != nil {
                            try handler.perform(tRequests!)
                        } else {
                            try handler.perform(qrVNDetectBarcodesRequest!)
                        }
                    } catch {
                        continuation.resume(throwing: VNRecognizeError.fatalError(error.localizedDescription))
                    }

                }
            }

            if isQrCodeDetection {
                let requests = [qrCodeDetectionRequest]
                runTextRequest(image: image, continuation, tRequests: nil, qrVNDetectBarcodesRequest: requests)
            } else {
                let requests = [vnRecognizeTextRequest]
                runTextRequest(image: image, continuation, tRequests: requests, qrVNDetectBarcodesRequest: nil)
            }
        }
    }
}

extension VNRecognizeClient {
    public static let empty = Self(
        recognizeTextRequest: { _ in VCard.empty }
    )

    public static let mock = Self(
        recognizeTextRequest: { _ in VCard.empty
        }
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

func parseVCard(_ vCardString: String) -> VCard {
    var fullName = ""
    var nameComponents = ""
    var title = ""
    var cellPhone = ""
    var workPhone = ""
    var homePhone = ""
    var imageUrl = ""
    var workEmail = ""
    var website = ""
    var address = ""
    var organization = ""

    let lines = vCardString.components(separatedBy: .newlines)
    for line in lines {
        let components = line.components(separatedBy: ":;")
        if components.count >= 2 {
            let property = components[0]
            let value = components[1]

            switch property {
            case "FN":
                fullName = value
            case "N":
                nameComponents = value
            case "TITLE":
                title = value
            case "TEL;CELL":
                cellPhone = value
            case "TEL;WORK;VOICE":
                workPhone = value
            case "TEL;HOME;VOICE":
                homePhone = value

                // this have to test
            case  "PHOTO;VALUE=URL":
                imageUrl = value
            case "EMAIL;WORK;INTERNET":
                workEmail = value
            case "URL":
                website = value
            case "ADR":
                address = value
            case "ORG":
                organization = value
            default:
                break
            }
        }
    }

    return .empty

//    VCard(fullName: fullName,
//                 nameComponents: nameComponents,
//                 title: title,
//                 cellPhone: cellPhone,
//                 workPhone: workPhone,
//                 homePhone: homePhone,
//                 imageURL: imageUrl,
//                 workEmail: workEmail,
//                 website: website,
//                 address: address,
//                 organization: organization)
}
