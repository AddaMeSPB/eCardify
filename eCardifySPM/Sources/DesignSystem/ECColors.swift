import SwiftUI

// MARK: - Brand Colors

public enum ECColors {

    // MARK: Primary

    /// Main brand color — used for primary buttons, active states, navigation
    public static let primary = Color("ECPrimary", bundle: .module)

    /// Darker primary — used for pressed/hover states
    public static let primaryDark = Color("ECPrimaryDark", bundle: .module)

    /// Lighter primary — used for tints, backgrounds, badges
    public static let primaryLight = Color("ECPrimaryLight", bundle: .module)

    // MARK: Accent

    /// Secondary action color — used for secondary CTAs, links
    public static let accent = Color("ECAccent", bundle: .module)

    // MARK: Status

    /// Success state — confirmations, completed actions
    public static let success = Color.green

    /// Warning state — caution indicators
    public static let warning = Color.orange

    /// Error state — validation errors, destructive actions
    public static let error = Color.red

    // MARK: Neutral

    /// Primary text color — adapts to light/dark mode
    public static let textPrimary = Color.primary

    /// Secondary text color — subtitles, captions
    public static let textSecondary = Color.secondary

    /// Surface background — cards, sheets
    public static let surface = Color(.systemBackground)

    /// Grouped background — behind grouped content
    public static let groupedBackground = Color(.systemGroupedBackground)

    /// Secondary grouped background — list rows in grouped style
    public static let secondaryGroupedBackground = Color(.secondarySystemGroupedBackground)

    /// Separator lines
    public static let separator = Color(.separator)
}

// MARK: - Adaptive Colors (light/dark auto)

public extension Color {
    /// Semantic primary brand color — teal/blue-green
    static let ecPrimary = ECColors.primary
    static let ecAccent = ECColors.accent
    static let ecSuccess = ECColors.success
    static let ecWarning = ECColors.warning
    static let ecError = ECColors.error
}
