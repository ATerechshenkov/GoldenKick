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

    var body: some View {
        switch engine.phase {
        case .idle:
            TabView {
                WorkoutListView(engine: engine)
                    .tabItem { Label("Тренировка", systemImage: "figure.run") }
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
                planWeek: engine.planSlot?.week,
                planSlot: engine.planSlot?.slot
            )
            modelContext.insert(record)
            try? modelContext.save()
        }
    }
}

#Preview {
    ContentView(engine: WorkoutEngine(config: TrainingPlan.firstWorkoutConfig))
        .modelContainer(for: WorkoutRecord.self, inMemory: true)
}
