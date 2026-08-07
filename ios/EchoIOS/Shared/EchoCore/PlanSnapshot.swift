import Foundation

public enum PlanItemKind: String, Codable, CaseIterable, Sendable {
    case calendarEvent
    case timeBlock
    case task
}

public enum PlanSource: String, Codable, Sendable {
    case preview
    case local
    case echoServer
}

public struct PlanItem: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var startsAt: Date?
    public var endsAt: Date?
    public var kind: PlanItemKind

    public init(id: String, title: String, startsAt: Date?, endsAt: Date?, kind: PlanItemKind) {
        self.id = id
        self.title = title
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.kind = kind
    }

    public func isActive(at date: Date) -> Bool {
        guard let startsAt, startsAt <= date, let endsAt else { return false }
        return date < endsAt
    }
}

public struct PlanSnapshot: Codable, Equatable, Sendable {
    public var generatedAt: Date
    public var timezoneIdentifier: String
    public var items: [PlanItem]
    public var source: PlanSource

    public init(
        generatedAt: Date,
        timezoneIdentifier: String,
        items: [PlanItem],
        source: PlanSource = .local
    ) {
        self.generatedAt = generatedAt
        self.timezoneIdentifier = timezoneIdentifier
        self.items = items
        self.source = source
    }

    public func focusItem(at date: Date, calendar: Calendar? = nil) -> PlanItem? {
        let active = items
            .filter { $0.isActive(at: date) }
            .sorted { ($0.startsAt ?? .distantPast) > ($1.startsAt ?? .distantPast) }
            .first
        if let active { return active }

        return items
            .filter { ($0.startsAt ?? .distantPast) > date }
            .sorted { ($0.startsAt ?? .distantFuture) < ($1.startsAt ?? .distantFuture) }
            .first
    }

    public func items(on date: Date, calendar suppliedCalendar: Calendar? = nil) -> [PlanItem] {
        var calendar = suppliedCalendar ?? Calendar(identifier: .gregorian)
        if suppliedCalendar == nil, let zone = TimeZone(identifier: timezoneIdentifier) {
            calendar.timeZone = zone
        }

        return items
            .filter { item in
                guard let startsAt = item.startsAt else { return false }
                return calendar.isDate(startsAt, inSameDayAs: date)
            }
            .sorted { ($0.startsAt ?? .distantFuture) < ($1.startsAt ?? .distantFuture) }
    }

    public static func preview(referenceDate: Date = .now) -> PlanSnapshot {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid") ?? .current
        let startOfDay = calendar.startOfDay(for: referenceDate)
        let at: (Int, Int) -> Date = { hour, minute in
            calendar.date(byAdding: DateComponents(hour: hour, minute: minute), to: startOfDay)!
        }

        return PlanSnapshot(
            generatedAt: referenceDate,
            timezoneIdentifier: calendar.timeZone.identifier,
            items: [
                PlanItem(id: "preview-1", title: "Выбрать один главный результат дня", startsAt: at(9, 0), endsAt: at(9, 30), kind: .task),
                PlanItem(id: "preview-2", title: "Глубокая работа над Echo", startsAt: at(10, 0), endsAt: at(12, 0), kind: .timeBlock),
                PlanItem(id: "preview-3", title: "Семья и восстановление", startsAt: at(19, 0), endsAt: at(21, 0), kind: .calendarEvent)
            ],
            source: .preview
        )
    }
}
