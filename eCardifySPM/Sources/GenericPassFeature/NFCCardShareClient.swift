import CoreNFC
import Dependencies
import Foundation

// MARK: - NFC Card Share Client

public struct NFCCardShareClient {
    public var isAvailable: @Sendable () -> Bool
    public var writeURL: @Sendable (URL) async throws -> Void
    public var writeVCard: @Sendable (String) async throws -> Void
}

// MARK: - Errors

public enum NFCCardShareError: LocalizedError, Equatable {
    case notAvailable
    case tagNotWritable
    case writeFailed(String)
    case sessionInvalidated(String)
    case payloadTooLarge
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "NFC is not available on this device"
        case .tagNotWritable:
            return "This NFC tag is read-only"
        case .writeFailed(let message):
            return "Failed to write: \(message)"
        case .sessionInvalidated(let message):
            return message
        case .payloadTooLarge:
            return "Card data is too large for this NFC tag"
        case .cancelled:
            return "NFC session was cancelled"
        }
    }
}

// MARK: - Live Implementation

final class NFCWriter: NSObject, NFCNDEFReaderSessionDelegate, @unchecked Sendable {
    private var session: NFCNDEFReaderSession?
    private var message: NFCNDEFMessage?
    private var continuation: CheckedContinuation<Void, Error>?

    func write(message: NFCNDEFMessage, alertMessage: String) async throws {
        guard NFCNDEFReaderSession.readingAvailable else {
            throw NFCCardShareError.notAvailable
        }

        self.message = message

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let session = NFCNDEFReaderSession(
                delegate: self,
                queue: .main,
                invalidateAfterFirstRead: false
            )
            session.alertMessage = alertMessage
            self.session = session
            session.begin()
        }
    }

    // MARK: - NFCNDEFReaderSessionDelegate

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {}

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {}

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first, let message = self.message else {
            session.invalidate(errorMessage: "No tag found")
            return
        }

        session.connect(to: tag) { [weak self] error in
            if let error {
                session.invalidate(errorMessage: error.localizedDescription)
                self?.continuation?.resume(throwing: NFCCardShareError.writeFailed(error.localizedDescription))
                self?.continuation = nil
                return
            }

            tag.queryNDEFStatus { status, capacity, error in
                if let error {
                    session.invalidate(errorMessage: error.localizedDescription)
                    self?.continuation?.resume(throwing: NFCCardShareError.writeFailed(error.localizedDescription))
                    self?.continuation = nil
                    return
                }

                guard status == .readWrite else {
                    session.invalidate(errorMessage: "Tag is not writable")
                    self?.continuation?.resume(throwing: NFCCardShareError.tagNotWritable)
                    self?.continuation = nil
                    return
                }

                let payloadSize = message.length
                guard payloadSize <= capacity else {
                    session.invalidate(errorMessage: "Card data too large for this tag")
                    self?.continuation?.resume(throwing: NFCCardShareError.payloadTooLarge)
                    self?.continuation = nil
                    return
                }

                tag.writeNDEF(message) { error in
                    if let error {
                        session.invalidate(errorMessage: "Write failed: \(error.localizedDescription)")
                        self?.continuation?.resume(throwing: NFCCardShareError.writeFailed(error.localizedDescription))
                    } else {
                        session.alertMessage = "Business card written to NFC tag!"
                        session.invalidate()
                        self?.continuation?.resume()
                    }
                    self?.continuation = nil
                }
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        let nfcError = error as? NFCReaderError
        if nfcError?.code == .readerSessionInvalidationErrorUserCanceled {
            continuation?.resume(throwing: NFCCardShareError.cancelled)
        } else if continuation != nil {
            continuation?.resume(throwing: NFCCardShareError.sessionInvalidated(error.localizedDescription))
        }
        continuation = nil
        self.session = nil
    }
}

// MARK: - Dependency Registration

extension NFCCardShareClient: DependencyKey {
    public static let liveValue: NFCCardShareClient = {
        let writer = NFCWriter()
        return NFCCardShareClient(
            isAvailable: {
                NFCNDEFReaderSession.readingAvailable
            },
            writeURL: { url in
                guard let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: url) else {
                    throw NFCCardShareError.writeFailed("Invalid URL")
                }
                let message = NFCNDEFMessage(records: [payload])
                try await writer.write(
                    message: message,
                    alertMessage: "Hold your iPhone near an NFC tag to write your card"
                )
            },
            writeVCard: { vCardString in
                guard let data = vCardString.data(using: .utf8) else {
                    throw NFCCardShareError.writeFailed("Invalid vCard data")
                }
                let payload = NFCNDEFPayload(
                    format: .media,
                    type: "text/vcard".data(using: .utf8)!,
                    identifier: Data(),
                    payload: data
                )
                let message = NFCNDEFMessage(records: [payload])
                try await writer.write(
                    message: message,
                    alertMessage: "Hold your iPhone near an NFC tag to write your contact card"
                )
            }
        )
    }()

    public static let testValue = NFCCardShareClient(
        isAvailable: { false },
        writeURL: { _ in },
        writeVCard: { _ in }
    )
}

extension DependencyValues {
    public var nfcCardShareClient: NFCCardShareClient {
        get { self[NFCCardShareClient.self] }
        set { self[NFCCardShareClient.self] = newValue }
    }
}
