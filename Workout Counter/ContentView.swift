import SwiftUI
import AVFoundation
import Combine
import Vision

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

#if os(iOS)
import UIKit

// MARK: - Workout Screen

struct WorkoutView: View {
    private enum CompletionAction {
        case repeatSet
        case changeGoal
        case finishWorkout
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraModel()
    @StateObject private var curlCounter = BicepCurlCounter()
    @StateObject private var repCuePlayer = RepCuePlayer()

    @State private var isCounting = false
    @State private var targetReps: Int?
    @State private var selectedTargetReps = 10
    @State private var showingRepGoal = false
    @State private var showingWorkoutComplete = false
    @State private var showingRepCue = false
    @State private var goalCompleted = false
    @State private var isRepAudioEnabled = true
    @State private var completionAction: CompletionAction?
    @State private var feedbackTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            CameraPreview(
                session: camera.session,
                pose: camera.pose,
                selectedArm: curlCounter.selectedArm
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    .black.opacity(0.7),
                    .clear,
                    .black.opacity(0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(.black.opacity(0.45))
                            .clipShape(Circle())
                    }

                    Spacer()

                    Button {
                        isRepAudioEnabled.toggle()
                        repCuePlayer.setAudioEnabled(isRepAudioEnabled)
                    } label: {
                        Image(
                            systemName: isRepAudioEnabled
                                ? "speaker.wave.2.fill"
                                : "speaker.slash.fill"
                        )
                        .font(.subheadline.bold())
                        .foregroundStyle(
                            isRepAudioEnabled ? .white : .white.opacity(0.55)
                        )
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.45))
                        .clipShape(Circle())
                    }
                    .accessibilityLabel(
                        isRepAudioEnabled
                            ? "Mute rep audio"
                            : "Turn on rep audio"
                    )

