import UIKit

/// A mock App Store rating dialog used during automated UI testing
/// to verify StoreKit review prompting, presentation, and dismissal without hitting StoreKit daemons.
public final class MockReviewPromptViewController: UIViewController {
    private let onDismiss: (() -> Void)?
    
    public init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *) {
            if let sheet = self.sheetPresentationController {
                sheet.detents = [.medium()]
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.accessibilityIdentifier = "storeKitReviewPrompt"
        
        let appName = Bundle.main.appName
        let titleLabel = UILabel()
        titleLabel.text = "Enjoying \(appName)?"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.accessibilityIdentifier = "reviewTitle"
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        let messageLabel = UILabel()
        messageLabel.text = "Tap a star to rate it on the App Store."
        messageLabel.font = .systemFont(ofSize: 16)
        messageLabel.textAlignment = .center
        messageLabel.textColor = .secondaryLabel
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(messageLabel)
        
        let submitButton = UIButton(type: .system)
        submitButton.setTitle("Submit", for: .normal)
        submitButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        submitButton.accessibilityIdentifier = "submitReviewButton"
        submitButton.translatesAutoresizingMaskIntoConstraints = false
        submitButton.addTarget(self, action: #selector(dismissPrompt), for: .touchUpInside)
        view.addSubview(submitButton)
        
        let notNowButton = UIButton(type: .system)
        notNowButton.setTitle("Not Now", for: .normal)
        notNowButton.titleLabel?.font = .systemFont(ofSize: 16)
        notNowButton.accessibilityIdentifier = "notNowReviewButton"
        notNowButton.translatesAutoresizingMaskIntoConstraints = false
        notNowButton.addTarget(self, action: #selector(dismissPrompt), for: .touchUpInside)
        view.addSubview(notNowButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            messageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            submitButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 28),
            submitButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            submitButton.heightAnchor.constraint(equalToConstant: 44),
            submitButton.widthAnchor.constraint(equalToConstant: 140),
            
            notNowButton.topAnchor.constraint(equalTo: submitButton.bottomAnchor, constant: 12),
            notNowButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            notNowButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc private func dismissPrompt() {
        dismiss(animated: true) { [weak self] in
            self?.onDismiss?()
        }
    }
}
