import SwiftUI
import UniformTypeIdentifiers

struct LanguageChallengeView: View {
    let unlockMinutes: Int
    let onComplete: (Int, Int, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var challenge = LanguageChallenge.sample(
        for: SharedSettings.preferredLearningLanguage(),
        level: SharedSettings.languageProgressSummary().level
    )
    @State private var currentIndex = 0
    @State private var selectedAnswer: String?
    @State private var typedAnswer = ""
    @State private var sentenceTokens: [String] = []
    @State private var pairMatches: [String: String] = [:]
    @State private var pairTargets: [String] = []
    @State private var activePairSource: String?
    @State private var correctCount = 0
    @State private var earnedXP = 0
    @State private var skillXP: [SharedSettings.LanguageSkill: Int] = [:]
    @State private var answeredIDs = Set<UUID>()
    @State private var isCompleting = false

    private var currentQuestion: LanguageQuestion {
        questions[currentIndex]
    }

    private var questions: [LanguageQuestion] {
        challenge.questions
    }

    private var isLastQuestion: Bool {
        currentIndex == questions.count - 1
    }

    private var hasAnswered: Bool {
        answeredIDs.contains(currentQuestion.id)
    }

    private var currentResponseIsCorrect: Bool {
        responseIsCorrect(for: currentQuestion)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                header
                progressBar
                questionCard
                Spacer(minLength: DesignSystem.Spacing.lg)
                actionButtons
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.xl)
            .padding(.bottom, DesignSystem.Spacing.xxl)
            .background(DesignSystem.AppBackground())
            .navigationBarHidden(true)
            .onAppear {
                prepareCurrentQuestion()
                AnalyticsService.shared.track(.languageChallengeStarted, properties: [
                    "language": .string(SharedSettings.preferredLearningLanguage().rawValue),
                    "question_count": .int(questions.count),
                    "unlock_minutes": .int(unlockMinutes)
                ])
            }
        }
    }

    private var header: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("Language unlock")
                .font(DesignSystem.Typography.title2)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text("Complete a few \(challenge.languageName) questions to earn more app time. Correct answers earn more XP.")
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var progressBar: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            HStack {
                Text("Question \(currentIndex + 1) of \(questions.count)")
                    .font(DesignSystem.Typography.caption.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Spacer()
                Text("\(earnedXP) XP")
                    .font(DesignSystem.Typography.caption.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(DesignSystem.Colors.primary)
                        .frame(width: proxy.size.width * Double(currentIndex + 1) / Double(questions.count))
                }
            }
            .frame(height: 8)
        }
    }

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            questionHeader
            questionInteraction

            if hasAnswered {
                feedbackCard
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glossySurface(cornerRadius: DesignSystem.CornerRadius.xl, opacity: 0.55)
        .cornerRadius(DesignSystem.CornerRadius.xl)
    }

    private var questionHeader: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text(currentQuestion.type.displayName)
                Text(currentQuestion.difficulty.displayName)
            }
            .font(DesignSystem.Typography.caption.weight(.semibold))
            .foregroundColor(DesignSystem.Colors.primary)
            .textCase(.uppercase)

            Text(currentQuestion.prompt)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(currentQuestion.context)
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var questionInteraction: some View {
        switch currentQuestion.type {
        case .multipleChoice, .reverseTranslation, .fillBlank:
            multipleChoiceInteraction
        case .typedAnswer:
            typedAnswerInteraction
        case .sentenceOrdering:
            sentenceOrderingInteraction
        case .connectPairs:
            connectPairsInteraction
        }
    }

    private var multipleChoiceInteraction: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(currentQuestion.choices, id: \.self) { choice in
                answerButton(choice)
            }
        }
    }

    private func answerButton(_ choice: String) -> some View {
        let selected = selectedAnswer == choice
        let correct = currentQuestion.correctAnswer == choice
        let showCorrect = hasAnswered && correct

        return Button {
            selectedAnswer = choice
            submitCurrentAnswer()
        } label: {
            HStack {
                Text(choice)
                    .font(DesignSystem.Typography.body.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer()
                if selected || showCorrect {
                    Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(correct ? DesignSystem.Colors.success : DesignSystem.Colors.warning)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(answerBackground(selected: selected, correct: correct, showCorrect: showCorrect))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(hasAnswered)
    }

    private var typedAnswerInteraction: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            TextField("Type your answer", text: $typedAnswer)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(DesignSystem.Typography.body.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .padding(DesignSystem.Spacing.md)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous))
                .disabled(hasAnswered)

            Button("Check answer") {
                submitCurrentAnswer()
            }
            .mindLockButton(style: .primary)
            .disabled(typedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasAnswered)
            .opacity(typedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasAnswered ? 0.5 : 1)
        }
    }

    private var sentenceOrderingInteraction: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Drag the words into order.")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            FlexibleTokenGrid(tokens: sentenceTokens) { token in
                sentenceToken(token)
            }

            Button("Check sentence") {
                submitCurrentAnswer()
            }
            .mindLockButton(style: .primary)
            .disabled(hasAnswered)
        }
    }

    private func sentenceToken(_ token: String) -> some View {
        Text(token)
            .font(DesignSystem.Typography.callout.weight(.semibold))
            .foregroundColor(DesignSystem.Colors.textPrimary)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(Color.white.opacity(0.09))
            .clipShape(Capsule())
            .onDrag { NSItemProvider(object: token as NSString) }
            .onDrop(of: [UTType.text], delegate: SentenceDropDelegate(
                token: token,
                tokens: $sentenceTokens
            ))
    }

    private var connectPairsInteraction: some View {
        GeometryReader { proxy in
            ZStack {
                PairLines(
                    matches: pairMatches,
                    leftItems: currentQuestion.pairSources,
                    rightItems: pairTargets
                )
                HStack(alignment: .top, spacing: DesignSystem.Spacing.xl) {
                    pairColumn(items: currentQuestion.pairSources, side: .left)
                    Spacer(minLength: DesignSystem.Spacing.md)
                    pairColumn(items: pairTargets, side: .right)
                }
            }
        }
        .frame(height: CGFloat(max(currentQuestion.pairSources.count, pairTargets.count)) * 58)
    }

    private func pairColumn(items: [String], side: PairSide) -> some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(items, id: \.self) { item in
                pairButton(item, side: side)
            }
        }
    }

    private func pairButton(_ item: String, side: PairSide) -> some View {
        let selected = activePairSource == item
        let matched = side == .left ? pairMatches[item] != nil : pairMatches.values.contains(item)

        return Button {
            handlePairTap(item, side: side)
        } label: {
            Text(item)
                .font(DesignSystem.Typography.callout.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .frame(height: 48)
                .frame(maxWidth: .infinity)
                .background(pairBackground(selected: selected, matched: matched))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(hasAnswered)
    }

    private func answerBackground(selected: Bool, correct: Bool, showCorrect: Bool) -> Color {
        if showCorrect { return DesignSystem.Colors.success.opacity(0.18) }
        if selected && !correct { return DesignSystem.Colors.warning.opacity(0.18) }
        return Color.white.opacity(0.07)
    }

    private func pairBackground(selected: Bool, matched: Bool) -> Color {
        if selected { return DesignSystem.Colors.primary.opacity(0.22) }
        if matched { return DesignSystem.Colors.success.opacity(0.18) }
        return Color.white.opacity(0.08)
    }

    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(currentResponseIsCorrect ? "Nice. You remembered it." : "Good practice. The answer is \(currentQuestion.correctAnswer).")
                .font(DesignSystem.Typography.callout.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.textPrimary)
            Text(currentQuestion.learningNote)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous))
    }

    private var actionButtons: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Button(isLastQuestion ? "Unlock more time" : "Next question") {
                continueTapped()
            }
            .mindLockButton(style: .primary)
            .disabled(!hasAnswered || isCompleting)
            .opacity(hasAnswered ? 1 : 0.5)

            Button("Not now") {
                dismiss()
            }
            .mindLockButton(style: .ghost)
            .disabled(isCompleting)
        }
    }

    private func prepareCurrentQuestion() {
        selectedAnswer = nil
        typedAnswer = ""
        activePairSource = nil
        pairMatches = [:]
        sentenceTokens = currentQuestion.tokens.shuffled()
        pairTargets = Array(currentQuestion.pairs.values).shuffled()
    }

    private func submitCurrentAnswer() {
        guard !answeredIDs.contains(currentQuestion.id) else { return }
        answeredIDs.insert(currentQuestion.id)

        let correct = responseIsCorrect(for: currentQuestion)
        if correct {
            correctCount += 1
        }

        let xp = currentQuestion.xp(correct: correct)
        earnedXP += xp
        skillXP[currentQuestion.skill, default: 0] += xp
    }

    private func responseIsCorrect(for question: LanguageQuestion) -> Bool {
        switch question.type {
        case .multipleChoice, .reverseTranslation, .fillBlank:
            return selectedAnswer == question.correctAnswer
        case .typedAnswer:
            let normalized = normalize(typedAnswer)
            return question.acceptedAnswers.map(normalize).contains(normalized)
        case .sentenceOrdering:
            return sentenceTokens == question.correctTokens
        case .connectPairs:
            return pairMatches == question.pairs
        }
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: "?", with: "")
    }

    private func handlePairTap(_ item: String, side: PairSide) {
        switch side {
        case .left:
            activePairSource = item
        case .right:
            guard let source = activePairSource else { return }
            pairMatches[source] = item
            activePairSource = nil
            if pairMatches.count == currentQuestion.pairs.count {
                submitCurrentAnswer()
            }
        }
    }

    private func continueTapped() {
        guard hasAnswered else { return }
        if isLastQuestion {
            isCompleting = true
            SharedSettings.recordLanguagePractice(
                questionCount: questions.count,
                correctCount: correctCount,
                xpEarned: earnedXP,
                skillXP: skillXP
            )
            AnalyticsService.shared.track(.languageChallengeCompleted, properties: [
                "language": .string(SharedSettings.preferredLearningLanguage().rawValue),
                "question_count": .int(questions.count),
                "correct_count": .int(correctCount),
                "xp_earned": .int(earnedXP),
                "unlock_minutes": .int(unlockMinutes)
            ])
            onComplete(questions.count, correctCount, unlockMinutes)
            dismiss()
        } else {
            currentIndex += 1
            prepareCurrentQuestion()
        }
    }
}

