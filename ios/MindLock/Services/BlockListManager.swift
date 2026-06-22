import Foundation
import FamilyControls
import ManagedSettings
import Combine

/// Central source of truth for the user's Block List (apps MindLock controls for Time Blocks).
@MainActor
final class BlockListManager: ObservableObject {
    static let shared = BlockListManager()

    @Published private(set) var selection: FamilyActivitySelection

    private init() {
        if let data = SharedSettings.sharedDefaults?.data(forKey: "shared.selectionData"),
           let stored = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selection = stored
        } else {
            selection = FamilyActivitySelection()
        }
    }

    func update(selection newSelection: FamilyActivitySelection, reason: String = "manual update") {
        selection = newSelection
        persist()
        print("📋 BlockListManager update (\(reason)): \(selection.applicationTokens.count) app(s)")
    }

    func contains(_ token: ApplicationToken) -> Bool {
        selection.applicationTokens.contains(token)
    }

    var applicationTokens: [ApplicationToken] {
        Array(selection.applicationTokens)
    }

    private func persist() {
        SharedSettings.persistSelection(selection)
    }
}
