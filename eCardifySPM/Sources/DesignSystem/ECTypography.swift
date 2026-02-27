import SwiftUI

// MARK: - Typography Scale

/// Consistent typography using SF Pro system fonts following Apple HIG.
public enum ECTypography {

    /// Screen titles — SF Pro Bold 34pt (matches .largeTitle)
    public static func largeTitle(_ weight: Font.Weight = .bold) -> Font {
        .system(.largeTitle, weight: weight)
    }

    /// Section headers — SF Pro Semibold 22pt (matches .title2)
    public static func sectionTitle(_ weight: Font.Weight = .semibold) -> Font {
        .system(.title2, weight: weight)
    }

    /// Card/item titles — SF Pro Semibold 17pt (matches .headline)
    public static func headline(_ weight: Font.Weight = .semibold) -> Font {
        .system(.headline, weight: weight)
    }

    /// Body content — SF Pro Regular 17pt
    public static func body(_ weight: Font.Weight = .regular) -> Font {
        .system(.body, weight: weight)
    }

    /// Secondary content — SF Pro Regular 15pt (matches .subheadline)
    public static func subheadline(_ weight: Font.Weight = .regular) -> Font {
        .system(.subheadline, weight: weight)
    }

    /// Labels/badges — SF Pro Medium 13pt (matches .footnote)
    public static func footnote(_ weight: Font.Weight = .medium) -> Font {
        .system(.footnote, weight: weight)
    }

    /// Small details — SF Pro Regular 12pt (matches .caption)
    public static func caption(_ weight: Font.Weight = .regular) -> Font {
        .system(.caption, weight: weight)
    }
}

// MARK: - View Modifier for Typography

public extension View {
    /// Apply a consistent typography style with color
    func ecTextStyle(
        _ font: Font,
        color: Color = ECColors.textPrimary
    ) -> some View {
        self
            .font(font)
            .foregroundStyle(color)
    }
}
