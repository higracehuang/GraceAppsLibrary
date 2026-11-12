import UIKit

/// A mock full-screen interstitial ad view controller used during automated UI testing
/// to verify ad presentation, timing, and dismissal without hitting live ad networks.
public final class MockInterstitialAdViewController: UIViewController {
    private let onDismiss: () -> Void
    
    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.accessibilityIdentifier = "mockInterstitialAd"
        
        let label = UILabel()
        label.text = "Sponsored Ad"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.accessibilityIdentifier = "mockAdTitle"
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Close Ad", for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        closeButton.accessibilityIdentifier = "closeAdButton"
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onDismiss()
        }
    }
}
