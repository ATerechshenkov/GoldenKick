//
//  ContentView.swift
//  GoldenKick
//
//  Created by Andrey on 08.10.2026.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    let engine: WorkoutEngine
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch engine.phase {
            case .idle:
                TabView {
                    TodayView(engine: engine)
                        .tabItem { Label("Сегодня", systemImage: "sun.max") }
                    WorkoutHistoryView()
                        .tabItem { Label("История", systemImage: "clock") }
                }
                .onAppear(perform: connectHistorySaving)
            case .running, .paused:
                WorkoutRunView(engine: engine)
            case .finished:
                WorkoutDoneView(engine: engine)
            }
        }
        // Covers both launch and returning to the app from the background.
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            Task { await ReminderScheduler.reschedule(context: modelContext) }
        }
    }

    /// Records a completed workout to history, unless it ran in fast mode.
    private func connectHistorySaving() {
        guard engine.onFinish == nil else { return }
        engine.onFinish = { [weak engine, modelContext] in
            guard let engine, engine.timeScale == 1, let startDate = engine.startDate else { return }
            let record = WorkoutRecord(
                startDate: startDate,
                title: engine.config.title,
                warmup: engine.config.warmup,
                run: engine.config.run,
                walk: engine.config.walk,
                cooldown: engine.config.cooldown,
                reps: engine.config.reps,
                activeDuration: engine.elapsedActive,
                runDuration: engine.runDuration,
                planDate: engine.planDate
            )
            modelContext.insert(record)
            try? modelContext.save()
            Task { await ReminderScheduler.reschedule(context: modelContext) }
        }
    }
}

#Preview {
    ContentView(engine: WorkoutEngine(config: TrainingPlan.firstWorkoutConfig))
        .modelContainer(for: WorkoutRecord.self, inMemory: true)
}
