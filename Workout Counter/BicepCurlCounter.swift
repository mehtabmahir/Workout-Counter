import Combine
import CoreGraphics
import Foundation

#if os(iOS)

enum ExerciseArm: Hashable, Sendable {
    case left
    case right
}

@MainActor
protocol ExerciseCounter: AnyObject, ObservableObject {
    var repCount: Int { get }

    func process(_ pose: ArmPose)
    func reset()
    func resetMovement()
}

@MainActor
final class BicepCurlCounter: ExerciseCounter {
    @Published private(set) var repCount = 0
    @Published private(set) var selectedArm: ExerciseArm?

    private enum Phase {
        case waitingForExtension
        case waitingForFlexion
    }

    private struct MotionSample {
        let point: CGPoint
        let angle: CGFloat
        let time: TimeInterval
    }

    // Use a forgiving range so camera perspective and natural partial motion
    // do not require a perfectly straight or fully closed elbow.
    private let extendedAngle: CGFloat = 130
    private let armSelectionAngle: CGFloat = 120
    private let flexedAngle: CGFloat = 100
    private let motionHistoryDuration = 0.6
    private let maximumInferenceAge = 0.4
    private let frameEdgeMargin: CGFloat = 0.22
    private let minimumCurlAngleChange: CGFloat = 12
    private let requiredStableFrames = 3
    private let requiredWristMissingFrames = 3
    private let maximumMissingFrames = 10
    private let minimumRepInterval = 0.5

    private var phase = Phase.waitingForExtension
    private var armedArms: Set<ExerciseArm> = []
    private var leftExtensionFrames = 0
    private var rightExtensionFrames = 0
    private var leftFlexionFrames = 0
    private var rightFlexionFrames = 0
    private var missingFrames = 0
    private var smoothedLeftAngle: CGFloat?
    private var smoothedRightAngle: CGFloat?
    private var leftMotionHistory: [MotionSample] = []
    private var rightMotionHistory: [MotionSample] = []
    private var selectedWristMissingFrames = 0
    private var lastRepTime = -Double.infinity

    func process(_ pose: ArmPose) {
        let measuredLeftAngle = pose.leftElbowAngle
        let measuredRightAngle = pose.rightElbowAngle
        let now = ProcessInfo.processInfo.systemUptime

        recordMotionSamples(
            from: pose,
            leftAngle: measuredLeftAngle,
            rightAngle: measuredRightAngle,
            at: now
        )

        let leftAngle = Self.smoothed(
            measuredLeftAngle,
            previous: &smoothedLeftAngle
        )
        let rightAngle = Self.smoothed(
            measuredRightAngle,
            previous: &smoothedRightAngle
        )

        switch phase {
        case .waitingForExtension:
            observeExtensions(
                leftAngle: leftAngle,
                rightAngle: rightAngle
            )

        case .waitingForFlexion:
            observeFlexions(
                leftAngle: leftAngle,
                rightAngle: rightAngle,
                pose: pose
            )
        }
    }

    func reset() {
        repCount = 0
        resetMovement()
    }

    func resetMovement() {
        phase = .waitingForExtension
        armedArms.removeAll()
        selectedArm = nil
        leftExtensionFrames = 0
        rightExtensionFrames = 0
        leftFlexionFrames = 0
        rightFlexionFrames = 0
        missingFrames = 0
        smoothedLeftAngle = nil
        smoothedRightAngle = nil
        leftMotionHistory.removeAll()
        rightMotionHistory.removeAll()
        selectedWristMissingFrames = 0
        lastRepTime = -Double.infinity
    }

    private func observeExtensions(
        leftAngle: CGFloat?,
        rightAngle: CGFloat?
    ) {
        updateArmedArms(
            leftAngle: leftAngle,
            rightAngle: rightAngle
        )

        if !armedArms.isEmpty {
            phase = .waitingForFlexion
            missingFrames = 0
        }
    }