private enum LanguageQuestionType: String, CaseIterable {
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

private enum LanguageDifficulty: String, CaseIterable {
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

private enum PairSide {
    case left
    case right
}

private struct LanguageChallenge {
    let languageName: String
    let questions: [LanguageQuestion]

    static func sample(for language: SharedSettings.LearningLanguage, level: Int) -> LanguageChallenge {
        let deck = deck(for: language)
        let availableQuestions = deck.questions.filter { $0.type.unlockLevel <= level }
        let candidates = availableQuestions.isEmpty ? deck.questions : availableQuestions
        return LanguageChallenge(
            languageName: deck.name,
            questions: Array(candidates.shuffled().prefix(3))
        )
    }

    private static func deck(for language: SharedSettings.LearningLanguage) -> (name: String, questions: [LanguageQuestion]) {
        switch language {
        case .spanish:
            return ("Spanish", LanguageDeck.spanish)
        case .french:
            return ("French", LanguageDeck.french)
        case .japanese:
            return ("Japanese", LanguageDeck.japanese)
        case .italian:
            return ("Italian", LanguageDeck.italian)
        case .german:
            return ("German", LanguageDeck.german)
        case .korean:
            return ("Korean", LanguageDeck.korean)
        }
    }
}

private struct LanguageQuestion: Identifiable {
    let id = UUID()
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

