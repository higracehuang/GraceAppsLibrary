import SwiftUI
import GraceAppsLibrary
import RevenueCat
import RevenueCatUI

/// Style variant for `UniversalSubscriptionSection`.
public enum UniversalSubscriptionStyle: Sendable {
    /// High-impact visual card featuring a gradient crown icon, tier name, PRO badge,
    /// bulleted feature list, and a prominent CTA button.
    case hero
    /// Standard Apple HIG form row with crown/sparkles icon, status text, and navigation/action buttons.
    case compact
}

/// A bullet point item for `UniversalSubscriptionStyle.hero`.
public struct UniversalSubscriptionFeature: Identifiable {
    public let id: String
    public let icon: String
    public let title: LocalizedStringKey

    public init(id: String? = nil, icon: String = "checkmark.circle.fill", title: LocalizedStringKey) {
        self.icon = icon
        self.title = title
        self.id = id ?? "\(icon)_\(UUID().uuidString)"
    }
}

/// A standardized user-facing subscription section for app Settings screens.
///
/// Automatically binds to `UniversalPurchaseCoordinator.shared` to display the active
/// or upgrade state, supports `.hero` and `.compact` visual presentations, and wires up
/// RevenueCat's `PaywallView` and `CustomerCenterView`.
///
/// Features and chrome strings are fully localized via GraceAppsLibrary and the host app bundle.
public struct UniversalSubscriptionSection: View {
    @ObservedObject private var coordinator: UniversalPurchaseCoordinator = .shared

    public let style: UniversalSubscriptionStyle
    public let showHeader: Bool
    public let headerTitle: LocalizedStringKey?
    public let tierName: String?
    public let subtitle: LocalizedStringKey?
    public let features: [UniversalSubscriptionFeature]
    public let gradientColors: [Color]
    public let upgradeAccessibilityIdentifier: String
    public let paywallAction: (() -> Void)?
    public let manageAction: (() -> Void)?

    @State private var showCustomerCenterSheet: Bool = false

    public init(
        style: UniversalSubscriptionStyle = .hero,
        showHeader: Bool? = nil,
        headerTitle: LocalizedStringKey? = nil,
        tierName: String? = nil,
        subtitle: LocalizedStringKey? = nil,
        features: [UniversalSubscriptionFeature] = [],
        gradientColors: [Color] = [Color.orange, Color.yellow],
        upgradeAccessibilityIdentifier: String = "settings.upgradeToPremiumButton",
        paywallAction: (() -> Void)? = nil,
        manageAction: (() -> Void)? = nil
    ) {
        self.style = style
        self.showHeader = showHeader ?? (style == .compact)
        self.headerTitle = headerTitle
        self.tierName = tierName
        self.subtitle = subtitle
        self.features = features
        self.gradientColors = gradientColors
        self.upgradeAccessibilityIdentifier = upgradeAccessibilityIdentifier
        self.paywallAction = paywallAction
        self.manageAction = manageAction
    }

    /// Convenience initializer accepting localized string keys for features.
    public init(
        style: UniversalSubscriptionStyle = .hero,
        showHeader: Bool? = nil,
        headerTitle: LocalizedStringKey? = nil,
        tierName: String? = nil,
        subtitle: LocalizedStringKey? = nil,
        features: [LocalizedStringKey],
        gradientColors: [Color] = [Color.orange, Color.yellow],
        upgradeAccessibilityIdentifier: String = "settings.upgradeToPremiumButton",
        paywallAction: (() -> Void)? = nil,
        manageAction: (() -> Void)? = nil
    ) {
        self.init(
            style: style,
            showHeader: showHeader,
            headerTitle: headerTitle,
            tierName: tierName,
            subtitle: subtitle,
            features: features.map { UniversalSubscriptionFeature(title: $0) },
            gradientColors: gradientColors,
            upgradeAccessibilityIdentifier: upgradeAccessibilityIdentifier,
            paywallAction: paywallAction,
            manageAction: manageAction
        )
    }

