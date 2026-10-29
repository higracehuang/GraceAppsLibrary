import SwiftUI
import UIKit

/// Indicator style options for onboarding progress visualization.
public enum OnboardingIndicatorStyle: Equatable {
    /// Traditional animated capsule page dots at the bottom of the slides.
    case dots
    /// Continuous smooth progress bar rendered at the top of the container.
    case progressBar(height: CGFloat = 4, cornerRadius: CGFloat = 2)
    /// Segmented progress bar (one bar per step) rendered at the top of the container.
    case segmentedProgressBar(height: CGFloat = 4, spacing: CGFloat = 4, cornerRadius: CGFloat = 2)
    /// No progress indicator rendered.
    case none
}

/// Continuous animated progress bar for onboarding flows with accessibility and reduced motion support.
public struct OnboardingProgressBar: View {
    public let progress: Double // 0.0 ... 1.0
    public let activeColor: Color
    public let trackColor: Color
    public let height: CGFloat
    public let cornerRadius: CGFloat
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init(
        progress: Double,
        activeColor: Color = .primary,
        trackColor: Color = Color.primary.opacity(0.15),
        height: CGFloat = 4,
        cornerRadius: CGFloat = 2
    ) {
        self.progress = max(0.0, min(1.0, progress))
        self.activeColor = activeColor
        self.trackColor = trackColor
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(trackColor)
                    .frame(height: height)
                
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(activeColor)
                    .frame(width: max(0, geometry.size.width * CGFloat(progress)), height: height)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.8),
                        value: progress
                    )
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Progress: \(Int(progress * 100)) percent"))
    }
}

/// Segmented progress bar (one bar segment per step) for onboarding flows.
public struct OnboardingSegmentedProgressBar: View {
    public let totalSteps: Int
    public let currentStep: Int // 0..<totalSteps
    public let activeColor: Color
    public let trackColor: Color
    public let height: CGFloat
    public let spacing: CGFloat
    public let cornerRadius: CGFloat
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init(
        totalSteps: Int,
        currentStep: Int,
        activeColor: Color = .primary,
        trackColor: Color = Color.primary.opacity(0.15),
        height: CGFloat = 4,
        spacing: CGFloat = 4,
        cornerRadius: CGFloat = 2
    ) {
        self.totalSteps = max(1, totalSteps)
        self.currentStep = max(0, min(currentStep, totalSteps - 1))
        self.activeColor = activeColor
        self.trackColor = trackColor
        self.height = height
        self.spacing = spacing
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<totalSteps, id: \.self) { index in
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(index <= currentStep ? activeColor : trackColor)
                    .frame(height: height)
                    .animation(
                        reduceMotion ? .none : .easeInOut(duration: 0.25),
                        value: currentStep
                    )
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Step \(currentStep + 1) of \(totalSteps)"))
    }
}

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

/// The master Onboarding shell coordinating slide pages, the animated indicator / progress bar, and a stable bottom action tray.
public struct OnboardingContainer<SlidesContent: View, BottomContent: View>: View {
    @Binding public var currentStep: Int
    public let totalSteps: Int
    public let indicatorStyle: OnboardingIndicatorStyle
    public let backgroundColor: Color
    public let indicatorActiveColor: Color
    public let indicatorInactiveColor: Color
    public let bottomTrayHeight: CGFloat
    public let isSwipeEnabled: Bool
    @ViewBuilder public let slides: () -> SlidesContent
    @ViewBuilder public let bottomActions: () -> BottomContent
    
    public init(
        currentStep: Binding<Int>,
        totalSteps: Int,
        indicatorStyle: OnboardingIndicatorStyle = .dots,
        backgroundColor: Color = Color(.systemBackground),
        indicatorActiveColor: Color = .primary,
        indicatorInactiveColor: Color = Color.primary.opacity(0.2),
        bottomTrayHeight: CGFloat = 0,
        isSwipeEnabled: Bool = true,
        @ViewBuilder slides: @escaping () -> SlidesContent,
        @ViewBuilder bottomActions: @escaping () -> BottomContent
    ) {
        self._currentStep = currentStep
        self.totalSteps = totalSteps
        self.indicatorStyle = indicatorStyle
        self.backgroundColor = backgroundColor
        self.indicatorActiveColor = indicatorActiveColor
        self.indicatorInactiveColor = indicatorInactiveColor
        self.bottomTrayHeight = bottomTrayHeight
        self.isSwipeEnabled = isSwipeEnabled
        self.slides = slides
        self.bottomActions = bottomActions
    }
    
