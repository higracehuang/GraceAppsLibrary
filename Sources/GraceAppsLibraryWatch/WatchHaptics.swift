#if os(watchOS)
import WatchKit

/// Lightweight watchOS haptic feedback helper.
public enum WatchHaptics {
    public enum Kind {
        case start
        case stop
        case success
        case click
    }

    public static func play(_ kind: Kind) {
        let device = WKInterfaceDevice.current()
        switch kind {
        case .start:
            device.play(.start)
        case .stop:
            device.play(.stop)
        case .success:
            device.play(.success)
        case .click:
            device.play(.click)
        }
    }
}
#endif
