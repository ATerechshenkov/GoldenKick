import SwiftUI

struct WorkoutRunView: View {
    let engine: WorkoutEngine
    @State private var confirmStop = false

    var body: some View {
        let segment = engine.currentSegment

        ZStack {
            segment.kind.color
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text(segment.kind.title)
                    .font(.system(size: 64, weight: .heavy))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text(TimeFormat.mmss(engine.remaining))
                    .font(.system(size: 110, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                if let rep = segment.repIndex {
                    Text("Повтор \(rep) из \(engine.config.reps)")
                        .font(.title2.bold())
                }

                if let next = engine.nextSegment {
                    Text("Дальше: \(next.kind.nextTitle) \(TimeFormat.mmss(engine.realDuration(next)))")
                        .font(.title3)
                } else {
                    Text("Последний отрезок")
                        .font(.title3)
                }

                if engine.phase == .paused {
                    Text("ПАУЗА")
                        .font(.title.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.3), in: Capsule())
                }

                Spacer()

                VStack(spacing: 8) {
                    ProgressView(value: engine.progress)
                        .tint(.white)
                        .scaleEffect(x: 1, y: 2)
                    HStack {
                        Text("Осталось всего")
                        Spacer()
                        Text(TimeFormat.mmss(engine.totalRemaining))
                            .monospacedDigit()
                    }
                    .font(.headline)
                }

                HStack(spacing: 16) {
                    Button {
                        if engine.phase == .paused {
                            engine.resume()
                        } else {
                            engine.pause()
                        }
                    } label: {
                        Text(engine.phase == .paused ? "Продолжить" : "Пауза")
                            .controlLabel()
                    }

                    Button {
                        confirmStop = true
                    } label: {
                        Text("Стоп")
                            .controlLabel()
                    }
                }
            }
            .foregroundStyle(.white)
            .padding()
        }
        .confirmationDialog("Остановить тренировку?", isPresented: $confirmStop, titleVisibility: .visible) {
            Button("Остановить", role: .destructive) {
                engine.stop()
            }
            Button("Продолжить тренировку", role: .cancel) {}
        }
    }
}

private extension View {
    func controlLabel() -> some View {
        font(.title2.bold())
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    WorkoutRunView(engine: WorkoutEngine(config: .current))
}