    public init(
        coordinator: OnboardingCoordinator,
        indicatorStyle: OnboardingIndicatorStyle = .dots,
        backgroundColor: Color = Color(.systemBackground),
        indicatorActiveColor: Color = .primary,
        indicatorInactiveColor: Color = Color.primary.opacity(0.2),
        bottomTrayHeight: CGFloat = 0,
        isSwipeEnabled: Bool = true,
        @ViewBuilder slides: @escaping () -> SlidesContent,
        @ViewBuilder bottomActions: @escaping () -> BottomContent
    ) {
        self.init(
            currentStep: Binding(
                get: { coordinator.currentStep },
                set: { coordinator.currentStep = $0 }
            ),
            totalSteps: coordinator.totalSteps,
            indicatorStyle: indicatorStyle,
            backgroundColor: backgroundColor,
            indicatorActiveColor: indicatorActiveColor,
            indicatorInactiveColor: indicatorInactiveColor,
            bottomTrayHeight: bottomTrayHeight,
            isSwipeEnabled: isSwipeEnabled,
            slides: slides,
            bottomActions: bottomActions
        )
    }
    
    private var tabSelection: Binding<Int> {
        Binding(
            get: { currentStep },
            set: { newValue in
                if isSwipeEnabled {
                    currentStep = newValue
                }
            }
        )
    }
    
    public var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Progress Bar (if configured)
                if totalSteps > 1 {
                    switch indicatorStyle {
                    case .progressBar(let height, let cornerRadius):
                        OnboardingProgressBar(
                            progress: Double(currentStep + 1) / Double(max(1, totalSteps)),
                            activeColor: indicatorActiveColor,
                            trackColor: indicatorInactiveColor,
                            height: height,
                            cornerRadius: cornerRadius
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, 12)
                        
                    case .segmentedProgressBar(let height, let spacing, let cornerRadius):
                        OnboardingSegmentedProgressBar(
                            totalSteps: totalSteps,
                            currentStep: currentStep,
                            activeColor: indicatorActiveColor,
                            trackColor: indicatorInactiveColor,
                            height: height,
                            spacing: spacing,
                            cornerRadius: cornerRadius
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, 12)
                        
                    case .dots, .none:
                        EmptyView()
                    }
                }
                
                // Main Slide Carousel
                TabView(selection: tabSelection) {
                    slides()
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .background(
                    OnboardingPageSwipeConfigurator(isSwipeEnabled: isSwipeEnabled)
                )
                
                // Bottom Page Indicator (if dots style)
                if totalSteps > 1 && indicatorStyle == .dots {
                    OnboardingPageIndicator(
                        totalCount: totalSteps,
                        currentIndex: currentStep,
                        activeColor: indicatorActiveColor,
                        inactiveColor: indicatorInactiveColor
                    )
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                
                // Bottom Action Tray
                VStack(spacing: 8) {
                    bottomActions()
                }
                .frame(height: bottomTrayHeight > 0 ? bottomTrayHeight : nil, alignment: .bottom)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
    }
}

private struct OnboardingPageSwipeConfigurator: UIViewRepresentable {
    let isSwipeEnabled: Bool

    func makeUIView(context: Context) -> SwipeConfiguratorView {
        let view = SwipeConfiguratorView()
        view.isSwipeEnabled = isSwipeEnabled
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: SwipeConfiguratorView, context: Context) {
        uiView.isSwipeEnabled = isSwipeEnabled
        uiView.applyConfiguration()
    }

    final class SwipeConfiguratorView: UIView {
        var isSwipeEnabled: Bool = true

        override func didMoveToWindow() {
            super.didMoveToWindow()
            applyConfiguration()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            applyConfiguration()
        }

        func applyConfiguration() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                var ancestor: UIView? = self.superview
                for _ in 0..<4 {
                    guard let current = ancestor else { break }
                    if Self.configurePagingScrollViews(in: current, isSwipeEnabled: self.isSwipeEnabled) {
                        return
                    }
                    ancestor = current.superview
                }
            }
        }

        @discardableResult
        private static func configurePagingScrollViews(in view: UIView, isSwipeEnabled: Bool) -> Bool {
            var found = false
            for subview in view.subviews {
                if let scrollView = subview as? UIScrollView {
                    let typeName = String(describing: type(of: scrollView))
                    if scrollView.isPagingEnabled || typeName.contains("QueuingScrollView") || typeName.contains("Page") {
                        scrollView.isScrollEnabled = isSwipeEnabled
                        scrollView.panGestureRecognizer.isEnabled = isSwipeEnabled
                        found = true
                    }
                }
                if configurePagingScrollViews(in: subview, isSwipeEnabled: isSwipeEnabled) {
                    found = true
                }
            }
            return found
        }
    }
}
