import Foundation

final class UserIdentity {
    static let shared = UserIdentity()

    private let defaults = UserDefaults.standard
    private let idKey = "MindLockUserID"
    private let emailKey = "MindLockUserEmail"

    let userId: String

    var email: String? {
        defaults.string(forKey: emailKey)
    }

    private init() {
        if let stored = defaults.string(forKey: idKey) {
            userId = stored
        } else {
            let newID = UUID().uuidString
            defaults.set(newID, forKey: idKey)
            userId = newID
        }
    }

    func updateEmail(_ email: String?) {
        defaults.set(email, forKey: emailKey)
    }
}
