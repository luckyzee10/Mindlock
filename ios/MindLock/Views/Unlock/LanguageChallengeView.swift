import AudioToolbox
import SwiftUI
import UIKit

struct LanguageChallengeView: View {
    let unlockMinutes: Int
    let onComplete: (Int, Int, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var challenge = LanguageLearningCatalog.nextChallenge(
        for: SharedSettings.preferredLearningLanguage(),
        completedLessonIDs: SharedSettings.completedLanguageLessonIDs()
    )
    @State private var currentIndex = 0
    @State private var selectedAnswer: String?
    @State private var typedAnswer = ""
    @State private var sentenceBankTokens: [SentenceToken] = []
    @State private var sentenceAnswerTokens: [SentenceToken] = []
    @State private var pairMatches: [String: String] = [:]
    @State private var pairTargets: [String] = []
    @State private var activePairSource: String?
    @State private var correctCount = 0
    @State private var earnedXP = 0
    @State private var skillXP: [SharedSettings.LanguageSkill: Int] = [:]
    @State private var answeredIDs = Set<String>()
    @State private var isCompleting = false
    @State private var latestFeedback: LanguageAnswerFeedback?
    @State private var showFloatingXP = false
    @State private var progressPulse = false
    @State private var cardShakeOffset: CGFloat = 0
    @State private var showCompletionBrief = false
    @State private var completionProgress: CGFloat = 0
    @State private var completionMessageVisible = false
    @State private var unlockGranted = false
    @Namespace private var sentenceAnimation

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

    private var answeredProgress: Double {
        min(max(Double(answeredIDs.count) / Double(questions.count), 0), 1)
    }

    var body: some View {
        NavigationView {
            ZStack {
                if showCompletionBrief {
                    completionBrief
                        .transition(.scale(scale: 0.94).combined(with: .opacity))
                } else {
                    lessonBody
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
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

    private var lessonBody: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            header
            progressBar
            questionCard
                .id(currentQuestion.id)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            Spacer(minLength: DesignSystem.Spacing.lg)
            actionButtons
        }
    }

    private var header: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("Language unlock")
                .font(DesignSystem.Typography.title2)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text("\(challenge.sectionTitle): \(challenge.lesson.title). Complete 4 \(challenge.languageName) questions to earn more app time.")
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
                    .contentTransition(.numericText())
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [DesignSystem.Colors.success, DesignSystem.Colors.primary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * CGFloat(answeredProgress))
                        .shadow(color: DesignSystem.Colors.success.opacity(progressPulse ? 0.65 : 0.25), radius: progressPulse ? 14 : 6)
                        .animation(.spring(response: 0.48, dampingFraction: 0.78), value: answeredProgress)
                }
                .scaleEffect(y: progressPulse ? 1.35 : 1, anchor: .center)
                .animation(.spring(response: 0.28, dampingFraction: 0.62), value: progressPulse)
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
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glossySurface(cornerRadius: DesignSystem.CornerRadius.xl, opacity: 0.55)
        .cornerRadius(DesignSystem.CornerRadius.xl)
        .overlay(alignment: .topTrailing) {
            floatingXPBadge
        }
        .offset(x: cardShakeOffset)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: hasAnswered)
    }

