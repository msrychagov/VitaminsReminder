import UIKit
import UserNotifications
import UserNotificationsUI

@objc(NotificationViewController)
final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private enum PayloadKeys {
        static let doseText = "reminder_dose_text"
        static let conditionText = "reminder_condition_text"
        static let interactionText = "reminder_interaction_text"
    }

    private enum FallbackText {
        static let doseText = "1 капсула 1 раз в день"
        static let conditionText = "Следуйте рекомендациям по приему."
        static let interactionText = "Нет данных о взаимодействии."
    }

    private let titleLabel = UILabel()
    private let instructionLabel = UILabel()
    private let doseLabel = UILabel()
    private let conditionLabel = UILabel()
    private let interactionLabel = UILabel()
    private let stackView = UIStackView()
    private let primaryTextColor = UIColor.black
    private var currentContent: UNNotificationContent?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        if let currentContent {
            apply(content: currentContent)
        } else {
            applyPlaceholderContent()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updatePreferredContentSize()
    }

    func didReceive(_ notification: UNNotification) {
        currentContent = notification.request.content
        loadViewIfNeeded()
        apply(content: notification.request.content)
    }

    private func apply(content: UNNotificationContent) {
        titleLabel.text = content.title
        instructionLabel.text = content.body

        let doseValue = trimmedString(for: PayloadKeys.doseText, in: content.userInfo) ?? FallbackText.doseText
        let conditionValue = trimmedString(for: PayloadKeys.conditionText, in: content.userInfo) ?? FallbackText.conditionText
        let interactionValue = trimmedString(for: PayloadKeys.interactionText, in: content.userInfo) ?? FallbackText.interactionText

        doseLabel.attributedText = formattedLine(
            title: "Дозировка",
            value: doseValue
        )
        conditionLabel.attributedText = formattedLine(
            title: "Условия приема",
            value: conditionValue
        )
        interactionLabel.attributedText = formattedLine(
            title: "Взаимодействие",
            value: interactionValue
        )
        doseLabel.isHidden = false
        conditionLabel.isHidden = false
        interactionLabel.isHidden = false
        view.setNeedsLayout()
        view.layoutIfNeeded()
        updatePreferredContentSize()
    }

    private func applyPlaceholderContent() {
        titleLabel.text = "Примите витамин!"
        instructionLabel.text = "Удерживайте, чтобы отметить прием и увидеть дополнительную информацию"

        doseLabel.attributedText = formattedLine(title: "Дозировка", value: FallbackText.doseText)
        conditionLabel.attributedText = formattedLine(title: "Условия приема", value: FallbackText.conditionText)
        interactionLabel.attributedText = formattedLine(title: "Взаимодействие", value: FallbackText.interactionText)

        doseLabel.isHidden = false
        conditionLabel.isHidden = false
        interactionLabel.isHidden = false
        view.setNeedsLayout()
        view.layoutIfNeeded()
        updatePreferredContentSize()
    }

    private func setupView() {
        view.backgroundColor = .clear

        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false

        [titleLabel, instructionLabel, doseLabel, conditionLabel, interactionLabel].forEach {
            $0.numberOfLines = 0
            stackView.addArrangedSubview($0)
        }

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = primaryTextColor

        instructionLabel.font = .preferredFont(forTextStyle: .subheadline)
        instructionLabel.textColor = primaryTextColor

        doseLabel.font = .preferredFont(forTextStyle: .body)
        doseLabel.textColor = primaryTextColor

        conditionLabel.font = .preferredFont(forTextStyle: .body)
        conditionLabel.textColor = primaryTextColor

        interactionLabel.font = .preferredFont(forTextStyle: .body)
        interactionLabel.textColor = primaryTextColor

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
        ])
    }

    private func formattedLine(title: String, value: String?) -> NSAttributedString? {
        guard let value else { return nil }

        let fullText = "\(title): \(value)"
        let result = NSMutableAttributedString(
            string: fullText,
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: primaryTextColor
            ]
        )

        let titleRange = NSRange(location: 0, length: title.count + 1)
        result.addAttributes(
            [
                .font: UIFont.boldSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize),
                .foregroundColor: primaryTextColor
            ],
            range: titleRange
        )

        return result
    }

    private func trimmedString(for key: String, in userInfo: [AnyHashable: Any]) -> String? {
        guard let raw = userInfo[key] as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func updatePreferredContentSize() {
        let fittingWidth = max(view.bounds.width, UIScreen.main.bounds.width) - 32
        guard fittingWidth > 0 else { return }

        let targetSize = CGSize(width: fittingWidth, height: UIView.layoutFittingCompressedSize.height)
        let measured = stackView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        preferredContentSize = CGSize(width: fittingWidth, height: min(max(measured.height + 32, 1), 420))
    }
}
