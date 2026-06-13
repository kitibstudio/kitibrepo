import Foundation

struct Template: Identifiable {
    let id: String
    let name: String
    let icon: String
    let filename: String
    let suggestedGoal: Int
    let body: String
}

enum Templates {
    static func today() -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: Date())
    }

    static var all: [Template] {
        [
            Template(
                id: "blank", name: "Blank Document", icon: "doc",
                filename: "Untitled", suggestedGoal: 0,
                body: ""
            ),
            Template(
                id: "report", name: "Report", icon: "doc.text",
                filename: "Report", suggestedGoal: 2000,
                body: """
                # Report Title

                **Author:** \u{20}
                **Date:** \(today())
                **Status:** Draft

                ## Executive Summary

                One paragraph that states the problem, the finding, and the recommendation.

                ## Background

                ## Findings

                ### Finding 1

                ### Finding 2

                ## Recommendations

                1.\u{20}
                2.\u{20}

                ## Appendix

                """
            ),
            Template(
                id: "design-note", name: "Design Note", icon: "pencil.and.ruler",
                filename: "Design Note", suggestedGoal: 1200,
                body: """
                # DN-001 — Title

                **Date:** \(today())
                **Author:** \u{20}
                **Reviewers:** \u{20}

                ## Executive Summary

                What are the key findings to highlight?

                ## Background

                The background information, stated plainly in one or two paragraphs.

                ## Options Considered

                ### Option A —\u{20}
                Pros:
                Cons:

                ### Option B —\u{20}
                Pros:
                Cons:

                ## Recommendations

                Considering above what are your recommendations?

                """
            ),
            Template(
                id: "blog", name: "Blog Post", icon: "text.alignleft",
                filename: "Blog Post", suggestedGoal: 1000,
                body: """
                # Working Title

                *Hook — one or two lines that earn the next paragraph.*

                ## The setup

                ## The insight

                ## What to do with it

                ---

                *Call to action / sign-off.*

                """
            ),
            Template(
                id: "linkedin", name: "LinkedIn Post", icon: "person.crop.square",
                filename: "LinkedIn Post", suggestedGoal: 250,
                body: """
                Hook line — stop the scroll. Keep it under 12 words.

                One-sentence setup of the problem or tension.

                The story or insight, in short lines.
                White space is your friend.

                The takeaway, stated plainly.

                Question to invite comments?

                #hashtag1 #hashtag2 #hashtag3

                """
            ),
        ]
    }
}
