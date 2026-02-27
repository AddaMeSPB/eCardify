import SwiftUI

// MARK: - Spacing Constants (8pt Grid)

/// Spacing values following Apple's 8pt grid system.
public enum ECSpacing {
    /// 4pt — tight spacing between related elements
    public static let xxs: CGFloat = 4

    /// 8pt — compact spacing within components
    public static let xs: CGFloat = 8

    /// 12pt — small gap between elements
    public static let sm: CGFloat = 12

    /// 16pt — standard spacing (Apple default)
    public static let md: CGFloat = 16

    /// 20pt — comfortable spacing between sections
    public static let lg: CGFloat = 20

    /// 24pt — generous spacing
    public static let xl: CGFloat = 24

    /// 32pt — large section spacing
    public static let xxl: CGFloat = 32

    /// 48pt — hero/feature spacing
    public static let xxxl: CGFloat = 48
}

// MARK: - Corner Radius

public enum ECRadius {
    /// 8pt — small elements (chips, badges)
    public static let sm: CGFloat = 8

    /// 12pt — cards, text fields
    public static let md: CGFloat = 12

    /// 16pt — large cards, sheets
    public static let lg: CGFloat = 16

    /// 24pt — full-rounded buttons
    public static let xl: CGFloat = 24

    /// Capsule — pill shape
    public static let capsule: CGFloat = .infinity
}

// MARK: - Minimum Touch Target

public enum ECTouchTarget {
    /// 44pt — Apple's minimum recommended touch target
    public static let minimum: CGFloat = 44
}
