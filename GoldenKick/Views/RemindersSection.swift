import SwiftData
import SwiftUI
import UIKit

/// Toggle + time picker for morning reminders. Permission is requested only
/// when the toggle is turned on, never at launch; if it's denied (now or
/// later, in Settings), the toggle turns itself off and shows a hint.
struct RemindersSection: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(ReminderScheduler.enabledKey) private var remindersEnabled = false
    @AppStorage(ReminderScheduler.minutesKey) private var reminderMinutes = ReminderScheduler.defaultMinutes
    @State private var showDeniedHint = false

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                let midnight = Calendar.current.startOfDay(for: .now)
                return Calendar.current.date(byAdding: .minute, value: reminderMinutes, to: midnight) ?? .now
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderMinutes = (components.hour ?? 6) * 60 + (components.minute ?? 30)
                Task { await ReminderScheduler.reschedule(context: modelContext) }
            }
        )
    }

    var body: some View {
        Section {
            Toggle("Утренние напоминания", isOn: $remindersEnabled)
                .onChange(of: remindersEnabled) { _, isOn in
                    handleToggle(isOn)
                }

            if remindersEnabled {
                DatePicker("Время", selection: timeBinding, displayedComponents: .hourAndMinute)
            }

            if showDeniedHint {
                Text("Уведомления запрещены. Включите их: Настройки → GoldenKick → Уведомления")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Открыть Настройки") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        } footer: {
            Text("В дни тренировок по плану и в дни целей.")
        }
        .task { await refreshDeniedState() }
    }

    private func handleToggle(_ isOn: Bool) {
        guard isOn else {
            showDeniedHint = false
            Task { await ReminderScheduler.reschedule(context: modelContext) }
            return
        }
        Task {
            let granted = await ReminderScheduler.requestAuthorization()
            if granted {
                showDeniedHint = false
                await ReminderScheduler.reschedule(context: modelContext)
            } else {
                remindersEnabled = false
                showDeniedHint = true
            }
        }
    }

    private func refreshDeniedState() async {
        guard remindersEnabled else { return }
        if await ReminderScheduler.isAuthorizationDenied() {
            remindersEnabled = false
            showDeniedHint = true
        }
    }
}
