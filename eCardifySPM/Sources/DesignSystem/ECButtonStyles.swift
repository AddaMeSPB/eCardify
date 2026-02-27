import SwiftUI

// MARK: - Primary Button Style

/// Full-width primary action button with brand color.
public struct ECPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ECTypography.headline())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: ECTouchTarget.minimum)
            .background(
                isEnabled
                    ? (configuration.isPressed ? ECColors.primaryDark : ECColors.primary)
                    : Color.gray.opacity(0.3)
            )
            .clipShape(RoundedRectangle(cornerRadius: ECRadius.md))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style

/// Outlined button with brand color border.
public struct ECSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ECTypography.headline())
            .foregroundStyle(isEnabled ? ECColors.primary : .gray)
            .frame(maxWidth: .infinity, minHeight: ECTouchTarget.minimum)
            .background(
                configuration.isPressed
                    ? ECColors.primary.opacity(0.08)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: ECRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: ECRadius.md)
                    .stroke(isEnabled ? ECColors.primary : .gray.opacity(0.3), lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Destructive Button Style

/// Red destructive action button.
public struct ECDestructiveButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ECTypography.headline())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: ECTouchTarget.minimum)
            .background(configuration.isPressed ? Color.red.opacity(0.8) : Color.red)
            .clipShape(RoundedRectangle(cornerRadius: ECRadius.md))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Convenience Extensions

public extension ButtonStyle where Self == ECPrimaryButtonStyle {
    static var ecPrimary: ECPrimaryButtonStyle { ECPrimaryButtonStyle() }
}

public extension ButtonStyle where Self == ECSecondaryButtonStyle {
    static var ecSecondary: ECSecondaryButtonStyle { ECSecondaryButtonStyle() }
}

public extension ButtonStyle where Self == ECDestructiveButtonStyle {
    static var ecDestructive: ECDestructiveButtonStyle { ECDestructiveButtonStyle() }
}
