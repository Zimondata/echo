import DeviceActivity
import FamilyControls
import Foundation
import SwiftUI
import EchoCore

@MainActor
final class AppModel: ObservableObject {
    @Published var plan: PlanSnapshot
    @Published var selection: FamilyActivitySelection
    @Published var authorizationStatus: AuthorizationStatus
    @Published var isPickerPresented = false
    @Published var focusEnabled: Bool
    @Published var scheduleEnabled: Bool
    @Published var scheduleStart: Date
    @Published var scheduleEnd: Date
    @Published var message: String?

    init() {
        let snapshot = PlanSnapshot.preview()
        let defaults = UserDefaults(suiteName: EchoAppGroup.identifier)
        let startMinute = defaults?.object(forKey: EchoAppGroup.scheduleStartMinuteKey) as? Int ?? 9 * 60
        let endMinute = defaults?.object(forKey: EchoAppGroup.scheduleEndMinuteKey) as? Int ?? 20 * 60

        self.plan = snapshot
        self.selection = FamilySelectionStore()?.load() ?? FamilyActivitySelection()
        self.authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        self.focusEnabled = defaults?.bool(forKey: EchoAppGroup.focusEnabledKey) ?? false
        self.scheduleEnabled = defaults?.bool(forKey: EchoAppGroup.scheduleEnabledKey) ?? false
        self.scheduleStart = Self.date(minuteOfDay: startMinute)
        self.scheduleEnd = Self.date(minuteOfDay: endMinute)
        try? SharedPlanSnapshotStore()?.save(snapshot)
    }

    var selectedCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    var focusWindow: DailyFocusWindow {
        DailyFocusWindow(startMinute: minuteOfDay(scheduleStart), endMinute: minuteOfDay(scheduleEnd))
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
            message = authorizationStatus == .approved ? "Доступ к Screen Time включён" : "Apple не дала доступ к Screen Time"
        } catch {
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
            message = error.localizedDescription
        }
    }

    func persistSelection() {
        do {
            try FamilySelectionStore()?.save(selection)
            if focusEnabled || (scheduleEnabled && focusWindow.contains(minuteOfDay: minuteOfDay(.now))) {
                ShieldController.apply(selection)
            }
            message = selectedCount == 0 ? "Сначала выбери приложения" : "Выбор сохранён приватно"
        } catch {
            message = error.localizedDescription
        }
    }

    func enableFocus() {
        persistSelection()
        guard authorizationStatus == .approved else {
            message = "Сначала разреши Screen Time"
            return
        }
        guard selectedCount > 0 else { return }
        ShieldController.apply(selection)
        focusEnabled = true
        UserDefaults(suiteName: EchoAppGroup.identifier)?.set(true, forKey: EchoAppGroup.focusEnabledKey)
        message = "Выбранные приложения теперь показывают твой план"
    }

    func disableFocus() {
        focusEnabled = false
        UserDefaults(suiteName: EchoAppGroup.identifier)?.set(false, forKey: EchoAppGroup.focusEnabledKey)
        if scheduleEnabled && focusWindow.contains(minuteOfDay: minuteOfDay(.now)) {
            ShieldController.apply(selection)
        } else {
            ShieldController.clear()
        }
        message = "Постоянная блокировка выключена"
    }

    func setSchedule(enabled: Bool) {
        guard !enabled || authorizationStatus == .approved else {
            scheduleEnabled = false
            message = "Сначала разреши Screen Time"
            return
        }
        guard !enabled || selectedCount > 0 else {
            scheduleEnabled = false
            message = "Сначала выбери приложения"
            return
        }
        guard focusWindow.isValid else {
            scheduleEnabled = false
            message = "Начало и конец расписания должны отличаться"
            return
        }

        let defaults = UserDefaults(suiteName: EchoAppGroup.identifier)
        if enabled {
            persistSelection()
            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: focusWindow.startMinute / 60, minute: focusWindow.startMinute % 60),
                intervalEnd: DateComponents(hour: focusWindow.endMinute / 60, minute: focusWindow.endMinute % 60),
                repeats: true
            )
            do {
                try DeviceActivityCenter().startMonitoring(.echoFocus, during: schedule)
                scheduleEnabled = true
                if focusWindow.contains(minuteOfDay: minuteOfDay(.now)) {
                    ShieldController.apply(selection)
                }
                defaults?.set(true, forKey: EchoAppGroup.scheduleEnabledKey)
                defaults?.set(focusWindow.startMinute, forKey: EchoAppGroup.scheduleStartMinuteKey)
                defaults?.set(focusWindow.endMinute, forKey: EchoAppGroup.scheduleEndMinuteKey)
                message = "Ежедневное расписание включено"
            } catch {
                scheduleEnabled = false
                message = error.localizedDescription
            }
        } else {
            DeviceActivityCenter().stopMonitoring([.echoFocus])
            scheduleEnabled = false
            defaults?.set(false, forKey: EchoAppGroup.scheduleEnabledKey)
            if !focusEnabled { ShieldController.clear() }
            message = "Расписание выключено"
        }
    }

    func refreshPreviewPlan() {
        let snapshot = PlanSnapshot.preview()
        plan = snapshot
        try? SharedPlanSnapshotStore()?.save(snapshot)
        message = "Локальный план обновлён"
    }

    private func minuteOfDay(_ date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    private static func date(minuteOfDay: Int) -> Date {
        Calendar.current.date(
            bySettingHour: minuteOfDay / 60,
            minute: minuteOfDay % 60,
            second: 0,
            of: .now
        ) ?? .now
    }
}
