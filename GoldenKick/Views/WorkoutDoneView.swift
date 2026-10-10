import SwiftUI

struct WorkoutDoneView: View {
    let engine: WorkoutEngine

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 96))
                .foregroundStyle(.green)
            Text("Тренировка завершена")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("Общее время: \(TimeFormat.mmss(engine.elapsedActive))")
                .font(.title2)
                .monospacedDigit()
            Spacer()
            Button {
                engine.reset()
            } label: {
                Text("На главный")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, minHeight: 64)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    WorkoutDoneView(engine: WorkoutEngine(config: .current))
}
