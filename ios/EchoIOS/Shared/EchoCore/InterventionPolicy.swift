import Foundation

public struct InterventionCopy: Equatable, Sendable {
    public let title: String
    public let subtitle: String
    public let primaryAction: String
    public let secondaryAction: String

    public init(title: String, subtitle: String, primaryAction: String, secondaryAction: String) {
        self.title = title
        self.subtitle = subtitle
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }
}

public enum InterventionPolicy {
    public static func copy(for snapshot: PlanSnapshot, now: Date = .now) -> InterventionCopy {
        guard let item = snapshot.focusItem(at: now) else {
            return InterventionCopy(
                title: "Ты точно сюда хотел?",
                subtitle: "Сделай паузу на десять секунд и выбери действие осознанно.",
                primaryAction: "Вернуться",
                secondaryAction: "Продолжить осознанно"
            )
        }

        let isActive = item.isActive(at: now)
        let title = isActive ? "Сейчас по плану" : "Следующее по плану"
        let time = timeLabel(for: item, timezoneIdentifier: snapshot.timezoneIdentifier)
        let rawSubtitle = time.map { "\($0) · \(item.title)" } ?? item.title

        return InterventionCopy(
            title: title,
            subtitle: bounded(rawSubtitle, limit: 120),
            primaryAction: "Вернуться к плану",
            secondaryAction: "Продолжить осознанно"
        )
    }

    private static func timeLabel(for item: PlanItem, timezoneIdentifier: String) -> String? {
        guard let startsAt = item.startsAt else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone(identifier: timezoneIdentifier)
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: startsAt)
    }

    private static func bounded(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(max(0, limit - 1))).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}
