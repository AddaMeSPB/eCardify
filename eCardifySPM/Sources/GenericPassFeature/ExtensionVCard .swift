import Foundation
import ECardifySharedModels
import FoundationExtension
import LoggerKit

extension VCard {

    /// Creates a new `VCard` instance by parsing a vCard string.
    ///
    /// - Parameter vCardString: The string representation of the vCard.
    /// - Returns: A new `VCard` instance if the parsing is successful, otherwise nil.
    public static func create(from vCardString: String) -> VCard? {
        // Split the vCard string into individual lines

        var vCard = VCard(
            contact: Contact.empty,
            formattedName: "",
            organization: nil,
            position: "",
            website: "",
            socialMedia: .empty
        )

        func getType(from line: String) -> String? {
            guard let typeStartIndex = line.range(of: "TYPE=")?.upperBound else { return nil }
            let typeEndIndex = line[line.index(after: typeStartIndex)...].firstIndex(of: ",") ?? line.endIndex
            return String(line[typeStartIndex..<typeEndIndex])
        }

        var contactProperties: [String: [String]] = [:]

        vCardString.enumerateLines { line, _ in
            // Ignore lines that don't have a colon separator
            guard line.contains(":") else {
                return
            }

            // Split the line into property name and value
            let components = line.split(separator: ":", maxSplits: 1)
            let propertyName = String(components[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let propertyValue = String(components[1]).trimmingCharacters(in: .whitespacesAndNewlines)

            if let existingValues = contactProperties[propertyName] {
                // Append value to existing property
                contactProperties[propertyName] = existingValues + [propertyValue]
            } else {
                // Add new property with value
                contactProperties[propertyName] = [propertyValue]
            }
        }

        // Access parsed vCard properties

        if let webSite = contactProperties["https"]?.first {
            vCard.website = "https:\(webSite)"
        }

        if let firstANDLastname = contactProperties["N"]?.first {
            let components = firstANDLastname.components(separatedBy: ";").filter { !$0.isEmpty }
            if components.count >= 1 {
                vCard.contact.firstName = components[0]
            }
            if components.count >= 2 {
                vCard.contact.lastName  = components[1]
            }
            if components.count >= 3 {
                vCard.contact.additionalName = components[2]
            }
        }

        if let name = contactProperties["FN"]?.first {
            let fullName = name.components(separatedBy: " ")
            vCard.contact.firstName = fullName.first ?? ""
            vCard.contact.lastName = fullName.last ?? ""
        }

        if let title = contactProperties["TITLE"]?.first {
            vCard.position = title
        }

        let phoneNumbers = contactProperties.keys.filter({ $0.hasPrefix("TEL") })
        for phoneNumberKey in phoneNumbers {
            if let phoneNumber = contactProperties[phoneNumberKey]?.first {
                let type = getType(from: phoneNumberKey) ?? "work"
                let rawValue = Telephone.TType(rawValue: type)
                vCard.telephones.append(.init(type: rawValue ?? .cell, number: phoneNumber))
            }
        }

        let emails = contactProperties.keys.filter({ $0.hasPrefix("EMAIL") })
        for emailKey in emails {
            if let email = contactProperties[emailKey]?.first {
                vCard.emails.append(.init(text: email))
            }
        }


        let urls = contactProperties.keys.filter({ $0.hasPrefix("URL") })
        for urlKey in urls {
            if let url = contactProperties[urlKey]?.first {
                vCard.urls.append(URL(string: url) ?? URL(string: "https://www.apple.com")!)
                vCard.website = url
            }
        }

        let addresses = contactProperties.keys.filter({ $0.hasPrefix("ADR") })

        for adrKey in addresses {
            if let adr = contactProperties[adrKey]?.first {

                let addrType = getType(from: adrKey) ?? "work"
                let components = adr.split(separator: ";").filter { !$0.isEmpty }
                let addressFinel = components.joined(separator: ", ")

                let type = VCard.Address.AType(rawValue: addrType) ?? .work
                sharedLogger.log(addressFinel)

                let addressAfterParse = VCard.Address.create(from: addressFinel, type: type)
                if let addressNonOptional = addressAfterParse {
                    vCard.addresses.append(addressNonOptional)
                }
            }
        }

        if let organization = contactProperties["ORG"]?.first {
            vCard.organization = organization
        }

        if let organization = contactProperties["ORG"]?.first {
            vCard.organization = organization
        }

        return vCard

    }

}


extension VCard.Address {
    public static func create(from addressString: String, type: VCard.Address.AType) -> Self? {

        var isDetectAddress: Bool = false
        let detector = NSDataDetector(types: .address)
        var vCardAddress = VCard.Address(
            type: type,
            postOfficeAddress: "nil",
            extendedAddress: nil,
            street: "",
            locality: "",
            region: nil,
            postalCode: "",
            country: ""
        )

        detector.enumerateMatches(in: addressString) { result, matchingFlags, bool  in
            if let type = result?.type, case let .address(components: addressComponents) = type {
                isDetectAddress = true

                if let street = addressComponents[.street] {
                    vCardAddress.street = street
                }

                if let postalCode = addressComponents[.zip] {
                    vCardAddress.postalCode = postalCode
                }

                if let state = addressComponents[.state] {
                    vCardAddress.region = state
                }

                if let city = addressComponents[.city] {
                    vCardAddress.locality = city
                }

                if let country = addressComponents[.country] {
                    vCardAddress.country = country
                }
            }
        }

        if !isDetectAddress {

                func findMatch(for pattern: String, in text: String) -> String? {
                    do {
                        let regex = try NSRegularExpression(pattern: pattern, options: [])
                        let range = NSRange(text.startIndex..., in: text)
                        if let match = regex.firstMatch(in: text, options: [], range: range) {
                            return String(text[Range(match.range, in: text)!])
                        }
                    } catch {
                        sharedLogger.logError("Error creating regex: \(error)")
                    }
                    return nil
                }

                var parsedAddress: [String: String] = [:]

                // Keywords for identifying components
                let countryKeywords = ["country"]
                let stateKeywords = ["state", "province", "region"]
                let cityKeywords = ["city", "town"]

                // Regular expression patterns for postcode and city
                let postcodePattern = "\\d{5}-?\\d{3}|\\d{3}-?\\d{2}|\\d{4,}"
                let cityPattern = "[A-Za-z\\s]+"

                var components = addressString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

                // Extract the country from the last component
                parsedAddress["country"] = components.removeLast()

                for component in components {
                    if countryKeywords.contains(where: { component.localizedCaseInsensitiveContains($0) }) {
                        parsedAddress["country"] = component
                    } else if stateKeywords.contains(where: { component.localizedCaseInsensitiveContains($0) }) {
                        parsedAddress["state"] = component
                    } else if cityKeywords.contains(where: { component.localizedCaseInsensitiveContains($0) }) {
                        parsedAddress["city"] = component
                    } else {
                        if let existingAddress = parsedAddress["address"] {
                            parsedAddress["address"] = "\(existingAddress), \(component)"
                        } else {
                            parsedAddress["address"] = component
                        }
                    }
                }

                // Find postcode and city using regular expressions
                let addressString = addressString.lowercased()
                if let postcode = findMatch(for: postcodePattern, in: addressString) {
                    parsedAddress["postcode"] = postcode
                }
                if let city = findMatch(for: cityPattern, in: addressString) {
                    parsedAddress["city"] = city.capitalized
                }

                guard let country = parsedAddress["country"],
                      let address = parsedAddress["address"],
                      let postcode = parsedAddress["postcode"],
                      let city = parsedAddress["city"] else {
                    return nil
                }

                let state = parsedAddress["state"]
                let extendedAddress = parsedAddress["extendedAddress"]

                vCardAddress.postOfficeAddress = address
                vCardAddress.extendedAddress = extendedAddress
                vCardAddress.street = "" // Update with the correct street value if available
                vCardAddress.locality = city
                vCardAddress.region = state
                vCardAddress.postalCode = postcode
                vCardAddress.country = country
                return vCardAddress

        } else {
            return vCardAddress
        }
    }
}

extension String {
    func isURLDetected() -> Bool {
        do {
            // Create a data detector with the URL type
            let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

            // Find the first URL in the string
            let range = NSRange(location: 0, length: self.utf16.count)
            let firstMatch = detector.firstMatch(in: self, options: [], range: range)

            // Return true if a URL is detected, false otherwise
            return firstMatch != nil && firstMatch!.url != nil
        } catch {
            return false
        }
    }
}



let vCardStringExm = """
    BEGIN:VCARD
    N:Khandoker;Saroar;
    FN:Saroar Khandoker
    TITLE: IOS Developer
    TEL;TYPE=cell,VOICE:1234567890
    TEL;TYPE=work,VOICE:9876543210
    TEL;TYPE=home,VOICE:5678901234
    PHOTO;VALUE=URL:http://example.com/photo.jpg
    EMAIL:email@example.com
    URL:http://example.com
    ADR;TYPE=WORK,PREF:;;123 Main St;Portugal
    ORG:Company
    END:VCARD
"""

let vCardStringExm1 = """
    BEGIN:VCARD
    N:Smith;John;
    TEL;TYPE=work,VOICE:(111) 555-1212
    TEL;TYPE=home,VOICE:(404) 386-1017
    TEL;TYPE=fax:(866) 408-1212
    EMAIL:smith.j@smithdesigns.com
    ORG:Smith Designs LLC
    TITLE:Lead Designer
    ADR;TYPE=WORK,PREF:;;151 Moore Avenue;Grand Rapids;MI;49503;United States of America
    URL:https://www.smithdesigns.com
    VERSION:3.0
    END:VCARD
"""

let vCardStringExm2 = """
    BEGIN:VCARD
    VERSION:4.0
    N:Gump;Forrest;;Mr.;
    FN:Sheri Nom
    ORG:Sheri Nom Co.
    TITLE:Ultimate Warrior
    PHOTO;MEDIATYPE#image/gif:http://www.sherinnom.com/dir_photos/my_photo.gif
    TEL;TYPE#work,voice;VALUE#uri:tel:+1-111-555-1212
    TEL;TYPE#home,voice;VALUE#uri:tel:+1-404-555-1212
    ADR;TYPE#WORK;PREF#1;LABEL#"Normality\nBaytown, LA 50514\nUnited States of America":;;100 Waters Edge;Baytown;LA;50514;United States of America
    ADR;TYPE#HOME;LABEL#"42 Plantation St.\nBaytown, LA 30314\nUnited States of America":;;42 Plantation St.;Baytown;LA;30314;United States of America
    EMAIL:sherinnom@example.com
    REV:20080424T195243Z
    x-qq:21588891
    END:VCARD
"""
