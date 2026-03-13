import SwiftUI

// MARK: - Card Container

/// Modern card container with material background and subtle shadow.
public struct ECCard<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(ECSpacing.md)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: ECRadius.lg))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Empty State

/// Placeholder for empty lists/screens.
public struct ECEmptyState: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    public init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: ECSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(ECColors.primary.opacity(0.6))

            VStack(spacing: ECSpacing.xs) {
                Text(title)
                    .font(ECTypography.sectionTitle())
                    .foregroundStyle(ECColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(ECTypography.body())
                    .foregroundStyle(ECColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.ecPrimary)
                    .frame(maxWidth: 240)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(ECSpacing.xxl)
    }
}

// MARK: - Section Header

/// Consistent section header with optional trailing action.
public struct ECSectionHeader: View {
    let title: String
    let trailing: AnyView?

    public init(_ title: String) {
        self.title = title
        self.trailing = nil
    }

    public init(_ title: String, @ViewBuilder trailing: () -> some View) {
        self.title = title
        self.trailing = AnyView(trailing())
    }

    public var body: some View {
        HStack {
            Text(title)
                .font(ECTypography.headline())
                .foregroundStyle(ECColors.textPrimary)

            Spacer()

            trailing
        }
    }
}

// MARK: - Loading Overlay

/// Full-screen loading overlay with blur.
public struct ECLoadingOverlay: View {
    let message: String

    public init(_ message: String = "Loading...") {
        self.message = message
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: ECSpacing.md) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.2)
                    .tint(.white)

                Text(message)
                    .font(ECTypography.footnote())
                    .foregroundStyle(.white)
            }
            .padding(ECSpacing.xl)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: ECRadius.lg))
        }
    }
}

// MARK: - Required Field Indicator

/// Small red dot to indicate a required field.
public struct ECRequiredDot: View {
    public init() {}

    public var body: some View {
        Circle()
            .fill(ECColors.error)
            .frame(width: 6, height: 6)
    }
}

// MARK: - Tag/Badge

/// Small pill-shaped tag/badge.
public struct ECBadge: View {
    let text: String
    let color: Color

    public init(_ text: String, color: Color = ECColors.primary) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text)
            .font(ECTypography.caption(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, ECSpacing.xs)
            .padding(.vertical, ECSpacing.xxs)
            .background(color)
            .clipShape(Capsule())
    }
}
