import Foundation

enum LanguageQuestionType: String, CaseIterable, Codable {
    case multipleChoice
    case reverseTranslation
    case fillBlank
    case typedAnswer
    case sentenceOrdering
    case connectPairs

    var displayName: String {
        switch self {
        case .multipleChoice: return "Meaning"
        case .reverseTranslation: return "Recall"
        case .fillBlank: return "Fill blank"
        case .typedAnswer: return "Type"
        case .sentenceOrdering: return "Build"
        case .connectPairs: return "Match"
        }
    }

    var baseXP: Int {
        switch self {
        case .multipleChoice: return 8
        case .reverseTranslation: return 10
        case .fillBlank: return 11
        case .typedAnswer: return 14
        case .sentenceOrdering: return 16
        case .connectPairs: return 12
        }
    }

    var unlockLevel: Int {
        switch self {
        case .multipleChoice, .reverseTranslation, .fillBlank, .connectPairs: return 1
        case .sentenceOrdering: return 2
        case .typedAnswer: return 3
        }
    }
}

enum LanguageDifficulty: String, CaseIterable, Codable {
    case easy
    case medium
    case hard

    var displayName: String { rawValue }

    var multiplier: Int {
        switch self {
        case .easy: return 1
        case .medium: return 2
        case .hard: return 3
        }
    }
}

struct LanguageCourse: Identifiable, Codable {
    let id: String
    let version: Int
    let sourceLanguage: String
    let targetLanguage: SharedSettings.LearningLanguage
    let displayName: String
    let sections: [LanguageSection]

    enum CodingKeys: String, CodingKey {
        case id = "courseId"
        case version
        case sourceLanguage
        case targetLanguage
        case displayName
        case sections
    }
}

struct LanguageQuestion: Identifiable, Codable {
    let id: String
    let type: LanguageQuestionType
    let skill: SharedSettings.LanguageSkill
    let difficulty: LanguageDifficulty
    let prompt: String
    let context: String
    let choices: [String]
    let correctAnswer: String
    let acceptedAnswers: [String]
    let tokens: [String]
    let correctTokens: [String]
    let pairs: [String: String]
    let learningNote: String

    var pairSources: [String] {
        Array(pairs.keys).sorted()
    }

    func xp(correct: Bool) -> Int {
        let completionXP = max(4, type.baseXP / 2)
        let accuracyXP = correct ? type.baseXP * difficulty.multiplier : 0
        return completionXP + accuracyXP
    }
}

struct LanguageLesson: Identifiable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let iconName: String
    let questions: [LanguageQuestion]
}

struct LanguageSection: Identifiable, Codable {
    let id: String
    let unitNumber: Int
    let title: String
    let theme: String
    let iconName: String
    let lessons: [LanguageLesson]
}

struct LanguageChallenge {
    let languageName: String
    let sectionTitle: String
    let lesson: LanguageLesson

    var questions: [LanguageQuestion] { lesson.questions }
}

enum LanguageLearningCatalog {
    static func course(for language: SharedSettings.LearningLanguage) -> LanguageCourse? {
        CoursePackLoader.course(for: language)
    }

    static func sections(for language: SharedSettings.LearningLanguage) -> [LanguageSection] {
        course(for: language)?.sections ?? []
    }

    static func nextChallenge(
        for language: SharedSettings.LearningLanguage,
        completedLessonIDs: Set<String>
    ) -> LanguageChallenge {
        let sections = sections(for: language)
        let next = sections
            .flatMap { section in section.lessons.map { (section, $0) } }
            .first { !completedLessonIDs.contains($0.1.id) }
            ?? sections.flatMap { section in section.lessons.map { (section, $0) } }.randomElement()

        guard let (section, lesson) = next else {
            let fallback = LanguageLesson(
                id: "fallback-language-lesson",
                title: "Quick practice",
                subtitle: "Try one short question",
                iconName: "book.fill",
                questions: []
            )
            return LanguageChallenge(languageName: language.displayName, sectionTitle: "Practice", lesson: fallback)
        }

        return LanguageChallenge(languageName: language.displayName, sectionTitle: section.title, lesson: lesson)
    }

    static func lessonCount(for language: SharedSettings.LearningLanguage) -> Int {
        sections(for: language).reduce(0) { $0 + $1.lessons.count }
    }
}

enum CoursePackLoader {
    private static var cache: [SharedSettings.LearningLanguage: LanguageCourse] = [:]

    static func course(for language: SharedSettings.LearningLanguage) -> LanguageCourse? {
        if let cached = cache[language] {
            return cached
        }

        guard let url = bundledCourseURL(for: language) else {
            assertionFailure("Missing bundled course JSON for \(language.rawValue)")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let course = try decoder.decode(LanguageCourse.self, from: data)
            cache[language] = course
            return course
        } catch {
            assertionFailure("Failed to decode course \(language.rawValue): \(error)")
            return nil
        }
    }

    static func bundledCourseURL(for language: SharedSettings.LearningLanguage) -> URL? {
        let filename = "\(language.rawValue)_en"
        let bundles = [Bundle.main] + Bundle.allBundles + Bundle.allFrameworks

        for bundle in bundles {
            if let url = bundle.url(forResource: filename, withExtension: "json", subdirectory: "Content/Courses")
                ?? bundle.url(forResource: filename, withExtension: "json") {
                return url
            }
        }

        return nil
    }
}
