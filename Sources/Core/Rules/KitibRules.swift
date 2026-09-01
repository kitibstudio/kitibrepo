import Foundation

// MARK: - KitibRules

/// The default ruleset the app runs (specs/problems-panel.md criterion 6):
/// the four spec rules, all enabled, at their default severities. The
/// Problems panel runs this exact list; the future QA export gate is the
/// next consumer.
///
/// Order matters: the engine's deterministic sort uses each rule's index in
/// this array as a tie-breaker for diagnostics at the same range
/// (specs/rules-engine.md criterion 3).
enum KitibRules {

    /// The four rules in spec order. ForbiddenPhraseRule ships with an
    /// EMPTY phrase list and is deliberately inert until a rules settings
    /// surface exists (specs/problems-panel.md criterion 6); the empty list
    /// is pinned by KitibRulesTests.
    static let all: [Rule] = [
        HeadingLevelJumpRule(),
        EmptySectionRule(),
        BrokenWikiLinkRule(),
        ForbiddenPhraseRule(phrases: []),
    ]
}
