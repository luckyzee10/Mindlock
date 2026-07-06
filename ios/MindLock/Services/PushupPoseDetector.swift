import AVFoundation
import CoreGraphics
import Foundation
import Vision

final class PushupPoseDetector: NSObject, ObservableObject {
    enum ExerciseKind {
        case pushups
        case squats
    }

    enum CameraState: Equatable {
        case idle
        case requestingPermission
        case unauthorized
        case configuring
        case running
        case failed(String)
    }

    enum FormState: String {
        case findingBody = "Find your body in frame"
        case moveToTop = "Start in high plank"
        case lowerDown = "Lower down"
        case pushUp = "Push back up"
        case standTall = "Stand tall"
        case squatDown = "Squat down"
        case standUp = "Stand back up"
        case complete = "Challenge complete"
    }

    @Published private(set) var cameraState: CameraState = .idle
    @Published private(set) var completedReps = 0
    @Published private(set) var formState: FormState = .findingBody
    @Published private(set) var lastAngle: Double?

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.mindlock.pushup.session")
    private let videoQueue = DispatchQueue(label: "com.mindlock.pushup.video")
    private let sequenceHandler = VNSequenceRequestHandler()
    private let repCounter = PushupRepCounter()
    private let squatCounter = SquatRepCounter()
    private var isProcessingFrame = false
    private var goal = 5
    private var exerciseKind: ExerciseKind = .pushups

    func start(goal: Int, kind: ExerciseKind = .pushups) {
        self.goal = goal
        self.exerciseKind = kind

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            cameraState = .requestingPermission
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureAndStart()
                    } else {
                        self?.cameraState = .unauthorized
                    }
                }
            }
        case .denied, .restricted:
            cameraState = .unauthorized
        @unknown default:
            cameraState = .failed("Camera permission is unavailable.")
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    func reset(goal: Int, kind: ExerciseKind = .pushups) {
        self.goal = goal
        self.exerciseKind = kind
        completedReps = 0
        formState = .findingBody
        lastAngle = nil
        repCounter.reset()
        squatCounter.reset()
    }

    private func configureAndStart() {
        cameraState = .configuring
        sessionQueue.async { [weak self] in
            guard let self else { return }

            self.session.beginConfiguration()
            self.session.sessionPreset = .medium
            self.session.inputs.forEach { self.session.removeInput($0) }
            self.session.outputs.forEach { self.session.removeOutput($0) }

            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ??
                    AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                finishConfigurationFailure("No camera is available.")
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: camera)
                guard self.session.canAddInput(input) else {
                    finishConfigurationFailure("MindLock could not use this camera.")
                    return
                }
                self.session.addInput(input)

                let output = AVCaptureVideoDataOutput()
                output.alwaysDiscardsLateVideoFrames = true
                output.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                output.setSampleBufferDelegate(self, queue: self.videoQueue)

                guard self.session.canAddOutput(output) else {
                    finishConfigurationFailure("MindLock could not read camera frames.")
                    return
                }
                self.session.addOutput(output)

                if let connection = output.connection(with: .video) {
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                    }
                    if connection.isVideoMirroringSupported, camera.position == .front {
                        connection.isVideoMirrored = true
                    }
                }

                self.session.commitConfiguration()
                self.session.startRunning()

                DispatchQueue.main.async {
                    self.cameraState = .running
                }
            } catch {
                finishConfigurationFailure(error.localizedDescription)
            }
        }
    }

    private func finishConfigurationFailure(_ message: String) {
        session.commitConfiguration()
        DispatchQueue.main.async {
            self.cameraState = .failed(message)
        }
    }
}

extension PushupPoseDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        if isProcessingFrame { return }
        isProcessingFrame = true

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            isProcessingFrame = false
            return
        }

        let request = VNDetectHumanBodyPoseRequest()

        do {
            try sequenceHandler.perform([request], on: pixelBuffer, orientation: .leftMirrored)
            guard let observation = request.results?.first else {
                publishNoBody()
                isProcessingFrame = false
                return
            }

            let sample = try ExercisePoseSample(observation: observation)
            let result: (reps: Int, formState: PushupPoseDetector.FormState, angle: Double)
            switch exerciseKind {
            case .pushups:
                result = repCounter.update(with: sample, goal: goal)
            case .squats:
                result = squatCounter.update(with: sample, goal: goal)
            }
            DispatchQueue.main.async {
                self.completedReps = result.reps
                self.formState = result.formState
                self.lastAngle = result.angle > 0 ? result.angle : nil
            }
        } catch {
            publishNoBody()
        }

        isProcessingFrame = false
    }

    private func publishNoBody() {
        DispatchQueue.main.async {
            if self.completedReps < self.goal {
                self.formState = .findingBody
                self.lastAngle = nil
            }
        }
    }
}

private struct ExercisePoseSample {
    let elbowAngle: Double?
    let kneeAngle: Double?
    let confidence: Float

    init(observation: VNHumanBodyPoseObservation) throws {
        let points = try observation.recognizedPoints(.all)
        let leftArm = ArmSidePoints(
            shoulder: points[.leftShoulder],
            elbow: points[.leftElbow],
            wrist: points[.leftWrist]
        )
        let rightArm = ArmSidePoints(
            shoulder: points[.rightShoulder],
            elbow: points[.rightElbow],
            wrist: points[.rightWrist]
        )
        let leftLeg = LegSidePoints(
            hip: points[.leftHip],
            knee: points[.leftKnee],
            ankle: points[.leftAnkle]
        )
        let rightLeg = LegSidePoints(
            hip: points[.rightHip],
            knee: points[.rightKnee],
            ankle: points[.rightAnkle]
        )

        let bestArm = [leftArm, rightArm]
            .compactMap { $0.validSample }
            .max { $0.confidence < $1.confidence }
        let bestLeg = [leftLeg, rightLeg]
            .compactMap { $0.validSample }
            .max { $0.confidence < $1.confidence }

        guard bestArm != nil || bestLeg != nil else {
            throw PoseError.missingJoints
        }

        elbowAngle = bestArm?.angle
        kneeAngle = bestLeg?.angle
        confidence = max(bestArm?.confidence ?? 0, bestLeg?.confidence ?? 0)
    }
}