                    Text(workoutStatus)
                        .font(.caption.bold())
                        .tracking(2)
                        .foregroundStyle(
                            isCounting || goalCompleted ? .green : .white
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.45))
                        .clipShape(Capsule())
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(.green.opacity(0.75), lineWidth: 5)
                        .frame(width: 190, height: 190)
                        .scaleEffect(showingRepCue ? 1.15 : 0.82)
                        .opacity(showingRepCue ? 0.9 : 0)

                    VStack(spacing: 7) {
                        ZStack(alignment: .topTrailing) {
                            Text("\(curlCounter.repCount)")
                                .font(
                                    .system(
                                        size: 100,
                                        weight: .black,
                                        design: .rounded
                                    )
                                )
                                .foregroundStyle(
                                    showingRepCue ? .green : .white
                                )
                                .scaleEffect(showingRepCue ? 1.08 : 1)

                            if showingRepCue {
                                Text("+1")
                                    .font(.headline.bold())
                                    .foregroundStyle(.green)
                                    .offset(x: 28, y: 8)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }

                        Text("REPS")
                            .font(.headline.bold())
                            .tracking(4)
                            .foregroundStyle(.white.opacity(0.75))

                        if let targetReps {
                            VStack(spacing: 7) {
                                Text(
                                    goalCompleted
                                        ? "GOAL COMPLETE"
                                        : "GOAL  \(targetReps)"
                                )
                                .font(.caption.bold())
                                .tracking(1.5)
                                .foregroundStyle(
                                    goalCompleted
                                        ? .green
                                        : .white.opacity(0.7)
                                )

                                ProgressView(
                                    value: Double(
                                        min(curlCounter.repCount, targetReps)
                                    ),
                                    total: Double(targetReps)
                                )
                                .tint(.green)
                                .frame(width: 150)
                            }
                            .padding(.top, 3)
                        }
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    Button {
                        curlCounter.reset()
                        goalCompleted = false
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2.bold())
                            .frame(width: 60, height: 60)
                            .foregroundStyle(.white)
                            .background(.white.opacity(0.2))
                            .clipShape(Circle())
                    }

                    Button {
                        handlePrimaryButton()
                    } label: {
                        Text(primaryButtonTitle)
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .foregroundStyle(.black)
                            .background(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }
            }
            .padding(20)

            if let message = camera.message {
                Text(message)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding()
                    .background(.black.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingRepGoal) {
            RepGoalSheet(
                selectedReps: $selectedTargetReps
            ) { reps in
                beginWorkout(target: reps)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(
            isPresented: $showingWorkoutComplete,
            onDismiss: handleCompletionDismissal
        ) {
            WorkoutCompleteView(
                repCount: targetReps ?? curlCounter.repCount,
                onRepeatSet: {
                    completionAction = .repeatSet
                    showingWorkoutComplete = false
                },
                onChangeGoal: {
                    completionAction = .changeGoal
                    showingWorkoutComplete = false
                },
                onFinish: {
                    completionAction = .finishWorkout
                    showingWorkoutComplete = false
                }
            )
            .interactiveDismissDisabled()
        }
        .task {
            await camera.start()
        }
        .onReceive(camera.$pose) { pose in
            guard isCounting else {
                return
            }

            curlCounter.process(pose)
        }
        .onChange(of: curlCounter.repCount) { oldCount, newCount in
            handleRepCountChange(from: oldCount, to: newCount)
        }
        .onDisappear {
            feedbackTask?.cancel()
            repCuePlayer.stop()
            camera.stop()
        }
    }

    private var workoutStatus: String {
        if goalCompleted {
            return "COMPLETE"
        }

        return isCounting ? "COUNTING" : "READY"
    }

    private var primaryButtonTitle: String {
        if isCounting {
            return "Pause"
        }

        if goalCompleted {
            return "New Set"
        }

        return targetReps == nil ? "Start Counting" : "Resume"
    }

    private func handlePrimaryButton() {
        if isCounting {
            isCounting = false
            curlCounter.resetMovement()
            return
        }

        if targetReps == nil || goalCompleted {
            showingRepGoal = true
        } else {
            isCounting = true
            curlCounter.resetMovement()
        }
    }

    private func beginWorkout(target: Int) {
        targetReps = target
        goalCompleted = false
        curlCounter.reset()
        isCounting = true
    }

    private func handleRepCountChange(
        from oldCount: Int,
        to newCount: Int
    ) {
        guard newCount > oldCount else {
            return
        }

        let completed = targetReps.map { newCount >= $0 } ?? false

        playVisualRepCue()
        repCuePlayer.play(rep: newCount, completedGoal: completed)

        if completed {
            isCounting = false
            goalCompleted = true
            curlCounter.resetMovement()
            showingWorkoutComplete = true
        }
    }

    private func handleCompletionDismissal() {
        let action = completionAction
        completionAction = nil

        switch action {
        case .repeatSet:
            guard let targetReps else {
                return
            }

            beginWorkout(target: targetReps)

        case .changeGoal:
            selectedTargetReps = targetReps ?? selectedTargetReps
            showingRepGoal = true

        case .finishWorkout:
            dismiss()

        case nil:
            break
        }
    }

    private func playVisualRepCue() {
        feedbackTask?.cancel()

        withAnimation(.none) {
            showingRepCue = false
        }

        withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
            showingRepCue = true
        }

        feedbackTask = Task {
            try? await Task.sleep(for: .milliseconds(550))

            guard !Task.isCancelled else {
                return
            }

            withAnimation(.easeOut(duration: 0.25)) {
                showingRepCue = false
            }
        }
    }
}

@MainActor
final class RepCuePlayer: ObservableObject {
    private let audioSession = AVAudioSession.sharedInstance()
    private let repHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let completionHaptic = UINotificationFeedbackGenerator()
    private var repPlayer: AVAudioPlayer?
    private var completionPlayer: AVAudioPlayer?
    private var isAudioEnabled = true

    init() {
        repPlayer = try? AVAudioPlayer(data: Self.makeRepSound())
        completionPlayer = try? AVAudioPlayer(
            data: Self.makeCompletionSound()
        )
        repPlayer?.prepareToPlay()
        completionPlayer?.prepareToPlay()

        repHaptic.prepare()
        completionHaptic.prepare()
    }

    func setAudioEnabled(_ isEnabled: Bool) {
        isAudioEnabled = isEnabled

        if !isEnabled {
            repPlayer?.stop()
            completionPlayer?.stop()
            try? audioSession.setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        }
    }

    func play(rep _: Int, completedGoal: Bool) {
        if completedGoal {
            completionHaptic.notificationOccurred(.success)
        } else {
            repHaptic.impactOccurred()
        }

        guard isAudioEnabled else {
            prepareHaptics()
            return
        }

        try? audioSession.setCategory(
            .playback,
            mode: .default,
            options: [.mixWithOthers]
        )
        try? audioSession.setActive(true)

        let player = completedGoal ? completionPlayer : repPlayer

        repPlayer?.stop()
        completionPlayer?.stop()
        player?.currentTime = 0
        player?.play()

        prepareHaptics()
    }

    func stop() {
        repPlayer?.stop()
        completionPlayer?.stop()
        try? audioSession.setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    private func prepareHaptics() {
        repHaptic.prepare()
        completionHaptic.prepare()
    }

    private static func makeRepSound() -> Data {
        makeWaveData(duration: 0.34) { time in
            let attack = min(time / 0.008, 1)
            let decay = exp(-9 * time)
            let fundamental = sin(2 * .pi * 1_175 * time)
            let harmonic = sin(2 * .pi * 2_350 * time) * 0.28

            return Float((fundamental + harmonic) * attack * decay * 0.42)
        }
    }

    private static func makeCompletionSound() -> Data {
        let notes: [(start: Double, frequency: Double)] = [
            (0, 784),
            (0.15, 988),
            (0.30, 1_318)
        ]

        return makeWaveData(duration: 0.9) { time in
            var sample = 0.0

            for note in notes where time >= note.start {
                let noteTime = time - note.start
                let attack = min(noteTime / 0.008, 1)
                let decay = exp(-5.5 * noteTime)
                let fundamental = sin(
                    2 * .pi * note.frequency * noteTime
                )
                let harmonic = sin(
                    2 * .pi * note.frequency * 2 * noteTime
                ) * 0.2

                sample += (fundamental + harmonic) * attack * decay * 0.25
            }

            return Float(max(-1, min(1, sample)))
        }
    }

    private static func makeWaveData(
        duration: Double,
        sample: (Double) -> Float
    ) -> Data {
        let sampleRate = 44_100
        let sampleCount = Int(duration * Double(sampleRate))
        let audioByteCount = sampleCount * MemoryLayout<Int16>.size

        var data = Data()
        data.reserveCapacity(44 + audioByteCount)

        data.append(contentsOf: "RIFF".utf8)
        append(UInt32(36 + audioByteCount), to: &data)
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8)
        append(UInt32(16), to: &data)
        append(UInt16(1), to: &data)
        append(UInt16(1), to: &data)
        append(UInt32(sampleRate), to: &data)
        append(UInt32(sampleRate * 2), to: &data)
        append(UInt16(2), to: &data)
        append(UInt16(16), to: &data)
        data.append(contentsOf: "data".utf8)
        append(UInt32(audioByteCount), to: &data)

        for frame in 0..<sampleCount {
            let time = Double(frame) / Double(sampleRate)
            let clampedSample = max(-1, min(1, sample(time)))
            let integerSample = Int16(
                (clampedSample * Float(Int16.max)).rounded()
            )

            append(integerSample, to: &data)
        }

        return data
    }

    private static func append<Value: FixedWidthInteger>(
        _ value: Value,
        to data: inout Data
    ) {
        var littleEndianValue = value.littleEndian

        Swift.withUnsafeBytes(of: &littleEndianValue) { bytes in
            data.append(contentsOf: bytes)
        }
    }
}

private struct RepGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedReps: Int

    let onStart: (Int) -> Void

    private let suggestedGoals = [8, 10, 12, 15]

    var body: some View {
        ZStack {
            Color(red: 0.025, green: 0.035, blue: 0.055)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Set your rep goal")
                        .font(.title2.bold())

                    Text("Choose how many bicep curls you want to complete.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.62))
                }

                HStack(spacing: 10) {
                    ForEach(suggestedGoals, id: \.self) { goal in
                        Button {
                            selectedReps = goal
                        } label: {
                            Text("\(goal)")
                                .font(.headline.bold())
                                .foregroundStyle(
                                    selectedReps == goal ? .black : .white
                                )
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    selectedReps == goal
                                        ? .green
                                        : .white.opacity(0.10)
                                )
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: 15,
                                        style: .continuous
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Stepper(value: $selectedReps, in: 1...100) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Custom goal")
                            .font(.subheadline.weight(.semibold))

                        Text("\(selectedReps) reps")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                }
                .tint(.green)

                Button {
                    onStart(selectedReps)
                    dismiss()
                } label: {
                    Text("Start Workout")
                        .font(.headline.bold())
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(.green)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 18,
                                style: .continuous
                            )
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
    }
}

private struct WorkoutCompleteView: View {
    let repCount: Int
    let onRepeatSet: () -> Void
    let onChangeGoal: () -> Void
    let onFinish: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.025, green: 0.035, blue: 0.055)
                .ignoresSafeArea()

            RadialGradient(
                colors: [.green.opacity(0.20), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 430
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(.green.opacity(0.12))
                        .frame(width: 150, height: 150)

                    Circle()
                        .stroke(.green.opacity(0.28), lineWidth: 2)
                        .frame(width: 150, height: 150)

                    Image(systemName: "checkmark")
                        .font(.system(size: 58, weight: .black))
                        .foregroundStyle(.green)
                }

                Text("SET COMPLETE")
                    .font(.caption.bold())
                    .tracking(3)
                    .foregroundStyle(.green)
                    .padding(.top, 28)

                Text("Great work.")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 9)

                Text("You completed \(repCount) reps.")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.62))
                    .padding(.top, 7)

                Spacer()

                VStack(spacing: 12) {
                    Button(action: onRepeatSet) {
                        HStack(spacing: 13) {
                            Image(systemName: "arrow.clockwise")
                                .font(.headline.bold())

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Start Another Set")
                                    .font(.headline.bold())

                                Text("Repeat the \(repCount)-rep goal")
                                    .font(.caption)
                                    .opacity(0.68)
                            }

                            Spacer()

                            Image(systemName: "arrow.right")
                                .font(.headline.bold())
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)
                        .frame(height: 68)
                        .background(.green)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 21,
                                style: .continuous
                            )
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: onChangeGoal) {
                        Text("Choose a Different Goal")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(.white.opacity(0.10))
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 19,
                                    style: .continuous
                                )
                            )
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius: 19,
                                    style: .continuous
                                )
                                .stroke(.white.opacity(0.10), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)

                    Button(action: onFinish) {
                        Text("Finish Workout")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.65))
                            .frame(height: 44)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Pose Data

