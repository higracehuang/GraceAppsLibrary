import SwiftUI

/// Defines the layout order of elements in an `OnboardingSlideLayout`.
public enum OnboardingSlideLayoutOrder: Equatable {
    /// Modern top-down sequence: Title and Subtitle at the top, followed by the content/card in the center.
    case titleFirst
    /// Classic sequence: Content/hero card at the top, followed by Title and Subtitle at the bottom.
    case contentFirst
}

/// A reusable slide layout template organizing content into a standardized Title -> Subtitle -> Content structure.
public struct OnboardingSlideLayout<CardContent: View, TrailingHeader: View>: View {
    public let cardTitle: Text
    public let narrativeTitle: Text
    public let narrativeSubtitle: Text
    public let layoutOrder: OnboardingSlideLayoutOrder
    public let cardBackgroundColor: Color
    public let cardCornerRadius: CGFloat
    public let cardPadding: CGFloat
    public let cardShadowRadius: CGFloat
    public let cardShadowColor: Color
    public let narrativeTextColor: Color
    public let narrativeSubtitleColor: Color
    public let isCardTitleUppercase: Bool
    @ViewBuilder public let cardTrailing: () -> TrailingHeader
    @ViewBuilder public let cardContent: () -> CardContent
    
    @Environment(\.sizeCategory) private var sizeCategory
    
    public init(
        cardTitle: Text = Text(""),
        narrativeTitle: Text,
        narrativeSubtitle: Text,
        layoutOrder: OnboardingSlideLayoutOrder = .titleFirst,
        cardBackgroundColor: Color = Color(.secondarySystemBackground),
        cardCornerRadius: CGFloat = 20,
        cardPadding: CGFloat = 16,
        cardShadowRadius: CGFloat = 0,
        cardShadowColor: Color = .clear,
        narrativeTextColor: Color = .primary,
        narrativeSubtitleColor: Color = .secondary,
        isCardTitleUppercase: Bool = true,
        @ViewBuilder cardTrailing: @escaping () -> TrailingHeader,
        @ViewBuilder cardContent: @escaping () -> CardContent
    ) {
        self.cardTitle = cardTitle
        self.narrativeTitle = narrativeTitle
        self.narrativeSubtitle = narrativeSubtitle
        self.layoutOrder = layoutOrder
        self.cardBackgroundColor = cardBackgroundColor
        self.cardCornerRadius = cardCornerRadius
        self.cardPadding = cardPadding
        self.cardShadowRadius = cardShadowRadius
        self.cardShadowColor = cardShadowColor
        self.narrativeTextColor = narrativeTextColor
        self.narrativeSubtitleColor = narrativeSubtitleColor
        self.isCardTitleUppercase = isCardTitleUppercase
        self.cardTrailing = cardTrailing
        self.cardContent = cardContent
    }
    
    public init(
        cardTitle: LocalizedStringKey = "",
        narrativeTitle: LocalizedStringKey,
        narrativeSubtitle: LocalizedStringKey,
        layoutOrder: OnboardingSlideLayoutOrder = .titleFirst,
        cardBackgroundColor: Color = Color(.secondarySystemBackground),
        cardCornerRadius: CGFloat = 20,
        cardPadding: CGFloat = 16,
        cardShadowRadius: CGFloat = 0,
        cardShadowColor: Color = .clear,
        narrativeTextColor: Color = .primary,
        narrativeSubtitleColor: Color = .secondary,
        isCardTitleUppercase: Bool = true,
        @ViewBuilder cardTrailing: @escaping () -> TrailingHeader,
        @ViewBuilder cardContent: @escaping () -> CardContent
    ) {
        self.init(
            cardTitle: Text(cardTitle),
            narrativeTitle: Text(narrativeTitle),
            narrativeSubtitle: Text(narrativeSubtitle),
            layoutOrder: layoutOrder,
            cardBackgroundColor: cardBackgroundColor,
            cardCornerRadius: cardCornerRadius,
            cardPadding: cardPadding,
            cardShadowRadius: cardShadowRadius,
            cardShadowColor: cardShadowColor,
            narrativeTextColor: narrativeTextColor,
            narrativeSubtitleColor: narrativeSubtitleColor,
            isCardTitleUppercase: isCardTitleUppercase,
            cardTrailing: cardTrailing,
            cardContent: cardContent
        )
    }
    
