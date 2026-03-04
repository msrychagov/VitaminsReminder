import UIKit
import UserNotifications
import UserNotificationsUI

@objc(NotificationViewController)
final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private enum PayloadKeys {
        static let dosePerIntake = "reminder_dose_per_intake_text"
        static let frequency = "reminder_frequency_text"
        static let condition = "reminder_condition_text"
        static let interaction = "reminder_interaction_text"
        static let compatibility = "reminder_compatibility_text"
        static let contraindications = "reminder_contraindications_text"
        static let instruction = "reminder_instruction_text"
    }

    private let titleLabel = UILabel()
    private let instructionLabel = UILabel()
    private let dosePerIntakeLabel = UILabel()
    private let frequencyLabel = UILabel()
    private let conditionLabel = UILabel()
    private let interactionLabel = UILabel()
    private let compatibilityLabel = UILabel()
    private let contraindicationsLabel = UILabel()
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

        let instructionValue = trimmedString(for: PayloadKeys.instruction, in: content.userInfo)
        instructionLabel.text = instructionValue ?? content.body

        let dosePerIntake = trimmedString(for: PayloadKeys.dosePerIntake, in: content.userInfo)
        let frequency = trimmedString(for: PayloadKeys.frequency, in: content.userInfo)
        let condition = trimmedString(for: PayloadKeys.condition, in: content.userInfo)
        let interaction = trimmedString(for: PayloadKeys.interaction, in: content.userInfo)
        let compatibility = trimmedString(for: PayloadKeys.compatibility, in: content.userInfo)
        let contraindications = trimmedString(for: PayloadKeys.contraindications, in: content.userInfo)

        dosePerIntakeLabel.attributedText = dosePerIntake.flatMap { formattedLine(title: "Доза за прием", value: $0) }
        frequencyLabel.attributedText = frequency.flatMap { formattedLine(title: "Частота", value: $0) }
        conditionLabel.attributedText = condition.flatMap { formattedLine(title: "Условие", value: $0) }
        interactionLabel.attributedText = interaction.flatMap { formattedLine(title: "Взаимодействие", value: $0) }
        compatibilityLabel.attributedText = compatibility.flatMap { formattedLine(title: "Совместимость", value: $0) }
        contraindicationsLabel.attributedText = contraindications.flatMap { formattedLine(title: "Противопоказания", value: $0) }

        dosePerIntakeLabel.isHidden = dosePerIntake == nil
        frequencyLabel.isHidden = frequency == nil
        conditionLabel.isHidden = condition == nil
        interactionLabel.isHidden = interaction == nil
        compatibilityLabel.isHidden = compatibility == nil
        contraindicationsLabel.isHidden = contraindications == nil

        view.setNeedsLayout()
        view.layoutIfNeeded()
        updatePreferredContentSize()
    }

    private func applyPlaceholderContent() {
        titleLabel.text = "Примите витамин!"
        instructionLabel.text = "Удерживайте, чтобы отметить прием и увидеть дополнительную информацию"

        dosePerIntakeLabel.isHidden = true
        frequencyLabel.isHidden = true
        conditionLabel.isHidden = true
        interactionLabel.isHidden = true
        compatibilityLabel.isHidden = true
        contraindicationsLabel.isHidden = true
        view.setNeedsLayout()
        view.layoutIfNeeded()
        updatePreferredContentSize()
    }

    private func setupView() {
        view.backgroundColor = .clear

        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let contentLabels = [
            titleLabel, instructionLabel,
            dosePerIntakeLabel, frequencyLabel, conditionLabel,
            interactionLabel, compatibilityLabel, contraindicationsLabel
        ]
        contentLabels.forEach {
            $0.numberOfLines = 0
            stackView.addArrangedSubview($0)
        }

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = primaryTextColor

        instructionLabel.font = .preferredFont(forTextStyle: .subheadline)
        instructionLabel.textColor = primaryTextColor

        [dosePerIntakeLabel, frequencyLabel, conditionLabel, interactionLabel, compatibilityLabel, contraindicationsLabel].forEach {
            $0.font = .preferredFont(forTextStyle: .body)
            $0.textColor = primaryTextColor
        }

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
