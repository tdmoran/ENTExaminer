import Testing
@testable import ENTExaminer

@Suite("PerformanceCalculator")
struct PerformanceCalculatorTests {
    let calculator = PerformanceCalculator()

    let sampleAnalysis = DocumentAnalysis(
        topics: [
            ExamTopic(name: "Topic A", importance: 0.8, keyConcepts: ["a1"], difficulty: .intermediate, subtopics: []),
            ExamTopic(name: "Topic B", importance: 0.6, keyConcepts: ["b1"], difficulty: .foundational, subtopics: []),
        ],
        documentSummary: "Test document",
        suggestedQuestionCount: 5,
        estimatedDurationMinutes: 10,
        difficultyAssessment: "intermediate"
    )

    @Test("Empty turns returns empty snapshot")
    func emptyTurnsReturnsEmptySnapshot() {
        let snapshot = calculator.computeSnapshot(turns: [], analysis: sampleAnalysis, maxQuestions: 10)
        #expect(snapshot == .empty)
    }

    @Test("Single turn computes score and counts")
    func singleTurnComputesScore() {
        let turn = makeTurn(index: 0, topicIndex: 0, correctness: 0.8, completeness: 0.6, clarity: 1.0)

        let snapshot = calculator.computeSnapshot(turns: [turn], analysis: sampleAnalysis, maxQuestions: 5)

        #expect(snapshot.overallScore > 0)
        #expect(snapshot.turnsCompleted == 1)
        #expect(snapshot.turnsRemaining == 4)
        #expect(snapshot.topicScores.count == 1)
        #expect(snapshot.turnScores.count == 1)
    }

    @Test("Composite score formula: 0.5*correctness + 0.3*completeness + 0.2*clarity")
    func compositeScoreFormula() {
        let eval = TurnEvaluation(
            correctnessScore: 1.0,
            completenessScore: 0.5,
            clarityScore: 0.0,
            keyPointsCovered: [],
            keyPointsMissed: [],
            feedback: "",
            followUpSuggestion: .moveToNextTopic
        )
        // Expected: 1.0*0.5 + 0.5*0.3 + 0.0*0.2 = 0.65
        #expect(abs(eval.compositeScore - 0.65) < 0.001)
    }

    @Test("Streak counts consecutive good answers from the end")
    func streakCountsConsecutiveGoodAnswers() {
        let turns = [
            makeTurn(index: 0, topicIndex: 0, score: 0.9),
            makeTurn(index: 1, topicIndex: 0, score: 0.9),
            makeTurn(index: 2, topicIndex: 0, score: 0.9),
        ]

        let snapshot = calculator.computeSnapshot(turns: turns, analysis: sampleAnalysis, maxQuestions: 10)
        #expect(snapshot.streak == 3)
    }

    @Test("Streak breaks on low score")
    func streakBreaksOnLowScore() {
        let turns = [
            makeTurn(index: 0, topicIndex: 0, score: 0.9),
            makeTurn(index: 1, topicIndex: 0, score: 0.3),
            makeTurn(index: 2, topicIndex: 0, score: 0.9),
        ]

        let snapshot = calculator.computeSnapshot(turns: turns, analysis: sampleAnalysis, maxQuestions: 10)
        #expect(snapshot.streak == 1) // Only the last one counts
    }

    @Test("Remaining turns calculated correctly")
    func remainingTurnsCalculation() {
        let turns = [
            makeTurn(index: 0, topicIndex: 0, score: 0.7),
            makeTurn(index: 1, topicIndex: 0, score: 0.7),
        ]

        let snapshot = calculator.computeSnapshot(turns: turns, analysis: sampleAnalysis, maxQuestions: 8)
        #expect(snapshot.turnsCompleted == 2)
        #expect(snapshot.turnsRemaining == 6)
    }

    @Test("Multiple topics tracked separately")
    func multipleTopicsTracked() {
        let turns = [
            makeTurn(index: 0, topicIndex: 0, score: 0.9),
            makeTurn(index: 1, topicIndex: 1, score: 0.5),
        ]

        let snapshot = calculator.computeSnapshot(turns: turns, analysis: sampleAnalysis, maxQuestions: 10)
        #expect(snapshot.topicScores.count == 2)

        let topicA = snapshot.topicScores.first(where: { $0.topicName == "Topic A" })
        let topicB = snapshot.topicScores.first(where: { $0.topicName == "Topic B" })

        #expect(topicA != nil)
        #expect(topicB != nil)
        #expect(topicA!.mastery > topicB!.mastery)
    }

    // MARK: - Helpers

    func makeTurn(index: Int, topicIndex: Int, score: Double) -> ExamTurn {
        makeTurn(index: index, topicIndex: topicIndex, correctness: score, completeness: score, clarity: score)
    }

    func makeTurn(index: Int, topicIndex: Int, correctness: Double, completeness: Double, clarity: Double) -> ExamTurn {
        ExamTurn(
            questionIndex: index,
            topic: sampleAnalysis.topics[topicIndex],
            question: "Q\(index)",
            userAnswer: "A",
            evaluation: TurnEvaluation(
                correctnessScore: correctness,
                completenessScore: completeness,
                clarityScore: clarity,
                keyPointsCovered: [],
                keyPointsMissed: [],
                feedback: "",
                followUpSuggestion: .moveToNextTopic
            )
        )
    }
}