    private var isAccessibilitySize: Bool {
        sizeCategory.isAccessibilityCategory
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            switch layoutOrder {
            case .titleFirst:
                // 1. Narrative Section (Title + Subtitle) at top
                narrativeSection
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                
                // 2. Content / Card in the center
                Group {
                    if isAccessibilitySize {
                        ScrollView(.vertical, showsIndicators: true) {
                            cardBody
                        }
                    } else {
                        cardBody
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 8)
                
            case .contentFirst:
                Spacer(minLength: 12)
                
                // Content / Card at top
                Group {
                    if isAccessibilitySize {
                        ScrollView(.vertical, showsIndicators: true) {
                            cardBody
                        }
                    } else {
                        cardBody
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 18)
                
                // Narrative Section at bottom
                narrativeSection
                    .padding(.bottom, 6)
            }
        }
    }
    
    private var narrativeSection: some View {
        VStack(spacing: 8) {
            narrativeTitle
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(narrativeTextColor)
                .lineSpacing(2)
                .accessibilityAddTraits(.isHeader)
            
            narrativeSubtitle
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .foregroundColor(narrativeSubtitleColor)
                .padding(.horizontal, 24)
                .frame(minHeight: 38, alignment: .top)
        }
        .accessibilityElement(children: .combine)
    }
    
    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardContent()
        }
        .padding(cardPadding)
        .background(cardBackgroundColor)
        .cornerRadius(cardCornerRadius)
        .shadow(color: cardShadowColor, radius: cardShadowRadius, x: 0, y: 2)
    }
}

public extension OnboardingSlideLayout where TrailingHeader == EmptyView {
    init(
        cardTitle: Text = Text(""),
        narrativeTitle: Text,
        narrativeSubtitle: Text,
        layoutOrder: OnboardingSlideLayoutOrder = .titleFirst,
        cardBackgroundColor: Color = Color(.secondarySystemBackground),
        cardCornerRadius: CGFloat = 20,
        cardPadding: CGFloat = 16,
        cardShadowRadius: CGFloat = 0,
        cardShadowColor: Color = .clear,
        narrativeTextColor: Color = .primary,
        narrativeSubtitleColor: Color = .secondary,
        isCardTitleUppercase: Bool = true,
        @ViewBuilder cardContent: @escaping () -> CardContent
    ) {
        self.init(
            cardTitle: cardTitle,
            narrativeTitle: narrativeTitle,
            narrativeSubtitle: narrativeSubtitle,
            layoutOrder: layoutOrder,
            cardBackgroundColor: cardBackgroundColor,
            cardCornerRadius: cardCornerRadius,
            cardPadding: cardPadding,
            cardShadowRadius: cardShadowRadius,
            cardShadowColor: cardShadowColor,
            narrativeTextColor: narrativeTextColor,
            narrativeSubtitleColor: narrativeSubtitleColor,
            isCardTitleUppercase: isCardTitleUppercase,
            cardTrailing: { EmptyView() },
            cardContent: cardContent
        )
    }
    
    init(
        cardTitle: LocalizedStringKey = "",
        narrativeTitle: LocalizedStringKey,
        narrativeSubtitle: LocalizedStringKey,
        layoutOrder: OnboardingSlideLayoutOrder = .titleFirst,
        cardBackgroundColor: Color = Color(.secondarySystemBackground),
        cardCornerRadius: CGFloat = 20,
        cardPadding: CGFloat = 16,
        cardShadowRadius: CGFloat = 0,
        cardShadowColor: Color = .clear,
        narrativeTextColor: Color = .primary,
        narrativeSubtitleColor: Color = .secondary,
        isCardTitleUppercase: Bool = true,
        @ViewBuilder cardContent: @escaping () -> CardContent
    ) {
        self.init(
            cardTitle: Text(cardTitle),
            narrativeTitle: Text(narrativeTitle),
            narrativeSubtitle: Text(narrativeSubtitle),
            layoutOrder: layoutOrder,
            cardBackgroundColor: cardBackgroundColor,
            cardCornerRadius: cardCornerRadius,
            cardPadding: cardPadding,
            cardShadowRadius: cardShadowRadius,
            cardShadowColor: cardShadowColor,
            narrativeTextColor: narrativeTextColor,
            narrativeSubtitleColor: narrativeSubtitleColor,
            isCardTitleUppercase: isCardTitleUppercase,
            cardTrailing: { EmptyView() },
            cardContent: cardContent
        )
    }
}
