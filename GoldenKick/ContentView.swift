//
//  ContentView.swift
//  GoldenKick
//
//  Created by Andrey on 08.10.2026.
//

import SwiftUI

struct ContentView: View {
    let engine: WorkoutEngine

    var body: some View {
        switch engine.phase {
        case .idle:
            WorkoutListView(engine: engine)
        case .running, .paused:
            WorkoutRunView(engine: engine)
        case .finished:
            WorkoutDoneView(engine: engine)
        }
    }
}

#Preview {
    ContentView(engine: WorkoutEngine(config: .current))
}
