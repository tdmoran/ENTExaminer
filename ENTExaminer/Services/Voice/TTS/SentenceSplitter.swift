import Foundation

/// Extracts complete sentences from a text buffer, splitting on sentence-ending
/// punctuation while avoiding false splits on common abbreviations.
struct SentenceSplitter: Sendable {
    /// The minimum character count for a fragment to be considered a complete sentence.
    /// Prevents splitting on lone punctuation or very short fragments.
    private static let minimumSentenceLength = 10

    /// Common abbreviations that end with a period but do not end a sentence.
    private static let abbreviations: Set<String> = [
        "mr", "mrs", "ms", "dr", "prof", "sr", "jr",
        "st", "ave", "blvd",
        "inc", "ltd", "corp",
        "vs", "etc", "approx",
        "dept", "est", "govt",
        "e.g", "i.e", "al",
    ]

    /// Result of extracting sentences from a buffer.
    struct ExtractionResult: Sendable, Equatable {
        /// Complete sentences ready to be spoken.
        let sentences: [String]
        /// Remaining text that has not yet formed a complete sentence.
        let remainder: String
    }

    /// Extracts complete sentences from the given text buffer.
    ///
    /// Splits on `.`, `!`, or `?` followed by whitespace or end of string.
    /// Handles common abbreviations to avoid false splits.
    ///
    /// - Parameter buffer: The accumulated text to scan for sentences.
    /// - Returns: An ``ExtractionResult`` containing found sentences and leftover text.
    func extract(from buffer: String) -> ExtractionResult {
        guard !buffer.isEmpty else {
            return ExtractionResult(sentences: [], remainder: "")
        }

        var sentences: [String] = []
        var searchStart = buffer.startIndex

        while searchStart < buffer.endIndex {
            guard let splitPoint = findSentenceBoundary(
                in: buffer,
                from: searchStart
            ) else {
                break
            }

            let sentence = String(buffer[searchStart...splitPoint])
                .trimmingCharacters(in: .whitespaces)

            if sentence.count >= Self.minimumSentenceLength {
                sentences.append(sentence)
            } else if let last = sentences.last {
                // Merge short fragments into the previous sentence
                sentences[sentences.count - 1] = last + " " + sentence
            }
            // else: skip orphaned short fragments at the start

            // Advance past the split point and any trailing whitespace
            let afterSplit = buffer.index(after: splitPoint)
            searchStart = afterSplit < buffer.endIndex
                ? skipWhitespace(in: buffer, from: afterSplit)
                : buffer.endIndex
        }

        let remainder = searchStart < buffer.endIndex
            ? String(buffer[searchStart...])
            : ""

        return ExtractionResult(sentences: sentences, remainder: remainder)
    }

    // MARK: - Private Helpers

    /// Finds the next sentence boundary in the buffer starting from the given index.
    /// Returns the index of the sentence-ending punctuation character, or nil if none found.
    private func findSentenceBoundary(
        in text: String,
        from start: String.Index
    ) -> String.Index? {
        var index = start

        while index < text.endIndex {
            let char = text[index]

            if char == "." || char == "!" || char == "?" {
                let afterPunc = text.index(after: index)

                // Punctuation at end of string is a valid boundary
                if afterPunc == text.endIndex {
                    return index
                }

                // Punctuation followed by whitespace is a valid boundary
                let nextChar = text[afterPunc]
                guard nextChar.isWhitespace else {
                    // Could be an abbreviation like "e.g." or a decimal — skip
                    index = afterPunc
                    continue
                }

                // Check if this is an abbreviation
                if char == ".", isAbbreviation(in: text, periodAt: index, from: start) {
                    index = afterPunc
                    continue
                }

                return index
            }

            index = text.index(after: index)
        }

        return nil
    }

    /// Determines whether the period at `periodIndex` is part of a known abbreviation.
    private func isAbbreviation(
        in text: String,
        periodAt periodIndex: String.Index,
        from segmentStart: String.Index
    ) -> Bool {
        // Walk backwards from the period to find the start of the word
        var wordStart = periodIndex
        while wordStart > segmentStart {
            let prev = text.index(before: wordStart)
            let prevChar = text[prev]
            if prevChar.isWhitespace {
                break
            }
            wordStart = prev
        }

        let word = String(text[wordStart..<periodIndex]).lowercased()
        return Self.abbreviations.contains(word)
    }

    /// Advances past whitespace characters starting from the given index.
    private func skipWhitespace(in text: String, from start: String.Index) -> String.Index {
        var index = start
        while index < text.endIndex, text[index].isWhitespace {
            index = text.index(after: index)
        }
        return index
    }
}
