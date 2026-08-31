import Foundation

// MARK: - HelpLane

/// The three kinds of help this app offers, in the order they are shown.
///
/// One window, three lanes, one search field. A second help surface would mean
/// the reader has to guess which one to open before they can look anything up —
/// and the search would have to be built twice.
public enum HelpLane: String, CaseIterable, Identifiable, Sendable {
    /// Syntax you type, each with an example that can be copied and used as-is.
    case cheatsheet
    /// "How do I …" — the situation first, the feature second.
    case guides
    /// Keys.
    case shortcuts

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cheatsheet: return "Cheatsheet"
        case .guides:     return "Guides"
        case .shortcuts:  return "Shortcuts"
        }
    }

    /// SF Symbol for the lane picker.
    public var symbol: String {
        switch self {
        case .cheatsheet: return "text.badge.star"
        case .guides:     return "lightbulb"
        case .shortcuts:  return "keyboard"
        }
    }

    /// Shown under the picker when no search is active.
    public var blurb: String {
        switch self {
        case .cheatsheet:
            return "What to type, and what it turns into. Every example can be copied."
        case .guides:
            return "Short walkthroughs, written around what you are trying to do."
        case .shortcuts:
            return "Everything here is also in the toolbar and the Writer menu."
        }
    }
}

// MARK: - HelpExample

/// A snippet the reader can lift straight into a document.
///
/// `code` is real Markdown for *this* app — not generic Markdown. The renderer
/// here is hand-written and deliberately small (`ExporterCore`), so an example
/// borrowed from another tool can be valid Markdown everywhere else and still do
/// nothing at all in Kitib.
public struct HelpExample: Equatable, Sendable {
    public let code: String
    /// What the reader will see once it renders. Optional — obvious cases don't
    /// need narrating.
    public let renders: String?

    public init(_ code: String, renders: String? = nil) {
        self.code = code
        self.renders = renders
    }
}

// MARK: - HelpEntry

/// One searchable unit of help.
///
/// Lives in `Core` rather than beside the view on purpose: `Sources/Shared` is
/// outside the test bundle (D16), so anything written in the view is unverifiable
/// — including whether every syntax entry actually carries an example, and
/// whether the guidance still matches the implementation it describes. Here it
/// is all testable.
public struct HelpEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public let lane: HelpLane
    /// For a guide this is the reader's problem, phrased as they would phrase it.
    public let title: String
    /// One line. What it is for, or when it applies.
    public let summary: String
    /// Ordered instructions. Guides only.
    public let steps: [String]
    /// The catch — shown set apart, because the catch is usually why someone
    /// opened the help.
    public let note: String?
    public let example: HelpExample?
    /// Key combination. Shortcuts only.
    public let shortcut: String?
    /// Words a reader might search that do not appear in the prose above.
    public let keywords: [String]

    public init(
        id: String,
        lane: HelpLane,
        title: String,
        summary: String,
        steps: [String] = [],
        note: String? = nil,
        example: HelpExample? = nil,
        shortcut: String? = nil,
        keywords: [String] = []
    ) {
        self.id = id
        self.lane = lane
        self.title = title
        self.summary = summary
        self.steps = steps
        self.note = note
        self.example = example
        self.shortcut = shortcut
        self.keywords = keywords
    }

    /// Everything a search should look at, apart from the title, which is
    /// weighted separately.
    public var bodyText: String {
        var parts = [summary]
        parts.append(contentsOf: steps)
        if let note { parts.append(note) }
        if let example {
            parts.append(example.code)
            if let renders = example.renders { parts.append(renders) }
        }
        if let shortcut { parts.append(shortcut) }
        return parts.joined(separator: "\n")
    }
}
