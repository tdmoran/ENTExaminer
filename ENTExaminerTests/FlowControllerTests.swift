import Testing
@testable import ENTExaminer

@Suite("FlowController")
struct FlowControllerTests {
    let flowController = FlowController()

    let sampleAnalysis = DocumentAnalysis(
        topics: [
            ExamTopic(name: "Photosynthesis", importance: 0.9, keyConcepts: ["chlorophyll", "light reactions"], difficulty: .intermediate, subtopics: ["Calvin cycle", "Electron transport"]),
            ExamTopic(name: "Cell Respiration", importance: 0.8, keyConcepts: ["mitochondria", "ATP"], difficulty: .intermediate, subtopics: ["Glycolysis", "Krebs cycle"]),
            ExamTopic(name: "DNA Replication", importance: 0.7, keyConcepts: ["helicase", "polymerase"], difficulty: .advanced, subtopics: ["Leading strand", "Lagging strand"]),
        ],
        documentSummary: "A biology textbook chapter on cellular processes.",
        suggestedQuestionCount: 10,
        estimatedDurationMinutes: 15,
        difficultyAssessment: "intermediate"
    )

    @Test("First question targets the most important topic at foundational level")
    func firstQuestionStartsWithMostImportantTopic() {
        let action = flowController.decideNextAction(
            analysis: sampleAnalysis,
            completedTurns: [],
            topicScores: [],
            maxQuestions: 10
        )

        if case .askQuestion(let topic, let difficulty, _) = action {
            #expect(topic.name == "Photosynthesis")
            #expect(difficulty == .foundational)
        } else {
            Issue.record("Expected askQuestion, got \(action)")
        }
    }

    @Test("Wraps up when max questions reached")
    func wrapsUpAtMaxQuestions() {
        let turns = (0..<10).map { index in
            makeTurn(index: index, topic: sampleAnalysis.topics[0], score: 0.8)
        }

        let action = flowController.decideNextAction(
            analysis: sampleAnalysis,
            completedTurns: turns,
            topicScores: [],
            maxQuestions: 10
        )

        #expect(action == .wrapUp)
    }

    @Test("Transitions to next topic after high mastery")
    func movesToNextTopicAfterHighMastery() {
        let turns = [
            makeTurn(index: 0, topic: sampleAnalysis.topics[0], score: 0.9),
            makeTurn(index: 1, topic: sampleAnalysis.topics[0], score: 0.9),
            makeTurn(index: 2, topic: sampleAnalysis.topics[0], score: 0.95),
        ]

        let topicScores = [
            TopicScore(topicName: "Photosynthesis", mastery: 0.9, questionsAsked: 3, questionsCorrect: 3, trend: .stable)
        ]

        let action = flowController.decideNextAction(
            analysis: sampleAnalysis,
            completedTurns: turns,
            topicScores: topicScores,
            maxQuestions: 10
        )

        if case .transitionTopic(let from, let to) = action {
            #expect(from.name == "Photosynthesis")
            #expect(to.name == "Cell Respiration")
        } else {
            Issue.record("Expected transitionTopic, got \(action)")
        }
    }

    @Test("Escalates difficulty when mastery is high but within same topic")
    func escalatesDifficultyOnHighMastery() {
        let turns = [
            makeTurn(index: 0, topic: sampleAnalysis.topics[0], score: 0.85),
        ]

        let topicScores = [
            TopicScore(topicName: "Photosynthesis", mastery: 0.85, questionsAsked: 1, questionsCorrect: 1, trend: .stable)
        ]

        let action = flowController.decideNextAction(
            analysis: sampleAnalysis,
            completedTurns: turns,
            topicScores: topicScores,
            maxQuestions: 10
        )

        // With only 1 question asked (< 3), should stay on topic but at advanced difficulty
        if case .askQuestion(let topic, let difficulty, _) = action {
            #expect(topic.name == "Photosynthesis")
            #expect(difficulty == .advanced)
        } else {
            Issue.record("Expected askQuestion, got \(action)")
        }
    }

    @Test("Reduces difficulty when mastery is low")
    func reducesDifficultyOnLowMastery() {
        let turns = [
            makeTurn(index: 0, topic: sampleAnalysis.topics[0], score: 0.2),
        ]

        let topicScores = [
            TopicScore(topicName: "Photosynthesis", mastery: 0.2, questionsAsked: 1, questionsCorrect: 0, trend: .declining)
        ]

        let action = flowController.decideNextAction(
            analysis: sampleAnalysis,
            completedTurns: turns,
            topicScores: topicScores,
            maxQuestions: 10
        )

        if case .askQuestion(_, let difficulty, _) = action {
            #expect(difficulty == .foundational)
        } else if case .clarifyMisunderstanding = action {
            // Also acceptable — the FlowController may choose to clarify
        } else {
            Issue.record("Expected askQuestion or clarify, got \(action)")
        }
    }

    // MARK: - Helpers

    func makeTurn(index: Int, topic: ExamTopic, score: Double) -> ExamTurn {
        ExamTurn(
            questionIndex: index,
            topic: topic,
            question: "Question \(index)",
            userAnswer: "Answer",
            evaluation: TurnEvaluation(
                correctnessScore: score,
                completenessScore: score,
                clarityScore: score,
                keyPointsCovered: [],
                keyPointsMissed: [],
                feedback: "OK",
                followUpSuggestion: .moveToNextTopic
            )
        )
    }
}
