import Foundation

// MARK: - SmartFolder

/// A named, saved search. Appears in the sidebar as a folder; opening it runs
/// `query` against the workspace index and shows live results.
struct SmartFolder: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var query: String

    init(id: UUID = UUID(), name: String, query: String) {
        self.id = id
        self.name = name
        self.query = query
    }
}

// MARK: - SmartFolderStore

/// Persists smart folders as a JSON array in UserDefaults. Order is preserved.
/// The store takes a UserDefaults instance so tests can inject an isolated
/// suite instead of touching the real defaults.
final class SmartFolderStore {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "smartFolders") {
        self.defaults = defaults
        self.key = key
    }

    /// Current folders, in saved order. A corrupt or absent blob yields [].
    var folders: [SmartFolder] {
        get {
            guard let data = defaults.data(forKey: key),
                  let decoded = try? JSONDecoder().decode([SmartFolder].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: key)
        }
    }

    /// Appends a folder and returns it.
    @discardableResult
    func add(name: String, query: String) -> SmartFolder {
        let folder = SmartFolder(name: name, query: query)
        var current = folders
        current.append(folder)
        folders = current
        return folder
    }

    func rename(id: UUID, to name: String) {
        var current = folders
        guard let idx = current.firstIndex(where: { $0.id == id }) else { return }
        current[idx].name = name
        folders = current
    }

    /// Updates both name and query of an existing folder. No-op for an
    /// unknown id.
    func update(id: UUID, name: String, query: String) {
        var current = folders
        guard let idx = current.firstIndex(where: { $0.id == id }) else { return }
        current[idx].name = name
        current[idx].query = query
        folders = current
    }

    func delete(id: UUID) {
        var current = folders
        current.removeAll { $0.id == id }
        folders = current
    }
}
