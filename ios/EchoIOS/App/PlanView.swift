import EchoCore
import SwiftUI

struct PlanView: View {
    @EnvironmentObject private var model: AppModel
    @State private var mode = 0
    @State private var selectedDate = Date()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                Picker("Период", selection: $mode) {
                    Text("Сегодня").tag(0)
                    Text("Месяц").tag(1)
                }
                .pickerStyle(.segmented)

                if mode == 0 {
                    today
                } else {
                    month
                }
            }
            .padding(18)
        }
        .background(Color.echoCanvas.ignoresSafeArea())
        .navigationTitle("Echo")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(dayLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.echoLavender)
            Text("План, который возвращает тебя к выбранному дню.")
                .font(.title2.bold())
        }
    }

    @ViewBuilder private var today: some View {
        let items = model.plan.items(on: Date())
        if let focus = model.plan.focusItem(at: Date()) {
            EchoCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Сейчас", systemImage: "scope")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.echoLavender)
                    Text(focus.title).font(.title3.bold())
                    if let startsAt = focus.startsAt {
                        Text(timeLabel(startsAt))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }

        VStack(spacing: 10) {
            ForEach(items) { item in
                PlanRow(item: item, timezoneIdentifier: model.plan.timezoneIdentifier)
            }
            if items.isEmpty {
                EchoCard {
                    Text("На сегодня ничего не запланировано. Это не ошибка — можно выбрать один главный шаг.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var month: some View {
        VStack(spacing: 14) {
            MonthGrid(selectedDate: $selectedDate, items: model.plan.items, timezoneIdentifier: model.plan.timezoneIdentifier)
            VStack(spacing: 10) {
                ForEach(model.plan.items(on: selectedDate)) { item in
                    PlanRow(item: item, timezoneIdentifier: model.plan.timezoneIdentifier)
                }
            }
        }
    }

    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone(identifier: model.plan.timezoneIdentifier)
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: .now)
    }

    private func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone(identifier: model.plan.timezoneIdentifier)
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct PlanRow: View {
    let item: PlanItem
    let timezoneIdentifier: String

    var body: some View {
        EchoCard {
            HStack(spacing: 14) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(.headline)
                    Text(meta).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private var color: Color {
        switch item.kind {
        case .calendarEvent: .pink
        case .timeBlock: Color.echoViolet
        case .task: .cyan
        }
    }

    private var meta: String {
        let kind = switch item.kind {
        case .calendarEvent: "Событие"
        case .timeBlock: "Блок фокуса"
        case .task: "Задача"
        }
        guard let startsAt = item.startsAt else { return kind }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone(identifier: timezoneIdentifier)
        formatter.timeStyle = .short
        return "\(formatter.string(from: startsAt)) · \(kind)"
    }
}

private struct MonthGrid: View {
    @Binding var selectedDate: Date
    let items: [PlanItem]
    let timezoneIdentifier: String
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale(identifier: "ru_RU")
        value.timeZone = TimeZone(identifier: timezoneIdentifier) ?? .current
        return value
    }

    var body: some View {
        EchoCard {
            VStack(spacing: 12) {
                Text(monthLabel)
                    .font(.headline)
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(calendar.veryShortWeekdaySymbols, id: \.self) { symbol in
                        Text(symbol.uppercased()).font(.caption2.bold()).foregroundStyle(.secondary)
                    }
                    ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                        if let date {
                            Button {
                                selectedDate = date
                            } label: {
                                VStack(spacing: 4) {
                                    Text("\(calendar.component(.day, from: date))")
                                        .font(.subheadline.weight(calendar.isDate(date, inSameDayAs: selectedDate) ? .bold : .regular))
                                    Circle()
                                        .fill(hasItems(on: date) ? Color.echoViolet : .clear)
                                        .frame(width: 4, height: 4)
                                }
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .background(calendar.isDate(date, inSameDayAs: selectedDate) ? Color.echoViolet.opacity(0.2) : .clear)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Color.clear.frame(height: 36)
                        }
                    }
                }
            }
        }
    }

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: selectedDate).capitalized
    }

    private var days: [Date?] {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))!
        let range = calendar.range(of: .day, in: .month, for: monthStart)!
        let weekday = calendar.component(.weekday, from: monthStart)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leading) + range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: monthStart)
        }
    }

    private func hasItems(on date: Date) -> Bool {
        items.contains { item in
            guard let startsAt = item.startsAt else { return false }
            return calendar.isDate(startsAt, inSameDayAs: date)
        }
    }
}
