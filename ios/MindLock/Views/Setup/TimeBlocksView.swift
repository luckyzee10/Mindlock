import SwiftUI

struct TimeBlocksView: View {
    @EnvironmentObject private var screenTimeManager: ScreenTimeManager
    @State private var blocks: [SharedSettings.TimeBlock] = []
    @State private var presentingEditor: SharedSettings.TimeBlock?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Time Blocks")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Spacer()
                Button {
                    presentingEditor = SharedSettings.TimeBlock(
                        id: UUID().uuidString,
                        name: "My Block",
                        startHour: 9, startMinute: 0,
                        endHour: 17, endMinute: 0,
                        daysOfWeek: Set([2,3,4,5,6]), // Mon–Fri
                        enabled: true
                    )
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }

            if blocks.isEmpty {
                Text("Block selected apps during specific hours. Free breaks still apply.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            } else {
                ForEach(blocks) { block in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(block.name)
                                .font(DesignSystem.Typography.body.weight(.semibold))
                            Text("\(twoDigits(block.startHour)):\(twoDigits(block.startMinute)) – \(twoDigits(block.endHour)):\(twoDigits(block.endMinute)) · \(daysLabel(block))")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: binding(for: block))
                            .labelsHidden()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { presentingEditor = block }
                    .padding()
                    .background(DesignSystem.Colors.surface.opacity(0.5))
                    .cornerRadius(12)
                    .contextMenu {
                        Button(role: .destructive) { delete(block) } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
        .onAppear { blocks = SharedSettings.loadTimeBlocks() }
        .sheet(item: $presentingEditor) { block in
            TimeBlockEditor(block: block) { updated in
                upsert(updated)
            }
        }
        .onChange(of: blocks) { _, newValue in
            SharedSettings.saveTimeBlocks(newValue)
            screenTimeManager.refreshMonitoringSchedule(reason: "time blocks updated")
        }
    }

    private func upsert(_ updated: SharedSettings.TimeBlock) {
        var copy = blocks
        if let idx = copy.firstIndex(where: { $0.id == updated.id }) {
            copy[idx] = updated
        } else {
            copy.append(updated)
        }
        blocks = copy.sorted { $0.name < $1.name }
        presentingEditor = nil
    }

    private func delete(_ block: SharedSettings.TimeBlock) {
        blocks.removeAll { $0.id == block.id }
    }

    private func binding(for block: SharedSettings.TimeBlock) -> Binding<Bool> {
        let idx = blocks.firstIndex(where: { $0.id == block.id })!
        return Binding<Bool>(
            get: { blocks[idx].enabled },
            set: { blocks[idx].enabled = $0 }
        )
    }

    private func twoDigits(_ n: Int) -> String { String(format: "%02d", n) }
    private func daysLabel(_ block: SharedSettings.TimeBlock) -> String {
        let map = [1:"S",2:"M",3:"T",4:"W",5:"T",6:"F",7:"S"]
        return [1,2,3,4,5,6,7].map { block.daysOfWeek.contains($0) ? map[$0]! : "·" }.joined(separator: " ")
    }
}

private struct TimeBlockEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var block: SharedSettings.TimeBlock
    let onSave: (SharedSettings.TimeBlock) -> Void

    @State private var start = Date()
    @State private var end = Date()
    @State private var error: String?

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Name", text: $block.name)
                }
                Section(header: Text("From")) {
                    DatePicker("", selection: $start, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                Section(header: Text("To")) {
                    DatePicker("", selection: $end, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                Section(header: Text("On these days")) {
                    HStack(spacing: 8) {
                        ForEach(1...7, id: \.self) { d in
                            let map = [1:"S",2:"M",3:"T",4:"W",5:"T",6:"F",7:"S"]
                            let selected = block.daysOfWeek.contains(d)
                            Text(map[d]!)
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 32, height: 32)
                                .background(selected ? DesignSystem.Colors.primary : DesignSystem.Colors.surface)
                                .foregroundColor(selected ? .white : DesignSystem.Colors.textSecondary)
                                .clipShape(Circle())
                                .onTapGesture {
                                    if selected { block.daysOfWeek.remove(d) } else { block.daysOfWeek.insert(d) }
                                }
                        }
                    }
                }
                Section {
                    Toggle("Enabled", isOn: $block.enabled)
                }
                if let error { Text(error).foregroundColor(.red) }
            }
            .navigationTitle("Time Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .onAppear { hydrateTimes() }
        }
    }

    private func hydrateTimes() {
        var comps = DateComponents()
        comps.hour = block.startHour; comps.minute = block.startMinute
        start = Calendar.current.date(from: comps) ?? Date()
        comps.hour = block.endHour; comps.minute = block.endMinute
        end = Calendar.current.date(from: comps) ?? Date().addingTimeInterval(3600)
    }

    private func save() {
        let sh = Calendar.current.component(.hour, from: start)
        let sm = Calendar.current.component(.minute, from: start)
        let eh = Calendar.current.component(.hour, from: end)
        let em = Calendar.current.component(.minute, from: end)
        let minutes = (eh*60 + em) - (sh*60 + sm)
        guard minutes > 0 else { error = "End must be after start."; return }
        guard minutes >= 60 else { error = "Minimum duration is 1 hour."; return }
        block.startHour = sh; block.startMinute = sm
        block.endHour = eh; block.endMinute = em
        if block.daysOfWeek.isEmpty { block.daysOfWeek = Set([2,3,4,5,6]) }
        onSave(block)
        dismiss()
    }
}
