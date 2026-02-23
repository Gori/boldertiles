import Foundation

/// Pure functions for context-enhanced text matching.
/// Uses surrounding context (~50 chars before/after) to disambiguate
/// when the same text appears multiple times in a note.
struct SuggestionMatcher {

    /// Find the range of `original` text in `noteText`, using context to disambiguate.
    /// Returns `nil` if the text is not found.
    static func findRange(
        original: String,
        contextBefore: String,
        contextAfter: String,
        in noteText: String
    ) -> Range<String.Index>? {
        guard !original.isEmpty, !noteText.isEmpty else { return nil }

        // Find all occurrences of the original text
        var occurrences: [Range<String.Index>] = []
        var searchStart = noteText.startIndex
        while let range = noteText.range(of: original, range: searchStart..<noteText.endIndex) {
            occurrences.append(range)
            searchStart = range.upperBound
        }

        guard !occurrences.isEmpty else { return nil }

        // If only one occurrence, return it directly
        if occurrences.count == 1 {
            return occurrences[0]
        }

        // Multiple occurrences — use context to disambiguate
        var bestMatch: Range<String.Index>?
        var bestScore = -1

        for range in occurrences {
            let score = contextScore(
                range: range,
                contextBefore: contextBefore,
                contextAfter: contextAfter,
                in: noteText
            )
            if score > bestScore {
                bestScore = score
                bestMatch = range
            }
        }

        return bestMatch
    }

    /// Score a candidate range based on how well the surrounding text matches the expected context.
    private static func contextScore(
        range: Range<String.Index>,
        contextBefore: String,
        contextAfter: String,
        in text: String
    ) -> Int {
        var score = 0

        // Check context before
        if !contextBefore.isEmpty {
            let beforeStart = text.index(range.lowerBound, offsetBy: -contextBefore.count, limitedBy: text.startIndex) ?? text.startIndex
            let actualBefore = String(text[beforeStart..<range.lowerBound])

            if actualBefore == contextBefore {
                score += 100
            } else {
                // Partial match — check suffix overlap
                score += suffixOverlap(expected: contextBefore, actual: actualBefore)
            }
        }

        // Check context after
        if !contextAfter.isEmpty {
            let afterEnd = text.index(range.upperBound, offsetBy: contextAfter.count, limitedBy: text.endIndex) ?? text.endIndex
            let actualAfter = String(text[range.upperBound..<afterEnd])

            if actualAfter == contextAfter {
                score += 100
            } else {
                // Partial match — check prefix overlap
                score += prefixOverlap(expected: contextAfter, actual: actualAfter)
            }
        }

        return score
    }

    /// Number of matching characters at the end of `expected` and `actual`.
    private static func suffixOverlap(expected: String, actual: String) -> Int {
        let expChars = Array(expected)
        let actChars = Array(actual)
        var count = 0
        var ei = expChars.count - 1
        var ai = actChars.count - 1
        while ei >= 0 && ai >= 0 {
            if expChars[ei] == actChars[ai] {
                count += 1
            } else {
                break
            }
            ei -= 1
            ai -= 1
        }
        return count
    }

    /// Number of matching characters at the start of `expected` and `actual`.
    private static func prefixOverlap(expected: String, actual: String) -> Int {
        let expChars = Array(expected)
        let actChars = Array(actual)
        var count = 0
        let limit = min(expChars.count, actChars.count)
        for i in 0..<limit {
            if expChars[i] == actChars[i] {
                count += 1
            } else {
                break
            }
        }
        return count
    }
}
