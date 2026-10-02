import SwiftUI

/// A reusable slide layout template splitting content between a top/center Hero Card and a bottom Narrative section.
public struct OnboardingSlideLayout<CardContent: View, TrailingHeader: View>: View {
    public let cardTitle: Text
    public let narrativeTitle: Text
    public let narrativeSubtitle: Text
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
        cardTitle: Text,
        narrativeTitle: Text,
        narrativeSubtitle: Text,
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
        cardTitle: LocalizedStringKey,
        narrativeTitle: LocalizedStringKey,
        narrativeSubtitle: LocalizedStringKey,
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
            Spacer(minLength: 12)
            
            // Hero Card
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
            
            // Narrative section (Title + Subtitle)
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
                    .padding(.horizontal, 28)
                    .frame(minHeight: 40, alignment: .top)
            }
            .padding(.bottom, 6)
            .accessibilityElement(children: .combine)
        }
    }
    
    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                cardTitle
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(narrativeTextColor.opacity(0.6))
                    .textCase(isCardTitleUppercase ? .uppercase : nil)
                
                Spacer()
                
                cardTrailing()
            }
            
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
        cardTitle: Text,
        narrativeTitle: Text,
        narrativeSubtitle: Text,
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
        cardTitle: LocalizedStringKey,
        narrativeTitle: LocalizedStringKey,
        narrativeSubtitle: LocalizedStringKey,
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