struct ArmPose: Sendable {
    var imageSize = CGSize.zero

    var leftShoulder: CGPoint?
    var leftElbow: CGPoint?
    var leftWrist: CGPoint?

    var rightShoulder: CGPoint?
    var rightElbow: CGPoint?
    var rightWrist: CGPoint?

    var leftArmConfidence: Float = 0
    var rightArmConfidence: Float = 0
    var leftWristIsDetected = false
    var rightWristIsDetected = false

    static let empty = ArmPose()

    var leftElbowAngle: CGFloat? {
        guard leftArmConfidence >= 0.25 else {
            return nil
        }

        return elbowAngle(
            shoulder: leftShoulder,
            elbow: leftElbow,
            wrist: leftWrist
        )
    }

    var rightElbowAngle: CGFloat? {
        guard rightArmConfidence >= 0.25 else {
            return nil
        }

        return elbowAngle(
            shoulder: rightShoulder,
            elbow: rightElbow,
            wrist: rightWrist
        )
    }

    private func elbowAngle(
        shoulder: CGPoint?,
        elbow: CGPoint?,
        wrist: CGPoint?
    ) -> CGFloat? {
        guard imageSize.width > 0,
              imageSize.height > 0,
              let shoulder,
              let elbow,
              let wrist else {
            return nil
        }

        let scaledShoulder = CGPoint(
            x: shoulder.x * imageSize.width,
            y: shoulder.y * imageSize.height
        )
        let scaledElbow = CGPoint(
            x: elbow.x * imageSize.width,
            y: elbow.y * imageSize.height
        )
        let scaledWrist = CGPoint(
            x: wrist.x * imageSize.width,
            y: wrist.y * imageSize.height
        )

        let upperArm = CGVector(
            dx: scaledShoulder.x - scaledElbow.x,
            dy: scaledShoulder.y - scaledElbow.y
        )
        let forearm = CGVector(
            dx: scaledWrist.x - scaledElbow.x,
            dy: scaledWrist.y - scaledElbow.y
        )

        let upperArmLength = hypot(upperArm.dx, upperArm.dy)
        let forearmLength = hypot(forearm.dx, forearm.dy)

        guard upperArmLength > 0,
              forearmLength > 0 else {
            return nil
        }

        let dotProduct = upperArm.dx * forearm.dx
            + upperArm.dy * forearm.dy
        let cosine = max(
            -1,
            min(1, dotProduct / (upperArmLength * forearmLength))
        )

        return acos(cosine) * 180 / CGFloat.pi
    }
}