    static func choice(
        _ type: LanguageQuestionType = .multipleChoice,
        skill: SharedSettings.LanguageSkill = .vocabulary,
        difficulty: LanguageDifficulty,
        prompt: String,
        context: String,
        choices: [String],
        answer: String,
        note: String
    ) -> LanguageQuestion {
        LanguageQuestion(
            type: type,
            skill: skill,
            difficulty: difficulty,
            prompt: prompt,
            context: context,
            choices: choices,
            correctAnswer: answer,
            acceptedAnswers: [answer],
            tokens: [],
            correctTokens: [],
            pairs: [:],
            learningNote: note
        )
    }

    static func typed(
        skill: SharedSettings.LanguageSkill = .recall,
        difficulty: LanguageDifficulty,
        prompt: String,
        context: String,
        answers: [String],
        note: String
    ) -> LanguageQuestion {
        LanguageQuestion(
            type: .typedAnswer,
            skill: skill,
            difficulty: difficulty,
            prompt: prompt,
            context: context,
            choices: [],
            correctAnswer: answers.first ?? "",
            acceptedAnswers: answers,
            tokens: [],
            correctTokens: [],
            pairs: [:],
            learningNote: note
        )
    }

    static func sentence(
        difficulty: LanguageDifficulty,
        prompt: String,
        context: String,
        tokens: [String],
        answer: String,
        note: String
    ) -> LanguageQuestion {
        LanguageQuestion(
            type: .sentenceOrdering,
            skill: .sentenceBuilding,
            difficulty: difficulty,
            prompt: prompt,
            context: context,
            choices: [],
            correctAnswer: answer,
            acceptedAnswers: [answer],
            tokens: tokens,
            correctTokens: tokens,
            pairs: [:],
            learningNote: note
        )
    }

