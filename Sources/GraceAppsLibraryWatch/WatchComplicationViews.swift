#if os(watchOS)
import SwiftUI
import WidgetKit

// MARK: - Timeline Entry & Provider

public struct WatchComplicationEntry<State>: TimelineEntry {
    public let date: Date
    public let state: State?

    public init(date: Date = Date(), state: State? = nil) {
        self.date = date
        self.state = state
    }
}

/// Generic `TimelineProvider` that reads cached `Codable` state from an App Group `UserDefaults`.
public struct WatchCachedStateProvider<State: Codable>: TimelineProvider {
    private let appGroupDefaults: UserDefaults?
    private let cacheKey: String
    private let placeholderState: State?
    private let decoder = JSONDecoder()

    public init(
        appGroupSuiteName: String,
        cacheKey: String,
        placeholderState: State? = nil
    ) {
        self.appGroupDefaults = UserDefaults(suiteName: appGroupSuiteName)
        self.cacheKey = cacheKey
        self.placeholderState = placeholderState
    }

    public func placeholder(in context: Context) -> WatchComplicationEntry<State> {
        WatchComplicationEntry(date: Date(), state: placeholderState)
    }

    public func getSnapshot(in context: Context, completion: @escaping (WatchComplicationEntry<State>) -> Void) {
        completion(WatchComplicationEntry(date: Date(), state: loadCachedState() ?? placeholderState))
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<WatchComplicationEntry<State>>) -> Void) {
        let entry = WatchComplicationEntry(date: Date(), state: loadCachedState())
        completion(Timeline(entries: [entry], policy: .never))
    }

    private func loadCachedState() -> State? {
        guard let data = appGroupDefaults?.data(forKey: cacheKey) else { return nil }
        return try? decoder.decode(State.self, from: data)
    }
}

/// Static `TimelineProvider` for simple app-launcher Watch complications.
public struct WatchStaticComplicationProvider: TimelineProvider {
    public init() {}

    public func placeholder(in context: Context) -> WatchComplicationEntry<Never> {
        WatchComplicationEntry(date: Date(), state: nil)
    }

    public func getSnapshot(in context: Context, completion: @escaping (WatchComplicationEntry<Never>) -> Void) {
        completion(WatchComplicationEntry(date: Date(), state: nil))
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<WatchComplicationEntry<Never>>) -> Void) {
        completion(Timeline(entries: [WatchComplicationEntry(date: Date(), state: nil)], policy: .never))
    }
}

// MARK: - Launcher Complication View

/// Reusable watchOS complication view supporting circular, rectangular, inline, and corner families.
public struct WatchLauncherComplicationView: View {
    @Environment(\.widgetFamily) private var family

    private let systemImage: String
    private let title: String
    private let subtitle: LocalizedStringKey?

    public init(
        systemImage: String,
        title: String,
        subtitle: LocalizedStringKey? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .widgetAccentable()
            }
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .widgetAccentable()

                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.headline)
                        .widgetAccentable()
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Tap to Open", bundle: .module)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryInline:
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .widgetAccentable()
                Text(title)
            }
        case .accessoryCorner:
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(Color.accentColor)
                .widgetAccentable()
        @unknown default:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .widgetAccentable()
            }
        }
    }
}

// MARK: - Progress Complication View

/// Reusable `Gauge`-based watchOS complication view for goal/timer apps.
public struct WatchProgressComplicationView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    private let systemImage: String
    private let title: String
    private let subtitle: String
    private let progress: Double
    private let timerStart: Date?

    public init(
        systemImage: String,
        title: String,
        subtitle: String,
        progress: Double,
        timerStart: Date? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
        self.progress = min(max(progress, 0), 1)
        self.timerStart = timerStart
    }

    public var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: progress) {
                Image(systemName: systemImage)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .widgetAccentable()
        case .accessoryCorner:
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .widgetAccentable()
                .widgetLabel {
                    Gauge(value: progress) {
                        Text(title)
                    }
                    .gaugeStyle(.accessoryLinearCapacity)
                }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: systemImage)
                        .foregroundStyle(Color.accentColor)
                        .widgetAccentable()
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                }
                if let timerStart, !isLuminanceReduced {
                    Text(timerStart, style: .timer)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Gauge(value: progress) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .widgetAccentable()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryInline:
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .widgetAccentable()
                Text(subtitle)
            }
        @unknown default:
            Gauge(value: progress) {
                Image(systemName: systemImage)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .widgetAccentable()
        }
    }
}
#endif