private struct PoseFilter {
    private struct JointFilter {
        private var point: CGPoint?
        private var missingFrames = 0

        mutating func update(with newPoint: CGPoint?) -> CGPoint? {
            if let newPoint {
                if let point {
                    let smoothingFactor: CGFloat = 0.45
                    self.point = CGPoint(
                        x: point.x
                            + smoothingFactor * (newPoint.x - point.x),
                        y: point.y
                            + smoothingFactor * (newPoint.y - point.y)
                    )
                } else {
                    point = newPoint
                }

                missingFrames = 0
            } else if point != nil {
                missingFrames += 1

                if missingFrames > 8 {
                    point = nil
                    missingFrames = 0
                }
            }

            return point
        }

        mutating func reset() {
            point = nil
            missingFrames = 0
        }
    }

    private var imageSize = CGSize.zero
    private var leftShoulder = JointFilter()
    private var leftElbow = JointFilter()
    private var leftWrist = JointFilter()
    private var rightShoulder = JointFilter()
    private var rightElbow = JointFilter()
    private var rightWrist = JointFilter()
    private var leftArmConfidence: Float = 0
    private var rightArmConfidence: Float = 0

    mutating func process(_ pose: ArmPose) -> ArmPose {
        if pose.imageSize != .zero {
            imageSize = pose.imageSize
        }

        let filteredLeftShoulder = leftShoulder.update(
            with: pose.leftShoulder
        )
        let filteredLeftElbow = leftElbow.update(with: pose.leftElbow)
        let filteredLeftWrist = leftWrist.update(with: pose.leftWrist)
        let filteredRightShoulder = rightShoulder.update(
            with: pose.rightShoulder
        )
        let filteredRightElbow = rightElbow.update(with: pose.rightElbow)
        let filteredRightWrist = rightWrist.update(with: pose.rightWrist)

        leftArmConfidence = filteredConfidence(
            newConfidence: pose.leftArmConfidence,
            previousConfidence: leftArmConfidence,
            hasCompleteArm: filteredLeftShoulder != nil
                && filteredLeftElbow != nil
                && filteredLeftWrist != nil
        )
        rightArmConfidence = filteredConfidence(
            newConfidence: pose.rightArmConfidence,
            previousConfidence: rightArmConfidence,
            hasCompleteArm: filteredRightShoulder != nil
                && filteredRightElbow != nil
                && filteredRightWrist != nil
        )

        return ArmPose(
            imageSize: imageSize,
            leftShoulder: filteredLeftShoulder,
            leftElbow: filteredLeftElbow,
            leftWrist: filteredLeftWrist,
            rightShoulder: filteredRightShoulder,
            rightElbow: filteredRightElbow,
            rightWrist: filteredRightWrist,
            leftArmConfidence: leftArmConfidence,
            rightArmConfidence: rightArmConfidence,
            leftWristIsDetected: pose.leftWristIsDetected,
            rightWristIsDetected: pose.rightWristIsDetected
        )
    }