    static func pairs(
        difficulty: LanguageDifficulty,
        prompt: String,
        context: String,
        pairs: [String: String],
        note: String
    ) -> LanguageQuestion {
        LanguageQuestion(
            type: .connectPairs,
            skill: .vocabulary,
            difficulty: difficulty,
            prompt: prompt,
            context: context,
            choices: [],
            correctAnswer: pairs.map { "\($0.key) = \($0.value)" }.sorted().joined(separator: ", "),
            acceptedAnswers: [],
            tokens: [],
            correctTokens: [],
            pairs: pairs,
            learningNote: note
        )
    }
}

private enum LanguageDeck {
    static let spanish: [LanguageQuestion] = [
        .choice(difficulty: .easy, prompt: "Casa", context: "What does this Spanish word mean?", choices: ["House", "Street", "Friend"], answer: "House", note: "Casa means house or home."),
        .choice(difficulty: .medium, prompt: "Cansado", context: "Choose the English meaning.", choices: ["Tired", "Careful", "Hungry"], answer: "Tired", note: "Cansado means tired. Cansada is the feminine form."),
        .choice(difficulty: .hard, prompt: "Pastizal", context: "Choose the closest English meaning.", choices: ["Grassland", "Pastry", "Hallway"], answer: "Grassland", note: "Pastizal means grassland or pasture."),
        .choice(.reverseTranslation, difficulty: .easy, prompt: "Thank you", context: "Choose the Spanish phrase.", choices: ["Gracias", "Agua", "Libro"], answer: "Gracias", note: "Gracias means thank you."),
        .choice(.fillBlank, skill: .grammar, difficulty: .medium, prompt: "Yo ___ agua.", context: "Fill in: I drink water.", choices: ["bebo", "bebe", "beben"], answer: "bebo", note: "Yo bebo means I drink."),
        .pairs(difficulty: .easy, prompt: "Connect the pairs.", context: "Match each Spanish word to English.", pairs: ["agua": "water", "libro": "book", "amigo": "friend"], note: "These are high-frequency beginner words."),
        .sentence(difficulty: .easy, prompt: "Build the sentence.", context: "I drink water.", tokens: ["Yo", "bebo", "agua"], answer: "Yo bebo agua", note: "Spanish often keeps the same subject-verb-object order as English."),
        .typed(difficulty: .medium, prompt: "Type the Spanish word for water.", context: "One word.", answers: ["agua"], note: "Agua means water.")
    ]