    private func observeFlexions(
        leftAngle: CGFloat?,
        rightAngle: CGFloat?,
        pose: ArmPose
    ) {
        // Watch both extended arms only until one begins a clear curl.
        updateArmedArms(
            leftAngle: leftAngle,
            rightAngle: rightAngle
        )

        selectArmIfNeeded(
            leftAngle: leftMotionHistory.last?.angle ?? leftAngle,
            rightAngle: rightMotionHistory.last?.angle ?? rightAngle
        )

        guard let selectedArm else {
            return
        }

        updateSelectedWristMissingFrames(using: pose)

        let hasVisibleArmedArm =
            selectedArm == .left
                ? leftAngle != nil
                : rightAngle != nil

        if !hasVisibleArmedArm {
            missingFrames += 1

            if missingFrames > maximumMissingFrames {
                resetTransition()
            }

            return
        }

        missingFrames = 0

        if selectedArm == .left,
           let leftAngle,
           leftAngle <= flexedAngle {
            leftFlexionFrames += 1
        } else {
            leftFlexionFrames = 0
        }

        if selectedArm == .right,
           let rightAngle,
           rightAngle <= flexedAngle {
            rightFlexionFrames += 1
        } else {
            rightFlexionFrames = 0
        }

        let completedWithVisibleWrist =
            leftFlexionFrames >= requiredStableFrames
            || rightFlexionFrames >= requiredStableFrames
        let completedUsingMotionHistory = canCompleteFromMotionHistory(
            pose: pose,
            selectedArm: selectedArm
        )

        guard completedWithVisibleWrist
                || completedUsingMotionHistory else {
            return
        }

        let now = ProcessInfo.processInfo.systemUptime

        if now - lastRepTime >= minimumRepInterval {
            repCount += 1
            lastRepTime = now
        }

        resetTransition()
    }

    private func resetTransition() {
        phase = .waitingForExtension
        armedArms.removeAll()
        leftExtensionFrames = 0
        rightExtensionFrames = 0
        leftFlexionFrames = 0
        rightFlexionFrames = 0
        missingFrames = 0
        leftMotionHistory.removeAll()
        rightMotionHistory.removeAll()
        selectedWristMissingFrames = 0
    }

    private func recordMotionSamples(
        from pose: ArmPose,
        leftAngle: CGFloat?,
        rightAngle: CGFloat?,
        at time: TimeInterval
    ) {
        if pose.leftWristIsDetected,
           let point = pose.leftWrist,
           let leftAngle {
            leftMotionHistory.append(
                MotionSample(
                    point: point,
                    angle: leftAngle,
                    time: time
                )
            )
        }

        if pose.rightWristIsDetected,
           let point = pose.rightWrist,
           let rightAngle {
            rightMotionHistory.append(
                MotionSample(
                    point: point,
                    angle: rightAngle,
                    time: time
                )
            )
        }

        let oldestAllowedTime = time - motionHistoryDuration
        leftMotionHistory.removeAll { $0.time < oldestAllowedTime }
        rightMotionHistory.removeAll { $0.time < oldestAllowedTime }
    }

    private func updateSelectedWristMissingFrames(using pose: ArmPose) {
        let wristIsDetected = selectedArm == .left
            ? pose.leftWristIsDetected
            : pose.rightWristIsDetected

        selectedWristMissingFrames = wristIsDetected
            ? 0
            : selectedWristMissingFrames + 1
    }

