import DeviceActivity
import FamilyControls
import Foundation
import SwiftUI
import EchoCore
import EchoScreenTime

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

    private let appGroupDefaults: UserDefaults?
    private let familySelectionStore: FamilySelectionStore?
    private let planSnapshotStore: SharedPlanSnapshotStore?
    private let scheduleSideEffects: ScheduleSideEffects

    init(scheduleSideEffects: ScheduleSideEffects = .live) {
        let snapshot = PlanSnapshot.preview()
        let defaults = UserDefaults(suiteName: EchoAppGroup.identifier)
        let selectionStore = try? FamilySelectionStore()
        let snapshotStore = try? SharedPlanSnapshotStore()
        let startMinute = defaults?.object(forKey: EchoAppGroup.scheduleStartMinuteKey) as? Int ?? 9 * 60
        let endMinute = defaults?.object(forKey: EchoAppGroup.scheduleEndMinuteKey) as? Int ?? 20 * 60

        self.appGroupDefaults = defaults
        self.familySelectionStore = selectionStore
        self.planSnapshotStore = snapshotStore
        self.scheduleSideEffects = scheduleSideEffects
        self.plan = snapshot
        self.selection = selectionStore?.load() ?? FamilyActivitySelection()
        self.authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        self.focusEnabled = defaults?.bool(forKey: EchoAppGroup.focusEnabledKey) ?? false
        self.scheduleEnabled = defaults?.bool(forKey: EchoAppGroup.scheduleEnabledKey) ?? false
        self.scheduleStart = Self.date(minuteOfDay: startMinute)
        self.scheduleEnd = Self.date(minuteOfDay: endMinute)
        self.message = nil

        guard defaults != nil, selectionStore != nil, let snapshotStore else {
            self.focusEnabled = false
            self.scheduleEnabled = false
            self.message = EchoSharedStoreError.appGroupUnavailable(EchoAppGroup.identifier).localizedDescription
            ShieldController.clear()
            return
        }

        do {
            try snapshotStore.save(snapshot)
        } catch {
            self.focusEnabled = false
            self.scheduleEnabled = false
            self.message = error.localizedDescription
            ShieldController.clear()
        }
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

    @discardableResult
    func persistSelection() -> Bool {
        guard let familySelectionStore, let planSnapshotStore else {
            message = EchoSharedStoreError.appGroupUnavailable(EchoAppGroup.identifier).localizedDescription
            return false
        }

        do {
            try familySelectionStore.save(selection)
            try planSnapshotStore.save(plan)
            if focusEnabled || (scheduleEnabled && focusWindow.contains(minuteOfDay: minuteOfDay(.now))) {
                ShieldController.apply(selection)
            }
            message = selectedCount == 0 ? "Сначала выбери приложения" : "Выбор сохранён приватно"
            return true
        } catch {
            message = error.localizedDescription
            return false
        }
    }

    func enableFocus() {
        guard authorizationStatus == .approved else {
            message = "Сначала разреши Screen Time"
            return
        }
        guard selectedCount > 0 else {
            message = "Сначала выбери приложения"
            return
        }
        guard let appGroupDefaults else {
            message = EchoSharedStoreError.appGroupUnavailable(EchoAppGroup.identifier).localizedDescription
            return
        }
        guard persistSelection() else { return }

        ShieldController.apply(selection)
        focusEnabled = true
        appGroupDefaults.set(true, forKey: EchoAppGroup.focusEnabledKey)
        message = "Выбранные приложения теперь показывают твой план"
    }

    func disableFocus() {
        focusEnabled = false
        guard let appGroupDefaults else {
            ShieldController.clear()
            message = EchoSharedStoreError.appGroupUnavailable(EchoAppGroup.identifier).localizedDescription
            return
        }

        appGroupDefaults.set(false, forKey: EchoAppGroup.focusEnabledKey)
        if scheduleEnabled && focusWindow.contains(minuteOfDay: minuteOfDay(.now)) {
            ShieldController.apply(selection)
        } else {
            ShieldController.clear()
        }
        message = "Постоянная блокировка выключена"
    }

    func setSchedule(enabled: Bool) {
        let transition = FocusScheduleTransition(requestedEnabled: enabled, window: focusWindow)

        if transition.shouldStopMonitoring {
            scheduleSideEffects.stopMonitoring()
            scheduleEnabled = false
            if !focusEnabled { scheduleSideEffects.clearShields() }

            do {
                try scheduleSideEffects.persistEnabled(false)
                message = "Расписание выключено"
            } catch {
                message = error.localizedDescription
            }
            return
        }

        guard transition.canStartMonitoring else {
            failSchedule("Начало и конец расписания должны отличаться")
            return
        }
        guard authorizationStatus == .approved else {
            failSchedule("Сначала разреши Screen Time")
            return
        }
        guard selectedCount > 0 else {
            failSchedule("Сначала выбери приложения")
            return
        }
        guard let appGroupDefaults else {
            failSchedule(EchoSharedStoreError.appGroupUnavailable(EchoAppGroup.identifier).localizedDescription)
            return
        }
        guard persistSelection() else {
            failSchedule(message ?? "Не удалось сохранить настройки расписания")
            return
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: focusWindow.startMinute / 60, minute: focusWindow.startMinute % 60),
            intervalEnd: DateComponents(hour: focusWindow.endMinute / 60, minute: focusWindow.endMinute % 60),
            repeats: true
        )
        do {
            try scheduleSideEffects.startMonitoring(schedule)
            try scheduleSideEffects.persistEnabled(true)
            scheduleEnabled = true
            if focusWindow.contains(minuteOfDay: minuteOfDay(.now)) {
                ShieldController.apply(selection)
            }
            appGroupDefaults.set(focusWindow.startMinute, forKey: EchoAppGroup.scheduleStartMinuteKey)
            appGroupDefaults.set(focusWindow.endMinute, forKey: EchoAppGroup.scheduleEndMinuteKey)
            message = "Ежедневное расписание включено"
        } catch {
            failSchedule(error.localizedDescription)
        }
    }

    private func failSchedule(_ errorMessage: String) {
        scheduleSideEffects.stopMonitoring()
        scheduleEnabled = false
        if !focusEnabled { scheduleSideEffects.clearShields() }
        do {
            try scheduleSideEffects.persistEnabled(false)
            message = errorMessage
        } catch {
            message = "\(errorMessage) \(error.localizedDescription)"
        }
    }

    func refreshPreviewPlan() {
        let snapshot = PlanSnapshot.preview()
        guard let planSnapshotStore else {
            message = EchoSharedStoreError.appGroupUnavailable(EchoAppGroup.identifier).localizedDescription
            return
        }

        do {
            try planSnapshotStore.save(snapshot)
            plan = snapshot
            message = "Локальный план обновлён"
        } catch {
            message = error.localizedDescription
        }
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