    mutating func reset() {
        imageSize = .zero
        leftShoulder.reset()
        leftElbow.reset()
        leftWrist.reset()
        rightShoulder.reset()
        rightElbow.reset()
        rightWrist.reset()
        leftArmConfidence = 0
        rightArmConfidence = 0
    }

    private func filteredConfidence(
        newConfidence: Float,
        previousConfidence: Float,
        hasCompleteArm: Bool
    ) -> Float {
        guard hasCompleteArm else {
            return 0
        }

        if newConfidence > 0.15 {
            return previousConfidence == 0
                ? newConfidence
                : previousConfidence * 0.4 + newConfidence * 0.6
        }

        return previousConfidence * 0.9
    }
}

// MARK: - Vision Processing

final class PoseProcessor:
    NSObject,
    AVCaptureVideoDataOutputSampleBufferDelegate,
    @unchecked Sendable {

    var onPose: (@Sendable (ArmPose) -> Void)?

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            onPose?(.empty)
            return
        }

        let imageSize = CGSize(
            width: CVPixelBufferGetHeight(pixelBuffer),
            height: CVPixelBufferGetWidth(pixelBuffer)
        )
        let request = VNDetectHumanBodyPoseRequest()

        let requestHandler = VNImageRequestHandler(
            cmSampleBuffer: sampleBuffer,
            orientation: .leftMirrored,
            options: [:]
        )

        do {
            try requestHandler.perform([request])

            guard let observation = request.results?.first else {
                onPose?(.empty)
                return
            }

            let recognizedPoints = try observation.recognizedPoints(.all)

            func location(
                for joint: VNHumanBodyPoseObservation.JointName
            ) -> CGPoint? {
                guard let point = recognizedPoints[joint],
                      point.confidence > 0.15 else {
                    return nil
                }

                // Vision's origin is bottom-left. AVFoundation uses top-left.
                return CGPoint(
                    x: 1 - point.location.x,
                    y: 1 - point.location.y
                )
            }

            func confidence(
                for joints: [VNHumanBodyPoseObservation.JointName]
            ) -> Float {
                joints.compactMap { recognizedPoints[$0]?.confidence }
                    .min() ?? 0
            }

            let leftWrist = location(for: .leftWrist)
            let rightWrist = location(for: .rightWrist)

            let pose = ArmPose(
                imageSize: imageSize,
                leftShoulder: location(for: .leftShoulder),
                leftElbow: location(for: .leftElbow),
                leftWrist: leftWrist,
                rightShoulder: location(for: .rightShoulder),
                rightElbow: location(for: .rightElbow),
                rightWrist: rightWrist,
                leftArmConfidence: confidence(
                    for: [.leftShoulder, .leftElbow, .leftWrist]
                ),
                rightArmConfidence: confidence(
                    for: [.rightShoulder, .rightElbow, .rightWrist]
                ),
                leftWristIsDetected: leftWrist != nil,
                rightWristIsDetected: rightWrist != nil
            )

            onPose?(pose)
        } catch {
            onPose?(.empty)
        }
    }
}

