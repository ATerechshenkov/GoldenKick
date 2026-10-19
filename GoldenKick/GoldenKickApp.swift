//
//  GoldenKickApp.swift
//  GoldenKick
//
//  Created by Andrey on 08.10.2026.
//

import SwiftData
import SwiftUI

@main
struct GoldenKickApp: App {
    @State private var engine = WorkoutEngine(config: .current)

    var body: some Scene {
        WindowGroup {
            ContentView(engine: engine)
        }
        .modelContainer(for: WorkoutRecord.self)
    }
}
