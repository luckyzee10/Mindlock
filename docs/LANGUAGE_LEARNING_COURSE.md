# Language Learning Course

MindLock's language unlock flow is now lesson-based. Unlock sessions do not pull random sample questions; they select the next incomplete lesson from the user's selected language journey.

## Bundled V1 Courses

MindLock ships complete beginner courses for:

- Spanish
- French
- Italian
- German
- Japanese
- Korean

Each course is organized like a lightweight learning path:

- 4+ themed sections
- 4 lessons per section
- 4 questions per lesson
- 8 sections per language
- 32 lessons per language
- 128 questions per language
- 768 total bundled questions across the six supported languages

Current sections:

1. **Order at a cafe**
   - Cafe words
   - Ask politely
   - Order food
   - Pay the bill

2. **Meet someone new**
   - Say hello
   - Names
   - Where from?
   - Nice to meet you

3. **Find your way around**
   - Places
   - Directions
   - Ask where
   - Transportation

4. **Talk about your day**
   - Home
   - Morning
   - Work day
   - Evening

Each language includes four additional beginner sections:

5. **Shop for groceries**
   - Grocery words
   - Ask for quantities
   - Find items
   - Checkout

6. **Work and study**
   - Desk words
   - Meetings
   - Study plans
   - Deadlines

7. **Travel basics**
   - Airport words
   - Hotel check-in
   - Ask for help
   - Travel plans

8. **Feelings and plans**
   - Feelings
   - Preferences
   - Weekend plans
   - Small talk

## Question Types

Every lesson contains a mix of interactions, following the Duolingo-style principle that practice should feel varied:

- Meaning recognition
- Reverse translation
- Fill in the blank
- Typed recall
- Sentence ordering
- Pair matching

Unlocks are awarded after completion, not only after perfect accuracy. Correct answers award more XP, but the main behavioral goal is to replace impulsive app opening with language practice.

Every bundled language uses the same section architecture so the Journey tab, unlock flow, and progress system behave consistently, while the actual lesson prompts, answers, sentence tokens, and accepted typed answers are localized per language.

## Lesson Feedback

Language unlock lessons are designed to feel active and game-like without making unlocks punitive:

- The lesson progress bar advances after each submitted question.
- Questions slide horizontally from one prompt to the next.
- XP animates into the current question card as a `+XP` badge.
- Correct choices pop green with a checkmark.
- Incorrect choices pop red, while the correct choice is revealed in green.
- Typed answers show a green or red field border after checking.
- Sentence-building tokens turn green when they are in the correct slot and red when misplaced.
- Pair-matching selections draw connector lines and reveal correct/incorrect matches after submission.
- Correct answers trigger success haptics and a positive system sound.
- Incorrect answers trigger warning haptics, a subtle card shake, and a softer system sound.
- Lesson completion opens a short animated summary with lesson progress, total XP, and the amount of app time unlocked.

The feedback rules live in `LanguageLessonFeedback.swift` so XP/progress behavior can be unit tested outside the SwiftUI view.

Temporary unlocks are applied through the shared shield ledger. The same grant path now covers daily-limit shields and active time-block shields, so completing a lesson should unlock app time regardless of why the app was blocked.

## Source Of Truth

Course content lives in:

`ios/MindLock/Content/Courses/<language>_en.json`

The Swift model and loader live in:

`ios/MindLock/Models/LanguageLearningContent.swift`

The app-facing API is still `LanguageLearningCatalog`, but that catalog now reads bundled JSON course packs through `CoursePackLoader`. New content should not be added as Swift arrays.

Progress lives in shared settings:

- completed lesson IDs
- lesson completion timestamps
- total XP
- weekly XP
- skill XP
- practiced/correct question counts

The Journey tab reads the same catalog and progress state used by unlock sessions.

## Extending Content

Each language has its own course pack:

- `spanish_en.json`
- `french_en.json`
- `italian_en.json`
- `german_en.json`
- `japanese_en.json`
- `korean_en.json`

To add another language:

1. Add the language to `SharedSettings.LearningLanguage`.
2. Add a bundled JSON file in `ios/MindLock/Content/Courses/` named `<language_raw_value>_en.json`.
3. Use stable IDs for sections, lessons, and questions. Question IDs should be language-scoped.
4. Keep each section to 4 lessons and each lesson to 4 questions unless product intentionally changes the structure.
5. Prefer practical themes: cafe, introductions, transit, work, home, travel, emergencies.
6. Run the JSON validation script or `LanguageLearningContentTests` before shipping.

## JSON Course Schema

Each course pack uses this shape:

- `courseId`
- `version`
- `sourceLanguage`
- `targetLanguage`
- `displayName`
- `sections`

Each section contains:

- `id`
- `unitNumber`
- `title`
- `theme`
- `iconName`
- `lessons`

Each lesson contains:

- `id`
- `title`
- `subtitle`
- `iconName`
- `questions`

Each question contains:

- `id`
- `type`
- `skill`
- `difficulty`
- `prompt`
- `context`
- `choices`
- `correctAnswer`
- `acceptedAnswers`
- `tokens`
- `correctTokens`
- `pairs`
- `learningNote`

## Validation Rules

`LanguageLearningContentTests` enforce the core content contract:

- Every configured language has a bundled course pack.
- Every section has 4 lessons.
- Every lesson has 4 questions.
- Question IDs are unique and language-scoped.
- All six question types are represented.
- Easy, medium, and hard difficulty levels are represented.
- Choice-based questions include the correct answer in the options.
- Typed questions include accepted answers.
- Sentence-ordering questions include ordered tokens.
- Pair-matching questions include enough pairs to be useful.
