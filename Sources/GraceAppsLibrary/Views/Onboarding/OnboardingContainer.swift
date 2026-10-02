import SwiftUI

/// Animated capsule page indicator for onboarding carousels with accessibility and reduced motion support.
public struct OnboardingPageIndicator: View {
    public let totalCount: Int
    public let currentIndex: Int
    public let activeColor: Color
    public let inactiveColor: Color
    public let activeWidth: CGFloat
    public let dotSize: CGFloat
    public let spacing: CGFloat
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init(
        totalCount: Int,
        currentIndex: Int,
        activeColor: Color = .primary,
        inactiveColor: Color = Color.primary.opacity(0.2),
        activeWidth: CGFloat = 20,
        dotSize: CGFloat = 7,
        spacing: CGFloat = 8
    ) {
        self.totalCount = max(0, totalCount)
        self.currentIndex = max(0, min(currentIndex, max(0, totalCount - 1)))
        self.activeColor = activeColor
        self.inactiveColor = inactiveColor
        self.activeWidth = activeWidth
        self.dotSize = dotSize
        self.spacing = spacing
    }
    
    public var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<totalCount, id: \.self) { index in
                Capsule()
                    .fill(currentIndex == index ? activeColor : inactiveColor)
                    .frame(
                        width: currentIndex == index ? activeWidth : dotSize,
                        height: dotSize
                    )
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.7),
                        value: currentIndex
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Page \(currentIndex + 1) of \(max(1, totalCount))"))
    }
}

/// The master Onboarding shell coordinating slide pages, the animated indicator, and a stable bottom action tray.
public struct OnboardingContainer<SlidesContent: View, BottomContent: View>: View {
    @Binding public var currentStep: Int
    public let totalSteps: Int
    public let backgroundColor: Color
    public let indicatorActiveColor: Color
    public let indicatorInactiveColor: Color
    public let bottomTrayHeight: CGFloat
    @ViewBuilder public let slides: () -> SlidesContent
    @ViewBuilder public let bottomActions: () -> BottomContent
    
    public init(
        currentStep: Binding<Int>,
        totalSteps: Int,
        backgroundColor: Color = Color(.systemBackground),
        indicatorActiveColor: Color = .primary,
        indicatorInactiveColor: Color = Color.primary.opacity(0.2),
        bottomTrayHeight: CGFloat = 90,
        @ViewBuilder slides: @escaping () -> SlidesContent,
        @ViewBuilder bottomActions: @escaping () -> BottomContent
    ) {
        self._currentStep = currentStep
        self.totalSteps = totalSteps
        self.backgroundColor = backgroundColor
        self.indicatorActiveColor = indicatorActiveColor
        self.indicatorInactiveColor = indicatorInactiveColor
        self.bottomTrayHeight = bottomTrayHeight
        self.slides = slides
        self.bottomActions = bottomActions
    }
    
    public init(
        coordinator: OnboardingCoordinator,
        backgroundColor: Color = Color(.systemBackground),
        indicatorActiveColor: Color = .primary,
        indicatorInactiveColor: Color = Color.primary.opacity(0.2),
        bottomTrayHeight: CGFloat = 90,
        @ViewBuilder slides: @escaping () -> SlidesContent,
        @ViewBuilder bottomActions: @escaping () -> BottomContent
    ) {
        self.init(
            currentStep: Binding(
                get: { coordinator.currentStep },
                set: { coordinator.currentStep = $0 }
            ),
            totalSteps: coordinator.totalSteps,
            backgroundColor: backgroundColor,
            indicatorActiveColor: indicatorActiveColor,
            indicatorInactiveColor: indicatorInactiveColor,
            bottomTrayHeight: bottomTrayHeight,
            slides: slides,
            bottomActions: bottomActions
        )
    }
    
    public var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Main Slide Carousel
                TabView(selection: $currentStep) {
                    slides()
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Page Indicator
                if totalSteps > 1 {
                    OnboardingPageIndicator(
                        totalCount: totalSteps,
                        currentIndex: currentStep,
                        activeColor: indicatorActiveColor,
                        inactiveColor: indicatorInactiveColor
                    )
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                }
                
                // Bottom Action Tray (with fixed height to prevent layout jumps)
                VStack(spacing: 8) {
                    bottomActions()
                }
                .frame(minHeight: bottomTrayHeight, alignment: .top)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
    }
}
