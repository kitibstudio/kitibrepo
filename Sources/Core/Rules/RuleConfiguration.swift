import Foundation

// MARK: - RuleConfiguration

/// Per-rule control: disable a rule entirely, or override the severity every
/// one of its diagnostics is emitted with (specs/rules-engine.md criterion 4).
///
/// A fresh configuration disables nothing and overrides nothing, so the
/// default behaviour of every rule is its `defaultSeverity`.
struct RuleConfiguration: Equatable {
    private var severityOverrides: [String: DiagnosticSeverity] = [:]
    private var disabledRules: Set<String> = []

    init() {}

    /// Overrides the severity of every diagnostic the named rule emits.
    mutating func setSeverity(_ severity: DiagnosticSeverity, for ruleID: String) {
        severityOverrides[ruleID] = severity
    }

    /// Disables the named rule. The engine must not even call its `evaluate`
    /// (criterion 4: a disabled rule produces nothing and costs nothing).
    mutating func disable(_ ruleID: String) {
        disabledRules.insert(ruleID)
    }

    /// Re-enables the named rule after a `disable`.
    mutating func enable(_ ruleID: String) {
        disabledRules.remove(ruleID)
    }

    /// Whether the named rule runs.
    func isEnabled(_ ruleID: String) -> Bool {
        !disabledRules.contains(ruleID)
    }

    /// The severity the named rule's diagnostics are emitted with:
    /// the override when one is set, otherwise `defaultSeverity`.
    func severity(for ruleID: String, default defaultSeverity: DiagnosticSeverity) -> DiagnosticSeverity {
        severityOverrides[ruleID] ?? defaultSeverity
    }
}
