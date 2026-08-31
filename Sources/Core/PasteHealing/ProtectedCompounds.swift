/// Hardcoded lexicon of engineering compound terms that must survive
/// paste-healing byte-identical. See specs/paste-healing.md criterion 3.
///
/// This is a fixed constant for now; a tunable JSON profile needs the A3
/// store (N2), which does not exist yet.
enum ProtectedCompounds {
    /// Every compound in the set must survive every transform unchanged.
    static let compounds: Set<String> = [
        "low-voltage",
        "star-delta",
        "XLPE/SWA/PVC",
        "Dyn11",
        "N+1",
        "11kV/415V",
    ]
}
