import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            Section("Данные") {
                LabeledContent("Источник плана", value: "Локальный preview")
                LabeledContent("Часовой пояс", value: model.plan.timezoneIdentifier)
                Button("Обновить демо-план") { model.refreshPreviewPlan() }
            }

            Section("Синхронизация") {
                Text("Production Echo пока не выдаёт безопасный токен нативному клиенту. Поэтому эта сборка не обходит Telegram-вход и не тащит owner-cookie в приложение.")
                    .font(.footnote)
                Link("Открыть web Echo", destination: URL(string: "https://echo.datapine.space")!)
            }

            Section("Приватность") {
                Text("План для системного shield-экрана хранится только в App Group контейнере Echo. Private Obsidian и психологические данные сюда не попадают.")
                    .font(.footnote)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.echoCanvas)
        .navigationTitle("Настройки")
    }
}
