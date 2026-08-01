import XCTest
@testable import MindLock

final class LanguageLessonFeedbackTests: XCTestCase {
    func test_FeedbackForCorrectAnswer_AwardsAccuracyXPAndProgress() {
        let question = LanguageLearningCatalog.sections(for: .spanish)[0].lessons[0].questions[0]

        let feedback = LanguageLessonFeedbackEngine.feedback(
            for: question,
            isCorrect: true,
            totalAnswered: 1,
            totalQuestions: 4
        )

        XCTAssertTrue(feedback.isCorrect)
        XCTAssertEqual(feedback.xpEarned, question.xp(correct: true))
        XCTAssertEqual(feedback.progress, 0.25, accuracy: 0.001)
        XCTAssertEqual(feedback.xpText, "+\(question.xp(correct: true)) XP")
        XCTAssertEqual(feedback.title, "Nice. You remembered it.")
    }

    func test_FeedbackForIncorrectAnswer_StillAwardsCompletionXP() {
        let question = LanguageLearningCatalog.sections(for: .spanish)[0].lessons[0].questions[0]

        let feedback = LanguageLessonFeedbackEngine.feedback(
            for: question,
            isCorrect: false,
            totalAnswered: 2,
            totalQuestions: 4
        )

        XCTAssertFalse(feedback.isCorrect)
        XCTAssertEqual(feedback.xpEarned, question.xp(correct: false))
        XCTAssertGreaterThan(feedback.xpEarned, 0)
        XCTAssertEqual(feedback.progress, 0.5, accuracy: 0.001)
        XCTAssertEqual(feedback.title, "Good practice.")
    }

    func test_FeedbackProgress_ClampsToValidRange() {
        let question = LanguageLearningCatalog.sections(for: .spanish)[0].lessons[0].questions[0]

        let feedback = LanguageLessonFeedbackEngine.feedback(
            for: question,
            isCorrect: true,
            totalAnswered: 6,
            totalQuestions: 4
        )

        XCTAssertEqual(feedback.progress, 1)
    }
}
