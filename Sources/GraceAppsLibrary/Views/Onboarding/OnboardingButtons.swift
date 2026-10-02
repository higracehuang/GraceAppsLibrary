import SwiftUI

/// Standard primary onboarding action button with built-in loading spinner and accessibility support.
public struct OnboardingPrimaryButton: View {
    public let title: Text
    public let isLoading: Bool
    public let backgroundColor: Color
    public let foregroundColor: Color?
    public let cornerRadius: CGFloat
    public let action: () -> Void
    
    public init(
        title: Text,
        isLoading: Bool = false,
        backgroundColor: Color = .primary,
        foregroundColor: Color? = nil,
        cornerRadius: CGFloat = 16,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.cornerRadius = cornerRadius
        self.action = action
    }
    
    public init(
        title: LocalizedStringKey,
        isLoading: Bool = false,
        backgroundColor: Color = .primary,
        foregroundColor: Color? = nil,
        cornerRadius: CGFloat = 16,
        action: @escaping () -> Void
    ) {
        self.init(
            title: Text(title),
            isLoading: isLoading,
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            cornerRadius: cornerRadius,
            action: action
        )
    }
    
    private var resolvedForegroundColor: Color {
        if let foregroundColor = foregroundColor {
            return foregroundColor
        }
        return backgroundColor == .primary ? Color(.systemBackground) : .white
    }
    
    public var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: resolvedForegroundColor))
                } else {
                    title
                        .font(.headline)
                        .foregroundColor(resolvedForegroundColor)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
        }
        .disabled(isLoading)
        .accessibilityAddTraits(.isButton)
    }
}

/// Standard secondary text button for skip or optional secondary actions.
public struct OnboardingSecondaryButton: View {
    public let title: Text
    public let foregroundColor: Color
    public let action: () -> Void
    
    /// Default initialization using GraceAppsLibrary built-in localized "Skip for now" translation.
    public init(
        foregroundColor: Color = .secondary,
        action: @escaping () -> Void
    ) {
        self.title = Text(LocalizedStringKey(Constants.StringKeys.onboardingSkip), bundle: .module)
        self.foregroundColor = foregroundColor
        self.action = action
    }
    
    public init(
        title: Text,
        foregroundColor: Color = .secondary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.foregroundColor = foregroundColor
        self.action = action
    }
    
    public init(
        title: LocalizedStringKey,
        foregroundColor: Color = .secondary,
        action: @escaping () -> Void
    ) {
        self.init(
            title: Text(title),
            foregroundColor: foregroundColor,
            action: action
        )
    }
    
    public var body: some View {
        Button(action: action) {
            title
                .font(.subheadline)
                .foregroundColor(foregroundColor)
                .padding(.vertical, 4)
        }
        .accessibilityAddTraits(.isButton)
    }
}
