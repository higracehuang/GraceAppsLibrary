import UIKit

extension UIApplication {
    /// Resolves the currently active, top-most visible `UIViewController` across scenes,
    /// navigation stacks, tab bars, and presented modals.
    @MainActor
    public static func getTopViewController(base: UIViewController? = nil) -> UIViewController? {
        let baseVC: UIViewController? = base ?? {
            let scenes = shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .filter { $0.activationState == .foregroundActive }
            
            for scene in scenes {
                if let keyWindow = scene.windows.first(where: { $0.isKeyWindow && $0.windowLevel == .normal }),
                   let rootVC = keyWindow.rootViewController {
                    return rootVC
                }
            }
            
            // Fallback to any window scene if foregroundActive wasn't matched yet
            for scene in shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
                if let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first,
                   let rootVC = window.rootViewController {
                    return rootVC
                }
            }
            return nil
        }()
        
        guard var top = baseVC else { return nil }
        while true {
            if let nav = top as? UINavigationController, let visible = nav.visibleViewController {
                top = visible
            } else if let tab = top as? UITabBarController, let selected = tab.selectedViewController {
                top = selected
            } else if let presented = top.presentedViewController, !presented.isBeingDismissed {
                top = presented
            } else {
                break
            }
        }
        return top
    }
}
