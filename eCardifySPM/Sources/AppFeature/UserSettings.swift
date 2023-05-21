import SwiftUI

public struct UserSettings: Codable, Equatable {
  public var colorScheme: ColorScheme

  public enum ColorScheme: String, CaseIterable, Codable {
    case dark
    case light
    case system

    public var userInterfaceStyle: UIUserInterfaceStyle {
      switch self {
      case .dark:
        return .dark
      case .light:
        return .light
      case .system:
        return .unspecified
      }
    }
  }

  public init(colorScheme: ColorScheme = .system) {
    self.colorScheme = colorScheme
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.colorScheme = (try? container.decode(ColorScheme.self, forKey: .colorScheme)) ?? .system
  }
}
