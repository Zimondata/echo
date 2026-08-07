import Foundation

public struct DailyFocusWindow: Codable, Equatable, Sendable {
    public let startMinute: Int
    public let endMinute: Int

    public init(startMinute: Int, endMinute: Int) {
        self.startMinute = startMinute
        self.endMinute = endMinute
    }

    public var isValid: Bool {
        (0 ..< 24 * 60).contains(startMinute)
            && (0 ..< 24 * 60).contains(endMinute)
            && startMinute != endMinute
    }

    public var crossesMidnight: Bool {
        isValid && endMinute < startMinute
    }

    public func contains(minuteOfDay minute: Int) -> Bool {
        guard isValid, (0 ..< 24 * 60).contains(minute) else { return false }
        if crossesMidnight {
            return minute >= startMinute || minute < endMinute
        }
        return minute >= startMinute && minute < endMinute
    }
}
