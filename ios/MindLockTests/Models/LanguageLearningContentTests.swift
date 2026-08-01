import XCTest
@testable import MindLock

final class LanguageLearningContentTests: XCTestCase {
    func test_AllCourses_LoadBundledCoursePacks() {
        for language in SharedSettings.LearningLanguage.allCases {
            let course = LanguageLearningCatalog.course(for: language)

            XCTAssertNotNil(course, language.displayName)
            XCTAssertEqual(course?.targetLanguage, language, language.displayName)
            XCTAssertFalse(course?.sections.isEmpty ?? true, language.displayName)
        }
    }

    func test_AllCourses_HaveFourLessonsPerSection() {
        for language in SharedSettings.LearningLanguage.allCases {
            let sections = LanguageLearningCatalog.sections(for: language)

            XCTAssertGreaterThanOrEqual(sections.count, 4, language.displayName)
            XCTAssertTrue(sections.allSatisfy { $0.lessons.count == 4 }, language.displayName)
        }
    }

    func test_AllCourses_AreExpandedToEightSections() {
        for language in SharedSettings.LearningLanguage.allCases {
            XCTAssertEqual(LanguageLearningCatalog.sections(for: language).count, 8, language.displayName)
            XCTAssertEqual(LanguageLearningCatalog.lessonCount(for: language), 32, language.displayName)
        }
    }

    func test_AllCourses_EachLessonHasFourQuestions() {
        for language in SharedSettings.LearningLanguage.allCases {
            let lessons = LanguageLearningCatalog.sections(for: language).flatMap(\.lessons)

            XCTAssertFalse(lessons.isEmpty, language.displayName)
            XCTAssertTrue(lessons.allSatisfy { $0.questions.count == 4 }, language.displayName)
        }
    }

    func test_AllCourses_QuestionIDsAreStableUniqueAndLanguageScoped() {
        let expectedPrefixes: [SharedSettings.LearningLanguage: String] = [
            .spanish: "es-",
            .french: "fr-",
            .japanese: "ja-",
            .italian: "it-",
            .german: "de-",
            .korean: "ko-"
        ]

        for language in SharedSettings.LearningLanguage.allCases {
            let questionIDs = LanguageLearningCatalog.sections(for: language)
                .flatMap(\.lessons)
                .flatMap(\.questions)
                .map(\.id)

            XCTAssertEqual(questionIDs.count, LanguageLearningCatalog.lessonCount(for: language) * 4, language.displayName)
            XCTAssertEqual(Set(questionIDs).count, questionIDs.count, language.displayName)
            XCTAssertTrue(questionIDs.allSatisfy { $0.hasPrefix(expectedPrefixes[language] ?? "") }, language.displayName)
        }
    }

    func test_AllCourses_UseVariedQuestionTypes() {
        for language in SharedSettings.LearningLanguage.allCases {
            let questionTypes = Set(LanguageLearningCatalog.sections(for: language)
                .flatMap(\.lessons)
                .flatMap(\.questions)
                .map(\.type))

            XCTAssertEqual(questionTypes, Set(LanguageQuestionType.allCases), language.displayName)
        }
    }

    func test_AllCourses_UseProgressiveDifficulty() {
        for language in SharedSettings.LearningLanguage.allCases {
            let difficulties = Set(LanguageLearningCatalog.sections(for: language)
                .flatMap(\.lessons)
                .flatMap(\.questions)
                .map(\.difficulty))

            XCTAssertEqual(difficulties, Set(LanguageDifficulty.allCases), language.displayName)
        }
    }

    func test_AllCourses_SectionsHaveStableLessonThemes() {
        for language in SharedSettings.LearningLanguage.allCases {
            let sections = LanguageLearningCatalog.sections(for: language)

            XCTAssertEqual(sections.prefix(4).map(\.title), [
                "Order at a cafe",
                "Meet someone new",
                "Find your way around",
                "Talk about your day"
            ], language.displayName)
            XCTAssertTrue(sections.allSatisfy { !$0.theme.isEmpty && !$0.iconName.isEmpty }, language.displayName)
        }
    }

    func test_AllCourses_HaveValidQuestionPayloads() {
        for language in SharedSettings.LearningLanguage.allCases {
            let questions = LanguageLearningCatalog.sections(for: language)
                .flatMap(\.lessons)
                .flatMap(\.questions)

            for question in questions {
                XCTAssertFalse(question.prompt.isEmpty, question.id)
                XCTAssertFalse(question.context.isEmpty, question.id)
                XCTAssertFalse(question.learningNote.isEmpty, question.id)

                switch question.type {
                case .multipleChoice, .reverseTranslation, .fillBlank:
                    XCTAssertGreaterThanOrEqual(question.choices.count, 3, question.id)
                    XCTAssertTrue(question.choices.contains(question.correctAnswer), question.id)
                case .typedAnswer:
                    XCTAssertFalse(question.correctAnswer.isEmpty, question.id)
                    XCTAssertFalse(question.acceptedAnswers.isEmpty, question.id)
                    XCTAssertTrue(question.acceptedAnswers.contains(question.correctAnswer), question.id)
                case .sentenceOrdering:
                    XCTAssertFalse(question.tokens.isEmpty, question.id)
                    XCTAssertEqual(question.tokens, question.correctTokens, question.id)
                    XCTAssertEqual(question.correctAnswer, question.correctTokens.joined(separator: " "), question.id)
                case .connectPairs:
                    XCTAssertGreaterThanOrEqual(question.pairs.count, 3, question.id)
                }
            }
        }
    }

    func test_AllCourses_HaveLocalizedSentenceContent() {
        let cafePoliteAnswers = Dictionary(uniqueKeysWithValues: SharedSettings.LearningLanguage.allCases.map { language in
            let answer = LanguageLearningCatalog.sections(for: language)[0].lessons[1].questions[2].correctAnswer
            return (language, answer)
        })

        XCTAssertEqual(cafePoliteAnswers[.spanish], "Un café, por favor")
        XCTAssertEqual(cafePoliteAnswers[.french], "Un café, s'il vous plaît")
        XCTAssertEqual(cafePoliteAnswers[.japanese], "コーヒーを ください")
        XCTAssertEqual(cafePoliteAnswers[.italian], "Un caffè, per favore")
        XCTAssertEqual(cafePoliteAnswers[.german], "Einen Kaffee, bitte")
        XCTAssertEqual(cafePoliteAnswers[.korean], "커피 한 잔 주세요")
    }

    func test_NextChallenge_UsesFirstIncompleteLesson() {
        let completed = Set(["spanish-cafe-1", "spanish-cafe-2"])

        let challenge = LanguageLearningCatalog.nextChallenge(for: .spanish, completedLessonIDs: completed)

        XCTAssertEqual(challenge.lesson.id, "spanish-cafe-3")
        XCTAssertEqual(challenge.questions.count, 4)
    }

    func test_NextChallenge_UsesLanguageSpecificFirstIncompleteLesson() {
        let completed = Set(["french-cafe-1", "french-cafe-2"])

        let challenge = LanguageLearningCatalog.nextChallenge(for: .french, completedLessonIDs: completed)

        XCTAssertEqual(challenge.lesson.id, "french-cafe-3")
        XCTAssertEqual(challenge.languageName, "French")
        XCTAssertEqual(challenge.questions.count, 4)
    }
}
