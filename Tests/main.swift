// Standalone test runner — no XCTest or Testing framework required.
// Run with: swift Tests/main.swift (or via Package.swift test target)

@testable import ENTExaminerCore
import Foundation

var passed = 0
var failed = 0

func assert(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if condition {
        passed += 1
    } else {
        failed += 1
        print("  FAIL [\(file.split(separator: "/").last ?? ""):\(line)] \(message)")
    }
}

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "", file: String = #file, line: Int = #line) {
    if a == b {
        passed += 1
    } else {
        failed += 1
        print("  FAIL [\(file.split(separator: "/").last ?? ""):\(line)] Expected \(b), got \(a). \(message)")
    }
}

func suite(_ name: String, _ block: () -> Void) {
    print("\n▸ \(name)")
    block()
}

func test(_ name: String, _ block: () -> Void) {
    print("  ◦ \(name)...", terminator: " ")
    let before = failed
    block()
    if failed == before {
        print("✓")
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - SentenceSplitter Tests
// ═══════════════════════════════════════════════════════

suite("SentenceSplitter") {
    let splitter = SentenceSplitter()

    test("Empty buffer") {
        let r = splitter.extract(from: "")
        assert(r.sentences.isEmpty, "Expected no sentences")
        assertEqual(r.remainder, "")
    }

    test("Single complete sentence") {
        let r = splitter.extract(from: "This is a complete sentence. ")
        assertEqual(r.sentences.count, 1)
        assertEqual(r.sentences.first, "This is a complete sentence.")
        assertEqual(r.remainder, "")
    }

    test("Incomplete sentence goes to remainder") {
        let r = splitter.extract(from: "This is not finished yet")
        assert(r.sentences.isEmpty, "Expected no sentences")
        assertEqual(r.remainder, "This is not finished yet")
    }

    test("Multiple sentences with remainder") {
        let r = splitter.extract(from: "First sentence here. Second sentence here. Third incomplete")
        assertEqual(r.sentences.count, 2)
        assertEqual(r.sentences[0], "First sentence here.")
        assertEqual(r.sentences[1], "Second sentence here.")
        assertEqual(r.remainder, "Third incomplete")
    }

    test("Question and exclamation marks") {
        let r = splitter.extract(from: "What is photosynthesis? It converts light to energy! More text")
        assertEqual(r.sentences.count, 2)
        assert(r.sentences[0].hasSuffix("?"), "First should end with ?")
        assert(r.sentences[1].hasSuffix("!"), "Second should end with !")
        assertEqual(r.remainder, "More text")
    }

    test("Abbreviations not split") {
        let r = splitter.extract(from: "Dr. Smith explained the process. It was clear.")
        assertEqual(r.sentences.count, 2)
        assert(r.sentences[0].contains("Dr."), "Should contain Dr.")
    }

    test("Sentence at end of string") {
        let r = splitter.extract(from: "Complete sentence at the very end.")
        assertEqual(r.sentences.count, 1)
        assertEqual(r.remainder, "")
    }

    test("Decimals not split") {
        let r = splitter.extract(from: "The value is 3.14 approximately. That is pi.")
        assertEqual(r.sentences.count, 2)
        assert(r.sentences[0].contains("3.14"), "Should contain 3.14")
    }

    test("Long text without sentence boundary") {
        let long = "This is a very long sentence that goes on and on without ever ending with punctuation"
        let r = splitter.extract(from: long)
        assert(r.sentences.isEmpty, "Expected no sentences")
        assertEqual(r.remainder, long)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - FlowController Tests
// ═══════════════════════════════════════════════════════

suite("FlowController") {
    let fc = FlowController()

    let analysis = DocumentAnalysis(
        topics: [
            ExamTopic(name: "Photosynthesis", importance: 0.9, keyConcepts: ["chlorophyll", "light reactions"], difficulty: .intermediate, subtopics: ["Calvin cycle", "Electron transport"]),
            ExamTopic(name: "Cell Respiration", importance: 0.8, keyConcepts: ["mitochondria", "ATP"], difficulty: .intermediate, subtopics: ["Glycolysis", "Krebs cycle"]),
            ExamTopic(name: "DNA Replication", importance: 0.7, keyConcepts: ["helicase", "polymerase"], difficulty: .advanced, subtopics: ["Leading strand", "Lagging strand"]),
        ],
        documentSummary: "Biology chapter.",
        suggestedQuestionCount: 10,
        estimatedDurationMinutes: 15,
        difficultyAssessment: "intermediate"
    )

    func makeTurn(index: Int, topic: ExamTopic, score: Double) -> ExamTurn {
        ExamTurn(
            questionIndex: index,
            topic: topic,
            question: "Q\(index)",
            userAnswer: "A",
            evaluation: TurnEvaluation(
                correctnessScore: score, completenessScore: score, clarityScore: score,
                keyPointsCovered: [], keyPointsMissed: [],
                feedback: "OK", followUpSuggestion: .moveToNextTopic
            )
        )
    }

    test("First question targets most important topic") {
        let action = fc.decideNextAction(analysis: analysis, completedTurns: [], topicScores: [], maxQuestions: 10)
        if case .askQuestion(let topic, let diff, _) = action {
            assertEqual(topic.name, "Photosynthesis")
            assertEqual(diff, .foundational)
        } else {
            assert(false, "Expected askQuestion, got \(action)")
        }
    }

    test("Wraps up at max questions") {
        let turns = (0..<10).map { makeTurn(index: $0, topic: analysis.topics[0], score: 0.8) }
        let action = fc.decideNextAction(analysis: analysis, completedTurns: turns, topicScores: [], maxQuestions: 10)
        assertEqual(action, .wrapUp)
    }

    test("Transitions topic after high mastery + 3 questions") {
        let turns = [
            makeTurn(index: 0, topic: analysis.topics[0], score: 0.9),
            makeTurn(index: 1, topic: analysis.topics[0], score: 0.9),
            makeTurn(index: 2, topic: analysis.topics[0], score: 0.95),
        ]
        let scores = [TopicScore(topicName: "Photosynthesis", mastery: 0.9, questionsAsked: 3, questionsCorrect: 3, trend: .stable)]
        let action = fc.decideNextAction(analysis: analysis, completedTurns: turns, topicScores: scores, maxQuestions: 10)
        if case .transitionTopic(let from, let to) = action {
            assertEqual(from.name, "Photosynthesis")
            assertEqual(to.name, "Cell Respiration")
        } else {
            assert(false, "Expected transitionTopic, got \(action)")
        }
    }

    test("Stays on topic at intermediate mastery, uses intermediate difficulty") {
        // Mastery 0.7 is in the 0.4-0.8 range: stays on topic, intermediate difficulty
        let turns = [makeTurn(index: 0, topic: analysis.topics[0], score: 0.7)]
        let scores = [TopicScore(topicName: "Photosynthesis", mastery: 0.7, questionsAsked: 1, questionsCorrect: 1, trend: .stable)]
        let action = fc.decideNextAction(analysis: analysis, completedTurns: turns, topicScores: scores, maxQuestions: 10)
        if case .askQuestion(let topic, let diff, _) = action {
            assertEqual(topic.name, "Photosynthesis")
            assertEqual(diff, .intermediate)
        } else if case .clarifyMisunderstanding = action {
            passed += 1
        } else {
            assert(false, "Expected askQuestion or clarify, got \(action)")
        }
    }

    test("Reduces difficulty on low mastery") {
        let turns = [makeTurn(index: 0, topic: analysis.topics[0], score: 0.2)]
        let scores = [TopicScore(topicName: "Photosynthesis", mastery: 0.2, questionsAsked: 1, questionsCorrect: 0, trend: .declining)]
        let action = fc.decideNextAction(analysis: analysis, completedTurns: turns, topicScores: scores, maxQuestions: 10)
        if case .askQuestion(_, let diff, _) = action {
            assertEqual(diff, .foundational)
        } else if case .clarifyMisunderstanding = action {
            passed += 1 // Also acceptable
        } else {
            assert(false, "Expected foundational or clarify, got \(action)")
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - PerformanceCalculator Tests
// ═══════════════════════════════════════════════════════

suite("PerformanceCalculator") {
    let calc = PerformanceCalculator()

    let analysis = DocumentAnalysis(
        topics: [
            ExamTopic(name: "Topic A", importance: 0.8, keyConcepts: ["a1"], difficulty: .intermediate, subtopics: []),
            ExamTopic(name: "Topic B", importance: 0.6, keyConcepts: ["b1"], difficulty: .foundational, subtopics: []),
        ],
        documentSummary: "Test doc",
        suggestedQuestionCount: 5,
        estimatedDurationMinutes: 10,
        difficultyAssessment: "intermediate"
    )

    func makeTurn(index: Int, topicIdx: Int, score: Double) -> ExamTurn {
        ExamTurn(
            questionIndex: index,
            topic: analysis.topics[topicIdx],
            question: "Q\(index)",
            userAnswer: "A",
            evaluation: TurnEvaluation(
                correctnessScore: score, completenessScore: score, clarityScore: score,
                keyPointsCovered: [], keyPointsMissed: [],
                feedback: "", followUpSuggestion: .moveToNextTopic
            )
        )
    }

    test("Empty turns returns empty snapshot") {
        let s = calc.computeSnapshot(turns: [], analysis: analysis, maxQuestions: 10)
        assertEqual(s, .empty)
    }

    test("Single turn computes score") {
        let s = calc.computeSnapshot(turns: [makeTurn(index: 0, topicIdx: 0, score: 0.8)], analysis: analysis, maxQuestions: 5)
        assert(s.overallScore > 0, "Score should be > 0")
        assertEqual(s.turnsCompleted, 1)
        assertEqual(s.turnsRemaining, 4)
        assertEqual(s.topicScores.count, 1)
        assertEqual(s.turnScores.count, 1)
    }

    test("Composite score formula") {
        let eval = TurnEvaluation(
            correctnessScore: 1.0, completenessScore: 0.5, clarityScore: 0.0,
            keyPointsCovered: [], keyPointsMissed: [],
            feedback: "", followUpSuggestion: .moveToNextTopic
        )
        let expected = 1.0 * 0.5 + 0.5 * 0.3 + 0.0 * 0.2  // 0.65
        assert(abs(eval.compositeScore - expected) < 0.001, "Expected ~0.65, got \(eval.compositeScore)")
    }

    test("Streak counts consecutive good answers") {
        let turns = (0..<3).map { makeTurn(index: $0, topicIdx: 0, score: 0.9) }
        let s = calc.computeSnapshot(turns: turns, analysis: analysis, maxQuestions: 10)
        assertEqual(s.streak, 3)
    }

    test("Streak breaks on low score") {
        let turns = [
            makeTurn(index: 0, topicIdx: 0, score: 0.9),
            makeTurn(index: 1, topicIdx: 0, score: 0.3),
            makeTurn(index: 2, topicIdx: 0, score: 0.9),
        ]
        let s = calc.computeSnapshot(turns: turns, analysis: analysis, maxQuestions: 10)
        assertEqual(s.streak, 1)
    }

    test("Multiple topics tracked separately") {
        let turns = [
            makeTurn(index: 0, topicIdx: 0, score: 0.9),
            makeTurn(index: 1, topicIdx: 1, score: 0.5),
        ]
        let s = calc.computeSnapshot(turns: turns, analysis: analysis, maxQuestions: 10)
        assertEqual(s.topicScores.count, 2)
        let a = s.topicScores.first(where: { $0.topicName == "Topic A" })
        let b = s.topicScores.first(where: { $0.topicName == "Topic B" })
        assert(a != nil, "Topic A should exist")
        assert(b != nil, "Topic B should exist")
        assert(a!.mastery > b!.mastery, "Topic A should have higher mastery")
    }

    test("Remaining turns calculation") {
        let turns = [makeTurn(index: 0, topicIdx: 0, score: 0.7), makeTurn(index: 1, topicIdx: 0, score: 0.7)]
        let s = calc.computeSnapshot(turns: turns, analysis: analysis, maxQuestions: 8)
        assertEqual(s.turnsCompleted, 2)
        assertEqual(s.turnsRemaining, 6)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - TurnEvaluation Tests
// ═══════════════════════════════════════════════════════

suite("TurnEvaluation") {
    test("Composite score weights are correct") {
        let eval = TurnEvaluation(
            correctnessScore: 0.8, completenessScore: 0.6, clarityScore: 1.0,
            keyPointsCovered: [], keyPointsMissed: [],
            feedback: "", followUpSuggestion: .moveToNextTopic
        )
        // 0.8*0.5 + 0.6*0.3 + 1.0*0.2 = 0.4 + 0.18 + 0.2 = 0.78
        assert(abs(eval.compositeScore - 0.78) < 0.001, "Expected 0.78, got \(eval.compositeScore)")
    }

    test("Perfect scores yield 1.0") {
        let eval = TurnEvaluation(
            correctnessScore: 1.0, completenessScore: 1.0, clarityScore: 1.0,
            keyPointsCovered: [], keyPointsMissed: [],
            feedback: "", followUpSuggestion: .moveToNextTopic
        )
        assert(abs(eval.compositeScore - 1.0) < 0.001, "Expected 1.0")
    }

    test("Zero scores yield 0.0") {
        let eval = TurnEvaluation(
            correctnessScore: 0.0, completenessScore: 0.0, clarityScore: 0.0,
            keyPointsCovered: [], keyPointsMissed: [],
            feedback: "", followUpSuggestion: .moveToNextTopic
        )
        assert(abs(eval.compositeScore) < 0.001, "Expected 0.0")
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Results
// ═══════════════════════════════════════════════════════

print("\n═══════════════════════════════")
print("Results: \(passed) passed, \(failed) failed")
print("═══════════════════════════════")

if failed > 0 {
    exit(1)
}