    private var completionBrief: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer(minLength: DesignSystem.Spacing.md)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Lesson complete")
                    .font(.system(size: 38, weight: .black))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("You unlocked \(unlockLengthText).")
                    .font(DesignSystem.Typography.title3.weight(.bold))
                    .foregroundColor(DesignSystem.Colors.success)
                    .multilineTextAlignment(.center)
                    .scaleEffect(completionMessageVisible ? 1 : 0.92)
                    .opacity(completionMessageVisible ? 1 : 0)
            }

            VStack(spacing: DesignSystem.Spacing.lg) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 18)
                    Circle()
                        .trim(from: 0, to: completionProgress)
                        .stroke(
                            LinearGradient(
                                colors: [DesignSystem.Colors.success, DesignSystem.Colors.primary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 18, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .shadow(color: DesignSystem.Colors.success.opacity(0.45), radius: 18)

                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text("+\(earnedXP)")
                            .font(.system(size: 46, weight: .black))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .contentTransition(.numericText())
                        Text("XP")
                            .font(DesignSystem.Typography.caption.weight(.bold))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .frame(width: 190, height: 190)

                VStack(spacing: DesignSystem.Spacing.sm) {
                    completionStat(title: "Questions", value: "\(questions.count)")
                    completionStat(title: "Remembered", value: "\(correctCount)/\(questions.count)")
                    completionStat(title: "Break", value: unlockLengthText)
                }
                .padding(DesignSystem.Spacing.lg)
                .frame(maxWidth: .infinity)
                .glossySurface(cornerRadius: DesignSystem.CornerRadius.xl, opacity: 0.68)
                .cornerRadius(DesignSystem.CornerRadius.xl)
            }

            Spacer()

            Button("Start my break") {
                finishUnlockFromBrief()
            }
            .mindLockButton(style: .primary)
        }
    }

    private func completionStat(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(DesignSystem.Typography.callout.weight(.bold))
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
    }

    private var unlockLengthText: String {
        unlockMinutes >= 24 * 60 ? "the rest of today" : "\(unlockMinutes) min"
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
        let feedbackState = answerFeedbackState(selected: selected, correct: correct)

        return Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.72)) {
                selectedAnswer = choice
            }
            submitCurrentAnswer()
        } label: {
            HStack {
                Text(choice)
                    .font(DesignSystem.Typography.body.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer()
                if feedbackState != .idle {
                    Image(systemName: feedbackState.iconName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(feedbackState.tint)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(DesignSystem.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(answerBackground(feedbackState))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous)
                    .stroke(feedbackState.borderColor, lineWidth: feedbackState == .idle ? 0 : 1.6)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous))
            .scaleEffect(feedbackState.shouldPop ? 1.03 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.58), value: feedbackState)
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
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous)
                        .stroke(typedAnswerBorderColor, lineWidth: hasAnswered ? 1.8 : 0)
                )
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
            Text("Tap the words into order.")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            sentenceAnswerArea

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 76), spacing: DesignSystem.Spacing.sm)],
                alignment: .leading,
                spacing: DesignSystem.Spacing.sm
            ) {
                ForEach(sentenceBankTokens) { token in
                    sentenceToken(token, placement: .bank)
                }
            }

            Button("Check sentence") {
                submitCurrentAnswer()
            }
            .mindLockButton(style: .primary)
            .disabled(sentenceAnswerTokens.isEmpty || hasAnswered)
            .opacity(sentenceAnswerTokens.isEmpty || hasAnswered ? 0.5 : 1)
        }
    }

    private var sentenceAnswerArea: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            FlexibleSentenceTokenGrid(tokens: sentenceAnswerTokens) { token in
                sentenceToken(token, placement: .answer)
            }
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
            .padding(DesignSystem.Spacing.sm)
            .background(Color.black.opacity(0.18))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [7, 6]))
                    .foregroundColor(Color.white.opacity(0.22))
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous))
            .overlay(alignment: .center) {
                if sentenceAnswerTokens.isEmpty {
                    Text("Build your sentence here")
                        .font(DesignSystem.Typography.callout.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            }

            if !sentenceAnswerTokens.isEmpty && !hasAnswered {
                Button("Clear") {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        sentenceBankTokens.append(contentsOf: sentenceAnswerTokens)
                        sentenceAnswerTokens.removeAll()
                    }
                }
                .font(DesignSystem.Typography.caption.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.primary)
                .buttonStyle(.plain)
            }
        }
    }

    private func sentenceToken(_ token: SentenceToken, placement: SentenceTokenPlacement) -> some View {
        Button {
            moveSentenceToken(token, from: placement)
        } label: {
            Text(token.value)
                .font(DesignSystem.Typography.callout.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(sentenceTokenBackground(token, placement: placement))
                .overlay(
                    Capsule()
                        .stroke(sentenceTokenBorder(token, placement: placement), lineWidth: hasAnswered && placement == .answer ? 1.4 : 0)
                )
                .clipShape(Capsule())
                .matchedGeometryEffect(id: token.id, in: sentenceAnimation)
                .scaleEffect(hasAnswered && placement == .answer ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .disabled(hasAnswered)
    }

    private func sentenceTokenBackground(_ token: SentenceToken, placement: SentenceTokenPlacement) -> Color {
        if hasAnswered && placement == .answer {
            return sentenceTokenIsCorrect(token) ? DesignSystem.Colors.success.opacity(0.24) : DesignSystem.Colors.warning.opacity(0.22)
        }
        switch placement {
        case .bank:
            return Color.white.opacity(0.10)
        case .answer:
            return DesignSystem.Colors.primary.opacity(0.22)
        }
    }

    private func sentenceTokenBorder(_ token: SentenceToken, placement: SentenceTokenPlacement) -> Color {
        guard hasAnswered && placement == .answer else { return .clear }
        return sentenceTokenIsCorrect(token) ? DesignSystem.Colors.success.opacity(0.8) : DesignSystem.Colors.warning.opacity(0.85)
    }

    private func sentenceTokenIsCorrect(_ token: SentenceToken) -> Bool {
        guard let index = sentenceAnswerTokens.firstIndex(of: token),
              currentQuestion.correctTokens.indices.contains(index) else {
            return false
        }
        return currentQuestion.correctTokens[index] == token.value
    }

    private func moveSentenceToken(_ token: SentenceToken, from placement: SentenceTokenPlacement) {
        guard !hasAnswered else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            switch placement {
            case .bank:
                guard let index = sentenceBankTokens.firstIndex(of: token) else { return }
                sentenceBankTokens.remove(at: index)
                sentenceAnswerTokens.append(token)
            case .answer:
                guard let index = sentenceAnswerTokens.firstIndex(of: token) else { return }
                sentenceAnswerTokens.remove(at: index)
                sentenceBankTokens.append(token)
            }
        }
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
        let feedbackState = pairFeedbackState(item, side: side, selected: selected, matched: matched)

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
                .background(pairBackground(feedbackState))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                        .stroke(feedbackState.borderColor, lineWidth: feedbackState == .idle ? 0 : 1.4)
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(hasAnswered)
    }

    private var typedAnswerBorderColor: Color {
        guard hasAnswered else { return .clear }
        return currentResponseIsCorrect ? DesignSystem.Colors.success.opacity(0.85) : DesignSystem.Colors.warning.opacity(0.85)
    }

    private func answerBackground(_ state: LanguageOptionFeedbackState) -> Color {
        switch state {
        case .idle:
            return Color.white.opacity(0.07)
        case .selected:
            return DesignSystem.Colors.primary.opacity(0.18)
        case .correct:
            return DesignSystem.Colors.success.opacity(0.22)
        case .incorrect:
            return DesignSystem.Colors.warning.opacity(0.20)
        }
    }

    private func pairBackground(_ state: LanguageOptionFeedbackState) -> Color {
        switch state {
        case .idle:
            return Color.white.opacity(0.08)
        case .selected:
            return DesignSystem.Colors.primary.opacity(0.22)
        case .correct:
            return DesignSystem.Colors.success.opacity(0.20)
        case .incorrect:
            return DesignSystem.Colors.warning.opacity(0.18)
        }
    }

    private func answerFeedbackState(selected: Bool, correct: Bool) -> LanguageOptionFeedbackState {
        if hasAnswered {
            if correct { return .correct }
            if selected { return .incorrect }
            return .idle
        }
        return selected ? .selected : .idle
    }

    private func pairFeedbackState(_ item: String, side: PairSide, selected: Bool, matched: Bool) -> LanguageOptionFeedbackState {
        if hasAnswered && matched {
            switch side {
            case .left:
                return pairMatches[item] == currentQuestion.pairs[item] ? .correct : .incorrect
            case .right:
                let source = pairMatches.first { $0.value == item }?.key
                return source.flatMap { currentQuestion.pairs[$0] } == item ? .correct : .incorrect
            }
        }
        if selected { return .selected }
        if matched { return .correct }
        return .idle
    }

    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: currentResponseIsCorrect ? "checkmark.circle.fill" : "sparkles")
                    .foregroundColor(currentResponseIsCorrect ? DesignSystem.Colors.success : DesignSystem.Colors.primary)
                Text(currentResponseIsCorrect ? "Nice. You remembered it." : "Good practice. The answer is \(currentQuestion.correctAnswer).")
                    .font(DesignSystem.Typography.callout.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Spacer()
                if let latestFeedback, latestFeedback.questionID == currentQuestion.id {
                    Text(latestFeedback.xpText)
                        .font(DesignSystem.Typography.caption.weight(.bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, 5)
                        .background(DesignSystem.Colors.success)
                        .clipShape(Capsule())
                }
            }
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

    @ViewBuilder
    private var floatingXPBadge: some View {
        if let latestFeedback, latestFeedback.questionID == currentQuestion.id, showFloatingXP {
            Text(latestFeedback.xpText)
                .font(.system(size: 18, weight: .black))
                .foregroundColor(.black)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(DesignSystem.Colors.success)
                .clipShape(Capsule())
                .shadow(color: DesignSystem.Colors.success.opacity(0.55), radius: 16)
                .offset(x: -DesignSystem.Spacing.md, y: -18)
                .transition(.asymmetric(insertion: .scale(scale: 0.7).combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity)))
        }
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
        latestFeedback = nil
        showFloatingXP = false
        progressPulse = false
        cardShakeOffset = 0
        sentenceAnswerTokens = []
        sentenceBankTokens = currentQuestion.tokens.map { SentenceToken(value: $0) }.shuffled()
        pairTargets = Array(currentQuestion.pairs.values).shuffled()
    }

    private func submitCurrentAnswer() {
        guard !answeredIDs.contains(currentQuestion.id) else { return }
        let correct = responseIsCorrect(for: currentQuestion)
        let feedback = LanguageLessonFeedbackEngine.feedback(
            for: currentQuestion,
            isCorrect: correct,
            totalAnswered: answeredIDs.count + 1,
            totalQuestions: questions.count
        )

        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            answeredIDs.insert(currentQuestion.id)
            latestFeedback = feedback
            if correct {
                correctCount += 1
            }
            earnedXP += feedback.xpEarned
            skillXP[currentQuestion.skill, default: 0] += feedback.xpEarned
            showFloatingXP = true
            progressPulse = true
        }

        playFeedback(correct: correct)
        animateFeedback(correct: correct)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.24)) {
                showFloatingXP = false
                progressPulse = false
            }
        }
    }

    private func responseIsCorrect(for question: LanguageQuestion) -> Bool {
        switch question.type {
        case .multipleChoice, .reverseTranslation, .fillBlank:
            return selectedAnswer == question.correctAnswer
        case .typedAnswer:
            let normalized = normalize(typedAnswer)
            return question.acceptedAnswers.map(normalize).contains(normalized)
        case .sentenceOrdering:
            return sentenceAnswerTokens.map(\.value) == question.correctTokens
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
            withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                pairMatches[source] = item
                activePairSource = nil
            }
            if pairMatches.count == currentQuestion.pairs.count {
                submitCurrentAnswer()
            }
        }
    }

    private func continueTapped() {
        guard hasAnswered else { return }
        if isLastQuestion {
            showLessonCompleteBrief()
        } else {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                currentIndex += 1
                prepareCurrentQuestion()
            }
        }
    }

    private func showLessonCompleteBrief() {
        guard !isCompleting else { return }
        isCompleting = true
        SharedSettings.recordLanguagePractice(
            lessonID: challenge.lesson.id,
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

        withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
            showCompletionBrief = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: 0.95)) {
                completionProgress = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            AudioServicesPlaySystemSound(1104)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.62)) {
                completionMessageVisible = true
            }
        }
    }

    private func finishUnlockFromBrief() {
        guard !unlockGranted else { return }
        unlockGranted = true
        onComplete(questions.count, correctCount, unlockMinutes)
        dismiss()
    }

    private func playFeedback(correct: Bool) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(correct ? .success : .warning)
        AudioServicesPlaySystemSound(correct ? 1104 : 1053)
    }

    private func animateFeedback(correct: Bool) {
        guard !correct else { return }
        withAnimation(.linear(duration: 0.06)) {
            cardShakeOffset = -7
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            withAnimation(.linear(duration: 0.06)) {
                cardShakeOffset = 7
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) {
                cardShakeOffset = 0
            }
        }
    }
}