// MARK: - Camera

final class CameraModel:
    ObservableObject,
    @unchecked Sendable {

    let session = AVCaptureSession()

    @Published private(set) var message: String?
    @Published private(set) var pose = ArmPose.empty

    private let poseProcessor = PoseProcessor()
    private var poseFilter = PoseFilter()

    private let sessionQueue = DispatchQueue(
        label: "WorkoutCounter.camera",
        qos: .userInitiated
    )

    private var configured = false

    init() {
        poseProcessor.onPose = { [weak self] pose in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                self.pose = self.poseFilter.process(pose)
            }
        }
    }

    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession()

        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)

            if granted {
                startSession()
            } else {
                publishMessage(
                    "Camera access is required to count workouts."
                )
            }

        case .denied, .restricted:
            publishMessage("Enable camera access in Settings.")

        @unknown default:
            publishMessage("Camera access is unavailable.")
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }

            if self.session.isRunning {
                self.session.stopRunning()
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.poseFilter.reset()
            self?.pose = .empty
        }
    }

    private func startSession() {
        sessionQueue.async { [weak self] in
            self?.configureAndStart()
        }
    }

    private func configureAndStart() {
        if configured {
            if !session.isRunning {
                session.startRunning()
            }

            return
        }

        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ) else {
            publishMessage("No camera is available on this device.")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            let videoOutput = AVCaptureVideoDataOutput()

            videoOutput.alwaysDiscardsLateVideoFrames = true

            videoOutput.setSampleBufferDelegate(
                poseProcessor,
                queue: DispatchQueue(
                    label: "WorkoutCounter.pose",
                    qos: .userInitiated
                )
            )

            session.beginConfiguration()

            if session.canSetSessionPreset(.vga640x480) {
                session.sessionPreset = .vga640x480
            } else {
                session.sessionPreset = .high
            }

            guard session.canAddInput(input) else {
                session.commitConfiguration()
                publishMessage("The camera could not be connected.")
                return
            }

            guard session.canAddOutput(videoOutput) else {
                session.commitConfiguration()
                publishMessage("Camera frames could not be analyzed.")
                return
            }

            session.addInput(input)
            session.addOutput(videoOutput)
            session.commitConfiguration()

            configured = true
            publishMessage(nil)
            session.startRunning()
        } catch {
            publishMessage("The camera could not be started.")
        }
    }

    private func publishMessage(_ newMessage: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.message = newMessage
        }
    }
}

