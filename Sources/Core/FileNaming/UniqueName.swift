import Foundation

// MARK: - UniqueName

/// Picks a name that is not already taken, by appending " 2", " 3", … to a
/// base name.
///
/// No filesystem access: the caller supplies an `isTaken` predicate, which also
/// owns case policy (a case-insensitive volume supplies a case-insensitive
/// predicate). The number is a suffix this function owns — a base that already
/// ends in a number keeps it, so "Section 2" becomes "Section 2 2".
enum UniqueName {

    /// How many candidates to try before giving up. A predicate that never
    /// yields must not hang the caller on a button press.
    static let attemptLimit = 1000

    /// Returns `base` if free, otherwise the first free "`base` N".
    ///
    /// Gaps are filled: with "New Folder" and "New Folder 3" taken, the result
    /// is "New Folder 2". If every candidate up to `attemptLimit` is taken, a
    /// UUID-suffixed name is returned rather than looping — it is distinct from
    /// every numbered candidate and from any other give-up name.
    static func next(base: String, isTaken: (String) -> Bool) -> String {
        guard isTaken(base) else { return base }

        for n in 2...attemptLimit {
            let candidate = "\(base) \(n)"
            if !isTaken(candidate) { return candidate }
        }

        return "\(base) \(UUID().uuidString)"
    }
}
