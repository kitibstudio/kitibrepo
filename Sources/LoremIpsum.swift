import Foundation

/// Classic placeholder-text generator. The first paragraph opens with the
/// canonical "Lorem ipsum dolor sit amet…", the rest is shuffled from the
/// traditional Latin word pool.
enum LoremIpsum {
    static let opening = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."

    private static let words: [String] = [
        "lorem", "ipsum", "dolor", "sit", "amet", "consectetur", "adipiscing",
        "elit", "sed", "do", "eiusmod", "tempor", "incididunt", "ut", "labore",
        "et", "dolore", "magna", "aliqua", "enim", "ad", "minim", "veniam",
        "quis", "nostrud", "exercitation", "ullamco", "laboris", "nisi",
        "aliquip", "ex", "ea", "commodo", "consequat", "duis", "aute", "irure",
        "in", "reprehenderit", "voluptate", "velit", "esse", "cillum", "eu",
        "fugiat", "nulla", "pariatur", "excepteur", "sint", "occaecat",
        "cupidatat", "non", "proident", "sunt", "culpa", "qui", "officia",
        "deserunt", "mollit", "anim", "id", "est", "laborum",
    ]

    static func sentence() -> String {
        let count = Int.random(in: 8...16)
        var picked = (0..<count).map { _ in words.randomElement()! }
        if count > 10 {
            picked[Int.random(in: 3...6)] += ","   // a comma mid-sentence reads naturally
        }
        let joined = picked.joined(separator: " ")
        return joined.prefix(1).uppercased() + joined.dropFirst() + "."
    }

    static func paragraph(canonicalStart: Bool = false) -> String {
        var sentences: [String] = canonicalStart ? [opening] : []
        for _ in 0..<Int.random(in: 3...6) {
            sentences.append(sentence())
        }
        return sentences.joined(separator: " ")
    }

    static func paragraphs(_ n: Int) -> String {
        (0..<n).map { paragraph(canonicalStart: $0 == 0) }.joined(separator: "\n\n")
    }
}