// MARK: - Camera Preview

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let pose: ArmPose
    let selectedArm: ExerciseArm?

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()

        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspect

        if let connection = view.previewLayer.connection,
           connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }

        return view
    }

    func updateUIView(
        _ uiView: PreviewView,
        context: Context
    ) {
        uiView.updatePose(
            pose,
            selectedArm: selectedArm
        )
    }
}

// MARK: - Pose Overlay

final class PreviewView: UIView {
    private let leftPoseLayer = CAShapeLayer()
    private let rightPoseLayer = CAShapeLayer()
    private var pose = ArmPose.empty
    private var selectedArm: ExerciseArm?

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configurePoseLayer(leftPoseLayer)
        configurePoseLayer(rightPoseLayer)

        layer.addSublayer(leftPoseLayer)
        layer.addSublayer(rightPoseLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        leftPoseLayer.frame = bounds
        rightPoseLayer.frame = bounds
        drawPose()
    }

    func updatePose(
        _ newPose: ArmPose,
        selectedArm: ExerciseArm?
    ) {
        pose = newPose
        self.selectedArm = selectedArm
        drawPose()
    }

    private func drawPose() {
        let leftPath = UIBezierPath()
        let rightPath = UIBezierPath()

        drawArm(
            shoulder: pose.leftShoulder,
            elbow: pose.leftElbow,
            wrist: pose.leftWrist,
            into: leftPath
        )

        drawArm(
            shoulder: pose.rightShoulder,
            elbow: pose.rightElbow,
            wrist: pose.rightWrist,
            into: rightPath
        )

        leftPoseLayer.path = leftPath.cgPath
        rightPoseLayer.path = rightPath.cgPath
        stylePoseLayers()
    }

    private func configurePoseLayer(_ poseLayer: CAShapeLayer) {
        poseLayer.strokeColor = UIColor.systemGreen.cgColor
        poseLayer.fillColor = UIColor.clear.cgColor
        poseLayer.lineWidth = 6
        poseLayer.lineCap = .round
        poseLayer.lineJoin = .round
    }

    private func stylePoseLayers() {
        guard let selectedArm else {
            styleActive(leftPoseLayer)
            styleActive(rightPoseLayer)
            return
        }

        style(
            leftPoseLayer,
            isActive: selectedArm == .left
        )
        style(
            rightPoseLayer,
            isActive: selectedArm == .right
        )
    }

    private func style(
        _ poseLayer: CAShapeLayer,
        isActive: Bool
    ) {
        if isActive {
            styleActive(poseLayer)
        } else {
            poseLayer.strokeColor = UIColor.systemGray.cgColor
            poseLayer.opacity = 0.22
            poseLayer.lineWidth = 4
        }
    }

    private func styleActive(_ poseLayer: CAShapeLayer) {
        poseLayer.strokeColor = UIColor.systemGreen.cgColor
        poseLayer.opacity = 1
        poseLayer.lineWidth = 6
    }

    private func drawArm(
        shoulder: CGPoint?,
        elbow: CGPoint?,
        wrist: CGPoint?,
        into path: UIBezierPath
    ) {
        let convertedShoulder = shoulder.map(convertToLayerPoint)
        let convertedElbow = elbow.map(convertToLayerPoint)
        let convertedWrist = wrist.map(convertToLayerPoint)

        if let convertedShoulder,
           let convertedElbow {
            path.move(to: convertedShoulder)
            path.addLine(to: convertedElbow)
        }

        if let convertedElbow,
           let convertedWrist {
            path.move(to: convertedElbow)
            path.addLine(to: convertedWrist)
        }

        for point in [
            convertedShoulder,
            convertedElbow,
            convertedWrist
        ].compactMap({ $0 }) {
            path.move(
                to: CGPoint(
                    x: point.x + 8,
                    y: point.y
                )
            )

            path.addArc(
                withCenter: point,
                radius: 8,
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: true
            )
        }
    }

    private func convertToLayerPoint(_ point: CGPoint) -> CGPoint {
        // Vision reports portrait-oriented points, but the preview layer
        // converts from the camera sensor's unrotated coordinate space.
        let captureDevicePoint = CGPoint(
            x: point.y,
            y: 1 - point.x
        )

        return previewLayer.layerPointConverted(
            fromCaptureDevicePoint: captureDevicePoint
        )
    }
}

#else

struct ContentView: View {
    var body: some View {
        Text("Workout Counter requires an iPhone.")
    }
}

#endif

#Preview {
    ContentView()
}
