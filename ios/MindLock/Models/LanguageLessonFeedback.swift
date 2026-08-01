import Foundation

struct LanguageAnswerFeedback: Equatable {
    let questionID: String
    let isCorrect: Bool
    let xpEarned: Int
    let totalAnswered: Int
    let totalQuestions: Int

    var progress: Double {
        guard totalQuestions > 0 else { return 0 }
        return min(max(Double(totalAnswered) / Double(totalQuestions), 0), 1)
    }

    var title: String {
        isCorrect ? "Nice. You remembered it." : "Good practice."
    }

    var xpText: String {
        "+\(xpEarned) XP"
    }
}

enum LanguageLessonFeedbackEngine {
    static func feedback(
        for question: LanguageQuestion,
        isCorrect: Bool,
        totalAnswered: Int,
        totalQuestions: Int
    ) -> LanguageAnswerFeedback {
        LanguageAnswerFeedback(
            questionID: question.id,
            isCorrect: isCorrect,
            xpEarned: question.xp(correct: isCorrect),
            totalAnswered: totalAnswered,
            totalQuestions: totalQuestions
        )
    }
}