private enum PairSide {
    case left
    case right
}

private enum SentenceTokenPlacement {
    case bank
    case answer
}

private enum LanguageOptionFeedbackState: Equatable {
    case idle
    case selected
    case correct
    case incorrect

    var tint: Color {
        switch self {
        case .idle:
            return DesignSystem.Colors.textTertiary
        case .selected:
            return DesignSystem.Colors.primary
        case .correct:
            return DesignSystem.Colors.success
        case .incorrect:
            return DesignSystem.Colors.warning
        }
    }

    var borderColor: Color {
        switch self {
        case .idle:
            return .clear
        case .selected:
            return DesignSystem.Colors.primary.opacity(0.8)
        case .correct:
            return DesignSystem.Colors.success.opacity(0.9)
        case .incorrect:
            return DesignSystem.Colors.warning.opacity(0.9)
        }
    }

    var iconName: String {
        switch self {
        case .idle:
            return ""
        case .selected:
            return "circle.fill"
        case .correct:
            return "checkmark.circle.fill"
        case .incorrect:
            return "xmark.circle.fill"
        }
    }

    var shouldPop: Bool {
        self == .correct || self == .incorrect
    }
}

private struct SentenceToken: Identifiable, Equatable {
    let id = UUID()
    let value: String
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

private struct FlexibleSentenceTokenGrid<Content: View>: View {
    let tokens: [SentenceToken]
    let content: (SentenceToken) -> Content

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 76), spacing: DesignSystem.Spacing.sm)],
            alignment: .leading,
            spacing: DesignSystem.Spacing.sm
        ) {
            ForEach(tokens) { token in
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