    private var resolvedTierName: String {
        tierName ?? coordinator.tierName
    }

    public var body: some View {
        Group {
            if showHeader {
                Section(header: Text(headerTitle ?? "subscription.section_title", bundle: .graceAppsLibrary)) {
                    sectionContent
                }
            } else {
                Section {
                    sectionContent
                }
            }
        }
        .sheet(isPresented: $showCustomerCenterSheet) {
            CustomerCenterView()
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        if coordinator.isPro {
            switch style {
            case .hero:
                heroActiveView
            case .compact:
                compactActiveView
            }
        } else {
            switch style {
            case .hero:
                heroFreeView
            case .compact:
                compactFreeView
            }
        }
    }

    // MARK: - Hero Free View

    private var heroFreeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Image(systemName: "crown.fill")
                        .foregroundColor(.white)
                        .font(.title3.weight(.bold))
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(verbatim: resolvedTierName)
                            .font(.headline.weight(.bold))
                            .foregroundColor(.primary)
                        Spacer()
                        proBadge
                    }

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if !features.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(features) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: feature.icon)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(gradientColors.first ?? .orange)
                                .frame(width: 16)
                            Text(feature.title)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }

            Button(action: handleUpgradeTap) {
                HStack {
                    Spacer()
                    Text("subscription.upgrade_to \(resolvedTierName)", bundle: .graceAppsLibrary)
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                    Spacer()
                }
                .padding(.vertical, 10)
                .foregroundColor(.white)
                .background(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(BorderlessButtonStyle())
            .accessibilityIdentifier(upgradeAccessibilityIdentifier)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Hero Active View

    private var heroActiveView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Image(systemName: "crown.fill")
                        .foregroundColor(.white)
                        .font(.subheadline.weight(.bold))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(resolvedTierName) \(String(localized: "subscription.active", bundle: .graceAppsLibrary))")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.primary)
                    Text("subscription.unlocked_all", bundle: .graceAppsLibrary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                proBadge
            }

            Button(action: handleManageTap) {
                HStack {
                    Label(
                        title: { Text("subscription.manage", bundle: .graceAppsLibrary) },
                        icon: { Image(systemName: "person.crop.circle.badge.checkmark") }
                    )
                    .font(.footnote.weight(.medium))
                    .foregroundColor(gradientColors.first ?? .orange)
                }
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.vertical, 4)
    }

    // MARK: - Compact Free View

    private var compactFreeView: some View {
        Button(action: handleUpgradeTap) {
            Label(
                title: { Text("subscription.upgrade_to \(resolvedTierName)", bundle: .graceAppsLibrary) },
                icon: { Image(systemName: "crown") }
            )
            .foregroundStyle(.tint)
        }
        .accessibilityIdentifier(upgradeAccessibilityIdentifier)
    }

    // MARK: - Compact Active View

    private var compactActiveView: some View {
        Group {
            HStack {
                Label(resolvedTierName, systemImage: "sparkles")
                Spacer()
                Text("subscription.active", bundle: .graceAppsLibrary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button(action: handleManageTap) {
                Label(
                    title: { Text("subscription.manage", bundle: .graceAppsLibrary) },
                    icon: { Image(systemName: "person.crop.circle.badge.checkmark") }
                )
            }
        }
    }

    // MARK: - Badges & Actions

    private var proBadge: some View {
        Text("subscription.pro_badge", bundle: .graceAppsLibrary)
            .font(.caption2.weight(.bold))
            .foregroundColor(gradientColors.first ?? .orange)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background((gradientColors.first ?? .orange).opacity(0.14))
            .clipShape(Capsule())
    }

    private func handleUpgradeTap() {
        if let paywallAction = paywallAction {
            paywallAction()
        } else {
            UniversalPaywallPresenter.present(trigger: "settings_upgrade")
        }
    }

    private func handleManageTap() {
        if let manageAction = manageAction {
            manageAction()
        } else {
            showCustomerCenterSheet = true
        }
    }
}
