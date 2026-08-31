import Foundation

/// The paste-healing entry point.
///
/// Spec: specs/paste-healing.md. `heal` applies the six transforms in the
/// order locked by D20 and by the spec's "Transform order — LOCKED" section:
///
///   repairGlyphs → stripArtefacts → unwrapLines → dehyphenate
///   → detectTables → preserveClauseNumbers
///
/// Reordering these is RED. Encoding is normalised before any transform
/// matches on characters, and page furniture is removed while it is still
/// line-isolated; the blueprint's original order made criterion 5
/// unsatisfiable.
///
/// This task adds no call site — the paste hook, the raw/healed preview
/// toggle, and undo integration are explicitly out of scope. `heal` is a pure
/// `String -> String` function and writes nothing.
public enum PasteHealer {

    /// Heals one pasted span. Deterministic (criterion 8) and idempotent
    /// (criterion 9): `heal(heal(x)) == heal(x)`.
    public static func heal(_ raw: String) -> String {
        preserveClauseNumbers(
            detectTables(
                dehyphenate(
                    unwrapLines(
                        stripArtefacts(
                            repairGlyphs(raw)
                        )
                    )
                )
            )
        )
    }

    /// Returns `true` when a paste is short enough to skip the preview sheet.
    /// The text has nothing to heal and showing a diff is just friction.
    /// Threshold: ≤80 characters AND no hard newline.
    public static func shouldSkipPastePreview(_ raw: String) -> Bool {
        raw.count <= 80 && raw.rangeOfCharacter(from: .newlines) == nil
    }
}
