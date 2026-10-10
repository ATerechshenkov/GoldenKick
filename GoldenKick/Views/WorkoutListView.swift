import SwiftUI

struct WorkoutListView: View {
    @Bindable var engine: WorkoutEngine

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(engine.config.title)
                            .font(.title2.bold())
                        Text("Общее время: \(TimeFormat.mmss(engine.config.totalDuration))")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Отрезки") {
                    ForEach(engine.segments) { segment in
                        HStack {
                            Circle()
                                .fill(segment.kind.color)
                                .frame(width: 10, height: 10)
                            Text(label(for: segment))
                            Spacer()
                            Text(TimeFormat.mmss(segment.duration))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                #if DEBUG
                Section {
                    Toggle("Быстрый режим (1 мин = 5 с)", isOn: $engine.fastMode)
                } footer: {
                    Text("Только в отладочной сборке.")
                }
                #endif
            }
            .navigationTitle("Личный тренер")
            .safeAreaInset(edge: .bottom) {
                Button {
                    engine.start()
                } label: {
                    Text("Старт")
                        .font(.title.bold())
                        .frame(maxWidth: .infinity, minHeight: 64)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .padding()
                .background(.bar)
            }
        }
    }

    private func label(for segment: Segment) -> String {
        if let rep = segment.repIndex {
            return "\(segment.kind.listTitle) · повтор \(rep)"
        }
        return segment.kind.listTitle
    }
}

#Preview {
    WorkoutListView(engine: WorkoutEngine(config: .current))
}