private struct ArmSidePoints {
    let shoulder: VNRecognizedPoint?
    let elbow: VNRecognizedPoint?
    let wrist: VNRecognizedPoint?

    var validSample: (angle: Double, confidence: Float)? {
        guard let shoulder, let elbow, let wrist else { return nil }
        let confidence = min(shoulder.confidence, elbow.confidence, wrist.confidence)
        guard confidence > 0.35 else { return nil }
        return (Self.angle(a: shoulder.location, b: elbow.location, c: wrist.location), confidence)
    }

    private static func angle(a: CGPoint, b: CGPoint, c: CGPoint) -> Double {
        let ab = CGVector(dx: a.x - b.x, dy: a.y - b.y)
        let cb = CGVector(dx: c.x - b.x, dy: c.y - b.y)
        let dot = ab.dx * cb.dx + ab.dy * cb.dy
        let magnitude = hypot(ab.dx, ab.dy) * hypot(cb.dx, cb.dy)
        guard magnitude > 0 else { return 180 }
        let cosine = max(-1, min(1, dot / magnitude))
        return acos(cosine) * 180 / .pi
    }
}

private struct LegSidePoints {
    let hip: VNRecognizedPoint?
    let knee: VNRecognizedPoint?
    let ankle: VNRecognizedPoint?

    var validSample: (angle: Double, confidence: Float)? {
        guard let hip, let knee, let ankle else { return nil }
        let confidence = min(hip.confidence, knee.confidence, ankle.confidence)
        guard confidence > 0.35 else { return nil }
        return (Self.angle(a: hip.location, b: knee.location, c: ankle.location), confidence)
    }

    private static func angle(a: CGPoint, b: CGPoint, c: CGPoint) -> Double {
        let ab = CGVector(dx: a.x - b.x, dy: a.y - b.y)
        let cb = CGVector(dx: c.x - b.x, dy: c.y - b.y)
        let dot = ab.dx * cb.dx + ab.dy * cb.dy
        let magnitude = hypot(ab.dx, ab.dy) * hypot(cb.dx, cb.dy)
        guard magnitude > 0 else { return 180 }
        let cosine = max(-1, min(1, dot / magnitude))
        return acos(cosine) * 180 / .pi
    }
}

private final class PushupRepCounter {
    private enum Phase {
        case waitingForTop
        case waitingForBottom
        case waitingForReturnTop
        case complete
    }

    private var phase: Phase = .waitingForTop
    private var reps = 0

    func reset() {
        phase = .waitingForTop
        reps = 0
    }

    func update(with sample: ExercisePoseSample, goal: Int) -> (reps: Int, formState: PushupPoseDetector.FormState, angle: Double) {
        guard let angle = sample.elbowAngle else {
            return (reps, .findingBody, 0)
        }
        let topThreshold = 150.0
        let bottomThreshold = 105.0

        switch phase {
        case .waitingForTop:
            if angle >= topThreshold {
                phase = .waitingForBottom
                return (reps, .lowerDown, angle)
            }
            return (reps, .moveToTop, angle)

        case .waitingForBottom:
            if angle <= bottomThreshold {
                phase = .waitingForReturnTop
                return (reps, .pushUp, angle)
            }
            return (reps, .lowerDown, angle)

        case .waitingForReturnTop:
            if angle >= topThreshold {
                reps = min(goal, reps + 1)
                phase = reps >= goal ? .complete : .waitingForBottom
                return (reps, reps >= goal ? .complete : .lowerDown, angle)
            }
            return (reps, .pushUp, angle)

        case .complete:
            return (reps, .complete, angle)
        }
    }
}

private final class SquatRepCounter {
    private enum Phase {
        case waitingForTop
        case waitingForBottom
        case waitingForReturnTop
        case complete
    }

    private var phase: Phase = .waitingForTop
    private var reps = 0

    func reset() {
        phase = .waitingForTop
        reps = 0
    }

    func update(with sample: ExercisePoseSample, goal: Int) -> (reps: Int, formState: PushupPoseDetector.FormState, angle: Double) {
        guard let angle = sample.kneeAngle else {
            return (reps, .findingBody, 0)
        }
        let topThreshold = 160.0
        let bottomThreshold = 105.0

        switch phase {
        case .waitingForTop:
            if angle >= topThreshold {
                phase = .waitingForBottom
                return (reps, .squatDown, angle)
            }
            return (reps, .standTall, angle)

        case .waitingForBottom:
            if angle <= bottomThreshold {
                phase = .waitingForReturnTop
                return (reps, .standUp, angle)
            }
            return (reps, .squatDown, angle)

        case .waitingForReturnTop:
            if angle >= topThreshold {
                reps = min(goal, reps + 1)
                phase = reps >= goal ? .complete : .waitingForBottom
                return (reps, reps >= goal ? .complete : .squatDown, angle)
            }
            return (reps, .standUp, angle)

        case .complete:
            return (reps, .complete, angle)
        }
    }
}

private enum PoseError: Error {
    case missingJoints
}