    static let french: [LanguageQuestion] = [
        .choice(difficulty: .easy, prompt: "Maison", context: "What does this French word mean?", choices: ["House", "Book", "Music"], answer: "House", note: "Maison means house or home."),
        .choice(difficulty: .medium, prompt: "Fatigué", context: "Choose the English meaning.", choices: ["Tired", "Fast", "Clean"], answer: "Tired", note: "Fatigué means tired."),
        .choice(difficulty: .hard, prompt: "Prairie", context: "Choose the closest English meaning.", choices: ["Meadow", "Prayer", "Window"], answer: "Meadow", note: "Prairie can mean meadow or grassland."),
        .choice(.reverseTranslation, difficulty: .easy, prompt: "Thank you", context: "Choose the French word.", choices: ["Merci", "Eau", "Livre"], answer: "Merci", note: "Merci means thank you."),
        .choice(.fillBlank, skill: .grammar, difficulty: .medium, prompt: "Je ___ de l'eau.", context: "Fill in: I drink water.", choices: ["bois", "boit", "buvez"], answer: "bois", note: "Je bois means I drink."),
        .pairs(difficulty: .easy, prompt: "Connect the pairs.", context: "Match each French word to English.", pairs: ["eau": "water", "livre": "book", "ami": "friend"], note: "Short words are a good way into French pronunciation."),
        .sentence(difficulty: .easy, prompt: "Build the sentence.", context: "I drink water.", tokens: ["Je", "bois", "de", "l'eau"], answer: "Je bois de l'eau", note: "De l'eau means some water."),
        .typed(difficulty: .medium, prompt: "Type the French word for thank you.", context: "One word.", answers: ["merci"], note: "Merci is the everyday way to say thanks.")
    ]

    static let japanese: [LanguageQuestion] = [
        .choice(difficulty: .easy, prompt: "Mizu", context: "What does this Japanese word mean?", choices: ["Water", "Food", "House"], answer: "Water", note: "Mizu means water."),
        .choice(difficulty: .medium, prompt: "Tsukareta", context: "Choose the English meaning.", choices: ["Tired", "Quiet", "Early"], answer: "Tired", note: "Tsukareta means tired."),
        .choice(difficulty: .hard, prompt: "Sougen", context: "Choose the closest English meaning.", choices: ["Grassland", "Train", "Library"], answer: "Grassland", note: "Sougen means grassland or plain."),
        .choice(.reverseTranslation, difficulty: .easy, prompt: "Thank you", context: "Choose the Japanese phrase.", choices: ["Arigatou", "Mizu", "Hon"], answer: "Arigatou", note: "Arigatou means thanks."),
        .choice(.fillBlank, skill: .grammar, difficulty: .medium, prompt: "Mizu o ___ .", context: "Fill in: I drink water.", choices: ["nomu", "miru", "yomu"], answer: "nomu", note: "Nomu means drink."),
        .pairs(difficulty: .easy, prompt: "Connect the pairs.", context: "Match each Japanese word to English.", pairs: ["mizu": "water", "hon": "book", "ie": "house"], note: "These are useful beginner nouns."),
        .sentence(difficulty: .easy, prompt: "Build the sentence.", context: "I drink water.", tokens: ["Mizu", "o", "nomu"], answer: "Mizu o nomu", note: "O marks the object in many Japanese sentences."),
        .typed(difficulty: .medium, prompt: "Type the Japanese word for book.", context: "Use romaji.", answers: ["hon"], note: "Hon means book.")
    ]

