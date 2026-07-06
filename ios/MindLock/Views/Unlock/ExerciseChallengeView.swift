import SwiftUI

struct ExerciseChallengeView: View {
    let mechanism: SharedSettings.UnlockMechanism
    let unlockMinutes: Int
    let onComplete: (SharedSettings.UnlockMechanism, Int, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var detector = PushupPoseDetector()
    @State private var isCompleting = false

    private var repGoal: Int {
        switch mechanism {
        case .pushups: return 5
        case .squats: return 10
        case .mindfulWait: return 0
        }
    }

    private var exerciseName: String {
        switch mechanism {
        case .pushups: return "pushup"
        case .squats: return "squat"
        case .mindfulWait: return "rep"
        }
    }

    private var detectorKind: PushupPoseDetector.ExerciseKind {
        mechanism == .squats ? .squats : .pushups
    }

    private var completedReps: Int {
        detector.completedReps
    }

    private var progress: Double {
        guard repGoal > 0 else { return 1 }
        return min(Double(completedReps) / Double(repGoal), 1)
    }

    private var remainingReps: Int {
        max(0, repGoal - completedReps)
    }

    var body: some View {
        NavigationView {
            ZStack {
                CameraPreviewView(session: detector.session)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.78),
                        Color.black.opacity(0.28),
                        Color.black.opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.0),
                        Color.black.opacity(0.45),
                        Color.black.opacity(0.88)
                    ],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: DesignSystem.Spacing.xl) {
                    header

                    Spacer(minLength: 0)

                    setupGuide
                    cameraOverlay
                    progressCard
                    footerActions
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.xl)
                .padding(.bottom, DesignSystem.Spacing.xxl)
            }
            .background(Color.black)
            .navigationBarHidden(true)
        }
        .onAppear {
            detector.reset(goal: repGoal, kind: detectorKind)
            detector.start(goal: repGoal, kind: detectorKind)
        }
        .onDisappear {
            detector.stop()
        }
    }

    private var header: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("\(mechanism.displayName) challenge")
                .font(DesignSystem.Typography.title2)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text("Complete \(repGoal) \(exerciseName)\(repGoal == 1 ? "" : "s") to earn more app time.")
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var progressCard: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            progressRing

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text(remainingReps == 0 ? "Challenge complete" : "\(remainingReps) \(exerciseName)\(remainingReps == 1 ? "" : "s") left")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(detector.formState.rawValue)
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                if let angle = detector.lastAngle {
                    Text("\(angleLabel) \(Int(angle.rounded()))°")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .glossySurface(cornerRadius: DesignSystem.CornerRadius.xl)
        .cornerRadius(DesignSystem.CornerRadius.xl)
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(DesignSystem.Colors.surfaceSecondary, lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    DesignSystem.Colors.primary,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(completedReps)")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Text("of \(repGoal)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .frame(width: 96, height: 96)
    }

    private var cameraOverlay: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                Image(systemName: cameraPromptIcon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(cameraPromptColor)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(cameraStatusTitle)
                        .font(DesignSystem.Typography.callout.weight(.semibold))
                        .foregroundColor(.white)
                    Text(cameraStatusDetail)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(.white.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.34))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var setupGuide: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            ForEach(setupTips, id: \.title) { tip in
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: tip.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primary)
                    Text(tip.title)
                        .font(DesignSystem.Typography.caption.weight(.semibold))
                        .foregroundColor(.white)
                    Text(tip.detail)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.black.opacity(0.26))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var footerActions: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Button {
                detector.reset(goal: repGoal, kind: detectorKind)
            } label: {
                Label("Reset reps", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .mindLockButton(style: .secondary)
            .disabled(isCompleting)

            Button {
                completeChallenge()
            } label: {
                Text("Unlock more time")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .mindLockButton(style: .primary)
            .disabled(completedReps < repGoal || isCompleting)
            .opacity(completedReps >= repGoal ? 1 : 0.5)

            Button("Not now") {
                dismiss()
            }
            .mindLockButton(style: .ghost)
            .disabled(isCompleting)
        }
    }

    private func completeChallenge() {
        guard completedReps >= repGoal, !isCompleting else { return }
        isCompleting = true
        onComplete(mechanism, completedReps, unlockMinutes)
        dismiss()
    }

    private var angleLabel: String {
        mechanism == .squats ? "Knee angle" : "Elbow angle"
    }

    private var cameraStatusTitle: String {
        switch detector.cameraState {
        case .idle, .configuring:
            return "Set up your camera"
        case .requestingPermission:
            return "Camera permission"
        case .unauthorized:
            return "Camera access needed"
        case .running:
            return livePrompt.title
        case .failed:
            return "Camera unavailable"
        }
    }

    private var cameraStatusDetail: String {
        switch detector.cameraState {
        case .idle, .configuring:
            return initialSetupDetail
        case .requestingPermission:
            return "Allow camera access so MindLock can verify reps on device."
        case .unauthorized:
            return "Enable camera access in Settings to complete exercise unlocks."
        case .running:
            return livePrompt.detail
        case .failed(let message):
            return message
        }
    }

    private var cameraPromptIcon: String {
        switch detector.cameraState {
        case .running:
            switch detector.formState {
            case .findingBody: return "viewfinder"
            case .lowerDown, .squatDown: return "arrow.down.circle.fill"
            case .pushUp, .standUp, .moveToTop, .standTall: return "arrow.up.circle.fill"
            case .complete: return "checkmark.circle.fill"
            }
        case .unauthorized, .failed:
            return "exclamationmark.triangle.fill"
        default:
            return "camera.viewfinder"
        }
    }

    private var cameraPromptColor: Color {
        switch detector.cameraState {
        case .running where detector.formState == .complete:
            return DesignSystem.Colors.success
        case .unauthorized, .failed:
            return DesignSystem.Colors.warning
        default:
            return DesignSystem.Colors.primary
        }
    }

    private var initialSetupDetail: String {
        mechanism == .squats
            ? "Place the phone upright 6-8 feet away. Use a side or 45-degree angle so your hips, knees, and ankles stay visible."
            : "Place the phone upright 4-6 feet away. Use a side angle so your shoulder, elbow, and wrist stay visible through the whole rep."
    }

    private var setupTips: [(icon: String, title: String, detail: String)] {
        switch mechanism {
        case .squats:
            return [
                ("iphone", "Phone upright", "6-8 feet away"),
                ("figure.stand", "Full body visible", "Head to shoes"),
                ("arrow.left.and.right", "Side angle", "45 degrees works")
            ]
        case .pushups:
            return [
                ("iphone", "Phone upright", "4-6 feet away"),
                ("figure.core.training", "Side view", "Arm fully visible"),
                ("light.max", "Good lighting", "Avoid shadows")
            ]
        case .mindfulWait:
            return []
        }
    }

    private var livePrompt: (title: String, detail: String) {
        switch detector.formState {
        case .findingBody:
            return ("Move into frame", initialSetupDetail)
        case .moveToTop:
            return ("Start high", "Straighten your arms first. A rep starts once your elbow angle is open enough.")
        case .lowerDown:
            if let angle = detector.lastAngle, angle > 105 {
                return ("Go lower", "Lower until your elbows bend more. Reps count after you reach the bottom position.")
            }
            return ("Good depth", "Now push back up until your arms are straight.")
        case .pushUp:
            return ("Push all the way up", "Finish with straight arms so MindLock can count the rep.")
        case .standTall:
            return ("Stand tall first", "Start upright with your knees straight. A squat starts from the top position.")
        case .squatDown:
            if let angle = detector.lastAngle, angle > 105 {
                return ("Squat lower", "Bend your knees deeper. Reps count after you reach the bottom position.")
            }
            return ("Depth reached", "Now stand back up until your knees are straight.")
        case .standUp:
            return ("Stand all the way up", "Fully straighten your knees to complete the squat.")
        case .complete:
            return ("Challenge complete", "Tap Unlock more time to continue.")
        }
    }
}

#Preview {
    ExerciseChallengeView(mechanism: .pushups, unlockMinutes: 10) { _, _, _ in }
}
