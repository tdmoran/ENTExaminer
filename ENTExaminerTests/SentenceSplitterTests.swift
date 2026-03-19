import Testing
@testable import ENTExaminer

@Suite("SentenceSplitter")
struct SentenceSplitterTests {
    let splitter = SentenceSplitter()

    @Test("Empty buffer returns no sentences")
    func emptyBuffer() {
        let result = splitter.extract(from: "")
        #expect(result.sentences.isEmpty)
        #expect(result.remainder == "")
    }

    @Test("Single complete sentence")
    func singleCompleteSentence() {
        let result = splitter.extract(from: "This is a complete sentence. ")
        #expect(result.sentences == ["This is a complete sentence."])
        #expect(result.remainder == "")
    }

    @Test("Incomplete sentence goes to remainder")
    func incompleteSentence() {
        let result = splitter.extract(from: "This is not finished yet")
        #expect(result.sentences.isEmpty)
        #expect(result.remainder == "This is not finished yet")
    }

    @Test("Multiple sentences with remainder")
    func multipleSentences() {
        let result = splitter.extract(from: "First sentence here. Second sentence here. Third incomplete")
        #expect(result.sentences.count == 2)
        #expect(result.sentences[0] == "First sentence here.")
        #expect(result.sentences[1] == "Second sentence here.")
        #expect(result.remainder == "Third incomplete")
    }

    @Test("Exclamation and question marks split correctly")
    func exclamationAndQuestionMark() {
        let result = splitter.extract(from: "What is photosynthesis? It converts light to energy! More text")
        #expect(result.sentences.count == 2)
        #expect(result.sentences[0].hasSuffix("?"))
        #expect(result.sentences[1].hasSuffix("!"))
        #expect(result.remainder == "More text")
    }

    @Test("Abbreviations do not cause false splits")
    func abbreviationsNotSplit() {
        let result = splitter.extract(from: "Dr. Smith explained the process. It was clear.")
        // "Dr." should NOT cause a split — both sentences should parse correctly
        #expect(result.sentences.count == 2)
        #expect(result.sentences[0].contains("Dr."))
    }

    @Test("Sentence at end of string (no trailing space)")
    func sentenceAtEndOfString() {
        let result = splitter.extract(from: "This is a complete sentence at the end.")
        #expect(result.sentences == ["This is a complete sentence at the end."])
        #expect(result.remainder == "")
    }

    @Test("Decimals do not cause false splits")
    func decimalsNotSplit() {
        let result = splitter.extract(from: "The value is 3.14 approximately. That is pi.")
        #expect(result.sentences.count == 2)
        #expect(result.sentences[0].contains("3.14"))
    }

    @Test("Multiple abbreviations in sequence")
    func multipleAbbreviations() {
        let result = splitter.extract(from: "Prof. Johnson and Dr. Lee published results. The paper was cited.")
        #expect(result.sentences.count == 2)
        #expect(result.sentences[0].contains("Prof."))
        #expect(result.sentences[0].contains("Dr."))
    }

    @Test("Very long sentence stays as one")
    func longSingleSentence() {
        let long = "This is a very long sentence that goes on and on and contains many words but never actually ends with a period or any other sentence-ending punctuation"
        let result = splitter.extract(from: long)
        #expect(result.sentences.isEmpty)
        #expect(result.remainder == long)
    }
}
