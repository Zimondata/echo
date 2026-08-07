import FamilyControls
import SwiftUI

struct FocusView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Не запрет ради запрета. Перед Instagram Echo возвращает тебе то, что ты сам выбрал на день.")
                    .font(.title3.bold())

                EchoCard {
                    VStack(alignment: .leading, spacing: 14) {
                        step("1", "Разрешить Screen Time", authorizationText)
                        Button("Разрешить") {
                            Task { await model.requestAuthorization() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.authorizationStatus == .approved)
                    }
                }

                EchoCard {
                    VStack(alignment: .leading, spacing: 14) {
                        step("2", "Выбрать соцсети", selectionText)
                        Button("Выбрать приложения") {
                            model.isPickerPresented = true
                        }
                        .buttonStyle(.bordered)
                    }
                }

                EchoCard {
                    VStack(alignment: .leading, spacing: 14) {
                        step("3", "Включить экран Echo", model.focusEnabled ? "Блокировка активна" : "Пока выключено")
                        Toggle("Блокировать прямо сейчас", isOn: focusBinding)
                            .tint(Color.echoViolet)
                    }
                }

                EchoCard {
                    VStack(alignment: .leading, spacing: 14) {
                        step("4", "Ежедневное расписание", model.scheduleEnabled ? "Работает автоматически" : "Не настроено")
                        DatePicker("Начало", selection: $model.scheduleStart, displayedComponents: .hourAndMinute)
                        DatePicker("Конец", selection: $model.scheduleEnd, displayedComponents: .hourAndMinute)
                        Toggle("Включить расписание", isOn: scheduleBinding)
                            .tint(Color.echoViolet)
                        if model.scheduleEnabled {
                            Button("Сохранить новое время") {
                                model.setSchedule(enabled: true)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                if let message = model.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(Color.echoLavender)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }

                Text("Выбор приложений хранится как непрозрачные токены Apple. Echo не получает историю сайтов и не видит, что именно ты выбрал.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
        }
        .background(Color.echoCanvas.ignoresSafeArea())
        .navigationTitle("Фокус")
        .familyActivityPicker(isPresented: $model.isPickerPresented, selection: $model.selection)
        .onChange(of: model.selection) { _, _ in model.persistSelection() }
    }

    private var authorizationText: String {
        switch model.authorizationStatus {
        case .approved: "Разрешение получено"
        case .denied: "Доступ запрещён в настройках iPhone"
        case .notDetermined: "Apple спросит разрешение один раз"
        @unknown default: "Статус неизвестен"
        }
    }

    private var selectionText: String {
        model.selectedCount == 0 ? "Например, Instagram и X" : "Выбрано: \(model.selectedCount)"
    }

    private var focusBinding: Binding<Bool> {
        Binding(
            get: { model.focusEnabled },
            set: { enabled in enabled ? model.enableFocus() : model.disableFocus() }
        )
    }

    private var scheduleBinding: Binding<Bool> {
        Binding(
            get: { model.scheduleEnabled },
            set: { model.setSchedule(enabled: $0) }
        )
    }

    private func step(_ number: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.headline)
                .frame(width: 34, height: 34)
                .background(Color.echoViolet.opacity(0.25), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