    static let italian: [LanguageQuestion] = [
        .choice(difficulty: .easy, prompt: "Casa", context: "What does this Italian word mean?", choices: ["House", "Street", "Friend"], answer: "House", note: "Casa means house or home."),
        .choice(difficulty: .medium, prompt: "Stanco", context: "Choose the English meaning.", choices: ["Tired", "Closed", "Sweet"], answer: "Tired", note: "Stanco means tired. Stanca is the feminine form."),
        .choice(difficulty: .hard, prompt: "Prateria", context: "Choose the closest English meaning.", choices: ["Prairie", "Printer", "Plate"], answer: "Prairie", note: "Prateria means prairie or grassland."),
        .choice(.reverseTranslation, difficulty: .easy, prompt: "Thank you", context: "Choose the Italian word.", choices: ["Grazie", "Acqua", "Libro"], answer: "Grazie", note: "Grazie means thank you."),
        .choice(.fillBlank, skill: .grammar, difficulty: .medium, prompt: "Io ___ acqua.", context: "Fill in: I drink water.", choices: ["bevo", "beve", "bevono"], answer: "bevo", note: "Io bevo means I drink."),
        .pairs(difficulty: .easy, prompt: "Connect the pairs.", context: "Match each Italian word to English.", pairs: ["acqua": "water", "libro": "book", "amico": "friend"], note: "Many Italian words are close to Latin roots."),
        .sentence(difficulty: .easy, prompt: "Build the sentence.", context: "I drink water.", tokens: ["Io", "bevo", "acqua"], answer: "Io bevo acqua", note: "Italian can use subject-verb-object order like English."),
        .typed(difficulty: .medium, prompt: "Type the Italian word for book.", context: "One word.", answers: ["libro"], note: "Libro means book.")
    ]

    static let german: [LanguageQuestion] = [
        .choice(difficulty: .easy, prompt: "Haus", context: "What does this German word mean?", choices: ["House", "Friend", "Street"], answer: "House", note: "Haus means house."),
        .choice(difficulty: .medium, prompt: "Müde", context: "Choose the English meaning.", choices: ["Tired", "Brave", "Small"], answer: "Tired", note: "Müde means tired."),
        .choice(difficulty: .hard, prompt: "Weideland", context: "Choose the closest English meaning.", choices: ["Pasture", "Weather", "Workshop"], answer: "Pasture", note: "Weideland means pasture or grazing land."),
        .choice(.reverseTranslation, difficulty: .easy, prompt: "Thank you", context: "Choose the German word.", choices: ["Danke", "Wasser", "Buch"], answer: "Danke", note: "Danke means thank you."),
        .choice(.fillBlank, skill: .grammar, difficulty: .medium, prompt: "Ich ___ Wasser.", context: "Fill in: I drink water.", choices: ["trinke", "trinkt", "trinken"], answer: "trinke", note: "Ich trinke means I drink."),
        .pairs(difficulty: .easy, prompt: "Connect the pairs.", context: "Match each German word to English.", pairs: ["wasser": "water", "buch": "book", "freund": "friend"], note: "German nouns are usually capitalized in standard writing."),
        .sentence(difficulty: .easy, prompt: "Build the sentence.", context: "I drink water.", tokens: ["Ich", "trinke", "Wasser"], answer: "Ich trinke Wasser", note: "The verb usually sits in the second position in simple German sentences."),
        .typed(difficulty: .medium, prompt: "Type the German word for water.", context: "One word.", answers: ["wasser"], note: "Wasser means water.")
    ]

