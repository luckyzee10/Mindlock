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
                    VStack(alignment: .leading, spacing: 6) {
                        Text(block.name)
                            .font(DesignSystem.Typography.body.weight(.semibold))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Text("\(twoDigits(block.startHour)):\(twoDigits(block.startMinute)) – \(twoDigits(block.endHour)):\(twoDigits(block.endMinute)) • \(daysLabel(block))")
                            .font(DesignSystem.Typography.callout)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { presentingEditor = block }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignSystem.Colors.surface.opacity(0.6))
                    .cornerRadius(DesignSystem.CornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .stroke(block.enabled ? Color.green.opacity(0.7) : Color.red.opacity(0.7), lineWidth: 2)
                    )
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.surfaceSecondary.opacity(0.5))
        .cornerRadius(DesignSystem.CornerRadius.xl)
        .onAppear { blocks = SharedSettings.loadTimeBlocks() }
        .sheet(item: $presentingEditor) { block in
            TimeBlockEditor(block: block) { updated in
                upsert(updated)
            } onDelete: { deleted in
                delete(deleted)
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

    private func twoDigits(_ n: Int) -> String { String(format: "%02d", n) }
    private func daysLabel(_ block: SharedSettings.TimeBlock) -> String {
        let map = [1:"S",2:"M",3:"T",4:"W",5:"T",6:"F",7:"S"]
        return [1,2,3,4,5,6,7].map { block.daysOfWeek.contains($0) ? map[$0]! : "·" }.joined(separator: " ")
    }
}

private struct TimeBlockEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var block: SharedSettings.TimeBlock
    let onSave: (SharedSettings.TimeBlock) -> Void
    let onDelete: (SharedSettings.TimeBlock) -> Void

    @State private var start = Date()
    @State private var end = Date()
    @State private var error: String?
    @State private var showDisableConfirm = false
    @State private var showDeleteConfirm = false
    @State private var pendingDisable = false

    init(block: SharedSettings.TimeBlock, onSave: @escaping (SharedSettings.TimeBlock) -> Void, onDelete: @escaping (SharedSettings.TimeBlock) -> Void) {
        self._block = State(initialValue: block)
        self.onSave = onSave
        self.onDelete = onDelete
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(bySettingHour: block.startHour, minute: block.startMinute, second: 0, of: now) ?? now
        let endDate = calendar.date(bySettingHour: block.endHour, minute: block.endMinute, second: 0, of: now) ?? now
        self._start = State(initialValue: startDate)
        self._end = State(initialValue: endDate)
    }

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
                    Toggle("Enabled", isOn: Binding(
                        get: { block.enabled },
                        set: { newValue in
                            if newValue {
                                block.enabled = true
                            } else {
                                pendingDisable = true
                                showDisableConfirm = true
                            }
                        }
                    ))
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Time Block", systemImage: "trash")
                    }
                }
                if let error { Text(error).foregroundColor(.red) }
            }
            .navigationTitle("Time Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .alert("Are you sure you want to proceed? This will turn off shielding for this time block.", isPresented: $showDisableConfirm) {
                Button("Cancel", role: .cancel) {
                    pendingDisable = false
                }
                Button("Proceed", role: .destructive) {
                    if pendingDisable {
                        block.enabled = false
                    }
                    pendingDisable = false
                }
            }
            .alert("Are you sure? This time block will be deleted.", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    onDelete(block)
                    dismiss()
                }
            }
        }
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
