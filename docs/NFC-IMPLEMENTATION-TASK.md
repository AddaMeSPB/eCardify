# eCardify — NFC Business Card Sharing (iOS Team Task)

## What
Add NFC tag writing/reading so users can tap phones to share their digital business card.

## Why
- "NFC business card" is a high-value keyword with low competition
- Differentiator — most digital card apps don't have NFC
- Hardware-free NFC sharing (iPhone to iPhone, or iPhone to NFC tag)

## Requirements
- iOS 13+ (CoreNFC available since iOS 13)
- iPhone 7+ (NFC reading), iPhone XS+ (NFC writing/background reading)

## Implementation Steps

### 1. Add CoreNFC Framework
- In Xcode: Target → General → Frameworks → Add `CoreNFC`
- Or in Package.swift if using SPM

### 2. Info.plist Entries
```xml
<key>NFCReaderUsageDescription</key>
<string>Tap to share your business card via NFC</string>
<key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>
<array>
    <string>D2760000850101</string>
</array>
```

### 3. Entitlements
Add "Near Field Communication Tag Reading" capability in Signing & Capabilities.

### 4. Two NFC Modes

#### Mode A: Share via NFC Tag (Write to physical tag)
User buys an NFC tag/sticker, writes their vCard to it. Anyone with a phone can tap to get the contact.

```swift
import CoreNFC

class NFCCardWriter: NSObject, NFCNDEFReaderSessionDelegate {
    var session: NFCNDEFReaderSession?
    var cardURL: URL?
    
    func writeCard(profileURL: URL) {
        self.cardURL = profileURL
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = "Hold your iPhone near an NFC tag to write your card"
        session?.begin()
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first, let url = cardURL else { return }
        
        session.connect(to: tag) { error in
            guard error == nil else { return }
            
            tag.queryNDEFStatus { status, capacity, error in
                guard status == .readWrite else {
                    session.invalidate(errorMessage: "Tag is not writable")
                    return
                }
                
                let urlRecord = NFCNDEFPayload.wellKnownTypeURIPayload(url: url)!
                let message = NFCNDEFMessage(records: [urlRecord])
                
                tag.writeNDEF(message) { error in
                    if let error = error {
                        session.invalidate(errorMessage: "Write failed: \(error.localizedDescription)")
                    } else {
                        session.alertMessage = "Card written successfully!"
                        session.invalidate()
                    }
                }
            }
        }
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {}
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {}
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {}
}
```

#### Mode B: Tap-to-Share (iPhone to iPhone via background tag reading)
When another iPhone taps, it reads the NFC tag and opens the eCardify profile URL.
This works automatically with the URL NDEF record written above — iOS opens the URL in Safari.

#### Mode C: vCard on NFC Tag (direct contact save)
```swift
func createVCardPayload(name: String, phone: String, email: String) -> NFCNDEFPayload {
    let vcard = """
    BEGIN:VCARD
    VERSION:3.0
    FN:\(name)
    TEL:\(phone)
    EMAIL:\(email)
    END:VCARD
    """
    let data = vcard.data(using: .utf8)!
    return NFCNDEFPayload(format: .media, type: "text/vcard".data(using: .utf8)!, identifier: Data(), payload: data)
}
```

### 5. UI Integration
- Add "Share via NFC" button on card detail screen
- Show NFC animation while waiting for tap
- Success/failure feedback
- Device capability check: `NFCNDEFReaderSession.readingAvailable`

### 6. ASO Keywords to Add After NFC Launch
- "NFC business card"
- "tap to share contact"
- "digital NFC card"
- "contactless business card"
- "NFC vCard"

## Out of Scope
- Android Beam / HCE (iOS only)
- NFC payment integration
- Custom NFC chip ordering (just support standard NDEF tags)

## Testing
- Need physical NFC tags (NTAG213 or NTAG215, ~$0.50 each)
- Test with iPhone XS or newer (NFC writing)
- Test background tag reading with iPhone XS or newer
