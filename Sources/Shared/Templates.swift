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

                ###Formula 
                This is a formula that can be used in Kitib.
                $$2X + 3Y = 10$$

                ###Sankey
                This is a Sankey diagram that shows the flow of things.
                ```mermaid
                ---
                config:
                sankey:
                    showValues: false
                ---
                sankey-beta

                Renewable, Solar, 25
                Renewable, Thermal, 25
                Solar, Homes, 25
                Thermal, Heating, 25
                Generator, Fuel, 25
                Energy Source,Electricity Grid,100
                Energy Source,Heat,50
                Electricity Grid,Industry,60
                Electricity Grid,Homes,40
                Heat,Homes,30
                Heat,Industry,20
                ```

                ###Flowchart
                These are examples of flowcharts that shows relationships between things. Elements like fill colours, border styles, etc. can be tweaked.

                ```mermaid
                stateDiagram-v2
                    direction LR
                    [*] --> Contract:::normal
                    Contract --> Inclusions:::normal
                    Contract --> Exclusions:::normal
                    Contract --> NamedAI:::key
                    Contract --> Ambiguity:::normal
                    NamedAI: AI Governance
                    Inclusions --> Scope:::normal
                    Exclusions --> Scope
                    NamedAI --> Scope
                    Ambiguity --> Scope: Resolved
                    Ambiguity --> Escalate:::key
                    Scope --> [*] 
                    Escalate --> Contract

                    classDef normal fill:#FFFFFF,stroke:#000000,,stroke-width:1px;
                    classDef standard fill:#FFFFFF,stroke:#32CD32,stroke-width:3px;
                    classDef key fill:#FFFFFF,stroke:#ff0000,stroke-width:2px;
                ```


                ```mermaid
                stateDiagram-v2
                    [*] --> Contract:::normal
                    Contract --> Inclusions:::normal
                    Contract --> Exclusions:::normal
                    Contract --> NamedAI:::key

                    Contract --> Ambiguity:::normal
                    NamedAI: AI Governance
                    Inclusions --> Scope:::normal
                    Exclusions --> Scope:::normal
                    NamedAI --> Scope
                    Ambiguity --> Scope: Resolved
                    Ambiguity --> Escalate:::key
                    Scope --> [*]
                    Escalate --> Contract

                    classDef normal fill:#FFFFFF,stroke:#000000,,stroke-width:1px;
                    classDef standard fill:#FFFFFF,stroke:#32CD32,stroke-width:3px;
                    classDef key fill:#FFFFFF,stroke:#ff0000,stroke-width:2px;
                ```

                ##Pie
                This is a pie chart that shows the distribution of things.
                ```mermaid
                ---
                config:
                  pie:
                    textPosition: 0.5
                    donutHole: 0.75
                    highlightSlice: "India"
                  themeVariables:
                    pieOuterStrokeWidth: "5px"
                ---
                pie showData
                    title Key elements in Product X
                    "Saudi Arabia" : 5
                    "UAE" : 4
                    "India" : 6
                    "United Kingdom" :  2
                ```

                ##Quadrant Chart
                This is a quadrant chart that shows the relationship between things.
                ```mermaid
                ---
                config:
                quadrantChart:
                    chartWidth: 500
                    chartHeight: 500
                themeVariables:
                    quadrant1TextFill: "ff0000"
                    quadrant1Fill: "#FFFAFA"
                    quadrant2Fill: "#FAFFFF"
                    quadrant3Fill: "#FAFAFF"
                    quadrant4Fill: "#FAFFFA"
                ---
                quadrantChart
                    title Reach and engagement of campaigns
                    x-axis Low Reach --> High Reach
                    y-axis Low Engagement --> "High Engagement 😎"
                    quadrant-1 We should expand
                    quadrant-2 Need to promote
                    quadrant-3 Re-evaluate
                    quadrant-4 May be improved
                    Campaign A:  [0.3, 0.6] 
                    Campaign B: [0.45, 0.23]
                    Campaign C: [0.57, 0.69]
                    Campaign D: [0.78, 0.34]
                    Campaign E: [0.40, 0.34]
                    Campaign F: [0.35, 0.78]
                ```

                ##Timeline	
                This is a timeline that shows the history of things.
                ```mermaid
                timeline
                    title History of Social Media Platform
                    2002 : LinkedIn
                    2004 : Facebook
                        : Google
                    2005 : YouTube
                    2006 : Twitter
                ```


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
                id: "article", name: "Article", icon: "newspaper",
                filename: "Article", suggestedGoal: 1000,
                body: """
                       ---
                title:\u{20}
                type:\u{20}
                category:\u{20}
                domain:\u{20}
                sector:\u{20}
                subdomain:\u{20}
                document_role:\u{20}
                riba_stages:\u{20}
                summary:\u{20}
                version:\u{20}
                status:\u{20}
                tags:\u{20}
                ---
                
                # Title

                **Date:** \(today())
                **Author:** \u{20}

                \(LoremIpsum.paragraphs(6))

                ###Flowchart
                This is a flowchart that shows relationships between things. Elements like fill colours, border styles, etc. can be tweaked.
                ```mermaid
                flowchart LR
                    A[Campaign A]:::highlight
                    B[Campaign B]:::standard
                    C[Campaign C]:::error
                    A --> B
                    B --> A
                    A --> C
                    
                    classDef highlight fill:#f96,stroke:#333,stroke-width:3px;
                    classDef standard fill:#e1f5fe,stroke:#0277bd,stroke-width:1px;
                    classDef error fill:#E6E6E6,stroke:#333,stroke-width:1px;
                ```

                """
            ),
            Template(
                id: "design-note", name: "Design Note", icon: "pencil.and.ruler",
                filename: "Design Note", suggestedGoal: 1200,
                body: """
                ---
                title:\u{20}
                type:\u{20}
                category:\u{20}
                domain:\u{20}
                sector:\u{20}
                subdomain:\u{20}
                document_role:\u{20}
                riba_stages:\u{20}
                summary:\u{20}
                version:\u{20}
                status:\u{20}
                tags:\u{20}
                ---

                # DN-001 — Title

                **Date:** \(today())
                **Author:** \u{20}
                **Reviewers:** \u{20}

                ## Executive Summary

                What are the key findings to highlight?

                ## Background

                ###Flowchart
                This is a flowchart that shows relationships between things. Elements like fill colours, border styles, etc. can be tweaked.
                ```mermaid
                flowchart LR
                    A[Campaign A]:::highlight
                    B[Campaign B]:::standard
                    C[Campaign C]:::error
                    A --> B
                    B --> A
                    A --> C
                    
                    classDef highlight fill:#f96,stroke:#333,stroke-width:3px;
                    classDef standard fill:#e1f5fe,stroke:#0277bd,stroke-width:1px;
                    classDef error fill:#E6E6E6,stroke:#333,stroke-width:1px;
                ```

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
                filename: "Blog Post", suggestedGoal: 500,
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
