import Foundation

// MARK: - Public Localization Helpers

/// Compile-time string literal localization.
/// Usage: `Text(L("Dashboard"))` or `Text(L("Renews \(dateStr)"))`
public func L(_ key: String.LocalizationValue) -> String {
    if let bundle = _screenshotBundle {
        let keyString: String
        let arguments: [String]
        let mirror = Mirror(reflecting: key)
        if let keyChild = mirror.children.first(where: { $0.label == "key" }) {
            keyString = keyChild.value as? String ?? "\(key)"
        } else {
            keyString = "\(key)"
        }
        arguments = _extractStringArguments(from: key)
        let template = bundle.localizedString(forKey: keyString, value: nil, table: nil)
        return arguments.isEmpty ? template : _formatString(template, arguments: arguments)
    }
    return String(localized: key, bundle: .module)
}

/// Runtime/dynamic key localization for enum rawValues and DB strings.
/// Usage: `Text(LDynamic(option.rawValue))`
public func LDynamic(_ key: String) -> String {
    if let bundle = _screenshotBundle {
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
    return Bundle.module.localizedString(forKey: key, value: nil, table: nil)
}

// MARK: - Private Helpers

private let _screenshotBundle: Bundle? = {
    guard let localeID = ProcessInfo.processInfo.environment["SCREENSHOT_LOCALE"],
          localeID != "en-US" else { return nil }

    let lprojName: String
    switch localeID {
    case "de-DE": lprojName = "de"
    case "fr-FR": lprojName = "fr"
    case "es-ES": lprojName = "es"
    case "pt-BR": lprojName = "pt-BR"
    case "zh-Hans": lprojName = "zh-Hans"
    case "ru-RU": lprojName = "ru"
    default: lprojName = localeID
    }

    guard let path = Bundle.module.path(forResource: lprojName, ofType: "lproj"),
          let bundle = Bundle(path: path) else { return nil }
    return bundle
}()

private func _extractStringArguments(from key: String.LocalizationValue) -> [String] {
    let mirror = Mirror(reflecting: key)
    guard let argsChild = mirror.children.first(where: { $0.label == "arguments" }) else { return [] }
    let argsMirror = Mirror(reflecting: argsChild.value)
    var results: [String] = []
    for child in argsMirror.children {
        let valueMirror = Mirror(reflecting: child.value)
        if let storage = valueMirror.children.first(where: { $0.label == "storage" }) {
            let storageMirror = Mirror(reflecting: storage.value)
            if let valueChild = storageMirror.children.first {
                switch valueChild.label {
                case "value":
                    if let s = valueChild.value as? String { results.append(s) }
                    else { results.append("\(valueChild.value)") }
                case "integer":
                    results.append("\(valueChild.value)")
                default:
                    results.append("\(valueChild.value)")
                }
            }
        }
    }
    return results
}

private func _formatString(_ template: String, arguments: [String]) -> String {
    var result = template
    // Handle positional specifiers first: %1$@, %1$lld, etc.
    for (index, arg) in arguments.enumerated() {
        result = result.replacingOccurrences(of: "%\(index + 1)$@", with: arg)
        result = result.replacingOccurrences(of: "%\(index + 1)$lld", with: arg)
    }
    // Handle sequential specifiers: %@, %lld
    for arg in arguments {
        if let range = result.range(of: "%@") {
            result = result.replacingCharacters(in: range, with: arg)
        } else if let range = result.range(of: "%lld") {
            result = result.replacingCharacters(in: range, with: arg)
        }
    }
    return result
}