    static let korean: [LanguageQuestion] = [
        .choice(difficulty: .easy, prompt: "Mul", context: "What does this Korean word mean?", choices: ["Water", "House", "Book"], answer: "Water", note: "Mul means water."),
        .choice(difficulty: .medium, prompt: "Pigonhae", context: "Choose the English meaning.", choices: ["Tired", "Bright", "Cold"], answer: "Tired", note: "Pigonhae means tired in casual speech."),
        .choice(difficulty: .hard, prompt: "Chowon", context: "Choose the closest English meaning.", choices: ["Grassland", "Kitchen", "Question"], answer: "Grassland", note: "Chowon means grassland or meadow."),
        .choice(.reverseTranslation, difficulty: .easy, prompt: "Thank you", context: "Choose the Korean phrase.", choices: ["Gamsahamnida", "Mul", "Chaek"], answer: "Gamsahamnida", note: "Gamsahamnida is a polite thank you."),
        .choice(.fillBlank, skill: .grammar, difficulty: .medium, prompt: "Mul-eul ___ .", context: "Fill in: I drink water.", choices: ["masyeoyo", "bwayo", "ilg-eoyo"], answer: "masyeoyo", note: "Masyeoyo means drink in polite speech."),
        .pairs(difficulty: .easy, prompt: "Connect the pairs.", context: "Match each Korean word to English.", pairs: ["mul": "water", "chaek": "book", "jip": "house"], note: "These are useful starter nouns."),
        .sentence(difficulty: .easy, prompt: "Build the sentence.", context: "I drink water.", tokens: ["Mul-eul", "masyeoyo"], answer: "Mul-eul masyeoyo", note: "Eul marks the object in this romanized sentence."),
        .typed(difficulty: .medium, prompt: "Type the Korean word for friend.", context: "Use romanization.", answers: ["chingu"], note: "Chingu means friend.")
    ]
}

private struct SentenceDropDelegate: DropDelegate {
    let token: String
    @Binding var tokens: [String]

    func performDrop(info: DropInfo) -> Bool {
        true
    }

    func dropEntered(info: DropInfo) {
        guard let provider = info.itemProviders(for: [UTType.text]).first else { return }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let dragged = object as? NSString else { return }
            DispatchQueue.main.async {
                let draggedToken = dragged as String
                guard draggedToken != self.token,
                      let from = self.tokens.firstIndex(of: draggedToken),
                      let to = self.tokens.firstIndex(of: self.token) else {
                    return
                }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    self.tokens.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
                }
            }
        }
    }
}

private struct PairLines: View {
    let matches: [String: String]
    let leftItems: [String]
    let rightItems: [String]

    var body: some View {
        Canvas { context, canvasSize in
            for (left, right) in matches {
                guard let leftIndex = leftItems.firstIndex(of: left),
                      let rightIndex = rightItems.firstIndex(of: right) else {
                    continue
                }

                let start = CGPoint(x: canvasSize.width * 0.42, y: CGFloat(leftIndex) * 56 + 24)
                let end = CGPoint(x: canvasSize.width * 0.58, y: CGFloat(rightIndex) * 56 + 24)
                var path = Path()
                path.move(to: start)
                path.addCurve(
                    to: end,
                    control1: CGPoint(x: canvasSize.width * 0.48, y: start.y),
                    control2: CGPoint(x: canvasSize.width * 0.52, y: end.y)
                )
                context.stroke(path, with: .color(DesignSystem.Colors.success.opacity(0.9)), lineWidth: 3)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct FlexibleTokenGrid<Content: View>: View {
    let tokens: [String]
    let content: (String) -> Content

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 76), spacing: DesignSystem.Spacing.sm)],
            alignment: .leading,
            spacing: DesignSystem.Spacing.sm
        ) {
            ForEach(tokens, id: \.self) { token in
                content(token)
            }
        }
    }
}

struct LanguageChallengeView_Previews: PreviewProvider {
    static var previews: some View {
        LanguageChallengeView(unlockMinutes: 10) { _, _, _ in }
    }
}