    private func canCompleteFromMotionHistory(
        pose: ArmPose,
        selectedArm: ExerciseArm
    ) -> Bool {
        guard selectedWristMissingFrames >= requiredWristMissingFrames else {
            return false
        }

        let upperArmIsVisible = selectedArm == .left
            ? pose.leftShoulder != nil && pose.leftElbow != nil
            : pose.rightShoulder != nil && pose.rightElbow != nil

        guard upperArmIsVisible else {
            return false
        }

        let history = selectedArm == .left
            ? leftMotionHistory
            : rightMotionHistory

        guard history.count >= 2,
              let lastSample = history.last else {
            return false
        }

        let now = ProcessInfo.processInfo.systemUptime

        guard now - lastSample.time <= maximumInferenceAge,
              isNearFrameEdge(lastSample.point) else {
            return false
        }

        let largestRecentAngle = history.map(\.angle).max()
            ?? extendedAngle
        let observedAngleChange = max(
            extendedAngle,
            largestRecentAngle
        ) - lastSample.angle

        guard observedAngleChange >= minimumCurlAngleChange else {
            return false
        }

        let comparisonSample = history.dropLast().suffix(5).first
            ?? history[0]
        let lastEdgeDistance = distanceToNearestEdge(lastSample.point)
        let earlierEdgeDistance = distanceToNearestEdge(
            comparisonSample.point
        )
        let clearlyAtEdge = lastEdgeDistance <= 0.08
        let movedTowardEdge = lastEdgeDistance
            <= earlierEdgeDistance - 0.015

        return clearlyAtEdge || movedTowardEdge
    }

    private func isNearFrameEdge(_ point: CGPoint) -> Bool {
        distanceToNearestEdge(point) <= frameEdgeMargin
    }

    private func distanceToNearestEdge(_ point: CGPoint) -> CGFloat {
        min(
            point.x,
            1 - point.x,
            point.y,
            1 - point.y
        )
    }

    private func selectArmIfNeeded(
        leftAngle: CGFloat?,
        rightAngle: CGFloat?
    ) {
        guard selectedArm == nil else {
            return
        }

        var candidates: [(arm: ExerciseArm, angle: CGFloat)] = []

        if armedArms.contains(.left),
           let leftAngle,
           leftAngle <= armSelectionAngle {
            candidates.append((.left, leftAngle))
        }

        if armedArms.contains(.right),
           let rightAngle,
           rightAngle <= armSelectionAngle {
            candidates.append((.right, rightAngle))
        }

        guard let movingArm = candidates.min(
            by: { $0.angle < $1.angle }
        )?.arm else {
            return
        }

        selectedArm = movingArm
        armedArms = [movingArm]
        leftFlexionFrames = 0
        rightFlexionFrames = 0
        missingFrames = 0
    }

    private func updateArmedArms(
        leftAngle: CGFloat?,
        rightAngle: CGFloat?
    ) {
        leftExtensionFrames = Self.updatedExtensionFrames(
            angle: leftAngle,
            previousFrames: leftExtensionFrames,
            threshold: extendedAngle
        )
        rightExtensionFrames = Self.updatedExtensionFrames(
            angle: rightAngle,
            previousFrames: rightExtensionFrames,
            threshold: extendedAngle
        )

        let canTrackLeft = selectedArm == nil || selectedArm == .left
        let canTrackRight = selectedArm == nil || selectedArm == .right

        if canTrackLeft,
           leftExtensionFrames >= requiredStableFrames {
            armedArms.insert(.left)
        }

        if canTrackRight,
           rightExtensionFrames >= requiredStableFrames {
            armedArms.insert(.right)
        }
    }

    private static func updatedExtensionFrames(
        angle: CGFloat?,
        previousFrames: Int,
        threshold: CGFloat
    ) -> Int {
        guard let angle,
              angle >= threshold else {
            return 0
        }

        return previousFrames + 1
    }

    private static func smoothed(
        _ newAngle: CGFloat?,
        previous: inout CGFloat?
    ) -> CGFloat? {
        guard let newAngle else {
            return nil
        }

        let smoothingFactor: CGFloat = 0.3

        if let previousAngle = previous {
            previous = previousAngle
                + smoothingFactor * (newAngle - previousAngle)
        } else {
            previous = newAngle
        }

        return previous
    }
}

#endif
