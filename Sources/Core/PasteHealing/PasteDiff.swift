import Foundation

// MARK: - DiffLine

/// One aligned pair of lines from an LCS diff.
public enum DiffLine: Equatable {
    case equal
    case added
    case removed
}

// MARK: - LCS diff

/// Computes an aligned side-by-side diff of two strings.
/// Returns an array of (status, rawLine, healedLine) tuples.
/// `.equal` — line present in both.
/// `.removed` — line in raw only (healed side is nil).
/// `.added` — line in healed only (raw side is nil).
///
/// Uses a standard O(m·n) Longest Common Subsequence algorithm — ~40 lines,
/// no external dependency. Handles insertions, deletions, and substitutions
/// correctly (failure mode 6 of the paste-preview spec).
public func computeDiff(raw: String, healed: String) -> [(DiffLine, String?, String?)] {
    let rawLines = raw.components(separatedBy: "\n")
    let healedLines = healed.components(separatedBy: "\n")
    let m = rawLines.count, n = healedLines.count

    // LCS table
    var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
    for i in 1...m {
        for j in 1...n {
            dp[i][j] = rawLines[i - 1] == healedLines[j - 1]
                ? dp[i - 1][j - 1] + 1
                : max(dp[i - 1][j], dp[i][j - 1])
        }
    }

    // Backtrack to produce aligned pairs
    var result: [(DiffLine, String?, String?)] = []
    var i = m, j = n
    while i > 0 || j > 0 {
        if i > 0, j > 0, rawLines[i - 1] == healedLines[j - 1] {
            result.insert((.equal, rawLines[i - 1], healedLines[j - 1]), at: 0)
            i -= 1; j -= 1
        } else if j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j]) {
            result.insert((.added, nil, healedLines[j - 1]), at: 0)
            j -= 1
        } else {
            result.insert((.removed, rawLines[i - 1], nil), at: 0)
            i -= 1
        }
    }
    return result
}
